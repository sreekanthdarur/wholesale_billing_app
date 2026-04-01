class InvoiceHeaderModel {
  final int? id;
  final String invoiceNo;
  final DateTime invoiceDate;
  final String invoiceType;
  final String customerName;
  final String sourceMode;
  final String notes;
  final String rawInputText;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvoiceHeaderModel({
    this.id,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.invoiceType,
    required this.customerName,
    required this.sourceMode,
    required this.notes,
    required this.rawInputText,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'invoice_no': invoiceNo,
        'invoice_date': invoiceDate.toIso8601String(),
        'invoice_type': invoiceType,
        'customer_name': customerName,
        'source_mode': sourceMode,
        'notes': notes,
        'raw_input_text': rawInputText,
        'total': total,
        'year': invoiceDate.year,
        'month': invoiceDate.month,
        'day': invoiceDate.day,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InvoiceHeaderModel.fromMap(Map<String, dynamic> map) {
    return InvoiceHeaderModel(
      id: map['id'] as int?,
      invoiceNo: map['invoice_no'] as String,
      invoiceDate: DateTime.parse(map['invoice_date'] as String),
      invoiceType: map['invoice_type'] as String,
      customerName: map['customer_name'] as String,
      sourceMode: map['source_mode'] as String,
      notes: (map['notes'] ?? '') as String,
      rawInputText: (map['raw_input_text'] ?? '') as String,
      total: (map['total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
