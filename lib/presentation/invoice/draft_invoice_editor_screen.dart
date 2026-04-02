import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/services/invoice_line_merge_service.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import 'invoice_preview_screen.dart';

class DraftInvoiceEditorScreen extends StatefulWidget {
  final DraftInvoiceModel draft;
  final String title;
  final bool saveAndPopToHome;

  const DraftInvoiceEditorScreen({
    super.key,
    required this.draft,
    this.title = 'Draft Invoice Editor',
    this.saveAndPopToHome = false,
  });

  @override
  State<DraftInvoiceEditorScreen> createState() =>
      _DraftInvoiceEditorScreenState();
}

class _DraftInvoiceEditorScreenState extends State<DraftInvoiceEditorScreen> {
  late DraftInvoiceModel draft;
  late TextEditingController customerController;
  late TextEditingController notesController;
  late TextEditingController rawTextController;

  List<ItemModel> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    draft = DraftInvoiceModel(
      invoiceType: widget.draft.invoiceType,
      customerName: widget.draft.customerName,
      sourceMode: widget.draft.sourceMode,
      notes: widget.draft.notes,
      rawInputText: widget.draft.rawInputText,
      invoiceDate: widget.draft.invoiceDate,
      lines: widget.draft.lines.map((e) => e.copyWith()).toList(),
    );

    customerController = TextEditingController(text: draft.customerName);
    notesController = TextEditingController(text: draft.notes);
    rawTextController = TextEditingController(text: draft.rawInputText);

    _loadItems();
  }

  Future<void> _loadItems() async {
    items = await itemRepository.getAll();
    if (!mounted) return;
    setState(() => loading = false);
  }

  void _preview() {
    final validLines = draft.lines
        .where((e) => e.itemName.trim().isNotEmpty && e.qty > 0)
        .toList();

    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one valid invoice line.'),
        ),
      );
      return;
    }

    draft.customerName = customerController.text.trim().isEmpty
        ? 'Cash'
        : customerController.text.trim();
    draft.notes = notesController.text.trim();
    draft.rawInputText = rawTextController.text.trim();
    draft.lines = invoiceLineMergeService.merge(validLines);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(initialDraft: draft),
      ),
    );
  }

  @override
  void dispose() {
    customerController.dispose();
    notesController.dispose();
    rawTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: _InfoBox(
                                label: 'Invoice No',
                                value: 'Auto on save',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoBox(
                                label: 'Date',
                                value: AppDateUtils.displayDate(
                                  draft.invoiceDate,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: customerController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: rawTextController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Raw Input Text',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...draft.lines.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final hasMatchingItem =
                      items.any((e) => e.name == item.itemName);

                  return Card(
                    color: item.needsReview ? Colors.orange.shade50 : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Line ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (item.needsReview)
                                const Chip(label: Text('Needs Review')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue:
                                hasMatchingItem ? item.itemName : null,
                            decoration: const InputDecoration(
                              labelText: 'Item',
                              border: OutlineInputBorder(),
                            ),
                            items: items
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e.name,
                                    child: Text(
                                      '${e.name} (₹${e.price.toStringAsFixed(2)}/${e.unit})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final selected = items.firstWhere(
                                (e) => e.name == value,
                              );
                              setState(() {
                                item.itemName = selected.name;
                                item.unit = selected.unit;
                                if (!item.isCustomRate) {
                                  item.rate = selected.price;
                                }
                              });
                            },
                          ),
                          if (!hasMatchingItem &&
                              item.itemName.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Current item: ${item.itemName}',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.qty.toString(),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity (${item.unit})',
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      item.qty =
                                          double.tryParse(value) ?? item.qty;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.rate.toStringAsFixed(2),
                                  decoration: const InputDecoration(
                                    labelText: 'Rate',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      item.rate =
                                          double.tryParse(value) ?? item.rate;
                                      item.isCustomRate = true;
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: draft.lines.length == 1
                                    ? null
                                    : () => setState(
                                          () => draft.lines.removeAt(index),
                                        ),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: item.sourceText,
                            decoration: const InputDecoration(
                              labelText: 'Source Text',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => item.sourceText = value,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Amount: ₹${item.amount.toStringAsFixed(2)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton(
                  onPressed: () => setState(() {
                    final firstItem = items.isNotEmpty ? items.first : null;
                    draft.lines.add(
                      InvoiceLineModel(
                        itemName: firstItem?.name ?? '',
                        qty: 1,
                        unit: firstItem?.unit ?? 'kg',
                        rate: firstItem?.price ?? 0,
                      ),
                    );
                  }),
                  child: const Text('Add Item Line'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${draft.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _preview,
                        icon: const Icon(Icons.preview),
                        label: const Text('Preview Invoice'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.indigo.shade50,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
