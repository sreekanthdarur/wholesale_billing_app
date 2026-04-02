class CustomerModel {
  final int? id;
  final String name;

  const CustomerModel({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() => {'name': name};

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }
}
