import '../data/premium.dart';

/// Entitlement layer. In the beta build every gate is open ([PremiumConfig.betaFree]).
/// In a paid build ([paidBuild]) the only source of truth is RevenueCat's server-verified customer
/// info, applied through [applyServerState] by `Billing`. Demo mode, owner mode and saved preferences
/// can no longer open paid content in a paid build.
abstract final class Entitlements {
  /// Product ids reserved for Play Console / RevenueCat (docs/monetisation/MODEL_FA.md).
  static const premiumMonthly = 'premium_monthly';
  static const premiumYearly = 'premium_yearly'; // 7-day free trial offer on this plan only
  static const premiumLifetime = 'premium_lifetime'; // non-consumable; map to the "premium" entitlement in RevenueCat
  static const careerPackPrefix = 'pack_';
  static const packNursery = 'pack_nursery';
  static const packLifeUk = 'pack_lifeuk';
  static const packTheory = 'pack_theory';
  static const allProducts = [premiumYearly, premiumMonthly, premiumLifetime, packNursery, packLifeUk, packTheory];

  /// True when this build sells content (set by `Billing.init` before the first frame).
  static bool paidBuild = false;
  static bool get billingEnabled => paidBuild;
  static bool get isPremium => PremiumConfig.betaFree || _unlockedPremium;
  static bool _unlockedPremium = false;
  static Set<String> _ownedPacks = {};
  static DateTime? _trialEndsAt;

  /// End of a running free trial (server-reported), shown in the app so the learner knows when they will be charged.
  static DateTime? get trialEndsAt => _unlockedPremium ? _trialEndsAt : null;

  /// Whether a pack (Career Pack or exam pack id: 'nursery', 'lifeuk', 'theory') is unlocked:
  /// beta, Premium, or a verified one-off purchase.
  static bool packUnlocked(String packId) => PremiumConfig.betaFree || isPremium || _ownedPacks.contains(packId);

  /// Replaces local entitlement state with what the billing server reports. Never called from UI code.
  static void applyServerState({required bool premium, required Set<String> packs, DateTime? trialEndsAt}) {
    _unlockedPremium = premium;
    _ownedPacks = {...packs};
    _trialEndsAt = trialEndsAt;
  }
}
