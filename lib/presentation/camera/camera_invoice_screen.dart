import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../data/services/camera_ocr_service.dart';
import '../invoice/draft_invoice_editor_screen.dart';

class CameraInvoiceScreen extends StatefulWidget {
  const CameraInvoiceScreen({super.key});

  @override
  State<CameraInvoiceScreen> createState() => _CameraInvoiceScreenState();
}

class _CameraInvoiceScreenState extends State<CameraInvoiceScreen> {
  final _picker = ImagePicker();
  final _cameraService = CameraOcrService();

  String invoiceType = AppConstants.invoiceTypes.first;
  final customerController = TextEditingController(text: 'Cash');
  final ocrTextController = TextEditingController();
  XFile? selectedImage;
  bool isPicking = false;
  bool isProcessing = false;

  @override
  void dispose() {
    customerController.dispose();
    ocrTextController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => isPicking = true);
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;
      if (!mounted) return;
      setState(() {
        selectedImage = image;
      });
    } finally {
      if (mounted) {
        setState(() => isPicking = false);
      }
    }
  }

  Future<void> _extractOcrText() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please capture or choose an image first.')),
      );
      return;
    }

    setState(() => isProcessing = true);
    try {
      final extractedText =
          await _cameraService.extractTextFromImage(selectedImage!.path);
      if (!mounted) return;
      setState(() {
        ocrTextController.text = extractedText;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('OCR text extracted. Review and continue.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _buildDraftFromOcr() {
    final ocrText = ocrTextController.text.trim();
    if (ocrText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('OCR text is empty. Extract or paste text first.')),
      );
      return;
    }

    final result = _cameraService.parseOcrText(
      ocrText: ocrText,
      invoiceType: invoiceType,
      customerName: customerController.text.trim().isEmpty
          ? 'Cash'
          : customerController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftInvoiceEditorScreen(
          title: result.warnings.isEmpty
              ? 'Camera Draft Invoice'
              : 'Camera Draft Invoice (Review Required)',
          draft: result.draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = selectedImage?.path;

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: invoiceType,
                    decoration: const InputDecoration(
                        labelText: 'Invoice Type',
                        border: OutlineInputBorder()),
                    items: AppConstants.invoiceTypes
                        .map<DropdownMenuItem<String>>((e) =>
                            DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => invoiceType = value ?? invoiceType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerController,
                    decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isPicking
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(isPicking ? 'Opening...' : 'Use Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isPicking
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick Image'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (imagePath != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePath),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selected image: $imagePath',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Capture or choose a raw bill image to extract OCR text and build a draft invoice.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isProcessing ? null : _extractOcrText,
                    icon: const Icon(Icons.document_scanner),
                    label: Text(
                        isProcessing ? 'Extracting...' : 'Extract OCR Text'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ocrTextController,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'OCR Text',
                      border: OutlineInputBorder(),
                      hintText: 'Example:\nRICE 3 KG\nSUGAR 2 KG\nOIL 1 LTR',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'OCR extraction is active. You can edit the OCR text before building the draft invoice.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _buildDraftFromOcr,
            icon: const Icon(Icons.receipt_long),
            label: const Text('Build Draft Invoice'),
          ),
        ],
      ),
    );
  }
}
