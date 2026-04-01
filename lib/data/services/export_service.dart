import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/invoice_detail.dart';

class ExportFileData {
  final String fileName;
  final String filePath;

  const ExportFileData({
    required this.fileName,
    required this.filePath,
  });
}

class ExportService {
  Future<ExportFileData> buildInvoiceExcel(List<InvoiceDetailModel> invoices,
      {String fileName = 'invoice_export.xlsx'}) async {
    final excel = Excel.createExcel();
    final sheet = excel['Invoices'];

    sheet.appendRow([
      TextCellValue('Invoice No'),
      TextCellValue('Invoice Date'),
      TextCellValue('Invoice Type'),
      TextCellValue('Customer'),
      TextCellValue('Source Mode'),
      TextCellValue('Item Name'),
      TextCellValue('Qty'),
      TextCellValue('Unit'),
      TextCellValue('Rate'),
      TextCellValue('Amount'),
      TextCellValue('Total'),
      TextCellValue('Notes'),
    ]);

    for (final invoice in invoices) {
      for (final line in invoice.lines) {
        sheet.appendRow([
          TextCellValue(invoice.header.invoiceNo),
          TextCellValue(invoice.header.invoiceDate.toIso8601String()),
          TextCellValue(invoice.header.invoiceType),
          TextCellValue(invoice.header.customerName),
          TextCellValue(invoice.header.sourceMode),
          TextCellValue(line.itemName),
          DoubleCellValue(line.qty),
          TextCellValue(line.unit),
          DoubleCellValue(line.rate),
          DoubleCellValue(line.amount),
          DoubleCellValue(invoice.header.total),
          TextCellValue(invoice.header.notes),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return ExportFileData(fileName: fileName, filePath: file.path);
  }

  Future<ExportFileData> buildTallyExcel(List<InvoiceDetailModel> invoices,
      {String fileName = 'tally_ready_import.xlsx'}) async {
    final excel = Excel.createExcel();
    final sheet = excel['TallyImport'];

    sheet.appendRow([
      TextCellValue('VoucherType'),
      TextCellValue('Date'),
      TextCellValue('VoucherNumber'),
      TextCellValue('PartyLedgerName'),
      TextCellValue('ItemName'),
      TextCellValue('BilledQty'),
      TextCellValue('Rate'),
      TextCellValue('Amount'),
      TextCellValue('Narration'),
    ]);

    for (final invoice in invoices) {
      for (final line in invoice.lines) {
        sheet.appendRow([
          TextCellValue(invoice.header.invoiceType),
          TextCellValue(
              invoice.header.invoiceDate.toIso8601String().split('T').first),
          TextCellValue(invoice.header.invoiceNo),
          TextCellValue(invoice.header.customerName),
          TextCellValue(line.itemName),
          TextCellValue('${line.qty} ${line.unit}'),
          DoubleCellValue(line.rate),
          DoubleCellValue(line.amount),
          TextCellValue(invoice.header.notes),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Tally Excel file.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return ExportFileData(fileName: fileName, filePath: file.path);
  }
}
