import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/constants/local_ai_config.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/missing_item_model.dart';
import '../repositories/item_repository.dart';
import 'invoice_line_merge_service.dart';
import 'item_alias_service.dart';
import 'local_ai_bridge_service.dart';

class OcrParseResult {
  final DraftInvoiceModel draft;
  final List<MissingItemModel> missingItems;

  const OcrParseResult({required this.draft, required this.missingItems});
}

class CameraOcrService {
  final TextRecognizer _recognizer = TextRecognizer();
  final InvoiceLineMergeService _mergeService = invoiceLineMergeService;
  final LocalAiBridgeService _localAiBridgeService = LocalAiBridgeService();

  Future<LocalAiHealthResult> healthCheck() {
    return _localAiBridgeService.healthCheck();
  }

  Future<String> extractTextFromImage(
    String imagePath, {
    String language = 'en',
    bool preferLocal = true,
  }) async {
    if (preferLocal && LocalAiConfig.enabled) {
      final localResult = await _localAiBridgeService.extractTextFromImage(
        imagePath: imagePath,
        language: language,
      );

      if (localResult != null && localResult.text.trim().isNotEmpty) {
        return localResult.text.trim();
      }
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);
    return recognized.text.trim();
  }

  Future<OcrParseResult> parseOcrText({
    required String ocrText,
    String invoiceType = 'Cash',
    String customerName = 'Cash',
  }) async {
    final cleanedLines = _stitchBrokenLines(_cleanLines(ocrText));
    final dbItems = await itemRepository.getAll();
    final parsedLines = <InvoiceLineModel>[];
    final missingItems = <MissingItemModel>[];

    for (final line in cleanedLines) {
      if (_skipLine(line)) {
        continue;
      }

      final alias = itemAliasService.match(line, dbItems: dbItems);
      final unit = _detectUnit(line, alias.unit ?? 'kg');
      final qty = _detectQuantity(line);
      final rate = _detectRate(line, qty);

      if (alias.canonicalName != null) {
        if (_hasMeaningfulNumbers(line)) {
          parsedLines.add(
            InvoiceLineModel(
              itemName: alias.canonicalName!,
              qty: qty,
              unit: unit,
              rate: rate ?? alias.defaultRate ?? 0,
              isCustomRate: rate != null,
              needsReview: rate == null,
              sourceText: line,
            ),
          );
        } else {
          missingItems.add(
            MissingItemModel(
              itemName: alias.canonicalName!,
              unit: unit,
              qty: qty,
              detectedRate: rate,
              sourceText: line,
            ),
          );
        }
      } else {
        final guessedName = _extractUnknownItemName(line);
        if (guessedName.isNotEmpty) {
          missingItems.add(
            MissingItemModel(
              itemName: guessedName,
              unit: unit,
              qty: qty,
              detectedRate: rate,
              sourceText: line,
            ),
          );
        }
      }
    }

    final merged = _mergeService.merge(parsedLines);

    final draft = DraftInvoiceModel(
      invoiceType: invoiceType,
      customerName: customerName,
      sourceMode: 'camera',
      notes: 'Draft generated from OCR',
      rawInputText: cleanedLines.join('\n'),
      invoiceDate: DateTime.now(),
      lines: merged.isEmpty
          ? [
              InvoiceLineModel(
                itemName: 'Review Item',
                qty: 1,
                unit: 'pcs',
                rate: 0,
                needsReview: true,
                sourceText: 'No confident OCR parse',
              ),
            ]
          : merged,
    );

    return OcrParseResult(
      draft: draft,
      missingItems: _dedupeMissing(missingItems),
    );
  }

