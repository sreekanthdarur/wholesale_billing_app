import 'package:flutter/material.dart';

import '../../domain/models/invoice_line.dart';
import '../../domain/models/missing_item_model.dart';

class MissingItemsPriceDialog extends StatefulWidget {
  final List<MissingItemModel> missingItems;

  const MissingItemsPriceDialog({
    super.key,
    required this.missingItems,
  });

  @override
  State<MissingItemsPriceDialog> createState() => _MissingItemsPriceDialogState();
}

class _MissingItemsPriceDialogState extends State<MissingItemsPriceDialog> {
  late final List<TextEditingController> _priceControllers;
  late final List<TextEditingController> _qtyControllers;

  @override
  void initState() {
    super.initState();
    _priceControllers = widget.missingItems
        .map(
          (e) => TextEditingController(
        text: e.detectedRate != null ? e.detectedRate!.toStringAsFixed(2) : '',
      ),
    )
        .toList();

    _qtyControllers = widget.missingItems
        .map(
          (e) => TextEditingController(
        text: e.qty.toStringAsFixed(0),
      ),
    )
        .toList();
  }

  @override
  void dispose() {
    for (final c in _priceControllers) {
      c.dispose();
    }
    for (final c in _qtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final lines = <InvoiceLineModel>[];

    for (var i = 0; i < widget.missingItems.length; i++) {
      final missing = widget.missingItems[i];
      final qty = double.tryParse(_qtyControllers[i].text.trim()) ?? 0;
      final price = double.tryParse(_priceControllers[i].text.trim()) ?? 0;

      if (qty <= 0 || price <= 0) continue;

      lines.add(
        InvoiceLineModel(
          itemName: missing.itemName,
          qty: qty,
          unit: missing.unit,
          rate: price,
          isCustomRate: true,
          needsReview: false,
          sourceText: missing.sourceText,
        ),
      );
    }

    Navigator.pop(context, lines);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Missing Items'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(widget.missingItems.length, (index) {
              final item = widget.missingItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyControllers[index],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Qty (${item.unit})',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _priceControllers[index],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Source: ${item.sourceText}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <InvoiceLineModel>[]),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add Items'),
        ),
      ],
    );
  }
}