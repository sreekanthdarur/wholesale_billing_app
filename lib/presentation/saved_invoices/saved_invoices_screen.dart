import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/invoice_header.dart';
import '../invoice/saved_invoice_preview_screen.dart';

class SavedInvoicesScreen extends StatefulWidget {
  const SavedInvoicesScreen({super.key});

  @override
  State<SavedInvoicesScreen> createState() => _SavedInvoicesScreenState();
}

class _SavedInvoicesScreenState extends State<SavedInvoicesScreen> {
  bool loading = true;
  Map<String, List<InvoiceHeaderModel>> grouped = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    grouped = await invoiceRepository.getGroupedHeaders();
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Invoices'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : grouped.isEmpty
          ? const Center(child: Text('No saved invoices available yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                final invoices = entry.value;
                return Card(
                  child: ExpansionTile(
                    title: Text(entry.key),
                    subtitle: Text('${invoices.length} invoice(s)'),
                    children: invoices.map((invoice) {
                      return ListTile(
                        title: Text(
                          '${invoice.invoiceNo} • ${invoice.customerName}',
                        ),
                        subtitle: Text(
                          '${invoice.invoiceType} • ₹${invoice.total.toStringAsFixed(2)} • ${AppDateUtils.displayDate(invoice.invoiceDate)}',
                        ),
                        trailing: const Icon(Icons.visibility),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavedInvoicePreviewScreen(
                                invoiceId: invoice.id!,
                              ),
                            ),
                          );
                          _load();
                        },
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
