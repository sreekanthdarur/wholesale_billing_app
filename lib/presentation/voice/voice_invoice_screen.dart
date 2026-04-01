import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/constants/app_constants.dart';
import '../../data/services/voice_parser_service.dart';
import '../invoice/draft_invoice_editor_screen.dart';

class VoiceInvoiceScreen extends StatefulWidget {
  const VoiceInvoiceScreen({super.key});

  @override
  State<VoiceInvoiceScreen> createState() => _VoiceInvoiceScreenState();
}

class _VoiceInvoiceScreenState extends State<VoiceInvoiceScreen> {
  final _parser = VoiceParserService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  String invoiceType = AppConstants.invoiceTypes.first;
  final customerController = TextEditingController(text: 'Cash');
  final transcriptController = TextEditingController();

  bool speechReady = false;
  bool isListening = false;
  String speechStatus = 'Tap microphone to start';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          speechStatus = status;
          if (status == 'done' || status == 'notListening') {
            isListening = false;
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          speechStatus = 'Error: ${error.errorMsg}';
          isListening = false;
        });
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice capture.'),
        ),
      );
    }
    return false;
  }

  Future<void> _toggleListening() async {
    final granted = await _ensureMicPermission();
    if (!granted) return;

    if (!speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
          ),
        );
      }
      return;
    }

    if (isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        isListening = false;
        speechStatus = 'Stopped';
      });
      return;
    }

    setState(() {
      isListening = true;
      speechStatus = 'Listening...';
    });

    await _speech.listen(
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          transcriptController.text = result.recognizedWords;
        });
      },
    );
  }

  void _buildDraft() {
    final transcript = transcriptController.text.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or capture transcript text first.')),
      );
      return;
    }

    final result = _parser.parseTranscript(
      transcript: transcript,
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
              ? 'Voice Draft Invoice'
              : 'Voice Draft Invoice (Review Required)',
          draft: result.draft,
        ),
      ),
    );
  }

  @override
  void dispose() {
    customerController.dispose();
    transcriptController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final micIcon = isListening ? Icons.stop : Icons.mic;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Invoice')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
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
                        border: OutlineInputBorder(),
                      ),
                      items: AppConstants.invoiceTypes
                          .map<DropdownMenuItem<String>>(
                            (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ),
                      )
                          .toList(),
                      onChanged: (value) => setState(() {
                        invoiceType = value ?? invoiceType;
                      }),
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
                    FilledButton.icon(
                      onPressed: _toggleListening,
                      icon: Icon(micIcon),
                      label: Text(isListening ? 'Stop Listening' : 'Start Listening'),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Speech Status: $speechStatus'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: transcriptController,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Transcript Text',
                        border: OutlineInputBorder(),
                        hintText: 'Example: rice 5 kg sugar 2 kg oil 1 ltr',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _buildDraft,
              icon: const Icon(Icons.mic),
              label: const Text('Build Draft Invoice'),
            ),
          ],
        ),
      ),
    );
  }
}