  List<String> _cleanLines(String ocrText) {
    return ocrText
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !RegExp(r'^\d{1,2}:\d{1,2}$').hasMatch(e))
        .map(
          (e) => e
              .replaceAll(RegExp(r'/-'), '')
              .replaceAll('Rs.', '')
              .replaceAll('Rs', '')
              .replaceAll('₹', '')
              .replaceAll('per', ' ')
              .replaceAll('KGS', ' kg ')
              .replaceAll('Kgs', ' kg ')
              .replaceAll('kgs', ' kg ')
              .replaceAll('KG', ' kg ')
              .replaceAll('kg', ' kg ')
              .replaceAll('LTR', ' ltr ')
              .replaceAll('Ltr', ' ltr ')
              .replaceAll('ltr', ' ltr ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        )
        .toList();
  }

  List<String> _stitchBrokenLines(List<String> lines) {
    final result = <String>[];
    int i = 0;

    while (i < lines.length) {
      final current = lines[i];

      if (i < lines.length - 1) {
        final next = lines[i + 1];
        final combined = '$current $next'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (_looksLikeSplitItem(current, next)) {
          result.add(combined);
          i += 2;
          continue;
        }
      }

      result.add(current);
      i++;
    }

    return result;
  }

  bool _looksLikeSplitItem(String a, String b) {
    final first = a.toLowerCase();
    final second = b.toLowerCase();

    if (RegExp(r'^[a-zA-Z]+$').hasMatch(first) &&
        RegExp(r'^[a-zA-Z]+$').hasMatch(second)) {
      return true;
    }

    if (!RegExp(r'\d').hasMatch(first) && RegExp(r'\d').hasMatch(second)) {
      return true;
    }

    return false;
  }

  bool _skipLine(String text) {
    final t = text.toLowerCase();
    return t.contains('invoice no') ||
        t.contains('bill no') ||
        t.contains('subtotal') ||
        t.contains('sub total') ||
        t.contains('grand total') ||
        t == 'total' ||
        t.startsWith('total ') ||
        t.contains('gst') ||
        t.contains('cgst') ||
        t.contains('sgst') ||
        t.contains('phone') ||
        t.contains('mobile');
  }

  bool _hasMeaningfulNumbers(String text) {
    return RegExp(r'\d').hasMatch(text);
  }

  String _detectUnit(String text, String fallback) {
    final t = text.toLowerCase();

    if (RegExp(r'\b(ltr|litre|liter|liters|litres)\b').hasMatch(t)) {
      return 'ltr';
    }
    if (RegExp(r'\b(kg|kgs|kilogram|kilograms)\b').hasMatch(t)) {
      return 'kg';
    }
    if (RegExp(r'\b(g|gm|gms|gram|grams)\b').hasMatch(t)) {
      return 'g';
    }
    if (RegExp(r'\b(pc|pcs|piece|pieces)\b').hasMatch(t)) {
      return 'pcs';
    }

    return fallback;
  }

  double _detectQuantity(String text) {
    final t = text.toLowerCase();

    if (RegExp(r'\bhalf\b').hasMatch(t)) {
      return 0.5;
    }

    final qtyWithUnit = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|kgs|kilogram|kilograms|ltr|litre|liter|liters|litres|g|gm|gms|gram|grams|pc|pcs|piece|pieces)\b',
    ).firstMatch(t);

    if (qtyWithUnit != null) {
      return double.tryParse(qtyWithUnit.group(1) ?? '') ?? 1.0;
    }

    final allNumbers = RegExp(r'(\d+(?:\.\d+)?)').allMatches(t).toList();
    if (allNumbers.isNotEmpty) {
      return double.tryParse(allNumbers.first.group(1) ?? '') ?? 1.0;
    }

    return 1.0;
  }

  double? _detectRate(String text, double qty) {
    final t = text.toLowerCase();
    final numbers = RegExp(r'(\d+(?:\.\d+)?)')
        .allMatches(t)
        .map((m) => double.tryParse(m.group(1) ?? ''))
        .whereType<double>()
        .toList();

    if (numbers.length <= 1) return null;

    final candidates = numbers.where((n) => (n - qty).abs() > 0.0001).toList();
    if (candidates.isEmpty) return null;

    final bigCandidates = candidates.where((n) => n > 20).toList();
    if (bigCandidates.isNotEmpty) {
      return bigCandidates.last;
    }

    return candidates.last;
  }

  String _extractUnknownItemName(String text) {
    var t = text.toLowerCase();

    t = t
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), ' ')
        .replaceAll(
          RegExp(
            r'\b(kg|kgs|kilogram|kilograms|ltr|litre|liter|liters|litres|g|gm|gms|gram|grams|pc|pcs|piece|pieces|rate|price)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (t.isEmpty) return '';

    return t
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  List<MissingItemModel> _dedupeMissing(List<MissingItemModel> items) {
    final map = <String, MissingItemModel>{};

    for (final item in items) {
      final key = item.itemName.trim().toLowerCase();
      map[key] = item;
    }

    return map.values.toList();
  }

  Future<void> dispose() async {
    await _recognizer.close();
    _localAiBridgeService.dispose();
  }
}
