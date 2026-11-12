import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/engine/practice_loop.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/speech.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/coach/coach_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner t306 item 4: a speaking practice loop on the speech-to-text result — word highlighting, focus words,
/// retries with history, slow model audio. It checks words, never claims a phoneme score.
void main() {
  setUp(() => BL.useGoogleFonts = false);

  test('loop: best recognizer alternative is scored, focus words come from the latest try, best score is kept', () {
    final l = PracticeLoop('I would like to book an appointment.');
    final r1 = l.add(['I would look at the point man', 'I like a point']);
    expect(r1.score, lessThan(70));
    expect(l.focusWords, contains('appointment'));
    expect(l.tip.$1, contains('coloured words'));
    l.add(['I would like to book an appointment']);
    expect(l.last!.score, greaterThanOrEqualTo(90));
    expect(l.focusWords, isEmpty);
    expect(l.passed, isTrue);
    expect(l.bestScore, l.last!.score);
    l.add(['I would']);
    expect(l.bestScore, greaterThanOrEqualTo(90), reason: 'the best try is kept');
    expect(l.attempts.length, 3);
  });

  test('no improvement twice: suggests the slow model and just the coloured words (EN+FA)', () {
    final l = PracticeLoop('Where is the nearest tube station?');
    l.add(['where is the']);
    l.add(['where is']);
    expect(l.tip.$1, contains('Hear slowly'));
    expect(l.tip.$2, contains('آهسته'));
  });

  testWidgets('coach: speak → highlighted words, focus chips, tries history; slow plays the same clip slower', (t) async {
    final rates = <double>[];
    Voice.debugSetAudio(keys: {Voice.key('hollie', 'Hello. How can I help you today?')}, player: (_, r) async {
      rates.add(r);
      return true;
    });
    addTearDown(() => Voice.debugSetAudio(keys: {}));
    final tries = [
      const SpeechResult(alternatives: ['hello how can I help']),
      const SpeechResult(alternatives: ['hello how can I help you today']),
    ];
    CoachScreenTest.listen = () async => tries.removeAt(0);
    addTearDown(() => CoachScreenTest.listen = null);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    t.view.physicalSize = const Size(400, 1600) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/coach');
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(seconds: 1));
    for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(seconds: 2));
    final speak = find.byKey(const ValueKey('coach-speak'), skipOffstage: false);
    await t.ensureVisible(speak);
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(speak);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('pron-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-focus')), findsOneWidget);
    expect(find.textContaining('Tries: 1:'), findsOneWidget);
    await t.tap(speak);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Tries: 1:'), findsOneWidget);
    expect(find.textContaining(' · 2: '), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-focus')), findsNothing);
    expect(find.text('Next line ✓'), findsOneWidget);
    final slow = find.byKey(const ValueKey('coach-slow'), skipOffstage: false);
    await t.ensureVisible(slow);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(slow);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 200));
    expect(rates, isNotEmpty);
    expect(rates.last, lessThan(1));
    expect(find.textContaining('phoneme', skipOffstage: false), findsNothing, reason: 'no phoneme-score claim on screen');
    expect(t.takeException(), isNull);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
