import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/seasons/seasons_data.dart';
import 'package:british_life/features/seasons/seasons_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seasonal events flow: home sheet → family calendar (nearest featured, locked levels) → event → scene → quiz.
void main() {
  group('seasons at 375x667', () {
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
    testWidgets('home → calendar → Halloween → scene → quiz → done', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      Seasons.debugToday = DateTime(2026, 10, 18);
      SeasonEventScreen.seed = 3;
      addTearDown(() => (Seasons.debugToday = null, SeasonEventScreen.seed = null));
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
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

      Text txt(String k) => t.widget<Text>(find.byKey(ValueKey(k)));

      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-home')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-home')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-seasons')));
      await t.pump(const Duration(milliseconds: 300));
      expect(txt('spot-seasons-next').data, 'Family calendar · Halloween: in 13 days');
      await t.tap(find.byKey(const ValueKey('spot-open-seasons')));
      await settle();

      expect(find.byKey(const ValueKey('sea-list')), findsOneWidget);
      expect(txt('sea-featured-title').data, 'Halloween');
      expect(txt('sea-featured-when').data, startsWith('IN 13 DAYS'));

      // A2 is locked for a new learner, like every other section.
      await tapKey('sea-ev-bonfire');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('sea-locked-snack')), findsOneWidget);
      router.go('/seasons/bonfire');
      await settle();
      expect(find.byKey(const ValueKey('sea-locked')), findsOneWidget);
      router.go('/seasons');
      await settle();

      await tapKey('sea-featured-open');
      await settle();
      expect(find.byKey(const ValueKey('sea-event')), findsOneWidget);
      expect(txt('sea-date').data, 'Next: Saturday 31 October 2026 · In 13 days');
      expect(find.byKey(const ValueKey('sea-line-fa-0')), findsNothing);
      await tapKey('sea-fa');
      await settle();
      expect(find.byKey(const ValueKey('sea-line-fa-0')), findsOneWidget);
      await tapKey('sea-play-0');
      await t.pump(const Duration(milliseconds: 300));
      await tapKey('sea-word-0');
      await t.pump(const Duration(milliseconds: 300));

      // Quiz: 2 of 3 right = done.
      await tapKey('sea-q0-opt-0');
      await tapKey('sea-q1-opt-2');
      await tapKey('sea-q2-opt-0');
      await settle();
      expect(txt('sea-score').data, startsWith('2 / 3'));
      expect(txt('sea-xp').data, startsWith('+10 XP'));
      await tapKey('sea-back-cal');
      await settle();
      expect(find.byKey(const ValueKey('sea-ev-done-halloween'), skipOffstage: false), findsOneWidget);
    });
  });
}
