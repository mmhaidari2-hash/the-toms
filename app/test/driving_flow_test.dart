import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/driving/driving_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driving School flow: map garage sheet → list (A2 locked) → cockpit drill → animated stage + subtitles → quiz.
void main() {
  group('driving at 375x667', () {
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
    testWidgets('garage → driving list → cockpit → scene → quiz → done', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      DrivingLessonScreen.seed = 3;
      addTearDown(() => DrivingLessonScreen.seed = null);
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

      Future<void> tapKey(String k, {double step = 200}) async {
        final f = find.byKey(ValueKey(k));
        await t.scrollUntilVisible(f, step, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 500));
      }

      Text txt(String k) => t.widget<Text>(find.byKey(ValueKey(k)));

      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-garage')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-garage')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('spot-open-theory')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-driving')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-open-driving')));
      await settle();
      expect(find.byKey(const ValueKey('drv-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('drv-theory')), findsOneWidget);

      await tapKey('drv-ev-directions');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('drv-locked-snack')), findsOneWidget);
      router.go('/driving/directions');
      await settle();
      expect(find.byKey(const ValueKey('drv-locked')), findsOneWidget);
      router.go('/driving');
      await settle();

      await tapKey('drv-ev-cockpit');
      await settle();
      expect(find.byKey(const ValueKey('drv-stage')), findsOneWidget);
      expect(find.byKey(const ValueKey('drv-road')), findsOneWidget, reason: 'in-car: drawn road, no painting');
      expect(find.text('Press play to start the scene'), findsOneWidget);
      await tapKey('drv-play-all');
      await t.pump(const Duration(milliseconds: 600));
      Text sub(String k) => t.widget<Text>(find.byKey(ValueKey(k), skipOffstage: false));
      expect(sub('drv-sub-name').data, 'Bev (instructor)');
      expect(sub('drv-sub-en').data, isNotEmpty);
      await t.tap(find.byKey(const ValueKey('drv-play-all'))); // stop
      await t.pump(const Duration(milliseconds: 300));
      await settle();
      await tapKey('drv-fa', step: -200);
      await settle();
      expect(find.byKey(const ValueKey('drv-line-fa-0')), findsOneWidget);

      await tapKey('drv-q0-opt-0');
      await tapKey('drv-q1-opt-2');
      await tapKey('drv-q2-opt-0');
      await settle();
      expect(txt('drv-score').data, startsWith('2 / 3'));
      expect(txt('drv-xp').data, startsWith('+10 XP'));
      await tapKey('drv-back-cal');
      await settle();
      expect(find.byKey(const ValueKey('drv-ev-done-cockpit'), skipOffstage: false), findsOneWidget);

      router.go('/driving/petrol');
      await settle();
      expect(find.byKey(const ValueKey('drv-painting')), findsOneWidget);
      router.go('/driving/mot'); // B1, locked: no stage
      await settle();
      expect(find.byKey(const ValueKey('drv-locked')), findsOneWidget);
    });
  });
}
