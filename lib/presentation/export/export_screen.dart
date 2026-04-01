import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../data/services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _service = ExportService();
  bool loading = false;
  String status = 'Choose an export format.';
  String? lastFilePath;

  Future<void> _exportExcel({required bool tallyReady}) async {
    setState(() {
      loading = true;
      status = 'Preparing export...';
      lastFilePath = null;
    });

    try {
      final headers = await invoiceRepository.getAllHeaders();
      final details = <dynamic>[];
      for (final header in headers) {
        if (header.id == null) continue;
        final detail = await invoiceRepository.getInvoiceDetail(header.id!);
        if (detail != null) details.add(detail);
      }

      final export = tallyReady
          ? await _service.buildTallyExcel(details.cast(),
              fileName: 'tally_ready_import.xlsx')
          : await _service.buildInvoiceExcel(details.cast(),
              fileName: 'invoice_export.xlsx');

      setState(() {
        status = 'Export created successfully.';
        lastFilePath = export.filePath;
      });
    } catch (e) {
      setState(() {
        status = 'Export failed: $e';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Center')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This phase generates Excel files locally. The second option creates a Tally-oriented workbook layout for import preparation.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    loading ? null : () => _exportExcel(tallyReady: false),
                icon: const Icon(Icons.file_download),
                label: const Text('Export Standard Excel'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    loading ? null : () => _exportExcel(tallyReady: true),
                icon: const Icon(Icons.table_chart),
                label: const Text('Export Tally-ready Excel'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Status'),
                subtitle: Text(status),
              ),
            ),
            if (lastFilePath != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Last Export File'),
                  subtitle: Text(lastFilePath!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
