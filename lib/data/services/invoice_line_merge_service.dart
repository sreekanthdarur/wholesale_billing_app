import '../../domain/models/invoice_line.dart';

class InvoiceLineMergeService {
  List<InvoiceLineModel> merge(List<InvoiceLineModel> lines) {
    final merged = <String, InvoiceLineModel>{};

    for (final line in lines) {
      final key = line.itemName.trim().toLowerCase();
      if (key.isEmpty) continue;

      if (!merged.containsKey(key)) {
        merged[key] = line.copyWith();
        continue;
      }

      final current = merged[key]!;
      final combinedQty = current.qty + line.qty;
      final rate = line.isCustomRate ? line.rate : current.rate;

      merged[key] = current.copyWith(
        qty: combinedQty,
        rate: rate,
        isCustomRate: current.isCustomRate || line.isCustomRate,
        needsReview: current.needsReview || line.needsReview,
        sourceText: '${current.sourceText} | ${line.sourceText}'.trim(),
      );
    }

    return merged.values.toList();
  }
}

final invoiceLineMergeService = InvoiceLineMergeService();
