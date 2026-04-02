import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import 'invoice_line_merge_service.dart';

class AutoAmountCatalogItem {
  final String itemName;
  final String unit;
  final double defaultRate;

  const AutoAmountCatalogItem({
    required this.itemName,
    required this.unit,
    required this.defaultRate,
  });
}

class AutoAmountServiceResult {
  final DraftInvoiceModel draft;
  final bool exactMatch;
  final double difference;

  const AutoAmountServiceResult({
    required this.draft,
    required this.exactMatch,
    required this.difference,
  });
}

class AutoAmountService {
  static const List<AutoAmountCatalogItem> _catalog = [
    AutoAmountCatalogItem(itemName: 'Rice', unit: 'kg', defaultRate: 52),
    AutoAmountCatalogItem(itemName: 'Sugar', unit: 'kg', defaultRate: 45),
    AutoAmountCatalogItem(itemName: 'Toor Dal', unit: 'kg', defaultRate: 130),
    AutoAmountCatalogItem(itemName: 'Oil', unit: 'ltr', defaultRate: 120),
    AutoAmountCatalogItem(itemName: 'Tamarind', unit: 'kg', defaultRate: 160),
  ];

  AutoAmountServiceResult generateDraft({
    required String invoiceType,
    required double targetAmount,
    String customerName = 'Cash',
  }) {
    final roundedTarget = targetAmount <= 0
        ? 0.0
        : double.parse(targetAmount.toStringAsFixed(2));

    final selectedCount = roundedTarget >= 800
        ? 5
        : roundedTarget >= 450
        ? 4
        : 3;

    final selected = _catalog.take(selectedCount).toList();
    final lines = <InvoiceLineModel>[];
    var remaining = roundedTarget;

    if (selected.isEmpty) {
      return AutoAmountServiceResult(
        draft: DraftInvoiceModel(
          invoiceType: invoiceType,
          customerName: customerName,
          sourceMode: 'auto_amount',
          notes: 'No catalog items available',
          rawInputText: 'Target Amount: ₹${roundedTarget.toStringAsFixed(2)}',
          invoiceDate: DateTime.now(),
          lines: [
            InvoiceLineModel(
              itemName: 'Review Item',
              qty: 1,
              unit: 'pcs',
              rate: 0,
              needsReview: true,
              sourceText: 'No catalog items available',
            ),
          ],
        ),
        exactMatch: false,
        difference: roundedTarget,
      );
    }

    // Base quantity of 1 for each selected item when affordable.
    final minBase = selected.fold<double>(
      0,
      (sum, item) => sum + item.defaultRate,
    );
    if (remaining >= minBase) {
      for (final item in selected) {
        lines.add(
          InvoiceLineModel(
            itemName: item.itemName,
            qty: 1,
            unit: item.unit,
            rate: item.defaultRate,
            sourceText: 'Auto-balanced base quantity',
          ),
        );
        remaining = double.parse(
          (remaining - item.defaultRate).toStringAsFixed(2),
        );
      }
    }

    // Distribute remaining budget more evenly instead of overfilling the first item.
    var pointer = 0;
    while (remaining >= 45 && pointer < 300) {
      final item = selected[pointer % selected.length];
      if (remaining >= item.defaultRate) {
        final index = lines.indexWhere((e) => e.itemName == item.itemName);
        if (index >= 0) {
          final current = lines[index];
          lines[index] = current.copyWith(qty: current.qty + 1);
        } else {
          lines.add(
            InvoiceLineModel(
              itemName: item.itemName,
              qty: 1,
              unit: item.unit,
              rate: item.defaultRate,
              sourceText: 'Auto-balanced round robin allocation',
            ),
          );
        }
        remaining = double.parse(
          (remaining - item.defaultRate).toStringAsFixed(2),
        );
      }
      pointer++;
    }

    // Fallback if target amount is smaller than all base totals.
    if (lines.isEmpty) {
      final cheapest = _catalog.reduce(
        (a, b) => a.defaultRate <= b.defaultRate ? a : b,
      );
      lines.add(
        InvoiceLineModel(
          itemName: cheapest.itemName,
          qty: 1,
          unit: cheapest.unit,
          rate: cheapest.defaultRate,
          sourceText: 'Auto-generated fallback line',
        ),
      );
      remaining = double.parse(
        (remaining - cheapest.defaultRate).toStringAsFixed(2),
      );
    }

    // Final adjustment on first line only for exact balancing.
    if (lines.isNotEmpty && remaining.abs() > 0.009) {
      final current = lines.first;
      final adjustedRate = double.parse(
        (current.rate + remaining).toStringAsFixed(2),
      );

      if (adjustedRate > 0) {
        lines[0] = current.copyWith(
          rate: adjustedRate,
          isCustomRate: true,
          needsReview: true,
          sourceText: 'Auto-adjusted to match target amount',
        );
      }
    }

    final merged = invoiceLineMergeService.merge(lines);

    final draft = DraftInvoiceModel(
      invoiceType: invoiceType,
      customerName: customerName,
      sourceMode: 'auto_amount',
      notes:
          'Balanced draft generated from target amount ₹${roundedTarget.toStringAsFixed(2)}',
      rawInputText: 'Target Amount: ₹${roundedTarget.toStringAsFixed(2)}',
      invoiceDate: DateTime.now(),
      lines: merged,
    );

    final difference = double.parse(
      (roundedTarget - draft.total).toStringAsFixed(2),
    );

    return AutoAmountServiceResult(
      draft: draft,
      exactMatch: difference == 0,
      difference: difference,
    );
  }
}
