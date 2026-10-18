import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/theory/thy_quiz_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Life in the UK prep flow: library sheet → notes → chapter (audio, Persian) → flashcards → quiz with review → timed mock.
void main() {
  group('theory at 375x667', () {
    setUp(() => BL.useGoogleFonts = false);
    setUpAll(() async {
      for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
        final file = {'Roboto': 'Inter', 'Inter': 'Inter', 'Fraunces': 'Fraunces', 'Vazirmatn': 'Vazirmatn'}[fam]!;
        final l = FontLoader(fam);
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
          l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
        }
        await l.load();
      }
    });
    testWidgets('library → prep → chapter → cards → quiz → mock', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('The Toms').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> settle() async {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 400));
        }
        for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull);
      }

      Future<void> tapKey(String k) async {
        final f = find.byKey(ValueKey(k));
        await t.scrollUntilVisible(f, 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 500));
      }

      ThyQuizScreen.seed = 5;
      addTearDown(() => ThyQuizScreen.seed = null);
      Text txt(String k) => t.widget<Text>(find.byKey(ValueKey(k)));

      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-garage')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-garage')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-theory')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-open-theory')));
      await settle();
      expect(find.byKey(const ValueKey('thy-hub')), findsOneWidget);
      expect(find.byKey(const ValueKey('thy-disclaimer')), findsOneWidget);
      expect(find.byKey(const ValueKey('thy-level-note')), findsOneWidget, reason: 'open to all, B1+ recommended');
      expect(find.textContaining('50 questions · 57 minutes · pass mark 43/50'), findsOneWidget);
      await tapKey('thy-hazard');
      expect(find.textContaining('44 out of 75'), findsOneWidget);

      // A chapter: voiced explanations; Persian on request.
      await tapKey('thy-ch-speed');
      await settle();
      expect(find.byKey(const ValueKey('thy-expl-fa-0')), findsNothing);
      await t.tap(find.byKey(const ValueKey('thy-play-0')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('thy-fa')));
      await settle();
      expect(find.byKey(const ValueKey('thy-expl-fa-0')), findsOneWidget);
      await tapKey('thy-open-cards');
      await settle();

      // Flashcards: flip, "Again" once, then know them all.
      await t.tap(find.byKey(const ValueKey('thy-card')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('thy-card-back')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('thy-again')));
      await t.pump(const Duration(milliseconds: 300));
      for (var k = 0; k < 8; k++) {
        await t.tap(find.byKey(const ValueKey('thy-got')));
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const ValueKey('thy-cards-done')), findsOneWidget);
      expect(txt('thy-cards-known').data, '8/8');

      // Chapter quiz: two wrong, the rest right; feedback after each; review of mistakes.
      await t.tap(find.byKey(const ValueKey('thy-cards-quiz')));
      await settle();
      for (var k = 0; k < 10; k++) {
        final wrong = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('thy-opt-') && (w.key as ValueKey).value != 'thy-opt-0');
        if (k < 2) {
          await tapKey('${((wrong.evaluate().first.widget.key as ValueKey).value)}');
        } else {
          await tapKey('thy-opt-0');
        }
        expect(find.byKey(const ValueKey('thy-why')), findsOneWidget);
        await tapKey(k == 9 ? 'thy-finish' : 'thy-next');
      }
      await settle();
      expect(txt('thy-score').data, '8 / 10 · 80%');
      expect(find.byKey(const ValueKey('thy-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('thy-review-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('thy-review-1')), findsOneWidget);

      // Mock test: answers can change; time runs out after 3 answers → results with 21+ to review.
      ThyQuizScreen.mockSeconds = 8;
      addTearDown(() => ThyQuizScreen.mockSeconds = null);
      router.go('/theory/mock');
      await settle();
      expect(find.byKey(const ValueKey('thy-timer')), findsOneWidget);
      expect(txt('thy-pos').data, '1/50');
      await tapKey('thy-opt-1');
      await tapKey('thy-opt-0');
      await tapKey('thy-next');
      await tapKey('thy-opt-0');
      await tapKey('thy-prev');
      expect(txt('thy-answered').data, startsWith('2 of 50'));
      for (var k = 0; k < 8; k++) {
        await t.pump(const Duration(seconds: 1));
      }
      await settle();
      expect(find.byKey(const ValueKey('thy-result')), findsOneWidget);
      expect(txt('thy-score').data, '2 / 50 · 4%');
      expect(txt('thy-verdict').data, startsWith('Not yet'));

      // A full mock, all right: pass.
      ThyQuizScreen.mockSeconds = null;
      router.go('/theory/mock?r=2');
      await settle();
      for (var k = 0; k < 50; k++) {
        await tapKey('thy-opt-0');
        await tapKey(k == 49 ? 'thy-finish' : 'thy-next');
      }
      await settle();
      expect(txt('thy-verdict').data, startsWith('Pass!'));
      router.go('/theory');
      await settle();
      expect(txt('thy-mock-best').data, '100%');
      await t.scrollUntilVisible(find.byKey(const ValueKey('thy-ch-best-speed')), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      expect(txt('thy-ch-best-speed').data, '80%');
    });
  });
}
