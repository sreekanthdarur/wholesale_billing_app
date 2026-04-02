class LocalAiConfig {
  const LocalAiConfig._();

  /// Replace this with your laptop/desktop LAN IP before testing on a real phone.
  /// Example: http://192.168.1.23:8099
  static const String baseUrl = String.fromEnvironment(
    'LOCAL_AI_URL',
    defaultValue: 'http://192.168.29.73:8099',
  );

  static const bool enabled = true;
  static const bool preferLocalForCamera = true;
  static const bool preferLocalForVoice = true;

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration requestTimeout = Duration(seconds: 90);

  static String get healthUrl => '$baseUrl/health';
  static String get ocrUrl => '$baseUrl/ocr';
  static String get transcribeUrl => '$baseUrl/transcribe';
}
