import 'dart:async';
import 'dart:io';

import 'package:british_life/core/platform/native_stt.dart';
import 'package:british_life/core/platform/speech.dart';
import 'package:british_life/features/speaking/speaking_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner t306 item 1: Android on-device speech recognition with an explained runtime permission and a typing
/// fallback. The plugin is faked; the real recognizer is Android's own.
class FakeBackend implements SttBackend {
  bool granted;
  bool initOk;
  final calls = <String>[];
  void Function(String, bool)? onError;
  void Function(String)? onStatus;
  void Function(SttEvent)? onResult;
  final listens = <bool>[];
  /// What each listen does: emits events / errors.
  List<void Function(FakeBackend b)> script;
  FakeBackend({this.granted = false, this.initOk = true, this.script = const []});

  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<bool> initialize({required void Function(String error, bool permanent) onError, required void Function(String status) onStatus}) async {
    calls.add('init');
    this.onError = onError;
    this.onStatus = onStatus;
    if (initOk) granted = true; // the system prompt was accepted
    return initOk;
  }

  @override
  Future<void> listen({required void Function(SttEvent e) onResult, required bool onDevice, required String localeId}) async {
    calls.add('listen:$onDevice:$localeId');
    listens.add(onDevice);
    this.onResult = onResult;
    final i = listens.length - 1;
    if (i < script.length) scheduleMicrotask(() => script[i](this));
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  tearDown(() {
    SpeechHooks.rationale = null;
    SpeechInput.debugUseStt(null);
  });

  test('explains first; declining asks Android for nothing and falls back to typing', () async {
    var asked = 0;
    SpeechHooks.rationale = () async {
      asked++;
      return false;
    };
    final b = FakeBackend();
    final r = await NativeStt(b).listen();
    expect(asked, 1);
    expect(r.permissionDenied, isTrue);
    expect(b.calls, isEmpty, reason: 'no system permission prompt, no recognizer');
  });

  test('accepting: runtime permission via initialize, then on-device-first recognition with partials', () async {
    var asked = 0;
    SpeechHooks.rationale = () async {
      asked++;
      return true;
    };
    final partials = <String>[];
    final b = FakeBackend(script: [
      (b) {
        b.onResult!(const SttEvent(['I would']));
        b.onResult!(const SttEvent(['I would like a coffee', 'I would like coffee'], confidence: .9, isFinal: true));
      },
      (b) => b.onResult!(const SttEvent(['thanks'], isFinal: true)),
    ]);
    final stt = NativeStt(b);
    final r = await stt.listen(onPartial: partials.add);
    expect(r.ok, isTrue);
    expect(r.alternatives, ['I would like a coffee', 'I would like coffee']);
    expect(partials.first, 'I would');
    expect(b.calls.take(2), ['init', 'listen:true:en_GB']);
    // Already allowed: no second explanation, no second init.
    final r2 = await stt.listen();
    expect(r2.best, 'thanks');
    expect(asked, 1);
    expect(b.calls.where((c) => c == 'init').length, 1);
  });

  test('no offline English model: retries once with Android\'s default recognizer', () async {
    final b = FakeBackend(granted: true, script: [
      (b) => b.onError!('error_language_unavailable', true),
      (b) => b.onResult!(const SttEvent(['hello'], isFinal: true)),
    ]);
    final r = await NativeStt(b).listen();
    expect(r.best, 'hello');
    expect(b.listens, [true, false]);
  });

  test('errors map to the existing UI codes; a partial survives a late no-match', () async {
    expect(NativeStt.mapError('error_permission'), 'not-allowed');
    expect(NativeStt.mapError('error_no_match'), 'no-speech');
    expect(NativeStt.mapError('error_speech_timeout'), 'no-speech');
    expect(NativeStt.mapError('error_network'), 'network');
    expect(NativeStt.mapError('error_audio_error'), 'audio-capture');
    final b = FakeBackend(granted: true, script: [
      (b) {
        b.onResult!(const SttEvent(['can I pay by card']));
        b.onError!('error_no_match', false);
      },
    ]);
    expect((await NativeStt(b).listen()).best, 'can I pay by card');
    final denied = FakeBackend(granted: true, script: [(b) => b.onError!('error_permission', true)]);
    expect((await NativeStt(denied).listen()).permissionDenied, isTrue);
  });

  test('phone without a recognizer: speech is switched off and the app offers typing', () async {
    final b = FakeBackend(granted: true, initOk: false);
    final stt = NativeStt(b);
    SpeechInput.debugUseStt(stt);
    expect(SpeechInput.sttSupported, isTrue);
    final r = await SpeechInput.listenDetailed();
    expect(r.error, 'unsupported');
    expect(SpeechInput.sttSupported, isFalse);
    expect(replyMicTip(web: false), 'Type your reply');
  });

  test('SpeechInput on Android uses the recognizer; listen() returns the best text', () async {
    SpeechInput.debugUseStt(NativeStt(FakeBackend(granted: true, script: [(b) => b.onResult!(const SttEvent(['good morning'], isFinal: true))])));
    expect(await SpeechInput.micPermission(), 'granted');
    expect(await SpeechInput.listen(), 'good morning');
  });

  test('copy: Android speech is honest about Google and says the app uploads nothing (EN+FA)', () {
    final c = micHelpCopy('not-allowed', web: false, sttSupported: true);
    expect(c.body, contains('Google may process your voice'));
    expect(c.body, contains('does not record, store or upload'));
    expect(c.bodyFa, contains('گوگل'));
    expect(replyMicTip(web: false, sttSupported: true, sttBroken: false), 'Speak your replies');
    expect(coachIntro(web: false, sttSupported: true).$1, contains('checks words, not sounds'));
    expect(coachIntro(web: false, sttSupported: true).$1, isNot(contains('browser')));
    expect(scoreMicNote(web: false, sttSupported: true).$1, contains('on the device'));
    expect(dictateFallback(web: false, sttSupported: true).$1, contains('Type your reply'));
    // Without a recognizer the installed app keeps the honest typing-only copy.
    expect(micHelpCopy(null, web: false, sttSupported: false).title, "Speaking isn't available in this app");
  });

  test('manifest: only INTERNET and RECORD_AUDIO are added; BILLING stays removed; recognizer query declared', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final perms = RegExp(r'<uses-permission android:name="([^"]+)"(?: tools:node="remove")?/>').allMatches(m).map((x) => x.group(0)!).toList();
    final added = [for (final p in perms) if (!p.contains('tools:node="remove"')) RegExp(r'name="([^"]+)"').firstMatch(p)!.group(1)];
    expect(added.toSet().difference({'android.permission.INTERNET', 'android.permission.RECORD_AUDIO', 'android.permission.POST_NOTIFICATIONS'}), isEmpty);
    expect(added, contains('android.permission.RECORD_AUDIO'));
    expect(m, contains('com.android.vending.BILLING" tools:node="remove"'));
    expect(m, contains('android.speech.RecognitionService'));
  });
}
