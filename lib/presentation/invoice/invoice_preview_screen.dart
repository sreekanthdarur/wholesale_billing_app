import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/draft_invoice.dart';
import '../print/print_preview_screen.dart';
import '../widgets/preview_card.dart';
import 'draft_invoice_editor_screen.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final DraftInvoiceModel initialDraft;

  const InvoicePreviewScreen({super.key, required this.initialDraft});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
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

  Future<void> _save() async {
    if (!_isDraftSaveable(widget.initialDraft)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(InvoiceRepository.invalidInvoiceMessage)),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() => saving = true);

    try {
      await invoiceRepository.createInvoiceFromDraft(widget.initialDraft);

      if (!mounted) return;
      setState(() => saving = false);

      Navigator.popUntil(context, (route) => route.isFirst);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully.')),
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

  void _edit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DraftInvoiceEditorScreen(
          draft: widget.initialDraft,
          title: 'Edit Draft Invoice',
        ),
      ),
    );
  }

  void _openPrintPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintPreviewScreen(
          title: 'Print Preview',
          draft: widget.initialDraft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PreviewCard(draft: widget.initialDraft),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Saving...' : 'Save Invoice'),
                ),
              ),
            ],
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
            icon: const Icon(Icons.delete_outline),
            label: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
