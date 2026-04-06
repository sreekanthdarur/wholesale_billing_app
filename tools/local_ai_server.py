import base64
import io
import os
import re
import tempfile
from functools import lru_cache

import cv2
import numpy as np
from flask import Flask, jsonify, request
from PIL import Image
from google.cloud import vision

try:
    from paddleocr import PaddleOCR
except Exception:
    PaddleOCR = None

try:
    from faster_whisper import WhisperModel
except Exception:
    WhisperModel = None

HOST = os.environ.get("LOCAL_AI_HOST", "0.0.0.0")
PORT = int(os.environ.get("LOCAL_AI_PORT", "8099"))

WHISPER_SIZE = os.environ.get("WHISPER_MODEL_SIZE", "medium")
WHISPER_DEVICE = os.environ.get("WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE_TYPE = os.environ.get("WHISPER_COMPUTE_TYPE", "int8")

app = Flask(__name__)

def _google_document_ocr(image_bytes: bytes):
    client = vision.ImageAnnotatorClient()

def _json_error(message: str, status: int = 400):
    return jsonify({"ok": False, "message": message}), status


def _decode_base64_file(data: str) -> bytes:
    if "," in data and data.strip().startswith("data:"):
        data = data.split(",", 1)[1]
    return base64.b64decode(data)


def _load_rgb_image(image_bytes: bytes) -> np.ndarray:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_np = np.array(image)

    if image_np.shape[1] > 2200:
        scale = 2200 / image_np.shape[1]
        image_np = cv2.resize(
            image_np,
            None,
            fx=scale,
            fy=scale,
            interpolation=cv2.INTER_AREA,
        )

    return image_np


def _prepare_image_variants(image_bytes: bytes) -> dict[str, np.ndarray]:
    image_np = _load_rgb_image(image_bytes)
    gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)

    denoised = cv2.fastNlMeansDenoising(gray, None, 15, 7, 21)
    adaptive = cv2.adaptiveThreshold(
        denoised,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31,
        11,
    )

    soft = cv2.GaussianBlur(gray, (3, 3), 0)
    soft = cv2.convertScaleAbs(soft, alpha=1.35, beta=8)

    otsu = cv2.GaussianBlur(gray, (3, 3), 0)
    _, otsu = cv2.threshold(
        otsu,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )

    return {
        "adaptive": adaptive,
        "soft_gray": soft,
        "otsu": otsu,
        "original": image_np,
    }


def _normalize_ocr_lang(language: str) -> str:
    mapping = {
        "en": "en",
        "english": "en",
        "hi": "devanagari",
        "hindi": "devanagari",
        "te": "te",
        "telugu": "te",
        "kn": "ka",
        "kannada": "ka",
        "ka": "ka",
    }
    return mapping.get((language or "en").lower(), "en")


def _normalize_stt_lang(language: str):
    mapping = {
        "auto": None,
        "en": "en",
        "english": "en",
        "hi": "hi",
        "hindi": "hi",
        "te": "te",
        "telugu": "te",
        "kn": "kn",
        "kannada": "kn",
        "ka": "kn",
    }
    return mapping.get((language or "auto").lower(), None)


def _build_initial_prompt(language: str | None) -> str:
    common = (
        "This is a grocery billing dictation. "
        "Recognize item names, quantities, units and prices accurately. "
        "Common units: kg, kilo, ltr, litre, liter, pcs, piece, packet. "
        "Common items: rice, sugar, toor dal, oil, tamarind, salt, milk, curd, atta, "
        "chips, tea powder, coffee powder, biscuits, soap, detergent. "
        "Preserve numbers carefully."
    )

    if language == "te":
        return (
            common
            + " Telugu grocery words may appear: బియ్యం, రైస్, చక్కెర, షుగర్, పప్పు, నూనె, "
            + "ఉప్పు, పాలు, పెరుగు, కిలో, లీటర్, పీస్, రేటు."
        )

    if language == "hi":
        return (
            common
            + " Hindi grocery words may appear: चावल, राइस, चीनी, शुगर, दाल, तेल, नमक, "
            + "दूध, दही, किलो, लीटर, पीस, रुपये."
        )

    if language == "kn":
        return (
            common
            + " Kannada grocery words may appear: ಅಕ್ಕಿ, ರೈಸ್, ಸಕ್ಕರೆ, ಬೇಳೆ, ಎಣ್ಣೆ, ಉಪ್ಪು, "
            + "ಹಾಲು, ಮೊಸರು, ಕಿಲೋ, ಲೀಟರ್, ಪೀಸ್, ದರ."
        )

    return common


