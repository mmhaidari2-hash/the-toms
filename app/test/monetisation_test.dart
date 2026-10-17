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

import 'dart:io';

/// Paywall, pack preview lock and certificates render without overflow at iPhone size (375×667).
void main() {
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

  test('prices are config, with a real yearly saving', () {
    expect(PremiumConfig.monthly, greaterThan(0));
    expect(PremiumConfig.yearly, lessThan(PremiumConfig.monthly * 12));
    expect(PremiumConfig.yearlySaving, inInclusiveRange(1, 90));
    expect(PremiumConfig.price(4.99), '£4.99');
  });

  testWidgets('premium, certificates and pack lock render at 375x667 (beta on, then payments on)', (t) async {
    addTearDown(() => PremiumConfig.betaFree = true);
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
      expect(t.takeException(), isNull, reason: r);
    }

    for (var i = 0; i < 40 && find.text('The Toms').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    for (final beta in [true, false]) {
      PremiumConfig.betaFree = beta;
      await go('/premium');
      expect(find.byKey(const ValueKey('beta-banner'), skipOffstage: false), findsOneWidget);
      expect(find.text(beta ? 'Beta: everything is free' : 'Coming soon', skipOffstage: false), findsOneWidget);
      expect(find.textContaining(PremiumConfig.price(PremiumConfig.monthly), skipOffstage: false), findsOneWidget);
      await go('/premium?pack=nursery');
      for (var lv = 1; lv <= 5; lv++) {
        await go('/certificate/$lv');
        expect(find.byKey(const ValueKey('certificate-locked'), skipOffstage: false), findsOneWidget);
      }
      await go('/pack/nursery');
      // A pack lesson past the free preview: the lesson route shows the paywall instead when payments are on.
      await go('/lesson/nur_1_2');
      expect(find.byKey(const ValueKey('beta-banner'), skipOffstage: false), beta ? findsNothing : findsOneWidget);
    }
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
