import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';

import 'speech_stub.dart' as stub;
import 'speech_result.dart';
export 'speech_result.dart';

/// Native (Android) build: voice clips and sound effects through the platform media player.
/// The ~44k voice clips are not packed into the APK (they would make it >600 MB); they stream from the
/// app's own site and play the same files the web app plays. Sound effects and the clip index are bundled.
/// Speech recognition / recording are not offered natively yet (same as the stub: the app falls back to tap modes).
/// Off Android (unit tests on the VM) everything behaves exactly like the stub.
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
  static Future<SpeechResult> listenDetailed({void Function(String partial)? onPartial}) async => const SpeechResult(error: 'unsupported');
  static void stop() {}
  static Future<String> micPermission() async => 'unknown';
  static Future<void> startRecording() async {}
  static Future<String?> stopRecording() async => null;

  static AudioPlayer? _voiceP, _fxP;
  static AudioPlayer get _voice => _voiceP ??= AudioPlayer(playerId: 'voice');
  static AudioPlayer get _fx => _fxP ??= AudioPlayer(playerId: 'fx');
  static Completer<bool>? _pending;
  static StreamSubscription<void>? _doneSub;

  /// 'assets/audio/x.mp3' streams from the site; any other bundled asset plays from the APK.
  static Source sourceFor(String asset) => asset.startsWith('assets/audio/') && !asset.endsWith('/silence.mp3')
      ? UrlSource('$remoteBase$asset')
      : AssetSource(asset.replaceFirst('assets/', ''));

  static void play(String url) {
    if (_native) _voice.play(UrlSource(url));
  }

  static Future<bool> playClip(String asset, double rate) async {
    if (!_native) return false;
    final old = _pending;
    if (old != null && !old.isCompleted) old.complete(true);
    final c = _pending = Completer<bool>();
    await _doneSub?.cancel();
    _doneSub = _voice.onPlayerComplete.listen((_) {
      if (!c.isCompleted) c.complete(true);
    });
    try {
      await _voice.stop();
      await _voice.setPlaybackRate(rate);
      await _voice.play(sourceFor(asset)).timeout(const Duration(seconds: 15));
      await _voice.setPlaybackRate(rate);
    } catch (_) {
      if (!c.isCompleted) c.complete(false);
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
