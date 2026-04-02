import '../../core/constants/app_constants.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import '../../domain/models/missing_item_model.dart';
import '../repositories/item_repository.dart';
import 'invoice_line_merge_service.dart';
import 'item_alias_service.dart';

class VoiceParseResult {
  final DraftInvoiceModel draft;
  final List<MissingItemModel> missingItems;

  const VoiceParseResult({
    required this.draft,
    required this.missingItems,
  });
}

class VoiceParserService {
  final InvoiceLineMergeService _mergeService = invoiceLineMergeService;

  Future<VoiceParseResult> parseTranscript({
    required String transcript,
    String invoiceType = 'Cash',
    String customerName = 'Cash',
  }) async {
    final cleanedTranscript = cleanupTranscript(transcript);
    final dbItems = await itemRepository.getAll();
    final segments = _splitIntoItemSegments(cleanedTranscript, dbItems);

    final parsedLines = <InvoiceLineModel>[];
    final missingItems = <MissingItemModel>[];

    for (final segment in segments) {
      final alias = itemAliasService.match(segment, dbItems: dbItems);
      final unit = _detectUnit(segment, alias.unit ?? 'kg');
      final qty = _detectQuantity(segment);
      final explicitRate = _detectRate(segment, qty);

      if (alias.canonicalName != null) {
        parsedLines.add(
          InvoiceLineModel(
            itemName: alias.canonicalName!,
            qty: qty,
            unit: unit,
            rate: explicitRate ?? alias.defaultRate ?? 0,
            isCustomRate: explicitRate != null,
            needsReview: explicitRate == null,
            sourceText: segment,
          ),
        );
      } else {
        final guessedName = _extractUnknownItemName(segment);
        if (guessedName.isNotEmpty) {
          missingItems.add(
            MissingItemModel(
              itemName: guessedName,
              unit: unit,
              qty: qty,
              detectedRate: explicitRate,
              sourceText: segment,
            ),
          );
        }
      }
    }

    final merged = _mergeService.merge(parsedLines);

    final draft = DraftInvoiceModel(
      invoiceType: invoiceType,
      customerName: customerName,
      sourceMode: 'voice',
      notes: 'Draft generated from transcript',
      rawInputText: cleanedTranscript,
      invoiceDate: DateTime.now(),
      lines: merged.isEmpty
          ? [
        InvoiceLineModel(
          itemName: 'Review Item',
          qty: 1,
          unit: 'pcs',
          rate: 0,
          needsReview: true,
          sourceText: 'No confident voice parse',
        ),
      ]
          : merged,
    );

    return VoiceParseResult(
      draft: draft,
      missingItems: _dedupeMissing(missingItems),
    );
  }

  List<String> _splitIntoItemSegments(String transcript, List<ItemModel> dbItems) {
    final aliasPositions = <_AliasHit>[];
    final normalized = transcript.toLowerCase();

    final allAliases = <String>{};

    AppConstants.itemAliases.forEach((_, aliases) {
      allAliases.addAll(aliases.map((e) => e.toLowerCase()));
    });

    for (final item in dbItems) {
      allAliases.add(item.name.toLowerCase());
      allAliases.addAll(item.aliases.map((e) => e.toLowerCase()));
    }

    for (final alias in allAliases) {
      final idx = normalized.indexOf(alias);
      if (idx >= 0) {
        aliasPositions.add(_AliasHit(index: idx, alias: alias));
      }
    }

    aliasPositions.sort((a, b) => a.index.compareTo(b.index));

    if (aliasPositions.isEmpty) {
      return transcript
          .split(RegExp(r',|;|\n| and '))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final segments = <String>[];
    for (int i = 0; i < aliasPositions.length; i++) {
      final start = aliasPositions[i].index;
      final end = i < aliasPositions.length - 1
          ? aliasPositions[i + 1].index
          : transcript.length;

      final seg = transcript.substring(start, end).trim();
      if (seg.isNotEmpty) {
        segments.add(seg);
      }
    }

    return segments;
  }

  String _detectUnit(String text, String fallback) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(ltr|litre|liter|liters|litres)\b').hasMatch(t)) return 'ltr';
    if (RegExp(r'\b(kg|kgs|kilogram|kilograms)\b').hasMatch(t)) return 'kg';
    if (RegExp(r'\b(g|gm|gms|gram|grams)\b').hasMatch(t)) return 'g';
    if (RegExp(r'\b(pc|pcs|piece|pieces)\b').hasMatch(t)) return 'pcs';
    return fallback;
  }

