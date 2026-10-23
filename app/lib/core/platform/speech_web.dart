import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'speech_result.dart';
export 'speech_result.dart';

/// Web Speech API (optional STT, en-GB) + MediaRecorder for shadowing.
/// Privacy: speech-to-text is done by the browser's own speech service (Google in Chrome, Apple in Safari),
/// which may send the audio to its servers. New Life UK never stores or uploads recordings itself;
/// MediaRecorder clips stay in memory on the device.
class SpeechInput {
  static JSFunction? get _ctor => (globalContext['SpeechRecognition'] ?? globalContext['webkitSpeechRecognition']) as JSFunction?;
  static bool get sttSupported => _ctor != null;
  /// Set when this device's speech service failed to start (iOS Home Screen app, Siri/Dictation off, no
  /// network): the mic then goes straight to the keyboard's own dictation mic, which works everywhere.
  static bool get sttBroken {
    try {
      return web.window.localStorage.getItem('nl_stt_broken') == '1';
    } catch (_) {
      return false;
    }
  }

  static void setBroken(bool v) {
    try {
      v ? web.window.localStorage.setItem('nl_stt_broken', '1') : web.window.localStorage.removeItem('nl_stt_broken');
      if (!v) web.window.localStorage.removeItem('nl_stt_fail');
    } catch (_) {}
  }

  static int _bumpFail() {
    try {
      final n = (int.tryParse(web.window.localStorage.getItem('nl_stt_fail') ?? '') ?? 0) + 1;
      web.window.localStorage.setItem('nl_stt_fail', '$n');
      return n;
    } catch (_) {
      return 2;
    }
  }

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
  static Timer? _quiet;

