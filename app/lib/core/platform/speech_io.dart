import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, HttpClient, HttpHeaders, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'audio_ver.g.dart';
import 'speech_result.dart';
import 'speech_stub.dart' as stub;
export 'speech_result.dart';

/// Native (Android) build: Azure neural clips only — never device TTS.
///
/// Clips are too big to pack (~565 MB). Strategy:
/// 1. Early-lesson clips listed in assets/audio/bundled.json play from the APK (offline).
/// 2. Everything else downloads once to a versioned on-device cache, then plays as a local file.
/// 3. URLs carry ?v=`audioCacheVer` so a re-voice never returns a stale HTTP/MediaPlayer cache.
/// 4. mimeType is always audio/mpeg (GitHub Pages sends audio/mp3, which some MediaPlayers reject).
class SpeechInput {
  static const remoteBase = 'https://mmhaidari2-hash.github.io/the-toms/assets/';
  static final bool _native = Platform.isAndroid;

  static bool get sttSupported => false;
  static bool get recordSupported => false;
  static bool get sttBroken => stub.SpeechInput.sttBroken;
  static void setBroken(bool v) => stub.SpeechInput.setBroken(v);
  static bool get isIos => false;
  static bool get isStandalone => false;
  static Future<String?> listen() async => null;
  static Future<SpeechResult> listenDetailed({void Function(String partial)? onPartial}) async =>
      const SpeechResult(error: 'unsupported');
  static void stop() {}
  static Future<String> micPermission() async => 'unknown';
  static Future<void> startRecording() async {}
  static Future<String?> stopRecording() async => null;

  static AudioPlayer? _voiceP, _fxP;
  static AudioPlayer get _voice => _voiceP ??= AudioPlayer(playerId: 'voice');
  static AudioPlayer get _fx => _fxP ??= AudioPlayer(playerId: 'fx');
  static Completer<bool>? _pending;
  static StreamSubscription<void>? _doneSub;

