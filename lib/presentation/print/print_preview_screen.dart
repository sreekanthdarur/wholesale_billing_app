import 'package:flutter/material.dart';

import '../../domain/models/draft_invoice.dart';
import '../widgets/preview_card.dart';

class PrintPreviewScreen extends StatelessWidget {
  final String title;
  final DraftInvoiceModel draft;

  const PrintPreviewScreen({
    super.key,
    required this.title,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PreviewCard(draft: draft),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This is the print preview foundation. Thermal printer / Bluetooth / device-print integration can be added in the next phase.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
