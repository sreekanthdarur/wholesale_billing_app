import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';

class DraftInvoiceService {
  DraftInvoiceModel createEmptyManualDraft() {
    return DraftInvoiceModel(
      invoiceType: 'Cash',
      customerName: 'Cash',
      sourceMode: 'manual',
      notes: '',
      rawInputText: '',
      invoiceDate: DateTime.now(),
      lines: [InvoiceLineModel(itemName: 'Rice', qty: 1, unit: 'kg', rate: 52)],
    );
  }
}
