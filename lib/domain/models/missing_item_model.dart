class MissingItemModel {
  final String itemName;
  final String unit;
  final double qty;
  final double? detectedRate;
  final String sourceText;

  const MissingItemModel({
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.detectedRate,
    required this.sourceText,
  });
}