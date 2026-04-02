import '../../domain/models/invoice_detail.dart';

class ExportService {
  String buildCsv(List<InvoiceDetailModel> invoices) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Invoice No,Invoice Date,Invoice Type,Customer,Source Mode,Item,Qty,Unit,Rate,Amount,Notes',
    );

    for (final invoice in invoices) {
      final header = invoice.header;

      if (invoice.lines.isEmpty) {
        buffer.writeln(
          [
            _csv(header.invoiceNo),
            _csv(header.invoiceDate.toIso8601String().split('T').first),
            _csv(header.invoiceType),
            _csv(header.customerName),
            _csv(header.sourceMode),
            '',
            '',
            '',
            '',
            '',
            _csv(header.notes),
          ].join(','),
        );
        continue;
      }

      for (final line in invoice.lines) {
        buffer.writeln(
          [
            _csv(header.invoiceNo),
            _csv(header.invoiceDate.toIso8601String().split('T').first),
            _csv(header.invoiceType),
            _csv(header.customerName),
            _csv(header.sourceMode),
            _csv(line.itemName),
            line.qty.toString(),
            _csv(line.unit),
            line.rate.toStringAsFixed(2),
            line.amount.toStringAsFixed(2),
            _csv(header.notes),
          ].join(','),
        );
      }
    }

    return buffer.toString();
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
