import 'asset_text.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../i18n/you.dart';
import 'device_tts.dart';
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
/// content-addressed by md5("speaker|text"). NPC lines never fall back to a robotic voice (silent beats robotic).
/// The learner's OWN model line (the reply they say, or a character's line while they play that role) may opt in
/// with `deviceFallback: true` (owner t338): with no recording, or when the clip cannot be played, the phone's own
/// British TTS (DeviceTts, en-GB where installed) reads it, and the "no recording" notice only shows when the
/// device has no voice either.
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
  static int _pub = 0;

  /// How many clips have started or been stopped. Store this before [say]
  /// and call [interrupted] as soon as [say] returns.
  static int get epoch => _gen;

  /// True when something other than that one [say] moved [epoch].
  static bool interrupted(int before) => _gen != before + 1;

  /// Notifies after the current build. A route change stops audio while the
  /// tree is locked; publishing in that moment was marking the lesson dirty.
  static void _publish(VoiceFailure? next) {
    final id = ++_pub;
    void apply() {
      if (_pub != id) return;
      failure.value = next;
    }

    SchedulerBinding? binding;
    try {
      binding = SchedulerBinding.instance;
    } catch (_) {
      binding = null;
    }
    final phase = binding?.schedulerPhase;
    if (binding != null && (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks)) {
      binding.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// True while the device voice is reading a learner line (so [stop] also stops it).
  static bool _deviceSpeaking = false;

  static void stop() {
    _gen++;
    SpeechInput.stopClip();
    if (_deviceSpeaking) {
      _deviceSpeaking = false;
      DeviceTts.stop();
    }
    _publish(null);
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
    bool deviceFallback = false,
  }) async {
    final ticket = _gen;
    if (!_ready) await load();
    if (ticket != _gen) return false;
    final g = ++_gen;
    _publish(null);
    final safeRate = rate.isFinite ? rate.clamp(.5, 2.0).toDouble() : 1.0;
    final k =
        _find(speaker, text) ?? (shown == null ? null : _find(speaker, shown));
    if (k == null) {
      SpeechInput.stopClip();
      if (g != _gen) return false;
      if (deviceFallback && await _device(g, shown ?? text, safeRate)) return true;
      if (g != _gen) return false;
      // The learner's own unrecorded words are not a missing lesson line.
      if (!scripted) return false;
      _publish(VoiceFailure(
        _ready ? VoiceFailureKind.missing : VoiceFailureKind.notReady,
        speaker,
        text,
        safeRate,
        shown,
      ));
      return false;
    }
    var ok = false;
    try {
      ok = await _play('assets/audio/$k.mp3', safeRate);
    } catch (_) {
      ok = false;
    }
    if (g != _gen) return false;
    if (!ok && deviceFallback) {
      if (await _device(g, shown ?? text, safeRate)) return true;
      if (g != _gen) return false;
    }
    if (!ok) {
      _publish(VoiceFailure(
        VoiceFailureKind.playback,
        speaker,
        text,
        safeRate,
        shown,
      ));
    }
    return ok;
  }

  /// Reads [line] with the device's own voice for generation [g]; true only when the whole line was spoken.
  static Future<bool> _device(int g, String line, double rate) async {
    final words = line.replaceAll(RegExp(r'\{you\}'), '').trim();
    if (words.isEmpty) return false;
    try {
      if (!await DeviceTts.available || g != _gen) return false;
      _deviceSpeaking = true;
      final spoke = await DeviceTts.speak(words, rate: rate);
      if (g != _gen) return false;
      _deviceSpeaking = false;
      return spoke;
    } catch (_) {
      if (g == _gen) _deviceSpeaking = false;
      return false;
    }
  }
}
