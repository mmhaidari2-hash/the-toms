import 'package:british_life/app/app.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Streak sheet: two-week history, freeze days, at-risk state, reminder switch.
void main() {
  late DateTime now;
  ProgressController ctrl([UserProgress p = const UserProgress(onboarded: true)]) {
    final store = MemoryProgressStore()..data = p.encode();
    return ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => now)]).read(progressProvider.notifier);
  }

  test('history marks practised days, the freeze-covered day and today', () {
    now = DateTime(2026, 10, 12, 18);
    final c = ctrl();
    for (var i = 0; i < 7; i++) {
      c.awardXp(10);
      now = now.add(const Duration(days: 1));
    }
    expect(c.freezes, 2); // 1 to start + 1 for the 7-day streak
    now = now.add(const Duration(days: 1)); // miss a day (19 Oct)
    c.awardXp(10); // 20 Oct: the freeze covers 19 Oct
    expect(c.currentStreak, 8);
    expect(c.freezes, 1);
    expect(c.freezeDays, contains('2026-10-19'));
    final days = {for (final (d, s) in c.streakDays(14)) Motivation.day(d): s};
    expect(days['2026-10-18'], 'done');
    expect(days['2026-10-19'], 'freeze');
    expect(days['2026-10-20'], 'done');
    expect(days['2026-10-11'], 'missed');
    expect(c.practisedToday, isTrue);
    now = now.add(const Duration(days: 1));
    expect(c.practisedToday, isFalse);
    expect(c.streakDays(14).last.$2, 'today');
  });

  testWidgets('tapping the streak chip opens the streak sheet with the reminder switch', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(750, 1334);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true, startTier: 0, missionsDone: {'pref:lvseen': '1'}).encode())], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('continue')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byKey(const ValueKey('stats-chip')));
    for (var i = 0; i < 5; i++) { await t.pump(const Duration(milliseconds: 150)); }
    expect(find.byKey(const ValueKey('streak-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-freezes')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('streak-remind')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('streak-remind')));
    await t.pump();
    expect(find.text('Daily reminder at 19:00'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
