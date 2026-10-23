import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/study_plan.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Personal study plan: estimates, pace and the plan screen at 375×667.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  group('plan maths', () {
    final d = DateTime(2026, 10, 23);
    test('days and minutes needed', () {
      expect(StudyPlan.daysNeeded(10, 12), 10);
      expect(StudyPlan.daysNeeded(10, 30), 4);
      expect(StudyPlan.daysNeeded(0, 15), 0);
      expect(StudyPlan.projected(10, 12, d), DateTime(2026, 11, 2));
      expect(StudyPlan.minutesNeeded(10, DateTime(2026, 11, 1), d), 12); // 10 days incl. today
      expect(StudyPlan.daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2); // across the clock change
    });
    test('encode/decode and on-track pace', () {
      final p = StudyPlan(4, 20, DateTime(2026, 12, 2), d, 40);
      expect(StudyPlan.decode(p.encode())!.encode(), p.encode());
      expect(StudyPlan.decode('junk'), isNull);
      expect(p.expectedLeft(d), 40);
      expect(p.expectedLeft(DateTime(2026, 11, 12)), 20);
      expect(p.onTrack(21, DateTime(2026, 11, 12)), isTrue);
      expect(p.onTrack(30, DateTime(2026, 11, 12)), isFalse);
      expect(p.perWeek(40, d), 7);
      expect(StudyPlan.nice(DateTime(2027, 3, 12)), '12 Mar 2027');
    });
  });

  testWidgets('B1 learner sets a B2 plan; My path shows it and lower levels read Skipped', (t) async {
    t.view.physicalSize = const Size(750, 1334);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, startTier: 2, missionsDone: {'pref:lvseen': '3'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('continue')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Skipped ✓'), findsNWidgets(2)); // A1 and A2
    router.go('/plan?first=1');
    for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 200)); }
    expect(find.text('Now make a plan'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-goal-A2')), findsNothing); // never below the current level
    await t.tap(find.byKey(const ValueKey('plan-goal-B2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('plan-min-30')));
    await t.pump();
    await t.scrollUntilVisible(find.byKey(const ValueKey('plan-save')), 200);
    expect(find.byKey(const ValueKey('plan-pace')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('plan-save')));
    for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 200)); }
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
    final plan = c.read(progressProvider.notifier).plan!;
    expect(plan.goal, 4);
    expect(plan.minutes, 30);
    expect(plan.startLeft, greaterThan(0));
    router.go('/course');
    for (var i = 0; i < 8; i++) { await t.pump(const Duration(milliseconds: 200)); }
    expect(find.byKey(const ValueKey('plan-card')), findsOneWidget);
    expect(find.textContaining('B2 by'), findsOneWidget);
    expect(find.text('MY PATH · A1–C1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
