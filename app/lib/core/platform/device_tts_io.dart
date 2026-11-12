import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'device_tts.dart';

DeviceTtsBackend platformTts() => _ChannelTts();

/// Android: android.speech.tts.TextToSpeech in MainActivity (channel 'newlifeuk/tts'). Other platforms: none.
class _ChannelTts implements DeviceTtsBackend {
  static const _ch = MethodChannel('newlifeuk/tts');
  bool get _android {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> available() async {
    if (!_android) return false;
    try {
      return await _ch.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> speak(String text, double rate) async {
    if (!_android) return false;
    try {
      return await _ch.invokeMethod<bool>('speak', {'text': text, 'rate': rate}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_android) return;
    try {
      await _ch.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
