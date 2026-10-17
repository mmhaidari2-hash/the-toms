import 'package:british_life/core/engine/pronunciation.dart';
import 'package:british_life/core/platform/speech.dart';
import 'package:british_life/features/speaking/speaking_widgets.dart';
import 'dart:convert';
import 'dart:io';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Speaking: per-word pronunciation scoring, best-option matching, the card and the mic help.
void main() {
  List<String> marks(PronResult r) => [for (final w in r.words) '${w.word}:${w.mark.name}'];

  test('exact, contractions, numbers and British/American spellings all count as clear', () {
    expect(Pronunciation.score("I'd like a cup of tea, please.", 'i would like a cup of tea please').score, 100);
    expect(Pronunciation.score('Twenty minutes, please.', '20 minutes please').score, 100);
    expect(Pronunciation.score("It's my favourite colour!", "it's my favorite color").score, 100);
    expect(Pronunciation.score('Good morning, Mare Street Surgery.', 'good morning mayor street surgery').score, 100, reason: 'homophones are pronounced the same');
    expect(Pronunciation.score('Can you put weight on it?', 'can you put wait on it').score, 100);
  });

  test('mispronounced words are marked close, missing words missed, with what was heard', () {
    final r = Pronunciation.score('Shall we watch the parade?', 'shall we wash the');
    expect(marks(r), ['Shall:good', 'we:good', 'watch:close', 'the:good', 'parade?:missed']);
    expect(r.words[2].heard, 'wash');
    expect(r.score, 70);
    expect(r.toPractise.map((w) => w.word), ['watch', 'parade?']);
    expect(Pronunciation.score('Lean forward, William.', '').score, 0);
    expect(Pronunciation.score('Lean forward, William.', 'banana').passed, isFalse);
  });

  test('extra words in the transcript do not hurt; punctuation stays on the display words', () {
    final r = Pronunciation.score('Of course. Lean on me.', 'um of course yeah lean on me');
    expect(r.score, 100);
    expect(r.words.first.word, 'Of');
    expect(r.words[1].word, 'course.');
  });

  test('picks the reply option the learner actually said, across recogniser alternatives', () {
    final options = ['Of course. Lean on me. Slowly.', 'Oh no! Does it hurt a lot?'];
    final best = Pronunciation.bestOf(options, ['does it hurt a lot', 'does it hurt allot'])!;
    expect(best.$1, 1);
    expect(best.$2.passed, isTrue);
    expect(Pronunciation.bestOf(options, const []), isNull);
  });

  test('sound keys merge letters that sound alike', () {
    expect(Pronunciation.soundKey('phone'), Pronunciation.soundKey('fone'));
    expect(Pronunciation.similarity('colour', 'color'), greaterThan(.8));
    expect(Pronunciation.similarity('biscuit', 'basket'), lessThan(.85));
  });

  test('speech fallback outside the browser: unsupported, never throws', () async {
    expect(SpeechInput.sttSupported, isFalse);
    final r = await SpeechInput.listenDetailed();
    expect(r.ok, isFalse);
    expect(r.error, 'unsupported');
    expect(const SpeechResult(error: 'not-allowed').permissionDenied, isTrue);
    expect(const SpeechResult(error: 'service-not-allowed').permissionDenied, isTrue);
    expect(const SpeechResult(alternatives: ['hi']).ok, isTrue);
    expect(speechErrorText('no-speech'), contains("didn't catch"));
  });

  testWidgets('pronunciation card highlights words at iPhone width and its buttons work', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    var sent = false, retried = false;
    final r = Pronunciation.score('Shall we watch the parade together on Sunday morning?', 'shall we wash the together on sunday morning');
    await t.pumpWidget(MaterialApp(home: Scaffold(backgroundColor: const Color(0xFF1B140F), body: Padding(padding: const EdgeInsets.all(16), child: PronunciationCard(result: r, onRetry: () => retried = true, onSend: () => sent = true, onListen: () {})))));
    expect(t.takeException(), isNull);
    expect(find.text('${r.score}%'), findsOneWidget);
    expect(find.text('watch'), findsOneWidget);
    expect(find.text('Send anyway'), r.passed ? findsNothing : findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pron-retry')));
    await t.tap(find.byKey(const ValueKey('pron-send')));
    expect(retried && sent, isTrue);
  });

  for (final e in ['unsupported', 'not-allowed', 'service-not-allowed']) {
    testWidgets('mic help explains "$e" without overflow', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      var typed = false;
      await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => showMicHelp(c, e, onType: () => typed = true), child: const Text('go')))))));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('mic-help')), findsOneWidget);
      expect(find.text(e == 'unsupported' ? "Speaking isn't available here" : e == 'service-not-allowed' ? 'Turn on Dictation' : 'Allow the microphone'), findsOneWidget);
      await t.tap(find.text('Type instead'));
      await t.pumpAndSettle();
      expect(typed, isTrue);
    });
  }

  testWidgets('in a chat, the mic offers speak mode and falls back gracefully where speech is unavailable', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99', 'pref:speakMode': 'on'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('The Toms').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    final id = (jsonDecode(File('assets/data/scenes_index.json').readAsStringSync()) as List).first;
    router.go('/chat/$id');
    for (var i = 0; i < 20; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(t.takeException(), isNull);
    // Speech isn't available in tests: speak mode stays off (typing composer) even though the pref is on.
    expect(find.byKey(const ValueKey('speak-mic'), skipOffstage: false), findsNothing);
    final mic = find.byTooltip('Speaking not available here', skipOffstage: false);
    expect(mic, findsOneWidget);
    await t.tap(mic, warnIfMissed: false);
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('mic-help'), skipOffstage: false), findsOneWidget);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
