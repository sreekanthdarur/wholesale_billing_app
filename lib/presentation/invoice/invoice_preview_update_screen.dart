import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/draft_invoice.dart';
import '../print/print_preview_screen.dart';
import '../widgets/preview_card.dart';

class InvoicePreviewUpdateScreen extends StatefulWidget {
  final int invoiceId;
  final String invoiceNo;
  final DraftInvoiceModel draft;

  const InvoicePreviewUpdateScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceNo,
    required this.draft,
  });

  @override
  State<InvoicePreviewUpdateScreen> createState() =>
      _InvoicePreviewUpdateScreenState();
}

class _InvoicePreviewUpdateScreenState
    extends State<InvoicePreviewUpdateScreen> {
  bool saving = false;

  bool _isDraftSaveable(DraftInvoiceModel draft) {
    final validLines = draft.lines.where((line) {
      return line.itemName.trim().isNotEmpty &&
          line.qty > 0 &&
          line.rate > 0 &&
          line.amount > 0;
    }).toList();

    return validLines.isNotEmpty && draft.total > 0;
  }

  Future<void> _updateInvoice() async {
    if (!_isDraftSaveable(widget.draft)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(InvoiceRepository.invalidInvoiceMessage)),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() => saving = true);

    try {
      await invoiceRepository.updateInvoice(
        invoiceId: widget.invoiceId,
        draft: widget.draft,
      );

      if (!mounted) return;
      setState(() => saving = false);

      Navigator.popUntil(context, (route) => route.isFirst);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Invoice updated successfully.')),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Invalid argument(s): ', '')),
        ),
      );
    }
  }

  void _openPrintPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintPreviewScreen(
          title: 'Print Preview ${widget.invoiceNo}',
          draft: widget.draft,
          invoiceNo: widget.invoiceNo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview Update ${widget.invoiceNo}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PreviewCard(draft: widget.draft, invoiceNo: widget.invoiceNo),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : _updateInvoice,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Updating...' : 'Update Invoice'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openPrintPreview,
            icon: const Icon(Icons.print),
            label: const Text('Open Print Preview'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Edit'),
          ),
        ],
      ),
    );
  }
}
