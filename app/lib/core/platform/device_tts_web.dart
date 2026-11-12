import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'device_tts.dart';

DeviceTtsBackend platformTts() => _WebTts();

/// Browser: Web Speech API speechSynthesis with an en-GB voice when the browser has one.
class _WebTts implements DeviceTtsBackend {
  int _gen = 0;
  web.SpeechSynthesis? get _s {
    try {
      return web.window.speechSynthesis;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> available() async => _s != null;

  @override
  Future<bool> speak(String text, double rate) {
    final s = _s;
    if (s == null) return Future.value(false);
    final g = ++_gen;
    s.cancel();
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = 'en-GB'
      ..rate = rate;
    try {
      for (final v in s.getVoices().toDart) {
        if (v.lang.toLowerCase().replaceAll('_', '-') == 'en-gb') {
          u.voice = v;
          break;
        }
      }
    } catch (_) {}
    final done = Completer<bool>();
    u.onend = ((web.Event _) {
      if (!done.isCompleted) done.complete(g == _gen);
    }).toJS;
    u.onerror = ((web.Event _) {
      if (!done.isCompleted) done.complete(false);
    }).toJS;
    s.speak(u);
    return done.future;
  }

  @override
  Future<void> stop() async {
    _gen++;
    _s?.cancel();
  }
}
