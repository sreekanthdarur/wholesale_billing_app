class MissingValueModel {
  final String itemName;
  final String unit;
  final double qty;
  final double? rate;
  final String sourceText;

  const MissingValueModel({
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.sourceText,
  });
}
