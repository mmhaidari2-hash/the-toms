import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/premium.dart';
import 'entitlements.dart';
import 'trial_reminder.dart';

enum BillingOutcome { success, cancelled, pending, unavailable, failed }

/// A price exactly as Google Play formats it (currency, VAT-inclusive), plus the free-trial length if any.
class StorePrice {
  final String text;
  final int? trialDays;
  const StorePrice(this.text, {this.trialDays});
}

/// RevenueCat + Google Play Billing (OPEN_QUESTIONS_FA.md Q42).
///
/// OFF unless all three hold: [PremiumConfig.betaFree] is false, the build was made with
/// `--dart-define=RC_GOOGLE_KEY=goog_...` (RevenueCat *public* SDK key, never a secret key), and the
/// app runs on Android. Purchases are validated by RevenueCat's servers against Google Play; the app
/// only ever trusts [CustomerInfo] from the SDK (which caches it for offline use), never a local flag.
abstract final class Billing {
  static const _key = String.fromEnvironment('RC_GOOGLE_KEY');
  /// Entitlement identifier configured in the RevenueCat dashboard.
  static const entitlementId = 'premium';

  static bool get available =>
      !PremiumConfig.betaFree && _key.isNotEmpty && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool _ready = false;

  /// Call once at start-up. Safe to call when billing is off (does nothing).
  static Future<void> init() async {
    Entitlements.paidBuild = available;
    if (!available || _ready) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(_key));
      _ready = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('Billing init failed: $e'); // stays locked; retried on next purchase/restore
    }
  }

  static void _apply(CustomerInfo info) {
    final ent = info.entitlements.active[entitlementId];
    Entitlements.applyServerState(
      // premium_lifetime should be attached to the "premium" entitlement in RevenueCat; the transaction check is
      // a fallback that still only trusts RevenueCat's verified CustomerInfo.
      premium: ent != null || info.nonSubscriptionTransactions.any((t) => t.productIdentifier == Entitlements.premiumLifetime),
      packs: {
        for (final t in info.nonSubscriptionTransactions)
          if (t.productIdentifier.startsWith(Entitlements.careerPackPrefix))
            t.productIdentifier.substring(Entitlements.careerPackPrefix.length),
      },
      trialEndsAt: ent != null && ent.periodType == PeriodType.trial ? DateTime.tryParse(ent.expirationDate ?? '')?.toLocal() : null,
    );
    unawaited(TrialReminder.sync());
  }

  /// Store prices for [Entitlements.allProducts], read from Google Play through RevenueCat. Empty when billing
  /// is off or the store is unreachable: callers must then NOT sell (no hard-coded charged amounts).
  static Future<Map<String, StorePrice>> prices() async {
    if (!available) return const {};
    if (!_ready) await init();
    if (!_ready) return const {};
    final out = <String, StorePrice>{};
    try {
      final offerings = await Purchases.getOfferings();
      for (final o in offerings.all.values) {
        for (final p in o.availablePackages) {
          final sp = p.storeProduct;
          out.putIfAbsent(sp.identifier.split(':').first, () => StorePrice(sp.priceString, trialDays: periodDays(sp.defaultOption?.freePhase?.billingPeriod?.iso8601)));
        }
      }
      final missing = Entitlements.allProducts.where((id) => !out.containsKey(id)).toList();
      if (missing.isNotEmpty) {
        for (final sp in await Purchases.getProducts(missing, productCategory: ProductCategory.nonSubscription)) {
          out.putIfAbsent(sp.identifier.split(':').first, () => StorePrice(sp.priceString));
        }
      }
    } catch (e) {
      debugPrint('Billing prices failed: $e');
    }
    return out;
  }

  /// Days in an ISO-8601 period such as P7D / P1W / P1M (approximate for months). Null when absent.
  static int? periodDays(String? iso) {
    final m = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso ?? '');
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return switch (m.group(2)) { 'D' => n, 'W' => n * 7, 'M' => n * 30, _ => n * 365 };
  }

  /// Buys [productId] (one of the [Entitlements] product ids). The caller must already have shown the
  /// price, renewal terms and the UK 14-day cancellation consent.
  static Future<BillingOutcome> buy(String productId) async {
    if (!available) return BillingOutcome.unavailable;
    if (!_ready) await init();
    if (!_ready) return BillingOutcome.unavailable;
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const <Package>[];
      final pkg = packages.where((p) => p.storeProduct.identifier.split(':').first == productId).firstOrNull;
      final PurchaseResult r;
      if (pkg != null) {
        r = await Purchases.purchase(PurchaseParams.package(pkg));
      } else {
        final products = await Purchases.getProducts([productId], productCategory: ProductCategory.nonSubscription);
        if (products.isEmpty) return BillingOutcome.unavailable;
        r = await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      }
      _apply(r.customerInfo);
      return BillingOutcome.success;
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => BillingOutcome.cancelled,
        PurchasesErrorCode.paymentPendingError => BillingOutcome.pending,
        _ => BillingOutcome.failed,
      };
    }
  }

  /// Restores purchases made with the same Google account (new phone, reinstall).
  static Future<BillingOutcome> restore() async {
    if (!available) return BillingOutcome.unavailable;
    if (!_ready) await init();
    if (!_ready) return BillingOutcome.unavailable;
    try {
      _apply(await Purchases.restorePurchases());
      return BillingOutcome.success;
    } on PlatformException {
      return BillingOutcome.failed;
    }
  }

  /// Google Play's own subscription page, where the user cancels or changes plan.
  static Uri manageUrl(String packageName) =>
      Uri.parse('https://play.google.com/store/account/subscriptions?package=$packageName');
}
