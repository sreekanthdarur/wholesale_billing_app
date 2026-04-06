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

  const VoiceParseResult({required this.draft, required this.missingItems});
}

class VoiceParserService {
  final InvoiceLineMergeService _mergeService = invoiceLineMergeService;

  static const Map<String, String> _wordReplacements = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'half': '0.5',
    'quarter': '0.25',
    'ek': '1',
    'do': '2',
    'teen': '3',
    'char': '4',
    'paanch': '5',
    'aadha': '0.5',
    'oka': '1',
    'okati': '1',
    'rendu': '2',
    'moodu': '3',
    'nalugu': '4',
    'aidu': '5',
    'ardha': '0.5',
    'ondu': '1',
    'eradu': '2',
    'mooru': '3',
    'naalku': '4',
    'aidu_kn': '5',
    'ardha_kn': '0.5',
  };

  static const Map<String, String> _scriptNormalization = {
    // Hindi
    'राइस': 'rice',
    'चावल': 'rice',
    'शुगर': 'sugar',
    'चीनी': 'sugar',
    'शक्कर': 'sugar',
    'चिप्स': 'chips',
    'तेल': 'oil',
    'दाल': 'dal',
    'तूर दाल': 'toor dal',
    'अरहर दाल': 'toor dal',
    'नमक': 'salt',
    'दूध': 'milk',
    'दही': 'curd',
    'आटा': 'atta',
    'साबुन': 'soap',
    'बिस्किट': 'biscuits',
    'कॉफी': 'coffee powder',
    'चाय पत्ती': 'tea powder',
    'डिटर्जेंट': 'detergent',
    'इमली': 'tamarind',
    'लाल मिर्च': 'red chilli',
    'मिर्च': 'chilli',
    'लालमिर्च': 'red chilli',
    'केजी': 'kg',
    'किलो': 'kg',
    'किग्रा': 'kg',
    'लीटर': 'ltr',
    'पीस': 'pcs',
    'पैकेट': 'pcs',
    'रुपये': 'rate',
    'रुपया': 'rate',

    // Telugu
    'బియ్యం': 'rice',
    'రైస్': 'rice',
    'చక్కెర': 'sugar',
    'షుగర్': 'sugar',
    'చిప్స్': 'chips',
    'నూనె': 'oil',
    'పప్పు': 'dal',
    'కందిపప్పు': 'toor dal',
    'ఉప్పు': 'salt',
    'పాలు': 'milk',
    'పెరుగు': 'curd',
    'పిండి': 'atta',
    'సబ్బు': 'soap',
    'బిస్కెట్': 'biscuits',
    'కాఫీ': 'coffee powder',
    'టీ పొడి': 'tea powder',
    'చింతపండు': 'tamarind',
    'ఎర్ర మిర్చి': 'red chilli',
    'మిర్చి': 'chilli',
    'సంతూర్ సబ్బు': 'santoor soap',
    'సండూర్ సబ్బు': 'santoor soap',
    'కిలో': 'kg',
    'లీటర్': 'ltr',
    'పీస్': 'pcs',
    'ప్యాకెట్': 'pcs',
    'రేటు': 'rate',

    // Kannada
    'ಸಕ್ಕರೆ': 'sugar',
    'ಅಕ್ಕಿ': 'rice',
    'ರೈಸ್': 'rice',
    'ಚಿಪ್ಸ್': 'chips',
    'ಎಣ್ಣೆ': 'oil',
    'ಬೇಳೆ': 'dal',
    'ತೊಗರಿ ಬೇಳೆ': 'toor dal',
    'ಉಪ್ಪು': 'salt',
    'ಹಾಲು': 'milk',
    'ಮೊಸರು': 'curd',
    'ಹಿಟ್ಟು': 'atta',
    'ಸಾಬೂನು': 'soap',
    'ಬಿಸ್ಕಟ್': 'biscuits',
    'ಕಾಫಿ': 'coffee powder',
    'ಟೀ ಪುಡಿ': 'tea powder',
    'ಹುಣಸೆಹಣ್ಣು': 'tamarind',
    'ಕೆಂಪು ಮೆಣಸಿನಕಾಯಿ': 'red chilli',
    'ಮೆಣಸಿನಕಾಯಿ': 'chilli',
    'ಕಿಲೋ': 'kg',
    'ಲೀಟರ್': 'ltr',
    'ಪೀಸ್': 'pcs',
    'ಪ್ಯಾಕೆಟ್': 'pcs',
    'ದರ': 'rate',

    // Phonetic / mixed
    'imli': 'tamarind',
    'lal mirch': 'red chilli',
    'red mirchi': 'red chilli',
    'santoor sabbu': 'santoor soap',
    'sandhoor sabbu': 'santoor soap',
    'sandur sabbu': 'santoor soap',
    'sabbu': 'soap',
    'kandi pappu': 'toor dal',
    'kandipappu': 'toor dal',
    'kandi ballu': 'toor dal',
    'kandiballu': 'toor dal',
    'kandi belu': 'toor dal',
    'tur dal': 'toor dal',
    'toor daal': 'toor dal',
    'arhar dal': 'toor dal',
  };

  static const Set<String> _noiseTokens = {
    'kg',
    'kgs',
    'ltr',
    'g',
    'gm',
    'pcs',
    'piece',
    'pieces',
    'packet',
    'packets',
    'rate',
    'price',
    'amt',
    'amount',
    'rupees',
    'rs',
    'rupaye',
    'rupaya',
    'kilo',
    'kilogram',
    'litre',
    'liter',
    'liters',
    'litres',
    'gram',
    'grams',
    'ke',
    'ko',
    'ka',
    'ki',
    'de',
    'dijiye',
    'dijie',
    'kejiye',
    'kijiye',
    'please',
    'plz',
    'andi',
    'ivvu',
    'ivvandi',
    'kodi',
    'और',
    'दे',
    'दीजिए',
    'दिजिए',
    'केजिए',
    'ಕೊಡಿ',
    'మరియు',
    'aur',
    'mariyu',
    'mattu',
    'phir',
    'tarvata',
    'aamele',
    'next',
    'and',
  };

  String normalizeForDisplay(String value) {
    return _normalizeForMatching(value);
  }

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

    for (final rawSegment in segments) {
      final segment = _normalizeForMatching(rawSegment);
      if (segment.trim().isEmpty) continue;

      final alias = itemAliasService.match(segment, dbItems: dbItems);
      final unit = _detectUnit(segment, alias.unit ?? 'kg');
      final qty = _detectQuantity(segment);
      final explicitRate = _detectRate(segment, qty);

      if (alias.canonicalName != null) {
        final resolvedRate = explicitRate ?? alias.defaultRate ?? 0;

        if (resolvedRate > 0) {
          parsedLines.add(
            InvoiceLineModel(
              itemName: alias.canonicalName!,
              qty: qty > 0 ? qty : 1,
              unit: unit,
              rate: resolvedRate,
              isCustomRate: explicitRate != null,
              needsReview: explicitRate == null,
              sourceText: rawSegment,
            ),
          );
        } else {
          missingItems.add(
            MissingItemModel(
              itemName: alias.canonicalName!,
              unit: unit,
              qty: qty > 0 ? qty : 1,
              detectedRate: explicitRate,
              sourceText: rawSegment,
            ),
          );
        }
      } else {
        final guessedName = _extractUnknownItemName(segment);
        if (guessedName.isNotEmpty) {
          missingItems.add(
            MissingItemModel(
              itemName: guessedName,
              unit: unit,
              qty: qty > 0 ? qty : 1,
              detectedRate: explicitRate,
              sourceText: rawSegment,
            ),
          );
        }
      }
    }

    final merged = _mergeService.merge(parsedLines);
    final safeLines = merged
        .where((e) => e.itemName.trim().isNotEmpty)
        .toList();

    final draft = DraftInvoiceModel(
      invoiceType: invoiceType,
      customerName: customerName,
      sourceMode: 'voice',
      notes: 'Draft generated from transcript',
      rawInputText: cleanedTranscript,
      invoiceDate: DateTime.now(),
      lines: safeLines.isEmpty
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
          : safeLines,
    );

    return VoiceParseResult(
      draft: draft,
      missingItems: _dedupeMissing(missingItems),
    );
  }

  List<String> _splitIntoItemSegments(
    String transcript,
    List<ItemModel> dbItems,
  ) {
    final normalized = _normalizeForMatching(transcript);

    // Primary split by separators first, so unknown items are preserved.
    final coarseSegments = normalized
        .split(
          RegExp(
            r',|;|\n| and | next | phir | tarvata | aamele | aur | mattu | mariyu ',
          ),
        )
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final finalSegments = <String>[];

    for (final coarse in coarseSegments) {
      final aliasPositions = <_AliasHit>[];
      final allAliases = <String>{};

      AppConstants.itemAliases.forEach((_, aliases) {
        allAliases.addAll(aliases.map((e) => _normalizeForMatching(e)));
      });

      for (final item in dbItems) {
        allAliases.add(_normalizeForMatching(item.name));
        allAliases.addAll(item.aliases.map((e) => _normalizeForMatching(e)));
      }

      for (final alias in allAliases) {
        int startIndex = 0;
        while (true) {
          final idx = coarse.indexOf(alias, startIndex);
          if (idx < 0) break;
          aliasPositions.add(_AliasHit(index: idx, alias: alias));
          startIndex = idx + alias.length;
        }
      }

      aliasPositions.sort((a, b) => a.index.compareTo(b.index));

      if (aliasPositions.isEmpty) {
        finalSegments.add(coarse);
        continue;
      }

      // Preserve text before first alias if meaningful
      if (aliasPositions.first.index > 0) {
        final prefix = coarse.substring(0, aliasPositions.first.index).trim();
        if (prefix.isNotEmpty) {
          finalSegments.add(prefix);
        }
      }

      for (int i = 0; i < aliasPositions.length; i++) {
        final start = aliasPositions[i].index;
        final end = i < aliasPositions.length - 1
            ? aliasPositions[i + 1].index
            : coarse.length;

        final seg = coarse.substring(start, end).trim();
        if (seg.isNotEmpty) {
          finalSegments.add(seg);
        }
      }
    }

    return finalSegments.where((e) => e.trim().isNotEmpty).toList();
  }

  String _normalizeForMatching(String value) {
    var text = value.toLowerCase();

    _scriptNormalization.forEach((key, replacement) {
      text = text.replaceAll(key.toLowerCase(), replacement);
    });

    text = text
        .replaceAll('&', ' and ')
        .replaceAll(' plus ', ' and ')
        .replaceAll(' then ', ' and ')
        .replaceAll(' phir ', ' and ')
        .replaceAll(' aur ', ' and ')
        .replaceAll(' tarvata ', ' and ')
        .replaceAll(' aamele ', ' and ')
        .replaceAll(' mariyu ', ' and ')
        .replaceAll(' mattu ', ' and ')
        .replaceAll(' litre', ' ltr')
        .replaceAll(' liter', ' ltr')
        .replaceAll(' litres', ' ltr')
        .replaceAll(' liters', ' ltr')
        .replaceAll(' kilograms', ' kg')
        .replaceAll(' kilogram', ' kg')
        .replaceAll(' kilo', ' kg')
        .replaceAll(' kgs', ' kg')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  String _detectUnit(String text, String fallback) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(ltr|litre|liter|liters|litres|lit)\b').hasMatch(t)) {
      return 'ltr';
    }
    if (RegExp(r'\b(kg|kgs|kilogram|kilograms|kilo)\b').hasMatch(t)) {
      return 'kg';
    }
    if (RegExp(r'\b(g|gm|gms|gram|grams)\b').hasMatch(t)) {
      return 'g';
    }
    if (RegExp(r'\b(pc|pcs|piece|pieces|packet|packets)\b').hasMatch(t)) {
      return 'pcs';
    }
    return fallback;
  }

  double _detectQuantity(String text) {
    final t = text.toLowerCase();

    final qtyWithUnit = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|kgs|kilogram|kilograms|kilo|ltr|litre|liter|liters|litres|g|gm|gms|gram|grams|pc|pcs|piece|pieces|packet|packets)\b',
    ).firstMatch(t);
    if (qtyWithUnit != null) {
      return double.tryParse(qtyWithUnit.group(1) ?? '') ?? 1.0;
    }

    final leadingQty = RegExp(r'^\s*(\d+(?:\.\d+)?)\b').firstMatch(t);
    if (leadingQty != null) {
      return double.tryParse(leadingQty.group(1) ?? '') ?? 1.0;
    }

    if (t.contains('half') || t.contains('aadha') || t.contains('ardha')) {
      return 0.5;
    }
    return 1.0;
  }

  double? _detectRate(String text, double qty) {
    final t = text.toLowerCase();

    final keyword = RegExp(
      r'\b(?:rate|price|amt|amount)\s*(?:is\s*)?(\d+(?:\.\d+)?)\b',
    ).firstMatch(t);
    if (keyword != null) {
      return double.tryParse(keyword.group(1) ?? '');
    }

    final nums = RegExp(r'(\d+(?:\.\d+)?)')
        .allMatches(t)
        .map((m) => double.tryParse(m.group(1) ?? ''))
        .whereType<double>()
        .toList();

    if (nums.length <= 1) return null;

    final candidates = nums
        .where((n) => (n - qty).abs() > 0.0001 && n > 0)
        .toList();

    if (candidates.isEmpty) return null;

    return candidates.last;
  }

  String _extractUnknownItemName(String text) {
    var t = text.toLowerCase();

    for (final noise in AppConstants.noiseWords) {
      t = t.replaceAll(RegExp('\\b${RegExp.escape(noise)}\\b'), ' ');
    }
    for (final token in _noiseTokens) {
      t = t.replaceAll(RegExp('\\b${RegExp.escape(token)}\\b'), ' ');
    }

    t = t
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (t.isEmpty) return '';

    final words = t
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .take(3)
        .toList();

    if (words.isEmpty) return '';

    return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  List<MissingItemModel> _dedupeMissing(List<MissingItemModel> items) {
    final map = <String, MissingItemModel>{};
    for (final item in items) {
      final key =
          '${item.itemName.trim().toLowerCase()}|${item.sourceText.trim().toLowerCase()}';
      map[key] = item;
    }
    return map.values.toList();
  }

  String cleanupTranscript(String value) {
    var text = value.toLowerCase();

    for (final noise in AppConstants.noiseWords) {
      text = text.replaceAll(RegExp('\\b${RegExp.escape(noise)}\\b'), ' ');
    }

    _wordReplacements.forEach((key, replacement) {
      text = text.replaceAll(
        RegExp('\\b${RegExp.escape(key)}\\b'),
        replacement,
      );
    });

    return _normalizeForMatching(text);
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
      if (aSuffix == bPrefix) return len;
    }
    return 0;
  }
}

class _AliasHit {
  final int index;
  final String alias;

  _AliasHit({required this.index, required this.alias});
}
