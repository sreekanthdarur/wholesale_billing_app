import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/services/auto_amount_service.dart';
import '../invoice/draft_invoice_editor_screen.dart';

class AutoAmountInvoiceScreen extends StatefulWidget {
  const AutoAmountInvoiceScreen({super.key});

  @override
  State<AutoAmountInvoiceScreen> createState() =>
      _AutoAmountInvoiceScreenState();
}

class _AutoAmountInvoiceScreenState extends State<AutoAmountInvoiceScreen> {
  final _service = AutoAmountService();
  String invoiceType = AppConstants.invoiceTypes.first;
  final amountController = TextEditingController();
  final customerController = TextEditingController(text: 'Cash');

  @override
  void dispose() {
    amountController.dispose();
    customerController.dispose();
    super.dispose();
  }

  void _generateDraft() {
    final targetAmount = double.tryParse(amountController.text.trim()) ?? 0;
    if (targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target amount.')),
      );
      return;
    }

    final result = _service.generateDraft(
      invoiceType: invoiceType,
      targetAmount: targetAmount,
      customerName: customerController.text.trim().isEmpty
          ? 'Cash'
          : customerController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftInvoiceEditorScreen(
          title: result.exactMatch
              ? 'Auto Amount Draft Invoice'
              : 'Auto Amount Draft Invoice (Review Required)',
          draft: result.draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto Amount Invoice')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: invoiceType,
                      decoration: const InputDecoration(
                          labelText: 'Invoice Type',
                          border: OutlineInputBorder()),
                      items: AppConstants.invoiceTypes
                          .map<DropdownMenuItem<String>>((e) =>
                              DropdownMenuItem<String>(
                                  value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => invoiceType = value ?? invoiceType),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerController,
                      decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Target Invoice Amount',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'The app will generate a draft invoice that matches the entered amount as closely as possible. Review and adjust before saving.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generateDraft,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Draft Invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
