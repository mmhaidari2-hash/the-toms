/// Outcome of one speech-recognition attempt.
class SpeechResult {
  final List<String> alternatives;
  final double confidence;
  final String? error;
  const SpeechResult({this.alternatives = const [], this.confidence = 0, this.error});
  bool get ok => error == null && alternatives.isNotEmpty;
  String get best => alternatives.isEmpty ? '' : alternatives.first;
  bool get permissionDenied => error == 'not-allowed' || error == 'service-not-allowed';
}

/// Platform-neutral hooks set by the app.
abstract final class SpeechHooks {
  /// Shows the microphone explanation (EN+FA) before Android's permission prompt. Returns true to continue.
  static Future<bool> Function()? rationale;
}