@lru_cache(maxsize=4)
def _get_ocr(lang: str):
    if PaddleOCR is None:
        raise RuntimeError("PaddleOCR is not installed")

    return PaddleOCR(
        use_angle_cls=True,
        lang=lang,
        show_log=False,
    )


@lru_cache(maxsize=1)
def _get_whisper():
    if WhisperModel is None:
        raise RuntimeError("faster-whisper is not installed")

    return WhisperModel(
        WHISPER_SIZE,
        device=WHISPER_DEVICE,
        compute_type=WHISPER_COMPUTE_TYPE,
    )


def _extract_text_from_paddle_result(result) -> tuple[str, float]:
    texts = []
    confidences = []

    if isinstance(result, list):
        for page in result:
            if not isinstance(page, list):
                continue
            for line in page:
                if not isinstance(line, (list, tuple)) or len(line) < 2:
                    continue
                rec = line[1]
                if isinstance(rec, (list, tuple)) and len(rec) >= 2:
                    text = str(rec[0]).strip()
                    conf = float(rec[1])
                    if text:
                        texts.append(text)
                        confidences.append(conf)

    joined = "\n".join(texts).strip()
    avg_conf = sum(confidences) / len(confidences) if confidences else 0.0
    return joined, avg_conf


def _flatten_ocr_lines(result) -> list[dict]:
    extracted = []

    if not isinstance(result, list):
        return extracted

    for page in result:
        if not isinstance(page, list):
            continue
        for line in page:
            if not isinstance(line, (list, tuple)) or len(line) < 2:
                continue

            box = line[0]
            rec = line[1]

            if not isinstance(rec, (list, tuple)) or len(rec) < 2:
                continue

            text = str(rec[0]).strip()
            conf = float(rec[1])

            if not text:
                continue

            try:
                xs = [p[0] for p in box]
                ys = [p[1] for p in box]
                x1, x2 = min(xs), max(xs)
                y1, y2 = min(ys), max(ys)
            except Exception:
                x1 = y1 = x2 = y2 = 0

            extracted.append(
                {
                    "text": text,
                    "confidence": conf,
                    "x1": float(x1),
                    "y1": float(y1),
                    "x2": float(x2),
                    "y2": float(y2),
                }
            )

    return extracted


def _looks_like_noise_line(text: str) -> bool:
    t = text.lower().strip()

    noise_patterns = [
        "invoice",
        "bill no",
        "phone",
        "mobile",
        "address",
        "gst",
        "fssai",
        "pin",
        "thank you",
        "welcome",
        "customer care",
        "www",
        ".com",
        "cash memo",
        "tax invoice",
        "date:",
        "time:",
    ]

    if any(p in t for p in noise_patterns):
        return True

    if len(t) <= 1:
        return True

    if re.fullmatch(r"[\d\W]+", t):
        return True

    return False


def _looks_like_item_line(text: str) -> bool:
    t = text.lower().strip()

    has_unit = bool(
        re.search(
            r"\b(kg|kgs|ltr|litre|liter|liters|litres|pcs|pc|piece|pieces|packet|packets|g|gm|grams?)\b",
            t,
        )
    )
    has_number = bool(re.search(r"\d", t))
    has_letters = bool(re.search(r"[a-zA-Z\u0900-\u097F\u0C00-\u0C7F\u0C80-\u0CFF]", t))

    if has_letters and has_number and has_unit:
        return True

    if has_letters and len(t.split()) >= 2 and has_number:
        return True

    return False


def _rank_item_line(text: str) -> int:
    t = text.lower().strip()
    score = 0

    if re.search(r"\b(kg|kgs|ltr|pcs|pc|g|gm)\b", t):
        score += 4
    if re.search(r"\d", t):
        score += 3
    if len(t.split()) >= 2:
        score += 2
    if not _looks_like_noise_line(t):
        score += 1

    return score


def _dedupe_preserve_order(lines: list[str]) -> list[str]:
    seen = set()
    result = []
    for line in lines:
        key = line.strip().lower()
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(line.strip())
    return result


def _crop_line_region(image: np.ndarray, line: dict) -> np.ndarray | None:
    h, w = image.shape[:2]
    x1 = max(0, int(line["x1"]) - 8)
    y1 = max(0, int(line["y1"]) - 6)
    x2 = min(w, int(line["x2"]) + 8)
    y2 = min(h, int(line["y2"]) + 6)

    if x2 <= x1 or y2 <= y1:
        return None

    return image[y1:y2, x1:x2].copy()


