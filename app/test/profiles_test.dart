import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/profiles/profiles_screen.dart';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kidBlocks hides adult bureaucracy routes', () {
    expect(kidBlocks('/forms'), isTrue);
    expect(kidBlocks('/forms/gp_register'), isTrue);
    expect(kidBlocks('/visa'), isTrue);
    expect(kidBlocks('/settlement'), isTrue);
    expect(kidBlocks('/park'), isFalse);
    expect(kidBlocks('/family'), isFalse);
    expect(kidBlocks('/progress'), isFalse);
  });

  test('MemoryProgressStore keeps separate streaks per profile', () async {
    final store = MemoryProgressStore();
    await store.write(const UserProgress(streak: 5, onboarded: true, lastActive: '2026-10-31').encode());
    final child = await store.addProfile(displayName: 'Sara', kind: ProfileKind.child);
    await store.switchTo(child.id);
    expect(store.read(), isNull);
    await store.write(const UserProgress(streak: 2, onboarded: true, lastActive: '2026-10-31').encode());
    await store.switchTo('adult');
    expect(UserProgress.decode(store.read()!).streak, 5);
    await store.switchTo(child.id);
    expect(UserProgress.decode(store.read()!).streak, 2);
    expect(store.activeProfile()!.isChild, isTrue);
  });

  test('buddy codes normalize and reject short input', () {
    expect(validBuddyCode('ab cd-ef'), isTrue);
    expect(normalizeBuddyCode('ab cd-ef'), 'ABCDEF');
    expect(validBuddyCode('short'), isFalse);
    expect(newBuddyCode().length, 6);
  });

  test('calm circle encode round-trip', () {
    const c = CalmCircle(week: '2026-W44', goalXp: 50, myCode: 'ABCDEF', buddyCode: 'ZYXWVU', buddyLabel: 'Ali');
    final d = CalmCircle.decode(c.encode(), '2026-W44');
    expect(d.myCode, 'ABCDEF');
    expect(d.buddyCode, 'ZYXWVU');
    expect(d.goalXp, 50);
  });

  testWidgets('profiles screen lists adult and can add child', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true).encode();
    await t.pumpWidget(ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: BL.theme(),
        home: const ProfilesScreen(),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('profiles-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('profiles-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-child-profile')), findsOneWidget);
  });

  testWidgets('progress shows calm-circle not league', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()
      ..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
    await t.pumpWidget(ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: const BritishLifeApp(),
    ));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/progress');
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('calm-circle'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('league'), skipOffstage: false), findsNothing);
  });
}
