import 'package:flutter/material.dart';

import '../../data/services/draft_invoice_service.dart';
import '../auto_amount/auto_amount_invoice_screen.dart';
import '../camera/camera_invoice_screen.dart';
import '../export/export_screen.dart';
import '../invoice/draft_invoice_editor_screen.dart';
import '../saved_invoices/saved_invoices_screen.dart';
import '../masters/manage_customers_screen.dart';
import '../masters/manage_items_screen.dart';
import '../voice/voice_invoice_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final draftService = DraftInvoiceService();

    final menu = [
      _HomeMenuItem('Create Manual Invoice', 'Draft -> preview -> save',
          Icons.receipt_long, () {
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedInvoicesScreen()),
        );
      }),
      _HomeMenuItem('Manage Customers', 'Customer master CRUD', Icons.people,
          () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageCustomersScreen()),
        );
      }),
      _HomeMenuItem(
          'Manage Items', 'Item master + aliases + prices', Icons.inventory_2,
          () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageItemsScreen()),
        );
      }),
      _HomeMenuItem(
          'Voice Invoice', 'Microphone -> transcript -> draft', Icons.mic, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoiceInvoiceScreen()),
        );
      }),
      _HomeMenuItem(
          'Camera Invoice', 'Camera OCR -> draft -> confirm', Icons.camera_alt,
          () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CameraInvoiceScreen()),
        );
      }),
      _HomeMenuItem('Auto Amount Invoice', 'Target value -> balanced draft',
          Icons.auto_awesome, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AutoAmountInvoiceScreen()),
        );
      }),
      _HomeMenuItem(
          'Export Center', 'CSV / Excel foundation', Icons.file_download, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExportScreen()),
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
