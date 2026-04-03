import '../../core/constants/app_constants.dart';
import '../../domain/models/item_model.dart';

class ItemAliasMatchResult {
  final String? canonicalName;
  final String? unit;
  final double? defaultRate;

  const ItemAliasMatchResult({
    required this.canonicalName,
    required this.unit,
    required this.defaultRate,
  });
}

class ItemAliasService {
  ItemAliasMatchResult match(
      String text, {
        List<ItemModel> dbItems = const [],
      }) {
    final normalized = _normalize(text);

    String? bestName;
    String? bestUnit;
    double? bestRate;
    var bestScore = 0;

    AppConstants.itemAliases.forEach((canonical, aliases) {
      for (final alias in aliases) {
        final aliasNormalized = _normalize(alias);
        if (_containsAlias(normalized, aliasNormalized) &&
            aliasNormalized.length > bestScore) {
          bestScore = aliasNormalized.length;
          bestName = canonical;
          final defaults = AppConstants.itemDefaults[canonical]!;
          bestUnit = defaults['unit'] as String;
          bestRate = defaults['rate'] as double;
        }
      }
    });

    for (final item in dbItems) {
      final allAliases = [item.name, ...item.aliases];
      for (final alias in allAliases) {
        final aliasNormalized = _normalize(alias);
        if (_containsAlias(normalized, aliasNormalized) &&
            aliasNormalized.length > bestScore) {
          bestScore = aliasNormalized.length;
          bestName = item.name;
          bestUnit = item.unit;
          bestRate = item.price;
        }
      }
    }

    return ItemAliasMatchResult(
      canonicalName: bestName,
      unit: bestUnit,
      defaultRate: bestRate,
    );
  }

  bool _containsAlias(String text, String alias) {
    if (text.contains(alias)) return true;
    if (text.replaceAll(' ', '').contains(alias.replaceAll(' ', ''))) {
      return true;
    }
    return false;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

final itemAliasService = ItemAliasService();