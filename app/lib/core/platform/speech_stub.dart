/// Non-web fallback: no speech recognition / recording (tests, VM).
class SpeechInput {
  static bool get sttSupported => false;
  static bool get recordSupported => false;
  static Future<String?> listen() async => null;
  static Future<void> startRecording() async {}
  static Future<String?> stopRecording() async => null;
  static void play(String url) {}
  static Future<bool> playClip(String asset, double rate) async => false;
  static void stopClip() {}
  static void unlockOnFirstTap() {}
}
