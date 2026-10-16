import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'speech.dart';

/// Natural British voices only: every authored line is pre-rendered (tool/render_voices.py) as an mp3,
/// content-addressed by md5("speaker|text"). There is deliberately NO robotic TTS fallback — silent beats robotic.
class Voice {
  static Set<String> _index = {};
  static const rates = [0.72, 0.86, 1.0]; // slow, medium, normal

  static Future<void> load() async {
    try {
      _index = (jsonDecode(await rootBundle.loadString('assets/audio/index.json')) as List).cast<String>().toSet();
    } catch (_) {}
    SpeechInput.unlockOnFirstTap();
  }

  static String key(String speaker, String text) => md5.convert(utf8.encode('$speaker|$text')).toString().substring(0, 16);

  static String? _find(String speaker, String text) {
    for (final t in {text, text.replaceAll('Mehdi', '{you}')}) {
      final k = key(speaker, t);
      if (_index.contains(k)) return k;
    }
    return null;
  }

  static bool has(String speaker, String text) => _find(speaker, text) != null;

  static void stop() => SpeechInput.stopClip();

  static Future<void> say(String speaker, String text, {double rate = 1, String? shown}) async {
    final k = _find(speaker, text) ?? (shown == null ? null : _find(speaker, shown));
    if (k == null) return;
    await SpeechInput.playClip('assets/audio/$k.mp3', rate);
  }
}
