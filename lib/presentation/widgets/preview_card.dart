import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/draft_invoice.dart';

class PreviewCard extends StatelessWidget {
  final DraftInvoiceModel draft;
  final String? invoiceNo;

  const PreviewCard({super.key, required this.draft, this.invoiceNo});

  @override
  Widget build(BuildContext context) {
    final hasInvoiceNo = invoiceNo != null && invoiceNo!.trim().isNotEmpty;

    return Card(
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'INVOICE PREVIEW',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            if (hasInvoiceNo)
              Text(
                'Invoice No: ${invoiceNo!.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            Text(
              'Customer: ${draft.customerName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Date: ${AppDateUtils.displayDate(draft.invoiceDate)}'),
            Text('Source: ${draft.sourceMode}'),
            const Divider(height: 20),
            const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rate',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...draft.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(line.itemName)),
                    Expanded(child: Text('${line.qty} ${line.unit}')),
                    Expanded(child: Text('₹${line.rate.toStringAsFixed(2)}')),
                    Expanded(child: Text('₹${line.amount.toStringAsFixed(2)}')),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ₹${draft.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (draft.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notes: ${draft.notes}'),
            ],
          ],
        ),
      ),
    );
  }
}
