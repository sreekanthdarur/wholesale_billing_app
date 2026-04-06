import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/services/invoice_line_merge_service.dart';
import '../../data/services/local_ai_bridge_service.dart';
import '../../data/services/voice_parser_service.dart';
import '../../domain/models/draft_invoice.dart';
import '../../domain/models/invoice_line.dart';
import '../../domain/models/item_model.dart';
import '../invoice/invoice_preview_screen.dart';
import '../widgets/missing_items_price_dialog.dart';

class VoiceInvoiceScreen extends StatefulWidget {
  const VoiceInvoiceScreen({super.key});

  @override
  State<VoiceInvoiceScreen> createState() => _VoiceInvoiceScreenState();
}

class _VoiceInvoiceScreenState extends State<VoiceInvoiceScreen> {
  final VoiceParserService _parser = VoiceParserService();
  final LocalAiBridgeService _localAiBridgeService = LocalAiBridgeService();
  final AudioRecorder _recorder = AudioRecorder();

  final customerController = TextEditingController(text: 'Cash');
  final transcriptController = TextEditingController();

  String invoiceType = AppConstants.invoiceTypes.first;
  String speechLanguage = 'auto';
  bool checkingBackend = true;
  bool localBackendReady = false;
  bool isRecording = false;
  bool isTranscribing = false;
  String status = 'Checking local speech server...';
  String? lastRecordedPath;

  final Map<String, String> speechLanguageOptions = const {
    'auto': 'Auto detect',
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
      status = 'Checking local speech server...';
    });

    final result = await _localAiBridgeService.healthCheck();
    if (!mounted) return;

    setState(() {
      localBackendReady = result.ok && result.sttReady;
      checkingBackend = false;
      status = result.ok
          ? 'Local AI speech is ready.'
          : 'Local AI speech unavailable. Please start the Python server.';
    });
  }

  Future<void> _toggleRecording() async {
    if (isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_invoice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );

    if (!mounted) return;
    setState(() {
      isRecording = true;
      status = 'Recording... tap again to stop and transcribe.';
      lastRecordedPath = filePath;
    });
  }

  Future<void> _stopRecordingAndTranscribe() async {
    final path = await _recorder.stop();
    if (!mounted) return;

    setState(() {
      isRecording = false;
      isTranscribing = true;
      status = 'Uploading audio to local AI...';
      lastRecordedPath = path;
    });

    if (path == null) {
      setState(() {
        isTranscribing = false;
        status = 'Recording failed. Please try again.';
      });
      return;
    }

    final result = await _localAiBridgeService.transcribeAudio(
      audioPath: path,
      language: speechLanguage,
    );

    if (!mounted) return;

    if (result == null || result.text.trim().isEmpty) {
      setState(() {
        isTranscribing = false;
        status = 'No speech detected. Try again closer to the phone mic.';
      });
      return;
    }

    final merged = _parser.appendTranscript(
      currentTranscript: transcriptController.text,
      newChunk: result.text,
    );

    setState(() {
      transcriptController.text = merged;
      transcriptController.selection = TextSelection.fromPosition(
        TextPosition(offset: transcriptController.text.length),
      );
      isTranscribing = false;
      status = 'Transcript captured from local AI.';
    });
  }

  bool _isValidManualLine(InvoiceLineModel line) {
    return line.itemName.trim().isNotEmpty &&
        line.qty > 0 &&
        line.rate > 0 &&
        line.amount > 0;
  }

  bool _isValidDraftLine(InvoiceLineModel line) {
    return line.itemName.trim().isNotEmpty &&
        line.itemName.trim().toLowerCase() != 'review item' &&
        line.qty > 0 &&
        line.rate > 0 &&
        line.amount > 0;
  }

  Future<List<InvoiceLineModel>> _collectManualLines(
    List<InvoiceLineModel> existingLines,
    List<InvoiceLineModel> manualLines,
  ) async {
    final combined = <InvoiceLineModel>[
      ...existingLines.where(_isValidDraftLine),
      ...manualLines.where(_isValidManualLine),
    ];

    if (combined.isEmpty) {
      return <InvoiceLineModel>[];
    }

    final merged = invoiceLineMergeService.merge(combined);

    return merged.where((e) => _isValidDraftLine(e)).toList();
  }

  Future<void> _buildDraft() async {
    final transcript = transcriptController.text.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record or type transcript text first.'),
        ),
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
        barrierDismissible: false,
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

        final finalLines = await _collectManualLines(
          result.draft.lines,
          validManualLines,
        );

        result = VoiceParseResult(
          draft: DraftInvoiceModel(
            invoiceType: result.draft.invoiceType,
            customerName: result.draft.customerName,
            sourceMode: result.draft.sourceMode,
            notes: result.draft.notes,
            rawInputText: result.draft.rawInputText,
            invoiceDate: result.draft.invoiceDate,
            lines: finalLines.isEmpty ? validManualLines : finalLines,
          ),
          missingItems: const [],
        );
      }
    }

    if (!mounted) return;

    final finalPreviewLines = result.draft.lines
        .where(_isValidDraftLine)
        .toList();

    if (finalPreviewLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No valid invoice items were prepared. Please review the transcript or add valid quantity and price for missing items.',
          ),
        ),
      );
      return;
    }

    final finalDraft = DraftInvoiceModel(
      invoiceType: result.draft.invoiceType,
      customerName: result.draft.customerName,
      sourceMode: result.draft.sourceMode,
      notes: result.draft.notes,
      rawInputText: result.draft.rawInputText,
      invoiceDate: result.draft.invoiceDate,
      lines: finalPreviewLines,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(initialDraft: finalDraft),
      ),
    );
  }

  void _clearTranscript() {
    setState(() {
      transcriptController.clear();
      status = 'Transcript cleared.';
    });
  }

  @override
  void dispose() {
    customerController.dispose();
    transcriptController.dispose();
    _recorder.dispose();
    _localAiBridgeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = localBackendReady ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: modeColor.withValues(alpha: 0.08),
            child: ListTile(
              leading: checkingBackend
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      localBackendReady
                          ? Icons.mic_external_on
                          : Icons.warning_amber,
                      color: modeColor,
                    ),
              title: Text(
                localBackendReady
                    ? 'Local AI speech mode'
                    : 'Local AI speech server not ready',
              ),
              subtitle: Text(status),
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
            initialValue: speechLanguage,
            decoration: const InputDecoration(
              labelText: 'Speech Language',
              border: OutlineInputBorder(),
            ),
            items: speechLanguageOptions.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                speechLanguage = value ?? speechLanguage;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: localBackendReady && !isTranscribing
                ? _toggleRecording
                : null,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            label: Text(
              isRecording
                  ? 'Stop Recording & Transcribe'
                  : isTranscribing
                  ? 'Transcribing...'
                  : 'Start Local AI Recording',
            ),
          ),
          if (lastRecordedPath != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last audio file: $lastRecordedPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
