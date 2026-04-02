import base64
import io
import os
import tempfile
from functools import lru_cache

import cv2
import numpy as np
from flask import Flask, jsonify, request
from PIL import Image

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
WHISPER_SIZE = os.environ.get("WHISPER_MODEL_SIZE", "small")
WHISPER_DEVICE = os.environ.get("WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE_TYPE = os.environ.get("WHISPER_COMPUTE_TYPE", "int8")

app = Flask(__name__)


def _json_error(message: str, status: int = 400):
    return jsonify({"ok": False, "message": message}), status


def _decode_base64_file(data: str) -> bytes:
    if "," in data and data.strip().startswith("data:"):
        data = data.split(",", 1)[1]
    return base64.b64decode(data)


def _prepare_image_bytes(image_bytes: bytes) -> np.ndarray:
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

    gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)
    gray = cv2.fastNlMeansDenoising(gray, None, 15, 7, 21)
    enhanced = cv2.adaptiveThreshold(
        gray,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31,
        11,
    )
    return enhanced


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


@app.route("/health", methods=["GET", "POST"])
def health():
    return jsonify(
        {
            "ok": True,
            "ocr_ready": PaddleOCR is not None,
            "stt_ready": WhisperModel is not None,
            "message": "Local AI server running",
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
        prepared = _prepare_image_bytes(image_bytes)

        ocr_lang = _normalize_ocr_lang(language)
        ocr_engine = _get_ocr(ocr_lang)
        result = ocr_engine.ocr(prepared, cls=True)
        text, confidence = _extract_text_from_paddle_result(result)

        if not text.strip():
            original = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
            fallback_result = ocr_engine.ocr(original, cls=True)
            text, confidence = _extract_text_from_paddle_result(fallback_result)

        return jsonify(
            {
                "ok": True,
                "text": text.strip(),
                "confidence": round(confidence, 4),
                "language": ocr_lang,
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
        segments, info = whisper.transcribe(
            tmp_path,
            language=normalized_language,
            vad_filter=True,
            beam_size=5,
            condition_on_previous_text=False,
        )

        segment_list = list(segments)
        text = " ".join(segment.text.strip() for segment in segment_list).strip()
        confidence = 0.0
        if segment_list:
            probs = [float(getattr(seg, "avg_logprob", -1.0)) for seg in segment_list]
            confidence = max(0.0, min(1.0, 1.0 + (sum(probs) / len(probs))))

        return jsonify(
            {
                "ok": True,
                "text": text,
                "language": getattr(info, "language", normalized_language or "auto"),
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
