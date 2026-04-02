class InvoiceLineModel {
  final int? id;
  final int? invoiceId;
  String itemName;
  double qty;
  String unit;
  double rate;
  bool isCustomRate;
  bool needsReview;
  String sourceText;

  InvoiceLineModel({
    this.id,
    this.invoiceId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.rate,
    this.isCustomRate = false,
    this.needsReview = false,
    this.sourceText = '',
  });

  double get amount => qty * rate;

  InvoiceLineModel copyWith({
    int? id,
    int? invoiceId,
    String? itemName,
    double? qty,
    String? unit,
    double? rate,
    bool? isCustomRate,
    bool? needsReview,
    String? sourceText,
  }) {
    return InvoiceLineModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      itemName: itemName ?? this.itemName,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      isCustomRate: isCustomRate ?? this.isCustomRate,
      needsReview: needsReview ?? this.needsReview,
      sourceText: sourceText ?? this.sourceText,
    );
  }

  Map<String, dynamic> toMap(int invoiceId) => {
    'invoice_id': invoiceId,
    'item_name': itemName,
    'qty': qty,
    'unit': unit,
    'rate': rate,
    'amount': amount,
    'is_custom_rate': isCustomRate ? 1 : 0,
    'needs_review': needsReview ? 1 : 0,
    'source_text': sourceText,
  };

  factory InvoiceLineModel.fromMap(Map<String, dynamic> map) {
    return InvoiceLineModel(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int?,
      itemName: map['item_name'] as String,
      qty: (map['qty'] as num).toDouble(),
      unit: map['unit'] as String,
      rate: (map['rate'] as num).toDouble(),
      isCustomRate: (map['is_custom_rate'] as int? ?? 0) == 1,
      needsReview: (map['needs_review'] as int? ?? 0) == 1,
      sourceText: (map['source_text'] ?? '') as String,
    );
  }
}
