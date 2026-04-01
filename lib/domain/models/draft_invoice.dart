import 'invoice_line.dart';

class DraftInvoiceModel {
  String invoiceType;
  String customerName;
  String sourceMode;
  String notes;
  String rawInputText;
  DateTime invoiceDate;
  List<InvoiceLineModel> lines;

  DraftInvoiceModel({
    required this.invoiceType,
    required this.customerName,
    required this.sourceMode,
    required this.notes,
    required this.rawInputText,
    required this.invoiceDate,
    required this.lines,
  });

  double get total => lines.fold(0, (sum, line) => sum + line.amount);
}
