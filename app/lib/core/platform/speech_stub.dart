import 'speech_result.dart';
export 'speech_result.dart';

class SpeechInput {
  static bool get sttSupported => false;
  static bool get recordSupported => false;
  static bool _broken = false;
  static bool get sttBroken => _broken;
  static void setBroken(bool v) => _broken = v;
  static bool get isIos => false;
  static bool get isStandalone => false;
  static Future<String?> listen() async => null;
  static Future<SpeechResult> listenDetailed({void Function(String partial)? onPartial}) async => const SpeechResult(error: 'unsupported');
  static void stop() {}
  static Future<String> micPermission() async => 'unknown';
  static Future<void> startRecording() async {}
  static Future<String?> stopRecording() async => null;
  static void play(String url) {}
  static Future<bool> playClip(String asset, double rate) async => false;
  static void stopClip() {}
  static void playFx(String asset, {double volume = .5}) {}
  static void stopFx() {}
  static void unlockOnFirstTap() {}
}
