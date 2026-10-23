import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/lifeuk/luk_quiz_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Life in the UK prep flow: library sheet → notes → chapter (audio, Persian) → flashcards → quiz with review → timed mock.
void main() {
  group('lifeuk at 375x667', () {
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
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
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

      LukQuizScreen.seed = 5;
      addTearDown(() => LukQuizScreen.seed = null);
      Text txt(String k) => t.widget<Text>(find.byKey(ValueKey(k)));

      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-library')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-library')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-lifeuk')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-open-lifeuk')));
      await settle();
      expect(find.byKey(const ValueKey('luk-hub')), findsOneWidget);
      expect(find.byKey(const ValueKey('luk-disclaimer')), findsOneWidget);
      expect(find.byKey(const ValueKey('luk-level-note')), findsOneWidget, reason: 'open to all, B1+ recommended');

      // A chapter: voiced explanations; Persian on request.
      await tapKey('luk-ch-history');
      await settle();
      expect(find.byKey(const ValueKey('luk-expl-fa-0')), findsNothing);
      await t.tap(find.byKey(const ValueKey('luk-play-0')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('luk-fa')));
      await settle();
      expect(find.byKey(const ValueKey('luk-expl-fa-0')), findsOneWidget);
      await tapKey('luk-open-cards');
      await settle();

      // Flashcards: flip, "Again" once, then know them all.
      await t.tap(find.byKey(const ValueKey('luk-card')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('luk-card-back')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('luk-again')));
      await t.pump(const Duration(milliseconds: 300));
      for (var k = 0; k < 10; k++) {
        await t.tap(find.byKey(const ValueKey('luk-got')));
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const ValueKey('luk-cards-done')), findsOneWidget);
      expect(txt('luk-cards-known').data, '10/10');

      // Chapter quiz: two wrong, the rest right; feedback after each; review of mistakes.
      await t.tap(find.byKey(const ValueKey('luk-cards-quiz')));
      await settle();
      for (var k = 0; k < 10; k++) {
        final wrong = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('luk-opt-') && (w.key as ValueKey).value != 'luk-opt-0');
        if (k < 2) {
          await tapKey('${((wrong.evaluate().first.widget.key as ValueKey).value)}');
        } else {
          await tapKey('luk-opt-0');
        }
        expect(find.byKey(const ValueKey('luk-why')), findsOneWidget);
        await tapKey(k == 9 ? 'luk-finish' : 'luk-next');
      }
      await settle();
      expect(txt('luk-score').data, '8 / 10 · 80%');
      expect(find.byKey(const ValueKey('luk-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('luk-review-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('luk-review-1')), findsOneWidget);

      // Mock test: answers can change; time runs out after 3 answers → results with 21+ to review.
      LukQuizScreen.mockSeconds = 8;
      addTearDown(() => LukQuizScreen.mockSeconds = null);
      router.go('/lifeuk/mock');
      await settle();
      expect(find.byKey(const ValueKey('luk-timer')), findsOneWidget);
      expect(txt('luk-pos').data, '1/24');
      await tapKey('luk-opt-1');
      await tapKey('luk-opt-0');
      await tapKey('luk-next');
      await tapKey('luk-opt-0');
      await tapKey('luk-prev');
      expect(txt('luk-answered').data, startsWith('2 of 24'));
      for (var k = 0; k < 8; k++) {
        await t.pump(const Duration(seconds: 1));
      }
      await settle();
      expect(find.byKey(const ValueKey('luk-result')), findsOneWidget);
      expect(txt('luk-score').data, '2 / 24 · 8%');
      expect(txt('luk-verdict').data, startsWith('Not yet'));

      // A full mock, all right: pass.
      LukQuizScreen.mockSeconds = null;
      router.go('/lifeuk/mock?r=2');
      await settle();
      for (var k = 0; k < 24; k++) {
        await tapKey('luk-opt-0');
        await tapKey(k == 23 ? 'luk-finish' : 'luk-next');
      }
      await settle();
      expect(txt('luk-verdict').data, startsWith('Pass!'));
      router.go('/lifeuk');
      await settle();
      expect(txt('luk-mock-best').data, '100%');
      await t.scrollUntilVisible(find.byKey(const ValueKey('luk-ch-best-history')), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      expect(txt('luk-ch-best-history').data, '80%');
    });
  });
}
