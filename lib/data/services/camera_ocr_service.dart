import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import 'voice_parser_service.dart';

class CameraOcrResult {
  final DraftInvoiceModel draft;
  final List<String> warnings;
  final String extractedText;

  const CameraOcrResult({
    required this.draft,
    required this.warnings,
    required this.extractedText,
  });
}

class CameraOcrService {
  final TextRecognizer _recognizer = TextRecognizer();
  final VoiceParserService _voiceParser = VoiceParserService();

  Future<String> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text.trim();
  }

  CameraOcrResult parseOcrText({
    required String ocrText,
    String invoiceType = 'Cash',
    String customerName = 'Cash',
  }) {
    final warnings = <String>[];
    final cleanedLines = _cleanLines(ocrText);
    final parsedLines = <InvoiceLineModel>[];

    for (final line in cleanedLines) {
      final structured = _parseStructuredLine(line);
      if (structured != null) {
        parsedLines.add(structured);
        continue;
      }

      final fallback = _voiceParser.parseTranscript(
        transcript: line,
        invoiceType: invoiceType,
        customerName: customerName,
      );

      if (fallback.draft.lines.isNotEmpty) {
        parsedLines.addAll(
          fallback.draft.lines.map((e) => e.copyWith(sourceText: line)),
        );
      } else {
        warnings.add("Could not parse OCR line: '$line'");
      }
    }

    if (parsedLines.isEmpty) {
      parsedLines.add(
        InvoiceLineModel(
          itemName: 'Review Item',
          qty: 1,
          unit: 'pcs',
          rate: 0,
          needsReview: true,
          sourceText: ocrText,
        ),
      );
      warnings.add('No valid OCR lines were extracted.');
    }

    final normalizedText = cleanedLines.join('\n');

    return CameraOcrResult(
      extractedText: normalizedText,
      warnings: warnings,
      draft: DraftInvoiceModel(
        invoiceType: invoiceType,
        customerName: customerName,
        sourceMode: 'camera',
        notes: warnings.isEmpty
            ? 'Draft generated from OCR'
            : 'Draft generated from OCR with review warnings',
        rawInputText: normalizedText,
        invoiceDate: DateTime.now(),
        lines: parsedLines,
      ),
    );
  }

  List<String> _cleanLines(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final cleaned = <String>[];

    for (var line in lines) {
      var value = line.trim();
      if (value.isEmpty) continue;

      if (RegExp(r'^\d{1,2}:\s*\d{1,2}$').hasMatch(value)) continue;

      if (RegExp(r'^[A-Za-z0-9]{4,}\s+[A-Za-z0-9]{4,}$').hasMatch(value) &&
          !value.toLowerCase().contains('kg')) {
        continue;
      }

      value = value.replaceAll('—', '-');
      value = value.replaceAll('–', '-');
      value = value.replaceAll(
        RegExp(r'(?<=\d)(kgs?)', caseSensitive: false),
        ' kg',
      );
      value = value.replaceAll(RegExp(r'/-'), '');
      value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (value.isNotEmpty) cleaned.add(value);
    }

    return cleaned;
  }

  InvoiceLineModel? _parseStructuredLine(String line) {
    final normalized = line.toLowerCase();

    final match = RegExp(
      r'^([a-zA-Z ]+?)\s*-?\s*(\d+(?:\.\d+)?)\s*(kg|kgs|ltr|litre|liter|pcs|piece|pieces)?\s*(\d+(?:\.\d+)?)?$',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match == null) return null;

    final rawName = (match.group(1) ?? '').trim();
    final qty = double.tryParse(match.group(2) ?? '') ?? 1;
    final rawUnit = (match.group(3) ?? 'kg').toLowerCase();
    final price = double.tryParse(match.group(4) ?? '');

    final name = _normalizeItemName(rawName);
    final unit = _normalizeUnit(rawUnit);
    final rate = price ?? _defaultRate(name);

    return InvoiceLineModel(
      itemName: name,
      qty: qty,
      unit: unit,
      rate: rate,
      isCustomRate: price != null,
      needsReview: price == null,
      sourceText: line,
    );
  }

  String _normalizeItemName(String raw) {
    final cleaned = raw.trim().toLowerCase();

    if (cleaned.contains('rice')) return 'Rice';
    if (cleaned.contains('daal') || cleaned.contains('dal')) return 'Toor Dal';
    if (cleaned.contains('tamrin') ||
        cleaned.contains('tamarin') ||
        cleaned.contains('tamarind')) {
      return 'Tamarind';
    }
    if (cleaned.contains('oil')) return 'Oil';
    if (cleaned.contains('sugar')) return 'Sugar';

    return raw.trim().isEmpty ? 'Review Item' : raw.trim();
  }

  String _normalizeUnit(String rawUnit) {
    if (rawUnit.startsWith('kg')) return 'kg';
    if (rawUnit.startsWith('ltr') || rawUnit.startsWith('lit')) return 'ltr';
    if (rawUnit.startsWith('pc') || rawUnit.startsWith('piece')) return 'pcs';
    return 'kg';
  }

  double _defaultRate(String itemName) {
    switch (itemName) {
      case 'Rice':
        return 70;
      case 'Toor Dal':
        return 650;
      case 'Tamarind':
        return 28;
      case 'Oil':
        return 120;
      case 'Sugar':
        return 45;
      default:
        return 0;
    }
  }

  Future<CameraOcrResult> processImage({
    required String imagePath,
    String invoiceType = 'Cash',
    String customerName = 'Cash',
  }) async {
    final text = await extractTextFromImage(imagePath);
    return parseOcrText(
      ocrText: text,
      invoiceType: invoiceType,
      customerName: customerName,
    );
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}