  static Set<String> _bundled = {};
  static String _ver = kAudioCacheVer;
  static Directory? _cacheDir;
  static bool _ready = false;
  static final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 12);

  /// Exposed for tests / QA gate.
  static String get audioVer => _ver;
  static Set<String> get bundledKeys => Set.unmodifiable(_bundled);
  static String remoteUrlFor(String asset) => '$remoteBase$asset?v=$_ver';

  /// Call once at startup (from [Voice.load]). Safe to call repeatedly.
  static Future<void> initAudio() async {
    if (!_native) return;
    if (_ready) return;
    try {
      await _voice.setReleaseMode(ReleaseMode.stop);
      await _fx.setReleaseMode(ReleaseMode.stop);
      final ctx = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.assistanceAccessibility,
          audioFocus: AndroidAudioFocus.gain,
        ),
      );
      await _voice.setAudioContext(ctx);
      await _fx.setAudioContext(ctx);
    } catch (_) {}
    try {
      final raw = await rootBundle.loadString('assets/audio/bundled.json');
      _bundled = (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      _bundled = {};
    }
    try {
      // Prefer the live site's audio version so a re-voice without a new APK still busts the cache.
      final req = await _http.getUrl(Uri.parse('${remoteBase}assets/audio/ver.json?ts=${DateTime.now().millisecondsSinceEpoch}'));
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final v = (jsonDecode(body) as Map)['v'];
        if (v is String && v.isNotEmpty) _ver = v;
      }
    } catch (_) {}
    try {
      final base = await _cacheRoot();
      _cacheDir = Directory('${base.path}/nl_audio_$_ver');
      await _cacheDir!.create(recursive: true);
      // Drop caches from older voice casts.
      await for (final e in base.list()) {
        if (e is Directory && e.path.contains('nl_audio_') && e.path != _cacheDir!.path) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    _ready = true;
  }

  static Future<Directory> _cacheRoot() async {
    // path_provider is a transitive dep of audioplayers; avoid a hard import by using the same temp pattern.
    final tmp = Directory.systemTemp;
    final d = Directory('${tmp.path}/newlifeuk_audio');
    await d.create(recursive: true);
    return d;
  }

  /// Resolve how to play a voice clip. Bundled → asset; else cached file; else download then file.
  /// Never returns a TTS source.
  static Future<Source> resolveClip(String asset) async {
    final name = asset.split('/').last; // KEY.mp3
    final key = name.replaceAll('.mp3', '');
    if (asset.endsWith('/silence.mp3') || asset.endsWith('silence.mp3')) {
      return AssetSource(asset.replaceFirst('assets/', ''), mimeType: 'audio/mpeg');
    }
    if (_bundled.contains(key)) {
      return AssetSource(asset.replaceFirst('assets/', ''), mimeType: 'audio/mpeg');
    }
    final dir = _cacheDir;
    if (dir != null) {
      final file = File('${dir.path}/$name');
      if (await file.exists() && await file.length() > 64) {
        return DeviceFileSource(file.path, mimeType: 'audio/mpeg');
      }
      final url = remoteUrlFor(asset);
      try {
        final bytes = await _download(url);
        if (bytes.length > 64) {
          await file.writeAsBytes(bytes, flush: true);
          return DeviceFileSource(file.path, mimeType: 'audio/mpeg');
        }
      } catch (_) {}
      // Last resort: stream with explicit MPEG mime + cache buster (still Azure clip, never TTS).
      return UrlSource(url, mimeType: 'audio/mpeg');
    }
    return UrlSource(remoteUrlFor(asset), mimeType: 'audio/mpeg');
  }

  static Future<List<int>> _download(String url) async {
    final uri = Uri.parse(url);
    Future<List<int>> once() async {
      final req = await _http.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'audio/mpeg,audio/*,*/*');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('HTTP ${res.statusCode} for $url');
      }
      final bytes = <int>[];
      await for (final chunk in res) {
        bytes.addAll(chunk);
      }
      return bytes;
    }

    try {
      return await once();
    } catch (_) {
      return await once(); // one retry
    }
  }

  /// Sync helper for unit tests (no I/O): bundled → AssetSource, else UrlSource with ?v= and mpeg mime.
  static Source sourceFor(String asset) {
    final name = asset.split('/').last;
    final key = name.replaceAll('.mp3', '');
    if (asset.startsWith('assets/audio/') && !asset.endsWith('/silence.mp3') && !asset.endsWith('silence.mp3')) {
      if (_bundled.contains(key)) {
        return AssetSource(asset.replaceFirst('assets/', ''), mimeType: 'audio/mpeg');
      }
      return UrlSource(remoteUrlFor(asset), mimeType: 'audio/mpeg');
    }
    if (asset.endsWith('silence.mp3')) {
      return AssetSource(asset.replaceFirst('assets/', ''), mimeType: 'audio/mpeg');
    }
    return AssetSource(asset.replaceFirst('assets/', ''));
  }

  /// Test seam: seed bundled keys without loading assets.
  static void debugSetBundled(Set<String> keys) => _bundled = Set.of(keys);
  static void debugSetVer(String v) => _ver = v;

  static void play(String url) {
    if (_native) _voice.play(UrlSource(url, mimeType: 'audio/mpeg'));
  }

  static Future<bool> playClip(String asset, double rate) async {
    if (!_native) return false;
    if (!_ready) await initAudio();
    final old = _pending;
    if (old != null && !old.isCompleted) old.complete(true);
    final c = _pending = Completer<bool>();
    await _doneSub?.cancel();
    _doneSub = _voice.onPlayerComplete.listen((_) {
      if (!c.isCompleted) c.complete(true);
    });
    try {
      await _voice.stop();
      final src = await resolveClip(asset);
      // Set rate after the source is attached (docs: call after play/resume); play() applies stored rate on start.
      await _voice.setPlaybackRate(rate.clamp(0.5, 2.0));
      await _voice.play(src).timeout(const Duration(seconds: 25));
      await _voice.setPlaybackRate(rate.clamp(0.5, 2.0));
    } catch (_) {
      // One more attempt via direct URL stream — still Azure, never TTS.
      try {
        await _voice.stop();
        await _voice.play(UrlSource(remoteUrlFor(asset), mimeType: 'audio/mpeg')).timeout(const Duration(seconds: 25));
        await _voice.setPlaybackRate(rate.clamp(0.5, 2.0));
      } catch (_) {
        if (!c.isCompleted) c.complete(false);
      }
    }
    return c.future;
  }

  static void stopClip() {
    if (_native) _voice.stop();
    final old = _pending;
    if (old != null && !old.isCompleted) old.complete(true);
    _pending = null;
  }

  static void playFx(String asset, {double volume = .5}) {
    if (!_native) return;
    _fx.play(sourceFor(asset), volume: volume).catchError((_) {});
  }

  static void stopFx() {
    if (_native) _fx.stop();
  }

  static void unlockOnFirstTap() {}
}
