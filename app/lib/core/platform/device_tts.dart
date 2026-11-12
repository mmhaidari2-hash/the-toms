import 'package:flutter/foundation.dart';

import 'device_tts_io.dart' if (dart.library.js_interop) 'device_tts_web.dart' as impl;

/// The phone's or browser's OWN text-to-speech voice, used ONLY for library books that have no recorded
/// British clips (Book.deviceVoice). It is never used for course lines (silent beats robotic there) and the
/// reader labels it clearly as a device voice. Free: Android TextToSpeech / Web Speech API, no key, no server
/// of ours. The device's engine decides the voice; some engines may use their own online service.
abstract class DeviceTts {
  static DeviceTtsBackend _b = impl.platformTts();
  @visibleForTesting
  static set debugBackend(DeviceTtsBackend? b) => _b = b ?? impl.platformTts();
  static Future<bool> get available => _b.available();
  /// Speaks [text] in British English; completes true when the whole sentence was spoken, false when it was
  /// stopped or the device has no voice.
  static Future<bool> speak(String text, {double rate = 1}) => _b.speak(text, rate);
  static Future<void> stop() => _b.stop();
}

abstract class DeviceTtsBackend {
  Future<bool> available();
  Future<bool> speak(String text, double rate);
  Future<void> stop();
}
