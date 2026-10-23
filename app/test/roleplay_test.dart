import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/motivation/motivation_widgets.dart';
import 'package:british_life/features/roleplay/roleplay_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Role-play missions: data rules, stars, and a full run (wrong try → My mistakes, hint, Persian, report card, Leitner).
void main() {
  setUp(() {
    BL.useGoogleFonts = false;
    Celebration.autoAdvance = false;
  });
  final rps = Roleplay.parse(File('assets/data/roleplays.json').readAsStringSync());
  final spots = File('assets/data/spots.json').readAsStringSync();

  test('every role-play: 3 goals, all reachable, one best answer and a wrong one per turn, real spot', () {
    expect(rps.length, greaterThanOrEqualTo(6));
    for (final r in rps) {
      expect(r.goals.length, 3, reason: r.id);
      expect(spots.contains('"id": "${r.spot}"') || spots.contains('"id":"${r.spot}"'), isTrue, reason: r.spot);
      final reach = <int>{};
      for (final t in r.turns) {
        expect(t.opts.where((o) => o.q == 2).length, 1, reason: '${r.id}: ${t.npc.en}');
        expect(t.opts.any((o) => o.q == 0), isTrue);
        reach.addAll(t.opts.where((o) => o.q >= 1 && o.goal >= 0).map((o) => o.goal));
        expect(t.hint.fa, isNotEmpty);
      }
      expect(reach, {0, 1, 2}, reason: r.id);
    }
    // Same generic names rule as everywhere: no fixed learner name and no real brand names in the lines.
    final all = File('assets/data/roleplays.json').readAsStringSync().toLowerCase();
    for (final bad in ['starbucks', 'costa', 'boots', 'barclays', 'lloyds', 'hsbc', 'tesco']) {
      expect(all.contains(bad), isFalse, reason: bad);
    }
  });

  test('stars', () {
    expect(Roleplay.stars(turns: 4, natural: 4, wrong: 0, hints: 0), 3);
    expect(Roleplay.stars(turns: 4, natural: 3, wrong: 1, hints: 0), 2);
    expect(Roleplay.stars(turns: 4, natural: 1, wrong: 2, hints: 2), 1);
  });

  testWidgets('a full café role-play', (t) async {
    t.view.physicalSize = const Size(750, 1334);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:lvseen': '1'}).encode())], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('continue')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await t.pump(const Duration(milliseconds: 150));
      }
    }

    router.push('/missions');
    await settle();
    expect(find.byKey(const ValueKey('rp-row')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rp-card-rp_cafe')));
    await settle();
    expect(find.byKey(const ValueKey('rp-brief-goal-2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rp-start')));
    await settle();
    expect(find.byKey(const ValueKey('rp-npc-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rp-slow-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rp-goal-0-open')), findsOneWidget);

    // A wrong try: explained, crossed out, and the natural answer goes to My mistakes.
    await t.tap(find.text("Yes, I'm fine, thank you."));
    await settle();
    expect(find.byKey(const ValueKey('rp-wrong')), findsOneWidget);
    expect(c.read(progressProvider).mistakes.keys, contains('s:Can I have a flat white, please?'));

    // Hint and Persian.
    await t.tap(find.byKey(const ValueKey('rp-hint')));
    await settle();
    expect(find.byKey(const ValueKey('rp-hint-text')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rp-fa')));
    await settle();
    expect(find.byKey(const ValueKey('rp-npc-fa-0')), findsOneWidget);

    final r = rps.firstWhere((x) => x.id == 'rp_cafe');
    for (final turn in r.turns) {
      await t.tap(find.text(turn.best.en));
      await settle();
    }
    expect(find.byKey(const ValueKey('rp-goal-2-done')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rp-report')));
    await settle();
    expect(find.byKey(const ValueKey('rp-reportcard')), findsOneWidget);
    // 3 of 4 natural first time, 1 retry, 1 hint: 6 - 1 - 1 = 4 → 2 stars.
    expect(find.byKey(const ValueKey('rp-star-1-on')), findsOneWidget);
    expect(find.byKey(const ValueKey('rp-star-2-off')), findsOneWidget);
    expect(c.read(progressProvider.notifier).roleplayStars('rp_cafe'), 2);
    await t.scrollUntilVisible(find.byKey(const ValueKey('rp-leit-0')), 150, scrollable: find.descendant(of: find.byKey(const ValueKey('rp-reportcard')), matching: find.byType(Scrollable)).first);
    await settle();
    await t.tap(find.byKey(const ValueKey('rp-leit-0')));
    await settle();
    expect(c.read(progressProvider).leitnerBox.keys, contains('Can I have a flat white, please?'));
    expect(find.byKey(const ValueKey('rp-leit-0-in')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a B1 role-play is locked for an A1 learner', (t) async {
    t.view.physicalSize = const Size(750, 1334);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:lvseen': '1'}).encode())], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('continue')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/roleplay/rp_bank');
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.byKey(const ValueKey('mis-locked')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
