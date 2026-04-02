import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../data/services/export_service.dart';
import '../../domain/models/invoice_detail.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool loading = false;
  final TextEditingController exportController = TextEditingController();
  final ExportService exportService = ExportService();

  Future<void> _buildExport() async {
    setState(() {
      loading = true;
      exportController.clear();
    });

    try {
      final headers = await invoiceRepository.getAllHeaders();
      final details = <InvoiceDetailModel>[];

      for (final header in headers) {
        final detail = await invoiceRepository.getInvoiceDetail(header.id);
        if (detail != null) {
          details.add(detail);
        }
      }

      final csv = exportService.buildCsv(details);

      if (!mounted) return;

      setState(() {
        exportController.text = csv;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate export: $e')),
      );
    }
  }

  Future<void> _copyToClipboard() async {
    final text = exportController.text.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export text copied to clipboard.')),
    );
  }

  @override
  void dispose() {
    exportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasExportText = exportController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This export module currently prepares CSV-style invoice data. It can be extended later into Excel and Tally-ready file output.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : _buildExport,
            icon: const Icon(Icons.file_download),
            label: Text(loading ? 'Preparing...' : 'Generate Export Data'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: hasExportText ? _copyToClipboard : null,
            icon: const Icon(Icons.copy),
            label: const Text('Copy Export Text'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: exportController,
            minLines: 12,
            maxLines: 20,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Export Output',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}