def _prepare_digit_retry_variants(crop: np.ndarray) -> list[np.ndarray]:
    variants = []

    if len(crop.shape) == 3:
        gray = cv2.cvtColor(crop, cv2.COLOR_RGB2GRAY)
    else:
        gray = crop

    enlarged = cv2.resize(gray, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
    variants.append(enlarged)

    blur = cv2.GaussianBlur(enlarged, (3, 3), 0)
    variants.append(cv2.convertScaleAbs(blur, alpha=1.4, beta=6))

    _, otsu = cv2.threshold(
        enlarged,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )
    variants.append(otsu)

    adaptive = cv2.adaptiveThreshold(
        enlarged,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        21,
        7,
    )
    variants.append(adaptive)

    return variants


def _best_line_retry_text(ocr_engine, crop: np.ndarray) -> tuple[str, float]:
    best_text = ""
    best_conf = 0.0

    for variant in _prepare_digit_retry_variants(crop):
        try:
            result = ocr_engine.ocr(variant, cls=True)
            text, conf = _extract_text_from_paddle_result(result)
        except Exception:
            continue

        text = text.strip()
        if not text:
            continue

        score = conf
        if re.search(r"\d", text):
            score += 0.4
        if re.search(r"\b(kg|kgs|ltr|pcs|pc|g|gm)\b", text.lower()):
            score += 0.2

        if score > best_conf:
            best_text = text
            best_conf = score

    return best_text, best_conf


def _recover_line_numbers(ocr_engine, original_rgb: np.ndarray, lines: list[dict]) -> list[str]:
    recovered = []

    for row in lines:
        base_text = row["text"].strip()
        chosen_text = base_text

        # Retry only when likely item line but numeric confidence is poor/missing
        needs_retry = (
            not re.search(r"\d", base_text)
            or not re.search(
                r"\b(kg|kgs|ltr|litre|liter|pcs|pc|piece|pieces|packet|packets|g|gm|grams?)\b",
                base_text.lower(),
            )
        )

        if needs_retry:
            crop = _crop_line_region(original_rgb, row)
            if crop is not None:
                retry_text, _ = _best_line_retry_text(ocr_engine, crop)
                if retry_text:
                    # Prefer retry text if it adds numbers or units
                    retry_has_digits = bool(re.search(r"\d", retry_text))
                    base_has_digits = bool(re.search(r"\d", base_text))
                    retry_has_units = bool(
                        re.search(
                            r"\b(kg|kgs|ltr|litre|liter|pcs|pc|piece|pieces|packet|packets|g|gm|grams?)\b",
                            retry_text.lower(),
                        )
                    )

                    if (retry_has_digits and not base_has_digits) or retry_has_units:
                        chosen_text = retry_text

        recovered.append(chosen_text.strip())

    return recovered


def _extract_contextual_bill_lines(
    ocr_engine,
    original_rgb: np.ndarray,
    all_lines: list[dict],
) -> list[str]:
    if not all_lines:
        return []

    sorted_lines = sorted(all_lines, key=lambda x: (x["y1"], x["x1"]))

    kept = []
    for row in sorted_lines:
        text = row["text"].strip()
        if _looks_like_noise_line(text):
            continue
        if _looks_like_item_line(text):
            kept.append(row)

    if not kept:
        return []

    recovered_lines = _recover_line_numbers(ocr_engine, original_rgb, kept)

    scored = []
    for text in recovered_lines:
        scored.append((text, _rank_item_line(text)))

    scored.sort(key=lambda x: x[1], reverse=True)
    scored_set = {x[0].lower().strip() for x in scored}

    ordered_ranked = []
    for text in recovered_lines:
        if text.lower().strip() in scored_set:
            ordered_ranked.append(text)

    return _dedupe_preserve_order(ordered_ranked)


def _post_process_transcript(text: str, language: str | None) -> str:
    cleaned = text.strip()

    replacements = {
        " k g ": " kg ",
        " kgs ": " kg ",
        " kilo gram ": " kg ",
        " litre ": " ltr ",
        " liter ": " ltr ",
        " lit er ": " ltr ",
        " pieces ": " pcs ",
        " piece ": " pcs ",
        " packets ": " pcs ",
        " packet ": " pcs ",
    }

    if language == "te":
        replacements.update(
            {
                " కిలో ": " kg ",
                " లీటర్ ": " ltr ",
                " పీస్ ": " pcs ",
                " రేటు ": " rate ",
            }
        )

    if language == "hi":
        replacements.update(
            {
                " किलो ": " kg ",
                " लीटर ": " ltr ",
                " पीस ": " pcs ",
                " रुपये ": " rate ",
                " रुपया ": " rate ",
            }
        )

    if language == "kn":
        replacements.update(
            {
                " ಕಿಲೋ ": " kg ",
                " ಲೀಟರ್ ": " ltr ",
                " ಪೀಸ್ ": " pcs ",
                " ದರ ": " rate ",
            }
        )

    normalized = f" {cleaned} "
    for src, dst in replacements.items():
        normalized = normalized.replace(src, dst)

    return " ".join(normalized.split()).strip()


@app.route("/health", methods=["GET", "POST"])
def health():
    return jsonify(
        {
            "ok": True,
            "ocr_ready": PaddleOCR is not None,
            "stt_ready": WhisperModel is not None,
            "message": "Local AI server running",
            "whisper_size": WHISPER_SIZE,
            "whisper_device": WHISPER_DEVICE,
            "whisper_compute_type": WHISPER_COMPUTE_TYPE,
        }
    )


@app.route("/ocr", methods=["POST"])
def ocr():
    payload = request.get_json(silent=True) or {}
    image_base64 = payload.get("image_base64")
    language = payload.get("language", "en")

    if not image_base64:
        return _json_error("image_base64 is required")

    try:
        image_bytes = _decode_base64_file(image_base64)
        variants = _prepare_image_variants(image_bytes)

        ocr_lang = _normalize_ocr_lang(language)
        ocr_engine = _get_ocr(ocr_lang)

        variant_results = []
        all_detected_lines = []

        for variant_name, image_variant in variants.items():
            result = ocr_engine.ocr(image_variant, cls=True)
            text, confidence = _extract_text_from_paddle_result(result)
            lines = _flatten_ocr_lines(result)

            variant_results.append(
                {
                    "variant": variant_name,
                    "text": text,
                    "confidence": confidence,
                    "lines": lines,
                }
            )
            all_detected_lines.extend(lines)

        best_variant = max(
            variant_results,
            key=lambda x: (x["confidence"], len(x["text"])),
            default={"text": "", "confidence": 0.0, "variant": "none"},
        )

        original_rgb = variants["original"]
        contextual_lines = _extract_contextual_bill_lines(
            ocr_engine,
            original_rgb,
            all_detected_lines,
        )
        contextual_text = "\n".join(contextual_lines).strip()

        final_text = contextual_text if contextual_text else best_variant["text"].strip()

        return jsonify(
            {
                "ok": True,
                "text": final_text,
                "raw_text": best_variant["text"].strip(),
                "contextual_text": contextual_text,
                "confidence": round(float(best_variant["confidence"]), 4),
                "language": ocr_lang,
                "best_variant": best_variant["variant"],
            }
        )
    except Exception as exc:
        return _json_error(f"OCR failed: {exc}", status=500)


@app.route("/transcribe", methods=["POST"])
def transcribe():
    payload = request.get_json(silent=True) or {}
    audio_base64 = payload.get("audio_base64")
    language = payload.get("language", "auto")
    file_ext = payload.get("file_ext", "wav")

    if not audio_base64:
        return _json_error("audio_base64 is required")

    tmp_path = None

    try:
        audio_bytes = _decode_base64_file(audio_base64)
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        whisper = _get_whisper()
        normalized_language = _normalize_stt_lang(language)
        initial_prompt = _build_initial_prompt(normalized_language)

        segments, info = whisper.transcribe(
            tmp_path,
            language=normalized_language,
            task="transcribe",
            vad_filter=True,
            vad_parameters={
                "min_silence_duration_ms": 400,
                "speech_pad_ms": 200,
            },
            beam_size=8,
            best_of=5,
            patience=1.2,
            temperature=0.0,
            compression_ratio_threshold=2.4,
            no_speech_threshold=0.45,
            condition_on_previous_text=False,
            initial_prompt=initial_prompt,
            word_timestamps=False,
        )

        segment_list = list(segments)
        raw_text = " ".join(segment.text.strip() for segment in segment_list).strip()
        text = _post_process_transcript(raw_text, normalized_language)

        confidence = 0.0
        if segment_list:
            probs = [float(getattr(seg, "avg_logprob", -1.0)) for seg in segment_list]
            confidence = max(0.0, min(1.0, 1.0 + (sum(probs) / len(probs))))

        return jsonify(
            {
                "ok": True,
                "text": text,
                "raw_text": raw_text,
                "language": getattr(info, "language", normalized_language or "auto"),
                "requested_language": normalized_language or "auto",
                "language_probability": float(getattr(info, "language_probability", 0.0)),
                "confidence": round(confidence, 4),
            }
        )
    except Exception as exc:
        return _json_error(f"Transcription failed: {exc}", status=500)
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass


if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=False)