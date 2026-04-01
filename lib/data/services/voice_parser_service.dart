import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';

class VoiceAliasItem {
  final String canonicalName;
  final String unit;
  final double defaultRate;
  final List<String> aliases;

  const VoiceAliasItem({
    required this.canonicalName,
    required this.unit,
    required this.defaultRate,
    required this.aliases,
  });
}

class VoiceParserResult {
  final DraftInvoiceModel draft;
  final List<String> warnings;

  const VoiceParserResult({
    required this.draft,
    required this.warnings,
  });
}

class VoiceParserService {
  static const List<VoiceAliasItem> _catalog = [
    VoiceAliasItem(
      canonicalName: 'Rice',
      unit: 'kg',
      defaultRate: 52,
      aliases: ['rice', 'biyyam', 'బియ్యం', 'akki', 'ಅಕ್ಕಿ', 'chawal', 'चावल'],
    ),
    VoiceAliasItem(
      canonicalName: 'Sugar',
      unit: 'kg',
      defaultRate: 45,
      aliases: [
        'sugar',
        'cheeni',
        'चीनी',
        'panchadara',
        'పంచదార',
        'sakkare',
        'ಸಕ್ಕರೆ'
      ],
    ),
    VoiceAliasItem(
      canonicalName: 'Toor Dal',
      unit: 'kg',
      defaultRate: 130,
      aliases: [
        'toor dal',
        'tur dal',
        'dal',
        'daal',
        'kandi pappu',
        'కంది పప్పు',
        'arhar dal',
        'अरहर दाल',
        'togari bele',
        'ತೊಗರಿ ಬೇಳೆ'
      ],
    ),
    VoiceAliasItem(
      canonicalName: 'Oil',
      unit: 'ltr',
      defaultRate: 120,
      aliases: ['oil', 'nune', 'నూనె', 'tel', 'तेल', 'enne', 'ಎಣ್ಣೆ'],
    ),
    VoiceAliasItem(
      canonicalName: 'Tamarind',
      unit: 'kg',
      defaultRate: 160,
      aliases: [
        'tamarind',
        'imli',
        'इमली',
        'chintapandu',
        'చింతపండు',
        'hunasehannu',
        'ಹುಣಸೆಹಣ್ಣು'
      ],
    ),
  ];

  static const Map<String, String> _unitAliases = {
    'kg': 'kg',
    'kgs': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'గ': 'g',
    'g': 'g',
    'gram': 'g',
    'grams': 'g',
    'ltr': 'ltr',
    'liter': 'ltr',
    'litre': 'ltr',
    'liters': 'ltr',
    'litres': 'ltr',
    'pcs': 'pcs',
    'piece': 'pcs',
    'pieces': 'pcs',
  };

  VoiceParserResult parseTranscript({
    required String transcript,
    String invoiceType = 'Cash',
    String customerName = 'Cash',
  }) {
    final warnings = <String>[];
    final normalized = _normalizeTranscript(transcript);
    final segments = _splitSegments(normalized);
    final lines = <InvoiceLineModel>[];

    for (final segment in segments) {
      final parsed = _parseSegment(segment);
      if (parsed != null) {
        lines.add(parsed);
      } else if (segment.trim().isNotEmpty) {
        warnings.add("Could not confidently parse segment: '$segment'");
        lines.add(
          InvoiceLineModel(
            itemName: 'Review Item',
            qty: 1,
            unit: 'pcs',
            rate: 0,
            needsReview: true,
            sourceText: segment,
          ),
        );
      }
    }

    if (lines.isEmpty) {
      warnings.add(
          'No valid invoice lines could be extracted from the transcript.');
      lines.add(
        InvoiceLineModel(
          itemName: 'Review Item',
          qty: 1,
          unit: 'pcs',
          rate: 0,
          needsReview: true,
          sourceText: transcript,
        ),
      );
    }

    final draft = DraftInvoiceModel(
      invoiceType: invoiceType,
      customerName: customerName,
      sourceMode: 'voice',
      notes: warnings.isEmpty
          ? 'Draft generated from voice transcript'
          : 'Draft generated from voice transcript with review warnings',
      rawInputText: transcript,
      invoiceDate: DateTime.now(),
      lines: lines,
    );

    return VoiceParserResult(draft: draft, warnings: warnings);
  }

  String _normalizeTranscript(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&', ' and ')
        .trim();
  }

  List<String> _splitSegments(String input) {
    final prepared = input
        .replaceAll(',', '|')
        .replaceAll(';', '|')
        .replaceAll(' and ', '|')
        .replaceAll('\n', '|');
    return prepared
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  InvoiceLineModel? _parseSegment(String segment) {
    final matchedItem = _findBestItem(segment);
    if (matchedItem == null) return null;

    final qty = _extractQuantity(segment) ?? 1;
    final unit = _extractUnit(segment) ?? matchedItem.unit;
    final explicitRate = _extractRate(segment, qty);
    final rate = explicitRate ?? matchedItem.defaultRate;

    return InvoiceLineModel(
      itemName: matchedItem.canonicalName,
      qty: qty,
      unit: unit,
      rate: rate,
      isCustomRate: explicitRate != null,
      needsReview: false,
      sourceText: segment,
    );
  }

  VoiceAliasItem? _findBestItem(String segment) {
    VoiceAliasItem? best;
    int bestScore = 0;
    for (final item in _catalog) {
      for (final alias in item.aliases) {
        if (segment.contains(alias) && alias.length > bestScore) {
          best = item;
          bestScore = alias.length;
        }
      }
    }
    return best;
  }

  double? _extractQuantity(String segment) {
    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(segment).toList();
    if (matches.isEmpty) return null;
    return double.tryParse(matches.first.group(1)!);
  }

  String? _extractUnit(String segment) {
    for (final entry in _unitAliases.entries) {
      if (segment.contains(entry.key)) return entry.value;
    }
    return null;
  }

  double? _extractRate(String segment, double qty) {
    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(segment).toList();
    if (matches.length < 2) return null;
    final lastValue = double.tryParse(matches.last.group(1)!);
    if (lastValue == null || lastValue == qty) return null;
    return lastValue;
  }
}