  /// iPhone / iPad (including iPadOS that reports itself as a Mac).
  static bool get isIos {
    final ua = web.window.navigator.userAgent;
    return RegExp('iPhone|iPad|iPod').hasMatch(ua) || (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
  }

  /// Opened from the Home Screen (iOS standalone web app), where Apple's speech service is often unavailable.
  static bool get isStandalone {
    try {
      final nav = web.window.navigator as JSObject;
      if ((nav['standalone'] as JSBoolean?)?.toDart ?? false) return true;
      return web.window.matchMedia('(display-mode: standalone)').matches;
    } catch (_) {
      return false;
    }
  }

  /// Detailed recognition: up to 3 alternatives, live partial text and a clear error code
  /// ('not-allowed' = mic or speech permission denied, 'service-not-allowed' = iPhone Siri/Dictation off or a
  /// Home Screen app without speech, 'no-speech', 'audio-capture', 'network', 'aborted', 'start-failed').
  /// Must be called straight from a tap (iOS).
  ///
  /// iOS Safari quirks handled here: it often never marks a result final and may not end by itself after the
  /// learner stops talking, and a tap on "stop" ends without a final result. So the latest partial text counts
  /// as the answer, ~1.4 s of silence after speech ends the turn, and the turn is capped at 10 s.
  static Future<SpeechResult> listenDetailed({void Function(String partial)? onPartial}) {
    final c = Completer<SpeechResult>();
    final ctor = _ctor;
    if (ctor == null) return Future.value(const SpeechResult(error: 'unsupported'));
    stop();
    // Our own clips must be silent first: iOS will not record while an audio element is playing.
    stopClip();
    stopFx();
    final rec = ctor.callAsConstructor<JSObject>();
    _active = rec;
    rec['lang'] = 'en-GB'.toJS;
    rec['interimResults'] = true.toJS;
    rec['continuous'] = false.toJS;
    rec['maxAlternatives'] = 3.toJS;
    final alts = <String>[];
    var partial = '';
    double conf = 0;
    var started = false;
    void finish(SpeechResult r) {
      _quiet?.cancel();
      if (!c.isCompleted) {
        if (r.error == 'service-not-allowed') {
          setBroken(true);
        } else if (r.error == 'start-failed' || r.error == 'network') {
          // One slow start can be the first-time permission prompt (iOS waits for the tap): only a second
          // failure in a row switches the mic to keyboard dictation.
          if (_bumpFail() >= 2) setBroken(true);
        } else if (r.ok) {
          setBroken(false);
        }
      }
      if (!c.isCompleted) c.complete(r);
    }

    SpeechResult soFar(String err) =>
        alts.isNotEmpty ? SpeechResult(alternatives: List.of(alts), confidence: conf) : partial.trim().isNotEmpty ? SpeechResult(alternatives: [partial.trim()], confidence: .6) : SpeechResult(error: err);
    void endSoon() {
      // Ask the browser to finish; if it never answers (iOS), use what we heard.
      try {
        rec.callMethod('stop'.toJS);
      } catch (_) {}
      Timer(const Duration(milliseconds: 700), () {
        try {
          rec.callMethod('abort'.toJS);
        } catch (_) {}
        finish(soFar('no-speech'));
      });
    }

    rec['onstart'] = ((JSObject _) => started = true).toJS;
    rec['onaudiostart'] = ((JSObject _) => started = true).toJS;
    rec['onresult'] = ((JSObject e) {
      started = true;
      final results = e['results'] as JSObject;
      final n = (results['length'] as JSNumber).toDartInt;
      if (n == 0) return;
      // Join every result so far (Safari may split one utterance into several).
      final buf = StringBuffer();
      var allFinal = true;
      for (var i = 0; i < n; i++) {
        final r = results.callMethod<JSObject>('item'.toJS, i.toJS);
        if (!((r['isFinal'] as JSBoolean?)?.toDart ?? true)) allFinal = false;
        buf.write('${((r.callMethod<JSObject>('item'.toJS, 0.toJS))['transcript'] as JSString).toDart} ');
      }
      final text = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      final last = results.callMethod<JSObject>('item'.toJS, (n - 1).toJS);
      if (!allFinal) {
        partial = text;
        if (text.isNotEmpty) onPartial?.call(text);
        _quiet?.cancel();
        _quiet = Timer(const Duration(milliseconds: 1400), endSoon);
        return;
      }
      final m = (last['length'] as JSNumber).toDartInt;
      final prefix = n > 1 ? text.substring(0, text.length - ((last.callMethod<JSObject>('item'.toJS, 0.toJS))['transcript'] as JSString).toDart.trim().length).trim() : '';
      alts
        ..clear()
        ..addAll([for (var i = 0; i < m; i++) '$prefix ${((last.callMethod<JSObject>('item'.toJS, i.toJS))['transcript'] as JSString).toDart}'.trim()]);
      conf = ((last.callMethod<JSObject>('item'.toJS, 0.toJS))['confidence'] as JSNumber?)?.toDartDouble ?? 0;
      if (conf == 0) conf = .8; // Safari reports 0 for confident results.
      finish(SpeechResult(alternatives: alts, confidence: conf));
      try {
        rec.callMethod('stop'.toJS);
      } catch (_) {}
    }).toJS;
    rec['onerror'] = ((JSObject e) {
      final code = (e['error'] as JSString?)?.toDart ?? 'error';
      // 'aborted'/'no-speech' after we already heard words: keep the words.
      if ((code == 'aborted' || code == 'no-speech') && (alts.isNotEmpty || partial.isNotEmpty)) {
        finish(soFar(code));
      } else {
        finish(SpeechResult(error: code));
      }
    }).toJS;
    rec['onend'] = ((JSObject _) {
      if (_active == rec) _active = null;
      finish(soFar('no-speech'));
    }).toJS;
    try {
      rec.callMethod('start'.toJS);
    } catch (_) {
      return Future.value(const SpeechResult(error: 'not-allowed'));
    }
    // Nothing at all within 4 s (no onstart): the speech service is not working here.
    Timer(const Duration(seconds: 4), () {
      if (!started && !c.isCompleted) {
        try {
          rec.callMethod('abort'.toJS);
        } catch (_) {}
        finish(const SpeechResult(error: 'start-failed'));
      }
    });
    return c.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _quiet?.cancel();
      try {
        rec.callMethod('abort'.toJS);
      } catch (_) {}
      if (_active == rec) _active = null;
      return soFar('no-speech');
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

  /// Sound effects on their own channel, so they never cut a voice clip.
  static final web.HTMLAudioElement _fx = web.HTMLAudioElement()..preload = 'auto';
  static void playFx(String asset, {double volume = .5}) {
    _fx.src = ui_web.assetManager.getAssetUrl(asset);
    _fx.volume = volume;
    _fx.play().toDart.then((_) {}, onError: (_) {});
  }
  static void stopFx() => _fx.pause();

  static void stopClip() {
    _el.pause();
    final old = _pending;
    if (old != null && !old.isCompleted) old.complete(true);
    _pending = null;
  }
}
