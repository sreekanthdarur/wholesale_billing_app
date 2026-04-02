import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';

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
  State<DraftInvoiceEditorScreen> createState() => _DraftInvoiceEditorScreenState();
}

class _DraftInvoiceEditorScreenState extends State<DraftInvoiceEditorScreen> {
  late DraftInvoiceModel draft;
  late TextEditingController customerController;
  late TextEditingController notesController;
  late TextEditingController rawTextController;

  bool saving = false;

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
  }

  @override
  void dispose() {
    customerController.dispose();
    notesController.dispose();
    rawTextController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final validLines = draft.lines
        .where((e) => e.itemName.trim().isNotEmpty && e.qty > 0)
        .toList();

    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one valid invoice line.')),
      );
      return;
    }

    setState(() => saving = true);

    final updatedDraft = draft.copyWith(
      customerName: customerController.text.trim().isEmpty
          ? 'Cash'
          : customerController.text.trim(),
      notes: notesController.text.trim(),
      rawInputText: rawTextController.text.trim(),
      lines: validLines,
    );

    final id = await invoiceRepository.createInvoiceFromDraft(updatedDraft);

    if (!mounted) return;
    setState(() {
      draft = updatedDraft;
      saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved successfully. ID: $id')),
    );

    if (widget.saveAndPopToHome) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                                value: AppDateUtils.displayDate(draft.invoiceDate),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: draft.invoiceType,
                          decoration: const InputDecoration(
                            labelText: 'Invoice Type',
                            border: OutlineInputBorder(),
                          ),
                          items: AppConstants.invoiceTypes
                              .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              draft = draft.copyWith(invoiceType: value);
                            });
                          },
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
                          decoration: InputDecoration(
                            labelText: draft.sourceMode == 'manual'
                                ? 'Raw Input Text (Optional)'
                                : 'Raw Input Text',
                            border: const OutlineInputBorder(),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (item.needsReview) const Chip(label: Text('Needs Review')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: item.itemName,
                            decoration: const InputDecoration(
                              labelText: 'Item Name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final updatedLines = [...draft.lines];
                              updatedLines[index] = item.copyWith(itemName: value);
                              setState(() {
                                draft = draft.copyWith(lines: updatedLines);
                              });
                            },
                          ),
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
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (value) {
                                    final updatedLines = [...draft.lines];
                                    updatedLines[index] =
                                        item.copyWith(qty: double.tryParse(value) ?? item.qty);
                                    setState(() {
                                      draft = draft.copyWith(lines: updatedLines);
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
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (value) {
                                    final updatedLines = [...draft.lines];
                                    updatedLines[index] =
                                        item.copyWith(rate: double.tryParse(value) ?? item.rate);
                                    setState(() {
                                      draft = draft.copyWith(lines: updatedLines);
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: draft.lines.length == 1
                                    ? null
                                    : () {
                                  final updatedLines = [...draft.lines]..removeAt(index);
                                  setState(() {
                                    draft = draft.copyWith(lines: updatedLines);
                                  });
                                },
                                icon: const Icon(Icons.delete, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: item.unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: AppConstants.units
                                .map((e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final updatedLines = [...draft.lines];
                              updatedLines[index] = item.copyWith(unit: value);
                              setState(() {
                                draft = draft.copyWith(lines: updatedLines);
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: item.sourceText,
                            decoration: const InputDecoration(
                              labelText: 'Source Text',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final updatedLines = [...draft.lines];
                              updatedLines[index] = item.copyWith(sourceText: value);
                              setState(() {
                                draft = draft.copyWith(lines: updatedLines);
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Custom Rate'),
                            value: item.isCustomRate,
                            onChanged: (value) {
                              final updatedLines = [...draft.lines];
                              updatedLines[index] = item.copyWith(isCustomRate: value);
                              setState(() {
                                draft = draft.copyWith(lines: updatedLines);
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Needs Review'),
                            value: item.needsReview,
                            onChanged: (value) {
                              final updatedLines = [...draft.lines];
                              updatedLines[index] = item.copyWith(needsReview: value);
                              setState(() {
                                draft = draft.copyWith(lines: updatedLines);
                              });
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Amount: ₹${item.amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton(
                  onPressed: () {
                    final updatedLines = [...draft.lines,
                      InvoiceLineModel(
                          itemName: '',
                          qty: 1,
                          unit: 'kg',
                          rate: 0,
                        ),
                      ];
                    setState(() {
                      draft = draft.copyWith(lines: updatedLines);
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
                      child: FilledButton(
                        onPressed: saving ? null : _save,
                        child: Text(saving ? 'Saving...' : 'Save Invoice'),
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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