import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'speech_result.dart';
export 'speech_result.dart';

/// Web Speech API (optional STT, en-GB) + MediaRecorder for shadowing.
/// Privacy: speech-to-text is done by the browser's own speech service (Google in Chrome, Apple in Safari),
/// which may send the audio to its servers. The Toms never stores or uploads recordings itself;
/// MediaRecorder clips stay in memory on the device.
class SpeechInput {
  static JSFunction? get _ctor => (globalContext['SpeechRecognition'] ?? globalContext['webkitSpeechRecognition']) as JSFunction?;
  static bool get sttSupported => _ctor != null;
  static bool get recordSupported => globalContext.has('MediaRecorder') && web.window.navigator.mediaDevices.isA<web.MediaDevices>();

  static Future<String?> listen() {
    final c = Completer<String?>();
    final ctor = _ctor;
    if (ctor == null) return Future.value(null);
    final rec = ctor.callAsConstructor<JSObject>();
    rec['lang'] = 'en-GB'.toJS;
    rec['interimResults'] = false.toJS;
    rec['maxAlternatives'] = 1.toJS;
    rec['onresult'] = ((JSObject e) {
      final results = e['results'] as JSObject;
      final first = (results.callMethod<JSObject>('item'.toJS, 0.toJS)).callMethod<JSObject>('item'.toJS, 0.toJS);
      if (!c.isCompleted) c.complete((first['transcript'] as JSString).toDart);
    }).toJS;
    rec['onerror'] = ((JSObject _) {
      if (!c.isCompleted) c.complete(null);
    }).toJS;
    rec['onend'] = ((JSObject _) {
      if (!c.isCompleted) c.complete(null);
    }).toJS;
    rec.callMethod('start'.toJS);
    return c.future.timeout(const Duration(seconds: 12), onTimeout: () => null);
  }

  static JSObject? _active;

  /// Detailed recognition: up to 3 alternatives, live partial text and a clear error code
  /// ('not-allowed' = mic or speech permission denied, 'service-not-allowed' = iPhone Siri/Dictation off,
  /// 'no-speech', 'audio-capture', 'network', 'aborted'). Must be called straight from a tap (iOS).
  static Future<SpeechResult> listenDetailed({void Function(String partial)? onPartial}) {
    final c = Completer<SpeechResult>();
    final ctor = _ctor;
    if (ctor == null) return Future.value(const SpeechResult(error: 'unsupported'));
    stop();
    final rec = ctor.callAsConstructor<JSObject>();
    _active = rec;
    rec['lang'] = 'en-GB'.toJS;
    rec['interimResults'] = (onPartial != null).toJS;
    rec['continuous'] = false.toJS;
    rec['maxAlternatives'] = 3.toJS;
    final alts = <String>[];
    double conf = 0;
    rec['onresult'] = ((JSObject e) {
      final results = e['results'] as JSObject;
      final n = (results['length'] as JSNumber).toDartInt;
      if (n == 0) return;
      final last = results.callMethod<JSObject>('item'.toJS, (n - 1).toJS);
      final isFinal = (last['isFinal'] as JSBoolean?)?.toDart ?? true;
      final m = (last['length'] as JSNumber).toDartInt;
      final texts = [for (var i = 0; i < m; i++) ((last.callMethod<JSObject>('item'.toJS, i.toJS))['transcript'] as JSString).toDart];
      if (!isFinal) {
        if (texts.isNotEmpty) onPartial?.call(texts.first);
        return;
      }
      alts
        ..clear()
        ..addAll(texts);
      conf = ((last.callMethod<JSObject>('item'.toJS, 0.toJS))['confidence'] as JSNumber?)?.toDartDouble ?? 0;
      if (!c.isCompleted) c.complete(SpeechResult(alternatives: alts, confidence: conf));
    }).toJS;
    rec['onerror'] = ((JSObject e) {
      final code = (e['error'] as JSString?)?.toDart ?? 'error';
      if (!c.isCompleted) c.complete(SpeechResult(error: code));
    }).toJS;
    rec['onend'] = ((JSObject _) {
      if (_active == rec) _active = null;
      if (!c.isCompleted) c.complete(alts.isEmpty ? const SpeechResult(error: 'no-speech') : SpeechResult(alternatives: alts, confidence: conf));
    }).toJS;
    try {
      rec.callMethod('start'.toJS);
    } catch (_) {
      return Future.value(const SpeechResult(error: 'not-allowed'));
    }
    return c.future.timeout(const Duration(seconds: 15), onTimeout: () {
      stop();
      return const SpeechResult(error: 'no-speech');
    });
  }

