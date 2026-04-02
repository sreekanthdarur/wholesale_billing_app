import '../db/app_database.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_detail.dart';
import '../../domain/models/invoice_header.dart';
import '../../domain/models/invoice_line.dart';
import 'package:sqflite/sqflite.dart';

class InvoiceRepository {
  Future<int> createInvoiceFromDraft(DraftInvoiceModel draft) async {
    final db = await AppDatabase.instance.database;

    return db.transaction((txn) async {
      final now = DateTime.now();
      final invoiceNo = await _generateInvoiceNo(txn, now);

      final invoiceId = await txn.insert('invoices', {
        'invoice_no': invoiceNo,
        'invoice_date': draft.invoiceDate.toIso8601String(),
        'invoice_type': draft.invoiceType,
        'customer_name': draft.customerName,
        'source_mode': draft.sourceMode,
        'notes': draft.notes,
        'raw_input_text': draft.rawInputText,
        'total': draft.total,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      for (final line in draft.lines) {
        await txn.insert('invoice_lines', {
          'invoice_id': invoiceId,
          'item_name': line.itemName,
          'qty': line.qty,
          'unit': line.unit,
          'rate': line.rate,
          'amount': line.amount,
          'is_custom_rate': line.isCustomRate ? 1 : 0,
          'needs_review': line.needsReview ? 1 : 0,
          'source_text': line.sourceText,
        });
      }

      return invoiceId;
    });
  }

  Future<void> updateInvoice({
    required int invoiceId,
    required DraftInvoiceModel draft,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      await txn.update(
        'invoices',
        {
          'invoice_date': draft.invoiceDate.toIso8601String(),
          'invoice_type': draft.invoiceType,
          'customer_name': draft.customerName,
          'source_mode': draft.sourceMode,
          'notes': draft.notes,
          'raw_input_text': draft.rawInputText,
          'total': draft.total,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      await txn.delete(
        'invoice_lines',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      for (final line in draft.lines) {
        await txn.insert('invoice_lines', {
          'invoice_id': invoiceId,
          'item_name': line.itemName,
          'qty': line.qty,
          'unit': line.unit,
          'rate': line.rate,
          'amount': line.amount,
          'is_custom_rate': line.isCustomRate ? 1 : 0,
          'needs_review': line.needsReview ? 1 : 0,
          'source_text': line.sourceText,
        });
      }
    });
  }

  Future<List<InvoiceHeaderModel>> getAllHeaders() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'invoices',
      orderBy: 'invoice_date DESC, id DESC',
    );
    return rows.map(_mapHeader).toList();
  }

  Future<Map<String, List<InvoiceHeaderModel>>> getGroupedHeaders() async {
    final headers = await getAllHeaders();
    final grouped = <String, List<InvoiceHeaderModel>>{};

    for (final header in headers) {
      final d = header.invoiceDate;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(header);
    }

    return grouped;
  }

  Future<InvoiceDetailModel?> getInvoiceDetail(int invoiceId) async {
    final db = await AppDatabase.instance.database;

    final headerRows = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );

    if (headerRows.isEmpty) return null;

    final lineRows = await db.query(
      'invoice_lines',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );

    return InvoiceDetailModel(
      header: _mapHeader(headerRows.first),
      lines: lineRows.map(_mapLine).toList(),
    );
  }

  InvoiceHeaderModel _mapHeader(Map<String, Object?> row) {
    return InvoiceHeaderModel(
      id: row['id'] as int,
      invoiceNo: (row['invoice_no'] ?? '') as String,
      invoiceDate: DateTime.parse(
          (row['invoice_date'] ?? DateTime.now().toIso8601String()) as String),
      invoiceType: ((row['invoice_type'] ?? 'Cash') as String),
      customerName: ((row['customer_name'] ?? 'Cash') as String),
      sourceMode: ((row['source_mode'] ?? 'manual') as String),
      total: ((row['total'] as num?) ?? 0).toDouble(),
      notes: ((row['notes'] ?? '') as String),
      rawInputText: ((row['raw_input_text'] ?? '') as String),
      createdAt: DateTime.tryParse(
          (row['created_at'] ?? DateTime.now().toIso8601String()) as String) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
          (row['updated_at'] ?? DateTime.now().toIso8601String()) as String) ??
          DateTime.now(),
    );
  }

  InvoiceLineModel _mapLine(Map<String, Object?> row) {
    return InvoiceLineModel(
      id: row['id'] as int?,
      itemName: (row['item_name'] ?? '') as String,
      qty: ((row['qty'] as num?) ?? 0).toDouble(),
      unit: (row['unit'] ?? 'pcs') as String,
      rate: ((row['rate'] as num?) ?? 0).toDouble(),
      isCustomRate: ((row['is_custom_rate'] as int?) ?? 0) == 1,
      needsReview: ((row['needs_review'] as int?) ?? 0) == 1,
      sourceText: (row['source_text'] ?? '') as String,
    );
  }

  Future<String> _generateInvoiceNo(DatabaseExecutor txn, DateTime now) async {
    final prefix =
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day
        .toString().padLeft(2, '0')}';

    final count = await txn.rawQuery(
      '''
    SELECT COUNT(*) as cnt
    FROM invoices
    WHERE invoice_no LIKE ?
    ''',
      ['$prefix-%'],
    );

    final current = ((count.first['cnt'] as int?) ?? 0) + 1;
    return '$prefix-${current.toString().padLeft(4, '0')}';
  }

  final invoiceRepository = InvoiceRepository();
}