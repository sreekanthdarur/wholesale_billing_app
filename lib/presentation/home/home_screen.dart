import 'package:flutter/material.dart';

import '../../data/services/draft_invoice_service.dart';
import '../auto_amount/auto_amount_invoice_screen.dart';
import '../camera/camera_invoice_screen.dart';
import '../export/export_screen.dart';
import '../invoice/draft_invoice_editor_screen.dart';
import '../saved_invoices/saved_invoices_screen.dart';
import '../voice/voice_invoice_screen.dart';
import '../widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final draftService = DraftInvoiceService();
    final menu = [
      _HomeMenuItem(
          'Manual Invoice', 'Draft -> review -> save', Icons.receipt_long, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DraftInvoiceEditorScreen(
              title: 'Manual Invoice',
              draft: draftService.createEmptyManualDraft(),
            ),
          ),
        );
      }),
      _HomeMenuItem(
          'Saved Invoices', 'Today / month / date grouping', Icons.folder_open,
          () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SavedInvoicesScreen()));
      }),
      _HomeMenuItem(
          'Voice Invoice', 'Microphone -> transcript -> draft', Icons.mic, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VoiceInvoiceScreen()));
      }),
      _HomeMenuItem(
          'Camera Invoice', 'Camera OCR -> draft -> confirm', Icons.camera_alt,
          () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CameraInvoiceScreen()));
      }),
      _HomeMenuItem('Auto Amount Invoice', 'Target value -> generated draft',
          Icons.auto_awesome, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AutoAmountInvoiceScreen()));
      }),
      _HomeMenuItem(
          'Export Center', 'Excel / Tally-ready export', Icons.file_download,
          () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ExportScreen()));
      }),
      _HomeMenuItem('Printer Setup', 'Receipt preview foundation', Icons.print,
          () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PlaceholderScreen(
              title: 'Printer Setup',
              description:
                  'Thermal printer device integration is the next phase. Print preview is already available from saved invoice edit screen.',
            ),
          ),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Wholesale Billing App')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: menu.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = menu[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(item.icon)),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.onTap,
            ),
          );
        },
      ),
    );
  }
}

class _HomeMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _HomeMenuItem(this.title, this.subtitle, this.icon, this.onTap);
}
