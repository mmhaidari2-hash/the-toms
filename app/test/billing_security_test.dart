import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/billing/billing.dart';
import 'package:british_life/core/billing/entitlements.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/features/premium/premium_screen.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paid builds must trust only server-verified entitlements (Q42). Demo mode, owner mode and saved
/// preferences may open paid content in the beta, never in a paid build.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  tearDown(() {
    PremiumConfig.betaFree = true;
    Entitlements.paidBuild = false;
    Entitlements.applyServerState(premium: false, packs: {});
  });

  ProviderContainer container(UserProgress p) {
    final store = MemoryProgressStore()..data = p.encode();
    return ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
  }

  test('billing stays off without the build key (tests, web, beta)', () async {
    PremiumConfig.betaFree = false;
    expect(Billing.available, isFalse);
    await Billing.init();
    expect(Entitlements.paidBuild, isFalse);
    expect(await Billing.buy(Entitlements.premiumYearly), BillingOutcome.unavailable);
  });

  test('paid build: demo/owner mode and local prefs do not unlock paid content', () {
    PremiumConfig.betaFree = false;
    Entitlements.paidBuild = true;
    final c = container(const UserProgress(onboarded: true, unlockAll: true, ownerMode: true, missionsDone: {'pref:premium': 'on'}));
    addTearDown(c.dispose);
    final ctrl = c.read(progressProvider.notifier);
    expect(ctrl.hasPremium, isFalse);
    Entitlements.applyServerState(premium: true, packs: {});
    expect(ctrl.hasPremium, isTrue, reason: 'a verified entitlement unlocks');
    Entitlements.applyServerState(premium: false, packs: {'nursery'});
    expect(Entitlements.packUnlocked('nursery'), isTrue);
    expect(Entitlements.packUnlocked('care'), isFalse);
  });

  test('demo / owner / saved prefs open everything only in the free beta, never once content is sold (t300)', () {
    // Before t300 an unpaid build with betaFree=false (and the web) let the demo toggle grant Premium.
    const p = UserProgress(onboarded: true, unlockAll: true, ownerMode: true, missionsDone: {'pref:premium': 'on', 'pack:nursery': 'owned', 'pack:lifeuk': 'owned'});
    final c = container(p);
    addTearDown(c.dispose);
    final ctrl = c.read(progressProvider.notifier);
    expect(ctrl.hasPremium, isTrue, reason: 'betaFree: demo works');
    PremiumConfig.betaFree = false; // selling, no billing key (web or unpaid build)
    expect(ctrl.hasPremium, isFalse);
    expect(ctrl.examUnlocked('lifeuk'), isFalse);
    expect(ctrl.certificatesUnlocked || ctrl.offlineVoicesUnlocked, isFalse);
    Entitlements.paidBuild = true;
    expect(ctrl.hasPremium, isFalse);
  });

  testWidgets('paid paywall: pay stays disabled until the 14-day consent is ticked', (t) async {
    PremiumConfig.betaFree = false;
    Entitlements.paidBuild = true;
    // Store prices come from Google Play at runtime; a fake store answers here.
    final load = PremiumScreen.loadPrices;
    PremiumScreen.loadPrices = () async => {Entitlements.premiumYearly: const StorePrice('£29.99', trialDays: 7)};
    addTearDown(() => PremiumScreen.loadPrices = load);
    t.view.physicalSize = const Size(375, 1800) * 3; // tall enough that the whole paywall list is built
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    router.go('/premium');
    for (var i = 0; i < 30 && find.byKey(const ValueKey('plan-yearly')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('restore-purchases')), findsOneWidget);
    expect(find.byKey(const ValueKey('manage-subscription')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('plan-yearly')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-consent')), findsOneWidget);
    expect(find.textContaining('Renews automatically'), findsOneWidget);
    FilledButton pay() => t.widget<FilledButton>(find.byKey(const ValueKey('consent-pay')));
    expect(pay().onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('consent-box')));
    await t.pump();
    expect(pay().onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });
}