  double _detectQuantity(String text) {
    final t = text.toLowerCase();

    final qtyWithUnit = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|kgs|kilogram|kilograms|ltr|litre|liter|liters|litres|g|gm|gms|gram|grams|pc|pcs|piece|pieces)\b',
    ).firstMatch(t);

    if (qtyWithUnit != null) {
      return double.tryParse(qtyWithUnit.group(1) ?? '') ?? 1.0;
    }

    final leadingQty = RegExp(r'^\s*(\d+(?:\.\d+)?)\b').firstMatch(t);
    if (leadingQty != null) {
      return double.tryParse(leadingQty.group(1) ?? '') ?? 1.0;
    }

    return 1.0;
  }

  double? _detectRate(String text, double qty) {
    final t = text.toLowerCase();

    final rateKeyword = RegExp(
      r'\b(?:rate|price)\s*(?:is\s*)?(\d+(?:\.\d+)?)\b',
    ).firstMatch(t);
    if (rateKeyword != null) {
      return double.tryParse(rateKeyword.group(1) ?? '');
    }

    final nums = RegExp(r'(\d+(?:\.\d+)?)')
        .allMatches(t)
        .map((m) => double.tryParse(m.group(1) ?? ''))
        .whereType<double>()
        .toList();

    if (nums.length <= 1) return null;

    final candidates = nums.where((n) => (n - qty).abs() > 0.0001).toList();
    if (candidates.isEmpty) return null;

    final bigCandidates = candidates.where((n) => n > 20).toList();
    if (bigCandidates.isNotEmpty) return bigCandidates.last;

    return candidates.last;
  }

  String _extractUnknownItemName(String text) {
    var t = text.toLowerCase();

    for (final noise in AppConstants.noiseWords) {
      t = t.replaceAll(RegExp('\\b$noise\\b'), ' ');
    }

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

  String cleanupTranscript(String value) {
    var text = value.toLowerCase();

    for (final noise in AppConstants.noiseWords) {
      text = text.replaceAll(RegExp('\\b$noise\\b'), ' ');
    }

    text = text
        .replaceAll(' one litre ', ' 1 ltr ')
        .replaceAll(' one liter ', ' 1 ltr ')
        .replaceAll(' one kg ', ' 1 kg ')
        .replaceAll(' two kg ', ' 2 kg ')
        .replaceAll(' three kg ', ' 3 kg ')
        .replaceAll(' four kg ', ' 4 kg ')
        .replaceAll(' five kg ', ' 5 kg ')
        .replaceAll(' litre', ' ltr')
        .replaceAll(' liter', ' ltr')
        .replaceAll(' litres', ' ltr')
        .replaceAll(' liters', ' ltr')
        .replaceAll(' kilograms', ' kg')
        .replaceAll(' kilogram', ' kg')
        .replaceAll(' kgs', ' kg')
        .replaceAll('&', ' and ')
        .replaceAll(' plus ', ' and ')
        .replaceAll(' then ', ' and ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  String appendTranscript({
    required String currentTranscript,
    required String newChunk,
  }) {
    final current = cleanupTranscript(currentTranscript).trim();
    final chunk = cleanupTranscript(newChunk).trim();

    if (chunk.isEmpty) return current;
    if (current.isEmpty) return chunk;

    if (current == chunk) return current;
    if (current.contains(chunk)) return current;
    if (chunk.contains(current)) return chunk;

    final overlap = _findSuffixPrefixOverlap(current, chunk);
    if (overlap > 0) {
      return '$current ${chunk.substring(overlap).trim()}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    return '$current $chunk'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _findSuffixPrefixOverlap(String a, String b) {
    final maxLen = a.length < b.length ? a.length : b.length;
    for (int len = maxLen; len >= 5; len--) {
      final aSuffix = a.substring(a.length - len).trim();
      final bPrefix = b.substring(0, len).trim();
      if (aSuffix == bPrefix) {
        return len;
      }
    }
    return 0;
  }
}

class _AliasHit {
  final int index;
  final String alias;

  _AliasHit({
    required this.index,
    required this.alias,
  });
}