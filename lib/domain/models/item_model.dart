class ItemModel {
  final int? id;
  final String name;
  final double price;
  final String unit;
  final String aliasesCsv;

  const ItemModel({
    this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.aliasesCsv = '',
  });

  List<String> get aliases => aliasesCsv
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'unit': unit,
        'aliases_csv': aliasesCsv,
      };

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      unit: map['unit'] as String,
      aliasesCsv: (map['aliases_csv'] ?? '') as String,
    );
  }
}
