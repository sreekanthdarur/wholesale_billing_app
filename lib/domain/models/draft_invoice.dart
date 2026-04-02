import 'invoice_line.dart';

class DraftInvoiceModel {
  final String invoiceType;
  final String customerName;
  final String sourceMode;
  final String notes;
  final String rawInputText;
  final DateTime invoiceDate;
  final List<InvoiceLineModel> lines;

  const DraftInvoiceModel({
    required this.invoiceType,
    required this.customerName,
    required this.sourceMode,
    required this.notes,
    required this.rawInputText,
    required this.invoiceDate,
    required this.lines,
  });

  double get total => lines.fold(0.0, (sum, line) => sum + line.amount);

  DraftInvoiceModel copyWith({
    String? invoiceType,
    String? customerName,
    String? sourceMode,
    String? notes,
    String? rawInputText,
    DateTime? invoiceDate,
    List<InvoiceLineModel>? lines,
  }) {
    return DraftInvoiceModel(
      invoiceType: invoiceType ?? this.invoiceType,
      customerName: customerName ?? this.customerName,
      sourceMode: sourceMode ?? this.sourceMode,
      notes: notes ?? this.notes,
      rawInputText: rawInputText ?? this.rawInputText,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      lines: lines ?? this.lines,
    );
  }
}