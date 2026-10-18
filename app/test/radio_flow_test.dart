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

/// Hackney Hum flow: map spot, locked levels, listen first (no text), transcript + Persian, questions.
void main() {
  group('radio at 375x667', () {
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
    testWidgets('map → schedule locks → listen → transcript + Persian → questions → understood', (t) async {
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

      // The map: the radio spot is open for a new learner and its sheet leads to the station.
      router.go('/');
      await settle();
      await t.tap(find.byKey(const ValueKey('spot-radio')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 600));
      if (find.byKey(const ValueKey('spot-open-radio')).evaluate().isNotEmpty) {
        await t.ensureVisible(find.byKey(const ValueKey('spot-open-radio')));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const ValueKey('spot-open-radio')));
        await settle();
        expect(find.byKey(const ValueKey('radio-list')), findsOneWidget, reason: 'sheet button opens the radio');
      }

      router.go('/radio');
      await settle();
      expect(find.byKey(const ValueKey('radio-level-A1')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('radio-status-A1'))).data, '0/2');
      expect(t.widget<Text>(find.byKey(const ValueKey('radio-status-A2'))).data, 'Locked · قفل');
      await t.tap(find.byKey(const ValueKey('seg-r_a2_travel')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('radio-locked-snack')), findsOneWidget);
      await t.pump(const Duration(seconds: 5));

      // Deep link to a locked level: never plays.
      router.go('/radio/r_c1_signals');
      await settle();
      expect(find.byKey(const ValueKey('seg-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('radio-set')), findsNothing);

      // Listening first: no text until the learner asks for it.
      router.go('/');
      await settle();
      router.push('/radio');
      await settle();
      await t.tap(find.byKey(const ValueKey('seg-r_a1_weather')));
      await settle();
      expect(find.byKey(const ValueKey('radio-set')), findsOneWidget);
      expect(find.byKey(const ValueKey('radio-text-0')), findsNothing, reason: 'transcript hidden by default');
      expect(find.byKey(const ValueKey('radio-hint')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('radio-play')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('radio-stop')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('radio-onair'))).data, 'BEX');
      expect(find.byKey(const ValueKey('radio-text-0')), findsNothing, reason: 'still no text while listening');
      var sawOwen = false;
      for (var i = 0; i < 120 && find.byKey(const ValueKey('radio-stop')).evaluate().isNotEmpty; i++) {
        await t.pump(const Duration(milliseconds: 500));
        sawOwen |= find.text('OWEN').evaluate().isNotEmpty;
      }
      expect(find.byKey(const ValueKey('radio-stop')), findsNothing, reason: 'programme finished');
      expect(sawOwen, isTrue, reason: 'the weatherman comes on air');
      expect(find.byKey(const ValueKey('radio-hint')), findsNothing, reason: 'listened');
      expect(t.takeException(), isNull);

      // Optional transcript, then Persian.
      await t.tap(find.byKey(const ValueKey('radio-transcript')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('radio-text-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('radio-fa-0')), findsNothing);
      await t.tap(find.byKey(const ValueKey('radio-fa')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('radio-fa-0')), findsOneWidget, reason: 'Persian under each line');
      await t.tap(find.byKey(const ValueKey('radio-transcript')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('radio-text-0')), findsNothing);

      // Questions (the correct option is index 0 before shuffling).
      await t.tap(find.byKey(const ValueKey('radio-quiz')));
      await t.pump(const Duration(milliseconds: 400));
      while (find.byKey(const ValueKey('radio-q')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const ValueKey('radio-opt-0')));
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const ValueKey('radio-celebrate')), findsOneWidget);
      expect(find.text('Programme understood!'), findsOneWidget);
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('radio-celebrate')))).read(progressProvider.notifier);
      expect(ctrl.segmentDone('r_a1_weather'), isTrue);
      expect(ctrl.radioScore('r_a1_weather'), 100);
      await t.tap(find.text('Continue').first);
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('radio-set')), findsOneWidget);
      router.go('/radio');
      await settle();
      expect(find.byKey(const ValueKey('seg-done-r_a1_weather')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('radio-status-A1'))).data, '1/2');
      await t.pump(const Duration(seconds: 3));
    });
  });
}