  /// Stops listening early (the result so far is still delivered).
  static void stop() {
    final a = _active;
    if (a == null) return;
    try {
      a.callMethod('stop'.toJS);
    } catch (_) {}
    _active = null;
  }

  /// 'granted', 'denied', 'prompt' or 'unknown' (Safari may not support the Permissions API).
  static Future<String> micPermission() async {
    try {
      final perms = web.window.navigator.permissions;
      final st = await perms.query({'name': 'microphone'}.jsify() as JSObject).toDart;
      return st.state;
    } catch (_) {
      return 'unknown';
    }
  }

  static web.MediaRecorder? _rec;
  static final _chunks = <web.Blob>[];

  static Future<void> startRecording() async {
    final stream = await web.window.navigator.mediaDevices.getUserMedia(web.MediaStreamConstraints(audio: true.toJS)).toDart;
    _chunks.clear();
    final r = web.MediaRecorder(stream);
    r.ondataavailable = ((web.BlobEvent e) => _chunks.add(e.data)).toJS;
    r.start();
    _rec = r;
  }

  static Future<String?> stopRecording() async {
    final r = _rec;
    if (r == null) return null;
    final done = Completer<void>();
    r.onstop = ((web.Event _) => done.complete()).toJS;
    r.stop();
    await done.future;
    r.stream.getTracks().toDart.forEach((t) => t.stop());
    _rec = null;
    final blob = web.Blob(_chunks.toJS, web.BlobPropertyBag(type: r.mimeType));
    return web.URL.createObjectURL(blob);
  }

  static void play(String url) => web.HTMLAudioElement()
    ..src = url
    ..play();

  // One shared element: once iOS has seen it play inside a tap, later programmatic plays are allowed.
  static final web.HTMLAudioElement _el = web.HTMLAudioElement()..preload = 'auto';
  static Completer<bool>? _pending;

  /// Plays a bundled clip; completes true when it finished, false if it could not play.
  static Future<bool> playClip(String asset, double rate) {
    final old = _pending;
    if (old != null && !old.isCompleted) old.complete(true);
    final c = _pending = Completer<bool>();
    void done(bool ok) {
      if (!c.isCompleted) c.complete(ok);
    }

    _el.onended = ((web.Event _) => done(true)).toJS;
    _el.onerror = ((web.Event _) => done(false)).toJS;
    _el.src = ui_web.assetManager.getAssetUrl(asset);
    _el.playbackRate = rate;
    _el.defaultPlaybackRate = rate;
    _el.play().toDart.then((_) {
      _el.playbackRate = rate;
    }, onError: (_) {
      done(false);
    });
    return c.future;
  }

  // iOS: media may only start inside a user gesture. On the very first touch we play a silent
  // clip on the shared element; from then on Safari lets it play programmatically (auto-play lines).
  static bool _unlocked = false;
  static void unlockOnFirstTap() {
    late final JSFunction h;
    h = ((web.Event _) {
      if (_unlocked) return;
      _unlocked = true;
      if (_pending == null) {
        _el.src = ui_web.assetManager.getAssetUrl('assets/audio/silence.mp3');
        _el.play().toDart.then((_) {}, onError: (_) {});
      }
      web.document.removeEventListener('touchend', h);
      web.document.removeEventListener('pointerdown', h);
    }).toJS;
    web.document.addEventListener('touchend', h);
    web.document.addEventListener('pointerdown', h);
  }

  static void stopClip() {
    _el.pause();
    final old = _pending;
    if (old != null && !old.isCompleted) old.complete(true);
    _pending = null;
  }
}
