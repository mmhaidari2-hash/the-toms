import 'asset_text.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../i18n/you.dart';
import 'speech.dart';

/// Natural British voices only: every authored line is pre-rendered (tool/render_voices.py) as an mp3,
/// content-addressed by md5("speaker|text"). There is deliberately NO robotic TTS fallback — silent beats robotic.
class Voice {
  static Set<String> _index = {};
  static const rates = [0.72, 0.86, 1.0]; // slow, medium, normal

  static Future<void> load() async {
    try {
      _index = (jsonDecode(await loadAssetText('assets/audio/index.json')) as List).cast<String>().toSet();
    } catch (_) {}
    SpeechInput.unlockOnFirstTap();
  }

  /// Career-pack guests (played instead of Mehdi) whose replies are recorded under their own voice.
  static const guests = ['sara'];

  static String key(String speaker, String text) => md5.convert(utf8.encode('$speaker|$text')).toString().substring(0, 16);

  static String? _find(String speaker, String text) {
    // Mehdi as an NPC (role switching) reuses the guest's recorded lines.
    for (final sp in {speaker, if (speaker == 'mehdi') 'me', if (speaker == 'me') ...guests}) {
      for (final t in {text, text.replaceAll('Mehdi', '{you}'), ?youRawOf[text]}) {
        final k = key(sp, t);
        if (_index.contains(k)) return k;
      }
    }
    return null;
  }

  /// A sound effect (assets/sfx/NAME.mp3) on a separate channel: never interrupts or is interrupted by a voice.
  static void fx(String name, {double volume = .5}) => SpeechInput.playFx('assets/sfx/$name.mp3', volume: volume);
  static void stopFx() => SpeechInput.stopFx();

  static bool has(String speaker, String text) => _find(speaker, text) != null;

  /// Bumped whenever a clip starts or playback is stopped: one clip plays at a time, always to its end
  /// unless something else replaces it.
  static int _gen = 0;

  static void stop() {
    _gen++;
    SpeechInput.stopClip();
  }

  /// Plays one whole line as one clip in its speaker's voice. Returns false when the clip was cut short by
  /// another clip or [stop] — "play all" loops must then stop instead of talking over the newer clip.
  static Future<bool> say(String speaker, String text, {double rate = 1, String? shown}) async {
    final k = _find(speaker, text) ?? (shown == null ? null : _find(speaker, shown));
    if (k == null) return true;
    final g = ++_gen;
    await SpeechInput.playClip('assets/audio/$k.mp3', rate);
    return g == _gen;
  }
}
