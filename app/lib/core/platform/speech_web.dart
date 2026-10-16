import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Web Speech API (optional STT, en-GB) + MediaRecorder for shadowing. Everything stays on the device.
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
