import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants/local_ai_config.dart';

class LocalAiHealthResult {
  final bool ok;
  final bool ocrReady;
  final bool sttReady;
  final String message;

  const LocalAiHealthResult({
    required this.ok,
    required this.ocrReady,
    required this.sttReady,
    required this.message,
  });

  factory LocalAiHealthResult.fromJson(Map<String, dynamic> json) {
    return LocalAiHealthResult(
      ok: json['ok'] == true,
      ocrReady: json['ocr_ready'] == true,
      sttReady: json['stt_ready'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }

  factory LocalAiHealthResult.failure([
    String message = 'Local AI service unavailable',
  ]) {
    return LocalAiHealthResult(
      ok: false,
      ocrReady: false,
      sttReady: false,
      message: message,
    );
  }
}

class LocalAiTranscriptResult {
  final String text;
  final String language;
  final double confidence;

  const LocalAiTranscriptResult({
    required this.text,
    required this.language,
    required this.confidence,
  });

  factory LocalAiTranscriptResult.fromJson(Map<String, dynamic> json) {
    return LocalAiTranscriptResult(
      text: (json['text'] ?? '').toString(),
      language: (json['language'] ?? 'auto').toString(),
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
    );
  }
}

class LocalAiOcrResult {
  final String text;
  final double confidence;

  const LocalAiOcrResult({required this.text, required this.confidence});

  factory LocalAiOcrResult.fromJson(Map<String, dynamic> json) {
    return LocalAiOcrResult(
      text: (json['text'] ?? '').toString(),
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
    );
  }
}

class LocalAiBridgeService {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = LocalAiConfig.connectTimeout;

  Future<LocalAiHealthResult> healthCheck() async {
    if (!LocalAiConfig.enabled) {
      return LocalAiHealthResult.failure('Local AI disabled');
    }

    try {
      final response = await _postJson(
        LocalAiConfig.healthUrl,
        const <String, dynamic>{},
      );

      if (response.statusCode != 200) {
        return LocalAiHealthResult.failure(
          'Health check failed (${response.statusCode})',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      return LocalAiHealthResult.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } catch (e) {
      return LocalAiHealthResult.failure(e.toString());
    }
  }

  Future<LocalAiOcrResult?> extractTextFromImage({
    required String imagePath,
    required String language,
  }) async {
    if (!LocalAiConfig.enabled) return null;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final response = await _postJson(LocalAiConfig.ocrUrl, <String, dynamic>{
        'image_base64': base64Encode(bytes),
        'language': language,
        'file_name': p.basename(imagePath),
      });

      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      return LocalAiOcrResult.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<LocalAiTranscriptResult?> transcribeAudio({
    required String audioPath,
    required String language,
  }) async {
    if (!LocalAiConfig.enabled) return null;

    try {
      final file = File(audioPath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final response =
          await _postJson(LocalAiConfig.transcribeUrl, <String, dynamic>{
            'audio_base64': base64Encode(bytes),
            'language': language,
            'file_name': p.basename(audioPath),
            'file_ext': p.extension(audioPath).replaceFirst('.', ''),
          });

      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      return LocalAiTranscriptResult.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<HttpClientResponse> _postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final request = await _client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode(payload));
    return request.close().timeout(LocalAiConfig.requestTimeout);
  }

  void dispose() {
    _client.close(force: true);
  }
}
