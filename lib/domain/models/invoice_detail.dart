import 'invoice_header.dart';
import 'invoice_line.dart';

class InvoiceDetailModel {
  final InvoiceHeaderModel header;
  final List<InvoiceLineModel> lines;

  const InvoiceDetailModel({required this.header, required this.lines});
}
