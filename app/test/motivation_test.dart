import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:british_life/features/motivation/motivation_widgets.dart';
import 'package:british_life/features/motivation/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// Motivation layer: XP, daily goal, streak + freezes, league, badges, reminders, celebration.
void main() {
  late DateTime now;
  ProgressController ctrl([UserProgress p = const UserProgress(onboarded: true)]) {
    final store = MemoryProgressStore()..data = p.encode();
    return ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => now)]).read(progressProvider.notifier);
  }

  setUp(() => now = DateTime(2026, 10, 12, 18)); // a Monday

  test('practice and stories earn XP towards the daily goal', () {
    final c = ctrl();
    expect(c.dailyGoal, Motivation.defaultGoal);
    final a = c.savePractice('l1_u1_1', 100);
    expect(a.xp, 15);
    expect(c.xpToday, 15);
    expect(a.goalJustHit, isFalse);
    final b = c.savePractice('l1_u1_1', 50); // replays earn XP but don't lower the best score
    expect(b.xp, 10);
    expect(b.goalJustHit, isTrue);
    expect(c.practiceScore('l1_u1_1'), 100);
    expect(c.xpTotal, 25);
    c.setDailyGoal(50);
    expect(c.dailyGoal, 50);
    expect(c.goalChosen, isTrue);
  });

  test('streak grows day by day, a freeze covers one missed day, two missed days reset it', () {
    final c = ctrl();
    expect(c.currentStreak, 0);
    c.awardXp(10);
    expect(c.currentStreak, 1);
    now = now.add(const Duration(days: 1));
    c.awardXp(10);
    expect(c.currentStreak, 2);
    expect(c.freezes, 1);
    // Miss one day: the freeze saves it.
    now = now.add(const Duration(days: 2));
    expect(c.currentStreak, 2, reason: 'shown as safe while a freeze can cover it');
    final a = c.awardXp(10);
    expect(a.freezeUsed, isTrue);
    expect(c.currentStreak, 3);
    expect(c.freezes, 0);
    // Miss two days: back to 1.
    now = now.add(const Duration(days: 3));
    expect(c.currentStreak, 0);
    c.awardXp(10);
    expect(c.currentStreak, 1);
  });

  test('a full week of streak earns a freeze (max 2)', () {
    final c = ctrl();
    for (var i = 0; i < 14; i++) {
      c.awardXp(5);
      now = now.add(const Duration(days: 1));
    }
    expect(c.state.streak, 14);
    expect(c.freezes, 2);
  });

  test('badges unlock once and appear in the award', () {
    final c = ctrl();
    final a = c.savePractice('l1_u1_1', 100);
    expect(a.newBadges.map((b) => b.id), containsAll(['first', 'perfect']));
    final b = c.savePractice('l1_u1_2', 100);
    expect(b.newBadges.map((b) => b.id), isNot(contains('first')));
    for (var i = 0; i < 10; i++) {
      c.awardXp(10);
    }
    expect(c.badgesEarned, contains('xp100'));
  });

  test('league: ten players, deterministic bots, promotion settles at the new week', () {
    final c = ctrl();
    final rows = c.leagueBoard();
    expect(rows.length, 10);
    expect(rows.where((r) => r.$3).length, 1);
    expect(c.leagueBoard().map((r) => r.$1).toList(), rows.map((r) => r.$1).toList(), reason: 'same bots all week');
    c.awardXp(2000); // top of the table this week
    expect(Motivation.rank(c.leagueBoard()), 1);
    now = now.add(const Duration(days: 7));
    c.awardXp(5);
    expect(c.leagueTier, 1, reason: 'promoted to Silver');
    expect(c.badgesEarned, contains('league'));
    expect(c.xpWeek, 5);
    expect(Motivation.nextTier(1, 10), 0);
    expect(Motivation.nextTier(4, 1), 4);
  });

  test('reminder is due once a day after the chosen time if the goal is not met', () {
    final c = ctrl();
    expect(c.reminderDue(), isFalse, reason: 'off by default');
    c.setReminder('17:30', true);
    expect(c.reminderDue(), isTrue);
    c.markReminded();
    expect(c.reminderDue(), isFalse);
    now = now.add(const Duration(days: 1));
    c.awardXp(c.dailyGoal);
    expect(c.reminderDue(), isFalse, reason: 'goal already met');
  });

  test('calendar reminder is a valid daily .ics event', () {
    final ics = reminderIcs(19, 5, DateTime(2026, 10, 17));
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, contains('DTSTART:20261017T190500'));
    expect(ics, contains('DTEND:20261017T191500'));
    expect(ics, contains('RRULE:FREQ=DAILY'));
    expect(ics, contains('BEGIN:VALARM'));
    expect(ics.trim(), endsWith('END:VCALENDAR'));
  });

  group('screens at 375x667', () {
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
    testWidgets('map stats chip, progress screen and the end-of-practice celebration render without overflow', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> go(String r) async {
        router.go(r);
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(seconds: 2));
        for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull, reason: r);
      }

      await go('/');
      expect(find.byKey(const ValueKey('stats-chip'), skipOffstage: false), findsOneWidget);
      await go('/progress');
      for (final k in ['progress-top', 'calm-circle']) {
        expect(find.byKey(ValueKey(k), skipOffstage: false), findsOneWidget, reason: k);
      }
      final sc = t.state<ScrollableState>(find.descendant(of: find.byType(ProgressScreen, skipOffstage: false), matching: find.byType(Scrollable, skipOffstage: false)).first);
      for (var i = 0; i < 4; i++) {
        sc.position.jumpTo(sc.position.maxScrollExtent);
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const ValueKey('reminders'), skipOffstage: false), findsOneWidget);
      expect(t.takeException(), isNull);
      await go('/practice/l1_u1_1');
      router.go('/');
      await t.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('celebration shows XP, streak, goal and new badges at 375x667', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    var tapped = false;
    final award = XpAward(xp: 15, total: 115, today: 25, goal: 20, streak: 7, streakUp: true, goalJustHit: true, newBadges: Motivation.badges.take(3).toList());
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Celebration(award: award, pass: true, checkpoint: false, right: 9, total: 10, onContinue: () => tapped = true))));
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
    expect(find.text('Lesson complete!'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
    expect(find.text('Daily goal reached!'), findsOneWidget);
    expect(find.text('7-day streak. Keep it going!'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-badge-first')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('celebrate-continue')));
    expect(tapped, isTrue);
  });
}
