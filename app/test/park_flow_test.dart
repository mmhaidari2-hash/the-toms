import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/park/game_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Park games flow: map → hub → locked level → all five games played to the end → best scores.
void main() {
  group('park at 375x667', () {
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
    testWidgets('map → hub → five games → best scores', (t) async {
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

      ParkGameScreen.seed = 7;
      addTearDown(() => ParkGameScreen.seed = null);
      Object? ans() => ParkGameScreen.answer.value;
      Future<void> next() async {
        await tapKey('park-next');
        await t.pump(const Duration(milliseconds: 300));
      }

      // The park spot is open for a new learner; its sheet leads to the games.
      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-park')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-park')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-park')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-open-park')));
      await settle();
      expect(find.byKey(const ValueKey('park-hub')), findsOneWidget);
      expect(find.byKey(const ValueKey('park-words')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('park-level-A2')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('park-locked-snack')), findsOneWidget);
      ScaffoldMessenger.of(t.element(find.byKey(const ValueKey('park-locked-snack')))).removeCurrentSnackBar();
      await t.pump(const Duration(milliseconds: 500));

      router.go('/park/B1/odd');
      await settle();
      expect(find.byKey(const ValueKey('park-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('park-locked-why')), findsOneWidget);

      // Word match: one wrong pair, then all six; the clock is running.
      router.go('/park/A1/match');
      await settle();
      await t.tap(find.byKey(const ValueKey('match-en-0')));
      await t.pump(const Duration(milliseconds: 1200));
      expect(t.widget<Text>(find.byKey(const ValueKey('match-timer'))).data, isNot('0:60'));
      await tapKey('match-fa-1');
      for (var i = 0; i < 6; i++) {
        await tapKey('match-en-$i');
        await tapKey('match-fa-$i');
      }
      await settle();
      expect(find.byKey(const ValueKey('park-celebrate')), findsOneWidget);

      // Listen & tap: all right but one.
      router.go('/park/A1/listen');
      await settle();
      for (var i = 0; i < 8; i++) {
        final a = ans() as String;
        final opts = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('listen-opt-'));
        if (i == 0) {
          final wrong = opts.evaluate().map((e) => '${(e.widget.key as ValueKey).value}').firstWhere((k) => k != 'listen-opt-$a');
          await tapKey(wrong);
        } else {
          await tapKey('listen-opt-$a');
        }
        expect(find.byKey(const ValueKey('listen-fa')), findsOneWidget);
        await next();
      }
      await settle();
      expect(find.byKey(const ValueKey('park-celebrate')), findsOneWidget);

      // Spelling bee: a hint, then type each word.
      router.go('/park/A1/spell');
      await settle();
      await tapKey('spell-hint');
      expect(find.byKey(const ValueKey('spell-hint-text')), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await t.enterText(find.byKey(const ValueKey('spell-input')), (ans() as String).toUpperCase());
        await tapKey('spell-check');
        expect(find.byKey(const ValueKey('spell-result')), findsOneWidget);
        await next();
      }
      await settle();
      expect(find.byKey(const ValueKey('park-celebrate')), findsOneWidget);

      // Odd one out.
      router.go('/park/A1/odd');
      await settle();
      for (var i = 0; i < 4; i++) {
        await tapKey('odd-opt-${ans()}');
        expect(find.byKey(const ValueKey('odd-why')), findsOneWidget);
        await next();
      }
      await settle();
      expect(find.byKey(const ValueKey('park-celebrate')), findsOneWidget);

      // Phrase builder: put a tile back once, then build each phrase.
      router.go('/park/A1/build');
      await settle();
      for (var i = 0; i < 5; i++) {
        final order = (ans() as List).cast<int>();
        if (i == 0) {
          await tapKey('build-tile-${order.last}');
          await tapKey('build-placed-${order.last}');
        }
        for (final k in order) {
          await tapKey('build-tile-$k');
        }
        await tapKey('build-check');
        expect(t.widget<Text>(find.byKey(const ValueKey('build-result'))).data, 'Brilliant!');
        await next();
      }
      await settle();
      expect(find.byKey(const ValueKey('park-celebrate')), findsOneWidget);

      router.go('/park');
      await settle();
      String best(String g) => t.widget<Text>(find.byKey(ValueKey('park-best-$g'))).data!;
      expect(best('match'), '95%');
      expect(best('listen'), '88%');
      expect(best('spell'), '100%');
      expect(best('odd'), '100%');
      await t.scrollUntilVisible(find.byKey(const ValueKey('park-best-build')), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      expect(best('build'), '100%');
      await t.scrollUntilVisible(find.byKey(const ValueKey('park-level-A2')), -200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      await t.tap(find.byKey(const ValueKey('park-level-A2')));
      await settle();
      expect(find.byKey(const ValueKey('park-locked-snack')), findsNothing, reason: 'A1 cleared opens A2');
      expect(best('match'), '–');
    });
  });
}
