import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../data/services/print_service.dart';

class PrintPreviewScreen extends StatefulWidget {
  final int invoiceId;

  const PrintPreviewScreen({super.key, required this.invoiceId});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final _printService = PrintService();
  bool loading = true;
  String receiptText = 'Loading receipt preview...';

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final detail = await invoiceRepository.getInvoiceDetail(widget.invoiceId);
    if (detail == null) {
      setState(() {
        loading = false;
        receiptText = 'Invoice not found.';
      });
      return;
    }
    final preview = _printService.buildReceipt(detail);
    setState(() {
      loading = false;
      receiptText = preview.receiptText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print Preview')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      receiptText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
