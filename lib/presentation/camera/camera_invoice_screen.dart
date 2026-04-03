import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/services/camera_ocr_service.dart';
import '../../data/services/invoice_line_merge_service.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import '../invoice/invoice_preview_screen.dart';
import '../widgets/missing_items_price_dialog.dart';

class CameraInvoiceScreen extends StatefulWidget {
  const CameraInvoiceScreen({super.key});

  @override
  State<CameraInvoiceScreen> createState() => _CameraInvoiceScreenState();
}

class _CameraInvoiceScreenState extends State<CameraInvoiceScreen> {
  final customerController = TextEditingController(text: 'Cash');
  final ocrTextController = TextEditingController();
  final CameraOcrService ocrService = CameraOcrService();
  final ImagePicker picker = ImagePicker();

  String invoiceType = AppConstants.invoiceTypes.first;
  String ocrLanguage = 'en';
  XFile? selectedImage;
  bool extracting = false;
  bool checkingBackend = true;
  bool localBackendReady = false;
  String backendMessage = 'Checking local OCR server...';

  final Map<String, String> ocrLanguageOptions = const {
    'en': 'English',
    'hi': 'Hindi',
    'te': 'Telugu',
    'kn': 'Kannada',
  };

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() {
      checkingBackend = true;
      backendMessage = 'Checking local OCR server...';
    });

    final result = await ocrService.healthCheck();
    if (!mounted) return;

    setState(() {
      localBackendReady = result.ok && result.ocrReady;
      checkingBackend = false;
      backendMessage = result.ok
          ? 'Local AI OCR is ready.'
          : 'Local AI OCR unavailable. Device OCR fallback will be used.';
    });
  }

  Future<void> _pickFromCamera() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (image == null) return;
    setState(() {
      selectedImage = image;
    });
  }

  Future<void> _pickFromGallery() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) return;
    setState(() {
      selectedImage = image;
    });
  }

  Future<void> _extractText() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture or select an image first.'),
        ),
      );
      return;
    }

    setState(() => extracting = true);

    try {
      final text = await ocrService.extractTextFromImage(
        selectedImage!.path,
        language: ocrLanguage,
        preferLocal: localBackendReady,
      );

      if (!mounted) return;
      setState(() {
        ocrTextController.text = text;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to extract OCR text from image.')),
      );
    } finally {
      if (mounted) {
        setState(() => extracting = false);
      }
    }
  }

  bool _isValidManualLine(InvoiceLineModel line) {
    return line.itemName.trim().isNotEmpty &&
        line.qty > 0 &&
        line.rate > 0 &&
        line.amount > 0;
  }

  Future<void> _buildDraft() async {
    final ocrText = ocrTextController.text.trim();
    if (ocrText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste or extract OCR text first.'),
        ),
      );
      return;
    }

    var result = await ocrService.parseOcrText(
      ocrText: ocrText,
      invoiceType: invoiceType,
      customerName: customerController.text.trim().isEmpty
          ? 'Cash'
          : customerController.text.trim(),
    );

    if (!mounted) return;

    if (result.missingItems.isNotEmpty) {
      final manualLines = await showDialog<List<InvoiceLineModel>>(
        context: context,
        builder: (_) =>
            MissingItemsPriceDialog(missingItems: result.missingItems),
      );

      final validManualLines = (manualLines ?? <InvoiceLineModel>[])
          .where(_isValidManualLine)
          .toList();

      if (validManualLines.isNotEmpty) {
        for (final line in validManualLines) {
          await itemRepository.addIfMissing(
            ItemModel(
              name: line.itemName,
              price: line.rate,
              unit: line.unit,
              aliasesCsv: line.itemName.toLowerCase(),
            ),
          );
        }

        final baseLines = result.draft.lines
            .where((e) => e.itemName != 'Review Item' && _isValidManualLine(e))
            .toList();

        final merged = invoiceLineMergeService.merge([
          ...baseLines,
          ...validManualLines,
        ]);

        result = OcrParseResult(
          draft: DraftInvoiceModel(
            invoiceType: result.draft.invoiceType,
            customerName: result.draft.customerName,
            sourceMode: result.draft.sourceMode,
            notes: result.draft.notes,
            rawInputText: result.draft.rawInputText,
            invoiceDate: result.draft.invoiceDate,
            lines: merged.isEmpty ? validManualLines : merged,
          ),
          missingItems: const [],
        );
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(initialDraft: result.draft),
      ),
    );
  }

  void _clearAll() {
    setState(() {
      selectedImage = null;
      ocrTextController.clear();
    });
  }

  @override
  void dispose() {
    customerController.dispose();
    ocrTextController.dispose();
    ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backendColor = localBackendReady ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: backendColor.withValues(alpha: 0.08),
            child: ListTile(
              leading: checkingBackend
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      localBackendReady
                          ? Icons.cloud_done
                          : Icons.phone_android,
                      color: backendColor,
                    ),
              title: Text(
                localBackendReady
                    ? 'Local AI OCR mode'
                    : 'Device OCR fallback mode',
              ),
              subtitle: Text(backendMessage),
              trailing: IconButton(
                onPressed: _checkBackend,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: customerController,
            decoration: const InputDecoration(
              labelText: 'Customer Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: invoiceType,
            decoration: const InputDecoration(
              labelText: 'Invoice Type',
              border: OutlineInputBorder(),
            ),
            items: AppConstants.invoiceTypes
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              setState(() {
                invoiceType = value ?? invoiceType;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: ocrLanguage,
            decoration: const InputDecoration(
              labelText: 'OCR Language',
              border: OutlineInputBorder(),
            ),
            items: ocrLanguageOptions.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                ocrLanguage = value ?? ocrLanguage;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Use Camera'),
              ),
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick Image'),
              ),
              OutlinedButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(selectedImage!.path),
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (selectedImage != null) const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: extracting ? null : _extractText,
            icon: const Icon(Icons.text_snippet),
            label: Text(
              extracting
                  ? 'Extracting...'
                  : localBackendReady
                  ? 'Extract with Local AI'
                  : 'Extract with Device OCR',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ocrTextController,
            minLines: 10,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'OCR Text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _buildDraft,
            icon: const Icon(Icons.preview),
            label: const Text('Preview Invoice'),
          ),
        ],
      ),
    );
  }
}
