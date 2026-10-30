import '../data/premium.dart';

/// Entitlement layer. Ready for Google Play Billing / RevenueCat later.
/// In this build every gate returns free ([PremiumConfig.betaFree] == true).
/// No real charges are ever taken.
abstract final class Entitlements {
  /// Product ids reserved for Play Console / billing catalog.
  static const premiumMonthly = 'premium_monthly';
  static const premiumYearly = 'premium_yearly';
  static const careerPackPrefix = 'pack_';

  static bool get billingEnabled => false; // flip when Play Billing is wired
  static bool get isPremium => PremiumConfig.betaFree || _unlockedPremium;
  static bool _unlockedPremium = false;

  /// Whether a Career Pack is unlocked. Beta: always. Later: receipt or one-off purchase.
  static bool packUnlocked(String packId) =>
      PremiumConfig.betaFree || isPremium || _ownedPacks.contains(packId);

  static final Set<String> _ownedPacks = {};

  /// Stub purchase — never charges. Records a local entitlement for UI testing.
  static Future<bool> purchaseStub(String productId) async {
    if (PremiumConfig.betaFree) return true;
    if (!billingEnabled) return false;
    // Real Play Billing Client would go here.
    if (productId == premiumMonthly || productId == premiumYearly) {
      _unlockedPremium = true;
      return true;
    }
    if (productId.startsWith(careerPackPrefix)) {
      _ownedPacks.add(productId.substring(careerPackPrefix.length));
      return true;
    }
    return false;
  }

  static void restoreStub() {
    // Placeholder for BillingClient.queryPurchasesAsync / RevenueCat restore.
  }
}
