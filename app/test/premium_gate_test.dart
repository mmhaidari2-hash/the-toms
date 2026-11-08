import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/billing/entitlements.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/grammar/mistakes_screen.dart';
import 'package:british_life/features/lifeuk/lifeuk_screen.dart';
import 'package:british_life/features/premium/premium_gate.dart';
import 'package:british_life/features/premium/premium_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Premium areas (decision 2026-11-08): Life in the UK beyond chapter 1 (and its mock test) and IELTS Life Skills
/// prep are Premium once payments are on. In the beta everything stays open.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  tearDown(() {
    PremiumConfig.betaFree = true;
    Entitlements.paidBuild = false;
    Entitlements.applyServerState(premium: false, packs: {});
  });

  final chapters = [for (final c in (jsonDecode(File('assets/data/lifeuk.json').readAsStringSync()) as Map)['chapters'] as List) (c as Map)['id'] as String];

  test('perks only promise what Premium unlocks; no offline-voices claim', () {
    final en = PremiumConfig.perks.map((p) => p.$1).join(' | ');
    expect(en.toLowerCase(), isNot(contains('offline')));
    expect(en, contains('Life in the UK'));
    expect(en, contains('Life Skills'));
    for (final (e, fa) in PremiumConfig.perks) {
      expect(RegExp(r'[؀-ۿ]').hasMatch(fa), isTrue, reason: e);
    }
  });

  test('Life in the UK has a free first chapter and more to unlock', () {
    expect(chapters.length, greaterThan(1));
  });

  testWidgets('beta: open; payments on: chapter 1 free, the rest and Life Skills show the paywall; Premium opens all', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    Future<void> go(String r) async {
      router.go(r);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 2));
      for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 200));
      }
      t.takeException();
    }

    // Start every check from the map: the page we left (mid-transition) then never holds a gate, so counts are exact.
    Future<void> open(String r) async {
      await go('/');
      await go(r);
    }

    Finder gate() => find.byType(PremiumGate, skipOffstage: false);
    Finder paywall() => find.descendant(of: gate(), matching: find.byType(PremiumScreen, skipOffstage: false), skipOffstage: false);
    Finder inside(Type ty) => find.descendant(of: gate(), matching: find.byType(ty, skipOffstage: false), skipOffstage: false);

    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }

    // Beta: every gate is open.
    PremiumConfig.betaFree = true;
    await open('/lifeskills');
    expect(inside(LifeSkillsScreen), findsOneWidget);
    await open('/lifeuk/${chapters[1]}');
    expect(inside(LukChapterScreen), findsOneWidget);

    // Payments on, no Premium.
    PremiumConfig.betaFree = false;
    Entitlements.paidBuild = true;
    await open('/lifeuk/${chapters.first}');
    expect(inside(LukChapterScreen), findsOneWidget, reason: 'chapter 1 is the free sample');
    expect(paywall(), findsNothing);
    await open('/lifeuk/${chapters[1]}');
    expect(paywall(), findsOneWidget);
    await open('/lifeuk/${chapters[1]}/quiz');
    expect(paywall(), findsOneWidget);
    await open('/lifeuk/mock');
    expect(paywall(), findsOneWidget);
    await open('/lifeskills');
    expect(paywall(), findsOneWidget);
    await open('/lifeuk');
    expect(find.byType(LukScreen, skipOffstage: false), findsOneWidget, reason: 'the Life in the UK hub stays free');

    // Server-verified Premium opens everything.
    Entitlements.applyServerState(premium: true, packs: {});
    await open('/lifeskills');
    expect(inside(LifeSkillsScreen), findsOneWidget);
    await open('/lifeuk/mock');
    expect(paywall(), findsNothing);

    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
