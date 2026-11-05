import '../data/premium.dart';

/// Entitlement layer. In the beta build every gate is open ([PremiumConfig.betaFree]).
/// In a paid build ([paidBuild]) the only source of truth is RevenueCat's server-verified customer
/// info, applied through [applyServerState] by `Billing`. Demo mode, owner mode and saved preferences
/// can no longer open paid content in a paid build.
abstract final class Entitlements {
  /// Product ids reserved for Play Console / RevenueCat.
  static const premiumMonthly = 'premium_monthly';
  static const premiumYearly = 'premium_yearly';
  static const careerPackPrefix = 'pack_';

  /// True when this build sells content (set by `Billing.init` before the first frame).
  static bool paidBuild = false;
  static bool get billingEnabled => paidBuild;
  static bool get isPremium => PremiumConfig.betaFree || _unlockedPremium;
  static bool _unlockedPremium = false;
  static Set<String> _ownedPacks = {};

  /// Whether a Career Pack is unlocked: beta, Premium, or a verified one-off purchase.
  static bool packUnlocked(String packId) => PremiumConfig.betaFree || isPremium || _ownedPacks.contains(packId);

  /// Replaces local entitlement state with what the billing server reports. Never called from UI code.
  static void applyServerState({required bool premium, required Set<String> packs}) {
    _unlockedPremium = premium;
    _ownedPacks = {...packs};
  }
}
