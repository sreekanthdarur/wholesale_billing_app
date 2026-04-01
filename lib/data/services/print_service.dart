import '../../domain/models/invoice_detail.dart';

class PrintPreviewData {
  final String receiptText;

  const PrintPreviewData({
    required this.receiptText,
  });
}

class PrintService {
  PrintPreviewData buildReceipt(InvoiceDetailModel detail) {
    final buffer = StringBuffer();
    buffer.writeln('WHOLESALE BILLING');
    buffer.writeln('------------------------------');
    buffer.writeln('Invoice No : ${detail.header.invoiceNo}');
    buffer.writeln('Date       : ${detail.header.invoiceDate.toLocal()}');
    buffer.writeln('Type       : ${detail.header.invoiceType}');
    buffer.writeln('Customer   : ${detail.header.customerName}');
    buffer.writeln('------------------------------');

    for (final line in detail.lines) {
      buffer.writeln(line.itemName);
      buffer.writeln(
          '  ${line.qty} ${line.unit} x ₹${line.rate.toStringAsFixed(2)} = ₹${line.amount.toStringAsFixed(2)}');
    }

    buffer.writeln('------------------------------');
    buffer.writeln('Total      : ₹${detail.header.total.toStringAsFixed(2)}');
    if (detail.header.notes.trim().isNotEmpty) {
      buffer.writeln('Notes      : ${detail.header.notes}');
    }
    buffer.writeln('------------------------------');
    buffer.writeln('Thank you');
    return PrintPreviewData(receiptText: buffer.toString());
  }
}
