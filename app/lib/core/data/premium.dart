/// Premium / paywall configuration (monetisation Option B, owner-approved 2026-11-12, docs/monetisation/MODEL_FA.md).
///
/// Charged prices ALWAYS come from Google Play via RevenueCat at runtime ([placeholderPrices] is only shown, marked
/// as an example, in builds that cannot sell). While [betaFree] is true nothing is locked anywhere.
class PremiumConfig {
  /// Public beta: Premium and every Career Pack are free. Flip to false only when billing is wired up
  /// (RevenueCat key, Play products, BILLING permission restored, terms/privacy updated).
  static bool betaFree = true;
  static const String currency = '£';

  /// Documented GBP placeholders (owner decision t299). NOT charged amounts: the paywall shows the store's
  /// own price string in a paid build and refuses to buy when the store price is unavailable.
  static const double monthly = 4.99;
  static const double yearly = 29.99;
  static const double lifetime = 59.99;
  static const double careerPack = 7.99; // pack_nursery, one-off
  static const double examPack = 4.99; // pack_lifeuk / pack_theory, one-off
  static const int trialDays = 7; // configured on the yearly base plan in Play; the store value wins at runtime
  /// Launch offer (Play intro offer on the yearly plan) for the first [foundingSeats] members. Placeholder.
  static const double foundingYear = 19.99;
  static const int foundingSeats = 1000;

  /// Free-zone limits (Option B).
  static const int freeCoreUnits = 10; // U1–U10
  static const int dailyFreeLessons = 1; // new lessons per local day after the free zone

  /// One-off products that exist per pack id (Career Packs + exam packs). Other packs need Premium.
  static const Set<String> oneOffPacks = {'nursery', 'lifeuk', 'theory'};
  static const Map<String, double> placeholderPrices = {
    'premium_monthly': monthly,
    'premium_yearly': yearly,
    'premium_lifetime': lifetime,
    'pack_nursery': careerPack,
    'pack_lifeuk': examPack,
    'pack_theory': examPack,
  };

  /// Always free, never behind the paywall.
  static const List<(String, String)> alwaysFree = [
    ('Arrival and emergency pack (with its offline download)', 'بستهٔ ورود و اضطراری (با دانلود آفلاین آن)'),
    ('Forms Lab, Visa desk and Settlement', 'آزمایشگاه فرم، میز ویزا و مسیر اقامت'),
    ('Grammar Class A1', 'کلاس گرامر A1'),
    ('Units 1–10 and the first unit of every level', 'واحدهای ۱ تا ۱۰ و واحد اول هر سطح'),
    ('Then one new lesson every day, and reviewing lessons you finished', 'بعد از آن روزی یک درس جدید، و مرور درس‌های تمام‌شده'),
    ('Online audio, Leitner and the pronunciation coach', 'صدای آنلاین، لایتنر و مربی تلفظ'),
  ];
  static String price(double v) => '$currency${v.toStringAsFixed(2)}';
  /// Yearly saving against twelve monthly payments, in whole percent (placeholders only).
  static int get yearlySaving => ((1 - yearly / (monthly * 12)) * 100).round();

  /// Only what Premium really unlocks in a paid build (Google Play subscriptions policy: accurate benefits).
  static const List<(String, String)> perks = [
    ('Unlimited new lessons every day (free: one a day after Units 1–10)', 'درس جدید نامحدود در روز (رایگان: بعد از واحدهای ۱ تا ۱۰، روزی یک درس)'),
    ('Offline voices: download lesson audio to play without internet', 'صداهای آفلاین: دانلود صدای درس‌ها برای پخش بدون اینترنت'),
    ('Certificates for every level (not an official qualification)', 'گواهی پایان هر سطح (مدرک رسمی نیست)'),
    ('Every Career Pack (Nursery, Homes and more to come)', 'همهٔ بسته‌های شغلی (مهدکودک، املاک و بسته‌های بعدی)'),
    ('All Life in the UK and Theory test practice and mock tests', 'همهٔ تمرین‌ها و آزمون‌های آزمایشی Life in the UK و تئوری رانندگی'),
  ];

  /// Certificates are not a qualification (shown on the paywall and on every certificate).
  static const certNotOfficial =
      'App certificates are a record of progress in New Life UK only. They are not an official or government qualification, not an accredited English test, and not accepted for visas, settlement (ILR) or citizenship.';
  static const certNotOfficialFa =
      'گواهی‌های اپ فقط نشان پیشرفت در New Life UK است. مدرک رسمی یا دولتی نیست، آزمون زبان معتبر نیست و برای ویزا، اقامت دائم (ILR) یا تابعیت پذیرفته نمی‌شود.';
}
