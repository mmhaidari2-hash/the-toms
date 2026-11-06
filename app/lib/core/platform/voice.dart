import 'asset_text.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../i18n/you.dart';
import 'speech.dart';

enum VoiceFailureKind { missing, playback, notReady }

class VoiceFailure {
  final VoiceFailureKind kind;
  final String speaker, text;
  final double rate;
  final String? shown;
  const VoiceFailure(this.kind, this.speaker, this.text, this.rate, this.shown);
}

/// Natural British voices only: every authored line is pre-rendered (tool/render_voices.py) as an mp3,
/// content-addressed by md5("speaker|text"). There is deliberately NO robotic TTS fallback — silent beats robotic.
class Voice {
  static Set<String> _index = {};
  static final failure = ValueNotifier<VoiceFailure?>(null);
  static Future<bool> Function(String, double) _play = SpeechInput.playClip;
  static const rates = [0.72, 0.86, 1.0]; // slow, medium, normal
  static bool _ready = false;
  static bool _allowLoad = true;
  static Future<void>? _loading;

  static Future<void> load() {
    if (!_allowLoad) {
      _ready = false;
      return Future.value();
    }
    return _loading ??= _readIndex();
  }

  static Future<void> _readIndex() async {
    try {
      _index = (jsonDecode(
        await loadAssetText('assets/audio/index.json'),
      ) as List).cast<String>().toSet();
      _ready = true;
    } catch (_) {
      _ready = false;
      _loading = null;
    }
    try {
      await SpeechInput.initAudio();
      SpeechInput.unlockOnFirstTap();
    } catch (_) {}
  }

  /// Career-pack guests (played instead of the learner) whose replies are recorded under their own voice.
  static const guests = ['sara'];

  static String key(String speaker, String text) =>
      md5.convert(utf8.encode('$speaker|$text')).toString().substring(0, 16);

  static String? _find(String speaker, String text) {
    // the learner as an NPC (role switching) reuses the guest's recorded lines.
    for (final sp in {
      speaker,
      if (speaker == 'learner') 'me',
      if (speaker == 'me') ...guests,
    }) {
      for (final t in {text, ?youRawOf[text]}) {
        final k = key(sp, t);
        if (_index.contains(k)) return k;
      }
    }
    return null;
  }

  /// A sound effect (assets/sfx/NAME.mp3) on a separate channel: never interrupts or is interrupted by a voice.
  static void fx(String name, {double volume = .5}) =>
      SpeechInput.playFx('assets/sfx/$name.mp3', volume: volume);
  static void stopFx() => SpeechInput.stopFx();

  static bool has(String speaker, String text) => _find(speaker, text) != null;

  /// Bumped whenever a clip starts or playback is stopped: one clip plays at a time, always to its end
  /// unless something else replaces it.
  static int _gen = 0;

  static void stop() {
    _gen++;
    SpeechInput.stopClip();
    failure.value = null;
  }

  static Future<bool> retry() async {
    final last = failure.value;
    if (last == null || last.kind == VoiceFailureKind.missing) return false;
    if (last.kind == VoiceFailureKind.notReady) {
      _ready = false;
      _loading = null;
      _allowLoad = true;
      await load();
    }
    return say(last.speaker, last.text, rate: last.rate, shown: last.shown);
  }

  @visibleForTesting
  static void debugSetAudio({
    Set<String>? keys,
    Future<bool> Function(String, double)? player,
    bool ready = true,
    bool allowLoad = true,
    bool clear = true,
  }) {
    if (clear) stop();
    if (keys != null) _index = Set.of(keys);
    if (player != null) {
      _play = player;
    } else if (keys != null) {
      _play = SpeechInput.playClip;
    }
    _ready = ready;
    _allowLoad = allowLoad;
    if (!allowLoad) _loading = null;
  }

  /// Plays one whole line as one clip in its speaker's voice. Returns false when the clip was cut short by
  /// another clip or [stop] — "play all" loops must then stop instead of talking over the newer clip.
  static Future<bool> say(
    String speaker,
    String text, {
    double rate = 1,
    String? shown,
    bool scripted = true,
  }) async {
    final ticket = _gen;
    if (!_ready) await load();
    if (ticket != _gen) return false;
    final g = ++_gen;
    failure.value = null;
    final safeRate = rate.isFinite ? rate.clamp(.5, 2.0).toDouble() : 1.0;
    final k =
        _find(speaker, text) ?? (shown == null ? null : _find(speaker, shown));
    if (k == null) {
      SpeechInput.stopClip();
      if (g != _gen) return false;
      // The learner's own unrecorded words are not a missing lesson line.
      if (!scripted) return false;
      failure.value = VoiceFailure(
        _ready ? VoiceFailureKind.missing : VoiceFailureKind.notReady,
        speaker,
        text,
        safeRate,
        shown,
      );
      return false;
    }
    var ok = false;
    try {
      ok = await _play('assets/audio/$k.mp3', safeRate);
    } catch (_) {
      ok = false;
    }
    if (g != _gen) return false;
    if (!ok) {
      failure.value = VoiceFailure(
        VoiceFailureKind.playback,
        speaker,
        text,
        safeRate,
        shown,
      );
    }
    return ok;
  }
}
