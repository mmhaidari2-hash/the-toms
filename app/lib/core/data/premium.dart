/// Premium / paywall configuration. No real payments exist yet: everything here is display-only.
/// Real billing (RevenueCat for the App Store / Play, Stripe on the web) is tracked in the GitHub issue
/// "Real payments + native store builds"; until then [betaFree] keeps every Career Pack open.
class PremiumConfig {
  /// Public beta: Premium and every Career Pack are free. Flip to false only when billing is wired up.
  static bool betaFree = true;
  static const String currency = '£';
  static const double monthly = 4.99;
  static const double yearly = 34.99;
  static const double careerPack = 9.99; // one-off, per pack, yours for good
  static const int trialDays = 7;
  static String price(double v) => '$currency${v.toStringAsFixed(2)}';
  /// Yearly saving against twelve monthly payments, in whole percent.
  static int get yearlySaving => ((1 - yearly / (monthly * 12)) * 100).round();
  static const List<(String, String)> perks = [
    ('Every Career Pack (Nursery and more to come)', 'همهٔ بسته‌های شغلی (مهدکودک و بسته‌های بعدی)'),
    ('Unlimited practice and unit reviews', 'تمرین و مرور نامحدود'),
    ('Certificates for every level', 'گواهی پایان هر سطح'),
    ('Offline voices for every lesson', 'صداهای آفلاین برای همهٔ درس‌ها'),
  ];
}
