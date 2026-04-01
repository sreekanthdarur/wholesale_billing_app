import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';

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
    final double roundedTarget =
    targetAmount <= 0 ? 0.0 : double.parse(targetAmount.toStringAsFixed(2));

    final lines = <InvoiceLineModel>[];

    if (roundedTarget <= 0) {
      return AutoAmountServiceResult(
        draft: DraftInvoiceModel(
          invoiceType: invoiceType,
          customerName: customerName,
          sourceMode: 'auto_amount',
          notes: 'Target amount too low; please review manually',
          rawInputText: 'Target Amount: ₹${roundedTarget.toStringAsFixed(2)}',
          invoiceDate: DateTime.now(),
          lines: [
            InvoiceLineModel(
              itemName: 'Rice',
              qty: 1,
              unit: 'kg',
              rate: 0,
              needsReview: true,
              sourceText: 'Target amount too low; please review manually',
            ),
          ],
        ),
        exactMatch: false,
        difference: roundedTarget,
      );
    }

    final selectedCount = roundedTarget >= 800
        ? 5
        : (roundedTarget >= 450 ? 4 : 3);

    final selected = _catalog.take(selectedCount).toList();
    double remaining = roundedTarget;

    final minBaseTotal = selected.fold<double>(
      0,
          (sum, item) => sum + item.defaultRate,
    );

    if (remaining >= minBaseTotal) {
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
        remaining =
            double.parse((remaining - item.defaultRate).toStringAsFixed(2));
      }
    }

    int pointer = 0;
    while (remaining >= 45 && pointer < 200) {
      final item = selected[pointer % selected.length];

      if (remaining >= item.defaultRate) {
        final idx = lines.indexWhere((e) => e.itemName == item.itemName);
        if (idx >= 0) {
          lines[idx] = lines[idx].copyWith(qty: lines[idx].qty + 1);
        } else {
          lines.add(
            InvoiceLineModel(
              itemName: item.itemName,
              qty: 1,
              unit: item.unit,
              rate: item.defaultRate,
              sourceText: 'Auto-balanced round-robin distribution',
            ),
          );
        }

        remaining =
            double.parse((remaining - item.defaultRate).toStringAsFixed(2));
      }

      pointer++;
    }

    if (lines.isEmpty) {
      final fallback = _catalog.first;
      lines.add(
        InvoiceLineModel(
          itemName: fallback.itemName,
          qty: 1,
          unit: fallback.unit,
          rate: fallback.defaultRate,
          sourceText: 'Auto-generated base line',
        ),
      );
      remaining =
          double.parse((remaining - fallback.defaultRate).toStringAsFixed(2));
    }

    if (remaining.abs() > 0.009) {
      final adjustItem = selected.first;
      final idx = lines.indexWhere((e) => e.itemName == adjustItem.itemName);
      if (idx >= 0) {
        final current = lines[idx];
        final adjustedRate =
        double.parse((current.rate + remaining).toStringAsFixed(2));

        if (adjustedRate > 0) {
          lines[idx] = current.copyWith(
            rate: adjustedRate,
            isCustomRate: true,
            needsReview: true,
            sourceText: 'Auto-adjusted to match target amount',
          );
        }
      }
    }

    final draft = DraftInvoiceModel(
      invoiceType: invoiceType,
      customerName: customerName,
      sourceMode: 'auto_amount',
      notes:
      'Balanced draft generated from target amount ₹${roundedTarget.toStringAsFixed(2)}',
      rawInputText: 'Target Amount: ₹${roundedTarget.toStringAsFixed(2)}',
      invoiceDate: DateTime.now(),
      lines: lines,
    );

    final difference =
    double.parse((roundedTarget - draft.total).toStringAsFixed(2));

    return AutoAmountServiceResult(
      draft: draft,
      exactMatch: difference == 0,
      difference: difference,
    );
  }
}