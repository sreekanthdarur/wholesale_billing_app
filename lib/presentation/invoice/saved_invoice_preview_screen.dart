import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/draft_invoice.dart';
import '../print/print_preview_screen.dart';
import '../widgets/preview_card.dart';
import 'invoice_editor_screen.dart';

class SavedInvoicePreviewScreen extends StatefulWidget {
  final int invoiceId;

  const SavedInvoicePreviewScreen({super.key, required this.invoiceId});

  @override
  State<SavedInvoicePreviewScreen> createState() =>
      _SavedInvoicePreviewScreenState();
}

class _SavedInvoicePreviewScreenState extends State<SavedInvoicePreviewScreen> {
  bool loading = true;
  String invoiceNo = '';
  DraftInvoiceModel? draft;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await invoiceRepository.getInvoiceDetail(widget.invoiceId);
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

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditorScreen(invoiceId: widget.invoiceId),
      ),
    );
    if (!mounted) return;
    _load();
  }

  void _openPrintPreview() {
    if (draft == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintPreviewScreen(
          title: 'Print Preview $invoiceNo',
          draft: draft!,
          invoiceNo: invoiceNo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Saved Invoice $invoiceNo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PreviewCard(draft: draft!, invoiceNo: invoiceNo),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit),
            label: const Text('Edit Invoice'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openPrintPreview,
            icon: const Icon(Icons.print),
            label: const Text('Open Print Preview'),
          ),
        ],
      ),
    );
  }
}
