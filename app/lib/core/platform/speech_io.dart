import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, HttpClient, HttpHeaders, Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../billing/offline_voices.dart';
import 'audio_ver.g.dart';
import 'native_stt.dart';
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
  static const remoteBase =
      'https://mmhaidari2-hash.github.io/the-toms/assets/';
  static final bool _native = Platform.isAndroid;

  // ---- Speech recognition (owner t306 item 1): Android's own SpeechRecognizer, on-device when the phone has an
  // offline English model. The app never records or uploads audio itself. Other native platforms: typing only.
  static NativeStt? _sttP;
  static bool _sttForced = false;
  static NativeStt get _stt => _sttP ??= NativeStt(PluginSttBackend());

  /// Test seam: run the Android recognizer path on the test VM with a fake backend (null resets).
  @visibleForTesting
  static void debugUseStt(NativeStt? stt) {
    _sttP = stt;
    _sttForced = stt != null;
  }

  static bool get sttSupported => (_native || _sttForced) && !(_sttP?.unavailable ?? false);
  static bool get recordSupported => false;
  static bool get sttBroken => stub.SpeechInput.sttBroken;
  static void setBroken(bool v) => stub.SpeechInput.setBroken(v);
  static bool get isIos => false;
  static bool get isStandalone => false;
  static Future<String?> listen() async {
    final r = await listenDetailed();
    return r.ok ? r.best : null;
  }

  static Future<SpeechResult> listenDetailed({
    void Function(String partial)? onPartial,
  }) async {
    if (!sttSupported) return const SpeechResult(error: 'unsupported');
    stopClip(); // never transcribe our own voice clip
    return _stt.listen(onPartial: onPartial);
  }

  static void stop() {
    if (_native || _sttForced) _sttP?.stop();
  }

  static Future<String> micPermission() async {
    if (!sttSupported) return 'unknown';
    try {
      return await _stt.backend.hasPermission() ? 'granted' : 'prompt';
    } catch (_) {
      return 'unknown';
    }
  }
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
  static final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

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
      final req = await _http.getUrl(
        Uri.parse(
          '${remoteBase}assets/audio/ver.json?ts=${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final v = (jsonDecode(body) as Map)['v'];
        if (v is String && v.isNotEmpty) _ver = v;
      }
    } catch (_) {}
    try {
      // Online-only clips from the last session (no offline voices entitlement) are not kept.
      final session = await sessionDirectory();
      await session.delete(recursive: true);
    } catch (_) {}
    try {
      final dir = await clipCacheDirectory();
      // Drop caches from older voice casts.
      await for (final e in dir.parent.list()) {
        if (e is Directory &&
            e.path.contains('nl_audio_') &&
            e.path != dir.path) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    _ready = true;
  }

  /// Versioned folder [resolveClip] reads. Arrival warming writes this same folder.
  static Future<Directory> clipCacheDirectory() async {
    final base = await _cacheRoot();
    final dir = Directory('${base.path}/nl_audio_$_ver');
    await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Per-session folder for clips played online without the offline voices entitlement. Wiped at start-up.
  static Future<Directory> sessionDirectory() async {
    final base = await _cacheRoot();
    final dir = Directory('${base.path}/nl_session');
    await dir.create(recursive: true);
    return dir;
  }

  /// Where a freshly downloaded clip goes: the persistent cache (offline voices: Premium, beta, web-free builds)
  /// or the session folder (online playback only). See [OfflineVoices].
  static Future<File> downloadTarget(String name) async {
    if (OfflineVoices.allowed()) {
      final dir = _cacheDir ?? await clipCacheDirectory();
      return File('${dir.path}/$name');
    }
    return File('${(await sessionDirectory()).path}/$name');
  }

  /// Write a finished clip to [target] via a sibling `.part` file, then rename.
  /// A non-200, exception, or short body never reaches here; a crash mid-write
  /// leaves only the `.part`, which is deleted and never played from the cache.
  @visibleForTesting
  static Future<void> commitDownload(File target, List<int> bytes) async {
    if (bytes.length <= 64) {
      throw StateError('short body ${bytes.length}');
    }
    final part = File('${target.path}.part');
    try {
      if (await part.exists()) await part.delete();
      await part.writeAsBytes(bytes, flush: true);
      if (await part.length() != bytes.length) {
        throw StateError('short write ${await part.length()} != ${bytes.length}');
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
    } catch (_) {
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    }
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
      return AssetSource(
        asset.replaceFirst('assets/', ''),
        mimeType: 'audio/mpeg',
      );
    }
    if (_bundled.contains(key)) {
      return AssetSource(
        asset.replaceFirst('assets/', ''),
        mimeType: 'audio/mpeg',
      );
    }
    final dir = _cacheDir;
    if (dir != null) {
      final file = File('${dir.path}/$name');
      final leftover = File('${file.path}.part');
      try {
        if (await leftover.exists()) await leftover.delete();
      } catch (_) {}
      if (await file.exists() && await file.length() > 64) {
        return DeviceFileSource(file.path, mimeType: 'audio/mpeg');
      }
      final url = remoteUrlFor(asset);
      try {
        final target = await downloadTarget(name);
        if (target.path != file.path && await target.exists() && await target.length() > 64) {
          return DeviceFileSource(target.path, mimeType: 'audio/mpeg');
        }
        final bytes = await _download(url);
        if (bytes.length > 64) {
          await commitDownload(target, bytes);
          return DeviceFileSource(target.path, mimeType: 'audio/mpeg');
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
      final expected = res.contentLength;
      final bytes = <int>[];
      await for (final chunk in res) {
        bytes.addAll(chunk);
      }
      if (expected >= 0 && bytes.length != expected) {
        throw StateError('short body ${bytes.length} != $expected for $url');
      }
      if (bytes.length <= 64) {
        throw StateError('short body ${bytes.length} for $url');
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
    if (asset.startsWith('assets/audio/') &&
        !asset.endsWith('/silence.mp3') &&
        !asset.endsWith('silence.mp3')) {
      if (_bundled.contains(key)) {
        return AssetSource(
          asset.replaceFirst('assets/', ''),
          mimeType: 'audio/mpeg',
        );
      }
      return UrlSource(remoteUrlFor(asset), mimeType: 'audio/mpeg');
    }
    if (asset.endsWith('silence.mp3')) {
      return AssetSource(
        asset.replaceFirst('assets/', ''),
        mimeType: 'audio/mpeg',
      );
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
    if (old != null && !old.isCompleted) old.complete(false);
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
        await _voice
            .play(UrlSource(remoteUrlFor(asset), mimeType: 'audio/mpeg'))
            .timeout(const Duration(seconds: 25));
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
    if (old != null && !old.isCompleted) old.complete(false);
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
