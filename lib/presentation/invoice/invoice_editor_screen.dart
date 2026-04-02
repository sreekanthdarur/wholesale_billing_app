import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/services/invoice_line_merge_service.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import 'invoice_preview_update_screen.dart';

class InvoiceEditorScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceEditorScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  bool loading = true;
  DraftInvoiceModel? draft;
  String invoiceNo = '';

  late TextEditingController customerController;
  late TextEditingController notesController;
  late TextEditingController rawTextController;

  List<ItemModel> items = [];

  @override
  void initState() {
    super.initState();
    customerController = TextEditingController();
    notesController = TextEditingController();
    rawTextController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final detail = await invoiceRepository.getInvoiceDetail(widget.invoiceId);
    items = await itemRepository.getAll();

    if (detail == null) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    invoiceNo = detail.header.invoiceNo;
    draft = DraftInvoiceModel(
      invoiceType: detail.header.invoiceType,
      customerName: detail.header.customerName,
      sourceMode: detail.header.sourceMode,
      notes: detail.header.notes,
      rawInputText: detail.header.rawInputText,
      invoiceDate: detail.header.invoiceDate,
      lines: detail.lines.map((e) => e.copyWith()).toList(),
    );

    customerController.text = draft!.customerName;
    notesController.text = draft!.notes;
    rawTextController.text = draft!.rawInputText;

    if (!mounted) return;
    setState(() => loading = false);
  }

  void _previewUpdate() {
    if (draft == null) return;

    final validLines = draft!.lines
        .where((e) => e.itemName.trim().isNotEmpty && e.qty > 0)
        .toList();

    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please keep at least one valid invoice line.'),
        ),
      );
      return;
    }

    final updatedDraft = draft!.copyWith(
      customerName: customerController.text.trim().isEmpty
          ? 'Cash'
          : customerController.text.trim(),
      notes: notesController.text.trim(),
      rawInputText: rawTextController.text.trim(),
      lines: invoiceLineMergeService.merge(validLines),
    );

    setState(() {
      draft = updatedDraft;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewUpdateScreen(
          invoiceId: widget.invoiceId,
          invoiceNo: invoiceNo,
          draft: updatedDraft,
        ),
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
    if (loading || draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Saved Invoice')),
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
                            Expanded(
                              child: _InfoBox(
                                label: 'Invoice No',
                                value: invoiceNo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoBox(
                                label: 'Date',
                                value: AppDateUtils.displayDate(
                                  draft!.invoiceDate,
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
                ...draft!.lines.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final hasMatchingItem = items.any(
                    (e) => e.name == item.itemName,
                  );

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
                            initialValue: hasMatchingItem
                                ? item.itemName
                                : null,
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
                              final updatedLines = [...draft!.lines];
                              updatedLines[index] = item.copyWith(
                                itemName: selected.name,
                                unit: selected.unit,
                                rate: item.isCustomRate
                                    ? item.rate
                                    : selected.price,
                              );
                              setState(() {
                                draft = draft!.copyWith(lines: updatedLines);
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
                                    final updatedLines = [...draft!.lines];
                                    updatedLines[index] = item.copyWith(
                                      qty: double.tryParse(value) ?? item.qty,
                                    );
                                    setState(() {
                                      draft = draft!.copyWith(
                                        lines: updatedLines,
                                      );
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
                                    final updatedLines = [...draft!.lines];
                                    updatedLines[index] = item.copyWith(
                                      rate: double.tryParse(value) ?? item.rate,
                                      isCustomRate: true,
                                    );
                                    setState(() {
                                      draft = draft!.copyWith(
                                        lines: updatedLines,
                                      );
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: draft!.lines.length == 1
                                    ? null
                                    : () {
                                        final updatedLines = [...draft!.lines]
                                          ..removeAt(index);
                                        setState(() {
                                          draft = draft!.copyWith(
                                            lines: updatedLines,
                                          );
                                        });
                                      },
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
                            onChanged: (value) {
                              final updatedLines = [...draft!.lines];
                              updatedLines[index] = item.copyWith(
                                sourceText: value,
                              );
                              setState(() {
                                draft = draft!.copyWith(lines: updatedLines);
                              });
                            },
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
                  onPressed: () {
                    final firstItem = items.isNotEmpty ? items.first : null;
                    final updatedLines = [
                      ...draft!.lines,
                      InvoiceLineModel(
                        itemName: firstItem?.name ?? '',
                        qty: 1,
                        unit: firstItem?.unit ?? 'kg',
                        rate: firstItem?.price ?? 0,
                      ),
                    ];
                    setState(() {
                      draft = draft!.copyWith(lines: updatedLines);
                    });
                  },
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
                          '₹${draft!.total.toStringAsFixed(2)}',
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
                        onPressed: _previewUpdate,
                        icon: const Icon(Icons.preview),
                        label: const Text('Preview Updated Invoice'),
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

  const _InfoBox({required this.label, required this.value});

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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
