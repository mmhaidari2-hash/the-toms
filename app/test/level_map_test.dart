import 'package:british_life/app/app.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The town map at a chosen level (375×667): CEFR districts, highlighted places, and the level-up celebration.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  Future<void> boot(WidgetTester t, UserProgress p) async {
    t.view.physicalSize = const Size(750, 1334);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = p.encode())], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('continue')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('B1 learner: districts labelled A1–C1, B1 marked, Continue at B1, no layout errors', (t) async {
    await boot(t, const UserProgress(onboarded: true, startTier: 2, missionsDone: {'pref:lvseen': '3'}));
    expect(t.takeException(), isNull);
    for (final c in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(find.byKey(ValueKey('zone-$c')), findsWidgets, reason: c);
    }
    expect(find.textContaining('CONTINUE · B1'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-up-3')), findsNothing);
  });

  testWidgets('passing the A2 level test celebrates once and moves Continue to B1', (t) async {
    await boot(t, const UserProgress(onboarded: true, startTier: 1, missionsDone: {'course:U151': '85', 'pref:lvseen': '2'}));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('level-up-3')), findsOneWidget);
    expect(find.textContaining('High Street is now open'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byKey(const ValueKey('level-up-later')));
    await t.tap(find.byKey(const ValueKey('level-up-later')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('CONTINUE · B1'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-up-3')), findsNothing);
  });
}
