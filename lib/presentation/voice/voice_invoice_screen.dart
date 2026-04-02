import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/constants/app_constants.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/services/invoice_line_merge_service.dart';
import '../../data/services/voice_parser_service.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import '../invoice/invoice_preview_screen.dart';
import '../widgets/missing_items_price_dialog.dart';
import '../../domain/models/draft_invoice.dart';

class VoiceInvoiceScreen extends StatefulWidget {
  const VoiceInvoiceScreen({super.key});

  @override
  State<VoiceInvoiceScreen> createState() => _VoiceInvoiceScreenState();
}

class _VoiceInvoiceScreenState extends State<VoiceInvoiceScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final VoiceParserService _parser = VoiceParserService();

  final customerController = TextEditingController(text: 'Cash');
  final transcriptController = TextEditingController();

  String invoiceType = AppConstants.invoiceTypes.first;
  bool speechReady = false;
  bool isListening = false;
  bool isInitializing = true;
  bool keepListening = false;
  String speechStatus = 'Preparing microphone...';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    speechReady = await _speech.initialize(
      onStatus: (status) async {
        if (!mounted) return;

        setState(() {
          speechStatus = status;
          if (status == 'done' || status == 'notListening') {
            isListening = false;
          }
        });

        if (keepListening && (status == 'done' || status == 'notListening')) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted && keepListening) {
            await _listenLoop();
          }
        }
      },
      onError: (error) async {
        if (!mounted) return;

        setState(() {
          speechStatus = 'Error: ${error.errorMsg}';
          isListening = false;
        });

        if (keepListening) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && keepListening) {
            await _listenLoop();
          }
        }
      },
    );

    if (!mounted) return;
    setState(() {
      isInitializing = false;
      speechStatus = speechReady ? 'Ready' : 'Speech recognition unavailable';
    });
  }

  Future<bool> _ensureMicPermission() async {
    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone permission is required.')),
    );
    return false;
  }

  Future<void> _listenLoop() async {
    if (!speechReady || !keepListening) return;

    setState(() {
      isListening = true;
      speechStatus = 'Listening...';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        final appended = _parser.appendTranscript(
          currentTranscript: transcriptController.text,
          newChunk: result.recognizedWords,
        );

        setState(() {
          transcriptController.text = appended;
          transcriptController.selection = TextSelection.fromPosition(
            TextPosition(offset: transcriptController.text.length),
          );
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: null,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _startListening() async {
    if (!await _ensureMicPermission()) return;

    if (!speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available on this device.')),
      );
      return;
    }

    keepListening = true;
    await _listenLoop();
  }

  Future<void> _stopListening() async {
    keepListening = false;
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      isListening = false;
      speechStatus = 'Stopped';
    });
  }

  Future<void> _toggleListening() async {
    if (keepListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _buildDraft() async {
    final transcript = transcriptController.text.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or type transcript text first.')),
      );
      return;
    }

    var result = await _parser.parseTranscript(
      transcript: transcript,
      invoiceType: invoiceType,
      customerName: customerController.text.trim().isEmpty
          ? 'Cash'
          : customerController.text.trim(),
    );

    if (!mounted) return;

    if (result.missingItems.isNotEmpty) {
      final manualLines = await showDialog<List<InvoiceLineModel>>(
        context: context,
        builder: (_) => MissingItemsPriceDialog(missingItems: result.missingItems),
      );

      if (manualLines != null && manualLines.isNotEmpty) {
        for (final line in manualLines) {
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
            .where((e) => e.itemName != 'Review Item')
            .toList();

        final merged = invoiceLineMergeService.merge([
          ...baseLines,
          ...manualLines,
        ]);

        result = VoiceParseResult(
          draft: DraftInvoiceModel(
            invoiceType: result.draft.invoiceType,
            customerName: result.draft.customerName,
            sourceMode: result.draft.sourceMode,
            notes: result.draft.notes,
            rawInputText: result.draft.rawInputText,
            invoiceDate: result.draft.invoiceDate,
            lines: merged,
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

  void _clearTranscript() {
    setState(() {
      transcriptController.clear();
    });
  }

  @override
  void dispose() {
    keepListening = false;
    customerController.dispose();
    transcriptController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final micIcon = keepListening ? Icons.stop : Icons.mic;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          FilledButton.icon(
            onPressed: isInitializing ? null : _toggleListening,
            icon: Icon(micIcon),
            label: Text(keepListening ? 'Stop Listening' : 'Start Listening'),
          ),
          const SizedBox(height: 8),
          Text('Speech Status: $speechStatus'),
          const SizedBox(height: 12),
          TextField(
            controller: transcriptController,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Transcript Text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _buildDraft,
            icon: const Icon(Icons.preview),
            label: const Text('Preview Invoice'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearTranscript,
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}