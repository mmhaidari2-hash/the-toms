import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real-life missions flow: map spot, locked levels, prepare (audio), Ready? Go!, check in, XP + badge.
void main() {
  group('missions at 375x667', () {
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
    testWidgets('map → locks → prepare → Ready? Go! → back later → check in → badge', (t) async {
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

      // The map: the missions spot is open for a new learner; its sheet leads to Missions.
      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-missions')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-missions')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('spot-open-missions')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-missions')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-open-missions')));
      await settle();
      expect(find.byKey(const ValueKey('missions-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('missions-safety')), findsOneWidget, reason: 'ground rules up front');
      expect(t.widget<Text>(find.byKey(const ValueKey('mis-status-A1'))).data, '0/2');
      await t.scrollUntilVisible(find.byKey(const ValueKey('mis-status-A2')), 200);
      expect(t.widget<Text>(find.byKey(const ValueKey('mis-status-A2'))).data, 'Locked · قفل');
      await t.tap(find.byKey(const ValueKey('mis-m_a2_weather')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('mis-locked-snack')), findsOneWidget);
      ScaffoldMessenger.of(t.element(find.byKey(const ValueKey('mis-locked-snack')))).removeCurrentSnackBar();
      await t.pump(const Duration(milliseconds: 500));

      // Deep link to a locked level.
      router.go('/missions/m_c1_complaint');
      await settle();
      expect(find.byKey(const ValueKey('mis-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('mis-prep')), findsNothing);

      // Prepare: goal, phrases with audio, what you might hear, tip.
      router.go('/missions/m_a1_flatwhite');
      await settle();
      expect(find.byKey(const ValueKey('mis-goal')), findsOneWidget);
      expect(find.text('Hello! Can I have a flat white, please?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('mis-say-0')));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      await tapKey('mis-ready');
      expect(find.byKey(const ValueKey('mis-go-title')), findsOneWidget);
      expect(find.text('Ready? Go!'), findsOneWidget);
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('mis-go')))).read(progressProvider.notifier);
      expect(ctrl.missionPending('m_a1_flatwhite'), isTrue);

      // Off they go; later, Missions shows "Check in" and the mission opens on the check-in.
      await tapKey('mis-later');
      await settle();
      expect(find.byKey(const ValueKey('mis-pending-m_a1_flatwhite')), findsOneWidget);
      await tapKey('mis-m_a1_flatwhite');
      await settle();
      expect(find.byKey(const ValueKey('mis-checkin-view')), findsOneWidget);
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('mis-save'))).onPressed, isNull, reason: 'pick how it went first');
      await t.tap(find.byKey(const ValueKey('mis-rate-2')));
      await t.pump(const Duration(milliseconds: 300));
      await tapKey('mis-used-0');
      await tapKey('mis-used-3');
      await tapKey('mis-save');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('mis-celebrate')), findsOneWidget);
      expect(find.text('Mission complete!'), findsOneWidget);
      expect(find.text('Phrases'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-badge-mission1')), findsOneWidget);
      expect(ctrl.missionDone('m_a1_flatwhite'), isTrue);
      expect(ctrl.missionPending('m_a1_flatwhite'), isFalse);
      await t.tap(find.text('Continue').first);
      await settle();
      expect(find.byKey(const ValueKey('mis-done-m_a1_flatwhite')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('mis-status-A1'))).data, '1/2');
      await t.pump(const Duration(seconds: 3));
    });
  });
}
