import '../../core/utils/date_utils.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_detail.dart';
import '../../domain/models/invoice_header.dart';
import '../../domain/models/invoice_line.dart';
import '../db/app_database.dart';
import '../services/invoice_number_service.dart';

abstract class InvoiceRepository {
  Future<int> createInvoiceFromDraft(DraftInvoiceModel draft);
  Future<void> updateInvoice({
    required int invoiceId,
    required DraftInvoiceModel draft,
  });
  Future<List<InvoiceHeaderModel>> getAllHeaders();
  Future<Map<String, List<InvoiceHeaderModel>>> getGroupedHeaders();
  Future<InvoiceDetailModel?> getInvoiceDetail(int invoiceId);
}

class LocalInvoiceRepository implements InvoiceRepository {
  LocalInvoiceRepository({required this.invoiceNumberService});

  final InvoiceNumberService invoiceNumberService;

  Future<int> _getSameDayCount(DateTime date) async {
    final db = await AppDatabase.instance.database;
    final key = AppDateUtils.isoDateKey(date);
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as count FROM invoices WHERE substr(invoice_date,1,10) = ?",
      [key],
    );
    return ((rows.first['count'] as int?) ?? 0);
  }

  @override
  Future<int> createInvoiceFromDraft(DraftInvoiceModel draft) async {
    final db = await AppDatabase.instance.database;
    final sameDayCount = await _getSameDayCount(draft.invoiceDate);
    final now = DateTime.now();
    final header = InvoiceHeaderModel(
      invoiceNo:
          invoiceNumberService.generate(draft.invoiceDate, sameDayCount + 1),
      invoiceDate: draft.invoiceDate,
      invoiceType: draft.invoiceType,
      customerName: draft.customerName,
      sourceMode: draft.sourceMode,
      notes: draft.notes,
      rawInputText: draft.rawInputText,
      total: draft.total,
      createdAt: now,
      updatedAt: now,
    );

    return db.transaction((txn) async {
      final invoiceId = await txn.insert('invoices', header.toMap());
      for (final line in draft.lines) {
        await txn.insert('invoice_lines', line.toMap(invoiceId));
      }
      return invoiceId;
    });
  }

  @override
  Future<void> updateInvoice(
      {required int invoiceId, required DraftInvoiceModel draft}) async {
    final db = await AppDatabase.instance.database;
    final existing = await getInvoiceDetail(invoiceId);
    if (existing == null) return;

    final updatedHeader = InvoiceHeaderModel(
      id: invoiceId,
      invoiceNo: existing.header.invoiceNo,
      invoiceDate: draft.invoiceDate,
      invoiceType: draft.invoiceType,
      customerName: draft.customerName,
      sourceMode: draft.sourceMode,
      notes: draft.notes,
      rawInputText: draft.rawInputText,
      total: draft.total,
      createdAt: existing.header.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.transaction((txn) async {
      await txn.update('invoices', updatedHeader.toMap(),
          where: 'id = ?', whereArgs: [invoiceId]);
      await txn.delete('invoice_lines',
          where: 'invoice_id = ?', whereArgs: [invoiceId]);
      for (final line in draft.lines) {
        await txn.insert('invoice_lines', line.toMap(invoiceId));
      }
    });
  }

  @override
  Future<List<InvoiceHeaderModel>> getAllHeaders() async {
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('invoices', orderBy: 'invoice_date DESC, id DESC');
    return rows.map(InvoiceHeaderModel.fromMap).toList();
  }

  @override
  Future<Map<String, List<InvoiceHeaderModel>>> getGroupedHeaders() async {
    final invoices = await getAllHeaders();
    final grouped = <String, List<InvoiceHeaderModel>>{
      "Today's Invoices": [],
      'This Month': [],
    };
    final now = DateTime.now();

    for (final invoice in invoices) {
      if (AppDateUtils.isoDateKey(invoice.invoiceDate) ==
          AppDateUtils.isoDateKey(now)) {
        grouped["Today's Invoices"]!.add(invoice);
      }
      if (invoice.invoiceDate.year == now.year &&
          invoice.invoiceDate.month == now.month) {
        grouped['This Month']!.add(invoice);
      }
      final folderKey =
          '${AppDateUtils.monthYearLabel(invoice.invoiceDate)} / ${AppDateUtils.displayDate(invoice.invoiceDate)}';
      grouped.putIfAbsent(folderKey, () => []).add(invoice);
    }
    return grouped;
  }

  @override
  Future<InvoiceDetailModel?> getInvoiceDetail(int invoiceId) async {
    final db = await AppDatabase.instance.database;
    final headers = await db.query('invoices',
        where: 'id = ?', whereArgs: [invoiceId], limit: 1);
    if (headers.isEmpty) return null;
    final lines = await db.query('invoice_lines',
        where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'id ASC');
    return InvoiceDetailModel(
      header: InvoiceHeaderModel.fromMap(headers.first),
      lines: lines.map(InvoiceLineModel.fromMap).toList(),
    );
  }
}

final InvoiceRepository invoiceRepository = LocalInvoiceRepository(
  invoiceNumberService: InvoiceNumberService(),
);
