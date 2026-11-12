import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/billing/billing.dart';
import '../../core/billing/entitlements.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';

/// Why the paywall opened (Option B paywall moments) and what to say, in English and Persian.
/// Moments: end of the free core, daily free lesson used, after the first mock result, tapping download,
/// a finished certificate, a locked exam chapter. Never inside a conversation, never on Arrival/emergency/Visa.
abstract final class PaywallCopy {
  static const reasons = <String, (String, String)>{
    'daily': (
      'Today’s free lesson is done. Another free lesson opens tomorrow, and you can review lessons you finished any time. Premium gives you unlimited new lessons.',
      'درس رایگان امروز تمام شد. فردا یک درس رایگان دیگر باز می‌شود و مرور درس‌های تمام‌شده همیشه آزاد است. با اشتراک ویژه درس جدید نامحدود دارید.',
    ),
    'core': (
      'You finished Units 1–10! The first unit of every level stays free, plus one new lesson every day. Premium unlocks unlimited lessons, offline voices and your level certificates.',
      'واحدهای ۱ تا ۱۰ را تمام کردید! واحد اول هر سطح رایگان می‌ماند و روزی یک درس جدید هم رایگان است. اشتراک ویژه درس نامحدود، صدای آفلاین و گواهی سطح را باز می‌کند.',
    ),
    'mock': (
      'Your first mock test is free. Premium, or the one-off test pack, unlocks every chapter and unlimited mock tests.',
      'اولین آزمون آزمایشی رایگان است. اشتراک ویژه یا خرید یک‌بارهٔ بستهٔ آزمون، همهٔ فصل‌ها و آزمون‌های آزمایشی نامحدود را باز می‌کند.',
    ),
    'exam': (
      'Chapter 1 and one mock test are free. Premium, or the one-off test pack, unlocks the rest.',
      'فصل ۱ و یک آزمون آزمایشی رایگان است. اشتراک ویژه یا خرید یک‌بارهٔ بستهٔ آزمون بقیه را باز می‌کند.',
    ),
    'download': (
      'Offline voices are part of Premium. Lessons still play online for free, and the Arrival and emergency pack download is always free.',
      'صدای آفلاین بخشی از اشتراک ویژه است. درس‌ها به‌صورت آنلاین رایگان پخش می‌شوند و دانلود بستهٔ ورود و اضطراری همیشه رایگان است.',
    ),
    'cert': ('You earned this certificate. Premium lets you add your name and share it.', 'این گواهی را به دست آوردید. با اشتراک ویژه می‌توانید نامتان را رویش بنویسید و آن را به اشتراک بگذارید.'),
  };

  static const terms =
      'Subscriptions renew automatically at the price shown until you cancel. Cancel any time in Google Play (Payments & subscriptions › Subscriptions); you keep access until the end of the period you paid for. On the yearly plan’s free trial, cancel before it ends and you pay nothing. You can keep using New Life UK free without subscribing.';
  static const termsFa =
      'اشتراک‌ها با همین قیمت خودکار تمدید می‌شوند تا لغوشان کنید. هر وقت بخواهید از گوگل‌پلی لغو کنید (پرداخت‌ها و اشتراک‌ها › اشتراک‌ها)؛ تا پایان دورهٔ پرداخت‌شده دسترسی دارید. در دورهٔ رایگانِ طرح سالانه، اگر قبل از پایانش لغو کنید چیزی پرداخت نمی‌کنید. بدون اشتراک هم می‌توانید رایگان از New Life UK استفاده کنید.';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// What a one-off pack contains.
  static (String, String) packNote(String id) => switch (id) {
    'lifeuk' => ('Every Life in the UK chapter and unlimited mock tests. One payment, no subscription.', 'همهٔ فصل‌های Life in the UK و آزمون آزمایشی نامحدود. یک بار پرداخت، بدون اشتراک.'),
    'theory' => (
      'Every Theory test chapter, unlimited mock tests and the 10 Driving English lessons. One payment, no subscription.',
      'همهٔ فصل‌های آزمون تئوری، آزمون آزمایشی نامحدود و ۱۰ درس انگلیسی رانندگی. یک بار پرداخت، بدون اشتراک.',
    ),
    _ => ('Every lesson in this Career Pack. One payment, yours for good, no subscription.', 'همهٔ درس‌های این بستهٔ شغلی. یک بار پرداخت، برای همیشه، بدون اشتراک.'),
  };
  static String packTitle(String id, String? careerTitle) => switch (id) {
    'lifeuk' => 'Life in the UK test pack',
    'theory' => 'Theory test pack',
    _ => careerTitle ?? 'One Career Pack',
  };
}

/// Child profiles never see offers or prices: just a calm limit message.
class _KidLimit extends StatelessWidget {
  final bool daily;
  const _KidLimit({required this.daily});
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('paywall-kid'),
    backgroundColor: BL.cream,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [NavButtons(), Spacer()]),
            const Spacer(),
            Text(
              hl(daily ? 'Today’s new lesson is done. Come back tomorrow for another one, or review a lesson you finished.' : 'This part is not available in this profile.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
            ),
            Text(
              hl(daily ? 'درس جدید امروز تمام شد. فردا برگرد یا یکی از درس‌های تمام‌شده را مرور کن.' : 'این بخش در این پروفایل در دسترس نیست.'),
              textAlign: TextAlign.center,
              textDirection: helperDir,
              style: BL.fa(13, color: BL.muted),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    ),
  );
}

/// Calm Premium offer shown on a finished-lesson / result screen (a paywall moment). Opens nothing by itself.
/// Hidden in child profiles (no offers to children).
class PaywallMomentCard extends ConsumerWidget {
  final String reason;
  final String? pack;
  const PaywallMomentCard({super.key, required this.reason, this.pack});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.read(progressProvider.notifier).kidMode) return const SizedBox.shrink();
    final (en, fa) = PaywallCopy.reasons[reason] ?? PaywallCopy.reasons['core']!;
    return Container(
      key: ValueKey('paywall-moment-$reason'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BL.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC9A04C), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hl(en), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.3)),
          const SizedBox(height: 4),
          Text(
            hl(fa),
            textDirection: helperDir,
            style: BL.fa(12, color: BL.muted),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('paywall-moment-open'),
            onPressed: () => context.push('/premium?reason=$reason${pack == null ? '' : '&pack=$pack'}'),
            icon: const Icon(Icons.workspace_premium_rounded),
            label: Text(hl('See Premium · اشتراک ویژه')),
          ),
        ],
      ),
    );
  }
}

/// Premium / paywall. Beta: display-only, everything free. Paid build: Google Play Billing via RevenueCat
/// ([Billing]); prices come from the store at runtime, with the UK pre-contract information and 14-day
/// cancellation consent shown before paying.
class PremiumScreen extends ConsumerStatefulWidget {
  final String? pack;
  final String? reason;
  const PremiumScreen({super.key, this.pack, this.reason});

  /// Test seam: store prices (defaults to [Billing.prices]).
  static Future<Map<String, StorePrice>> Function() loadPrices = Billing.prices;
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Map<String, StorePrice> _prices = const {};

  @override
  void initState() {
    super.initState();
    if (Entitlements.paidBuild) {
      PremiumScreen.loadPrices().then((p) {
        if (mounted) setState(() => _prices = p);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final pad = MediaQuery.paddingOf(context);
    if (ref.read(progressProvider.notifier).kidMode) return _KidLimit(daily: widget.reason == 'daily'); // no offers in child profiles
    final beta = PremiumConfig.betaFree;
    final pack = widget.pack;
    final pk = pack == null ? null : c?.course.pack(pack);
    final paid = Entitlements.paidBuild;
    // Only packs with their own Play product get a one-off plan; other Career Packs come with Premium.
    final onePack = pack != null && PremiumConfig.oneOffPacks.contains(pack) ? pack : null;
    void say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(hl(m))));

    /// Display price: the store's own string in a paid build; an example placeholder otherwise; never invented.
    String? storePrice(String id) => _prices[id]?.text;
    String shown(String id, String per) {
      final sp = storePrice(id);
      if (sp != null) return '$sp$per';
      if (paid) return 'Price in Google Play';
      return 'e.g. ${PremiumConfig.price(PremiumConfig.placeholderPrices[id] ?? 0)}$per';
    }

    final trialDays = paid ? _prices[Entitlements.premiumYearly]?.trialDays : PremiumConfig.trialDays;
    Future<void> tapPlan(String productId) async {
      if (!paid) return say(beta ? 'Free during the beta. No payment is taken. Enjoy!' : 'Payments are coming soon.');
      final sp = storePrice(productId);
      if (sp == null) return say('The store is not available right now. Please try again later.');
      final trialEnd = trialDays == null ? null : PaywallCopy.date(DateTime.now().add(Duration(days: trialDays)));
      final (terms, termsFa) = switch (productId) {
        Entitlements.premiumYearly => (
          trialDays == null
              ? '$sp a year. Renews automatically every year until you cancel in Google Play.'
              : '$trialDays-day free trial, then $sp a year. If you start today, the trial ends on $trialEnd; cancel in Google Play before then and you pay nothing. Renews automatically every year until you cancel.',
          trialDays == null
              ? 'سالانه $sp. هر سال خودکار تمدید می‌شود تا در گوگل‌پلی لغو کنید.'
              : '$trialDays روز رایگان، بعد سالانه $sp. اگر امروز شروع کنید، دورهٔ رایگان در $trialEnd تمام می‌شود؛ اگر قبل از آن در گوگل‌پلی لغو کنید چیزی پرداخت نمی‌کنید. هر سال خودکار تمدید می‌شود تا لغو کنید.',
        ),
        Entitlements.premiumMonthly => ('$sp a month. Renews automatically every month until you cancel in Google Play.', 'ماهانه $sp. هر ماه خودکار تمدید می‌شود تا در گوگل‌پلی لغو کنید.'),
        Entitlements.premiumLifetime => ('$sp once. Premium for good, no subscription and no renewals.', 'یک بار $sp. اشتراک ویژه برای همیشه، بدون تمدید.'),
        _ => ('$sp once. No subscription.', 'یک بار $sp. بدون اشتراک.'),
      };
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _Consent(terms: terms, termsFa: termsFa),
      );
      if (ok != true) return;
      final r = await Billing.buy(productId);
      if (!context.mounted) return;
      say(switch (r) {
        BillingOutcome.success => 'Thank you. Unlocked.',
        BillingOutcome.cancelled => 'Purchase cancelled. You were not charged.',
        BillingOutcome.pending => 'Payment pending. It unlocks as soon as Google Play confirms it.',
        BillingOutcome.unavailable => 'The store is not available right now. Please try again later.',
        BillingOutcome.failed => 'Something went wrong. You were not charged.',
      });
    }

    void close() => pk != null ? context.go('/pack/${pk.id}') : (context.canPop() ? context.pop() : context.go('/'));
    final why = widget.reason == null ? null : PaywallCopy.reasons[widget.reason!];
    final trialEnds = Entitlements.trialEndsAt;
    return Scaffold(
      backgroundColor: BL.cream,
      // A Column (not a lazy ListView): the paywall is short, and every term must be built and readable.
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NavButtons(),
                const Spacer(),
                IconButton(key: const ValueKey('paywall-close'), tooltip: 'Close', onPressed: close, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFC9A04C)]),
                ),
                child: const Icon(Icons.workspace_premium_rounded, size: 36, color: BL.ink),
              ),
            ),
            const SizedBox(height: 12),
            Text('New Life UK Premium', textAlign: TextAlign.center, style: BL.display(28)),
            Text(
              hl('اشتراک ویژهٔ New Life UK'),
              textAlign: TextAlign.center,
              textDirection: helperDir,
              style: BL.fa(14, color: BL.muted),
            ),
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('beta-banner'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: beta ? BL.green : BL.navy, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  // A paid build sells through Google Play, so it must not say payments are "coming soon".
                  Text(
                    hl(
                      beta
                          ? 'Beta: everything is free'
                          : paid
                          ? (pk != null ? 'Unlock every Career Pack' : 'Go further with Premium')
                          : 'Coming soon',
                    ),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hl(
                      beta
                          ? 'Premium and every Career Pack are open while we test. No card, no payment.'
                          : paid
                          ? 'You can keep learning free without a subscription. Premium removes the limits.'
                          : 'Payments are not switched on yet.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hl(
                      beta
                          ? 'در دورهٔ آزمایشی همه چیز رایگان است. بدون کارت و بدون پرداخت.'
                          : paid
                          ? 'بدون اشتراک هم می‌توانید رایگان یاد بگیرید. اشتراک ویژه محدودیت‌ها را برمی‌دارد.'
                          : 'پرداخت هنوز فعال نشده است.',
                    ),
                    textAlign: TextAlign.center,
                    textDirection: helperDir,
                    style: BL.fa(12.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (why != null && !beta) ...[
              const SizedBox(height: 14),
              Text(
                hl(why.$1),
                key: const ValueKey('paywall-reason'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: BL.ink, height: 1.3, fontWeight: FontWeight.w700),
              ),
              Text(
                hl(why.$2),
                textAlign: TextAlign.center,
                textDirection: helperDir,
                style: BL.fa(12, color: BL.muted),
              ),
            ],
            if (pk != null && !beta) ...[
              const SizedBox(height: 14),
              Text(
                hl('You tried the free first lesson of ${pk.title}. Unlock the rest with Premium${onePack != null ? ' or buy the pack once' : ''}.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: BL.ink, height: 1.3),
              ),
            ],
            if (trialEnds != null) ...[
              const SizedBox(height: 14),
              Text(
                hl('Your free trial ends on ${PaywallCopy.date(trialEnds)}. After that Google Play charges the yearly price unless you cancel in Google Play before then.'),
                key: const ValueKey('trial-ends'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BL.ink),
              ),
              Text(
                hl('دورهٔ رایگان شما در ${PaywallCopy.date(trialEnds)} تمام می‌شود. بعد از آن گوگل‌پلی هزینهٔ سالانه را می‌گیرد، مگر اینکه قبلش در گوگل‌پلی لغو کنید.'),
                textAlign: TextAlign.center,
                textDirection: helperDir,
                style: BL.fa(11.5, color: BL.muted),
              ),
            ],
            const SizedBox(height: 18),
            for (final p in PremiumConfig.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: BL.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hl(p.$1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(
                            hl(p.$2),
                            textDirection: helperDir,
                            style: BL.fa(11.5, color: BL.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              hl(PremiumConfig.certNotOfficial),
              key: const ValueKey('cert-not-official'),
              style: const TextStyle(fontSize: 11.5, color: BL.muted, height: 1.3),
            ),
            Text(
              hl(PremiumConfig.certNotOfficialFa),
              textDirection: helperDir,
              style: BL.fa(11, color: BL.muted),
            ),
            const SizedBox(height: 12),
            _Plan(
              key: const ValueKey('plan-yearly'),
              title: 'Yearly',
              fa: 'سالانه',
              price: shown(Entitlements.premiumYearly, ' / year'),
              note: trialDays == null ? 'Billed once a year · renews automatically' : '$trialDays-day free trial, then billed once a year · renews automatically',
              best: true,
              beta: beta,
              onTap: () => tapPlan(Entitlements.premiumYearly),
            ),
            _Plan(
              key: const ValueKey('plan-monthly'),
              title: 'Monthly',
              fa: 'ماهانه',
              price: shown(Entitlements.premiumMonthly, ' / month'),
              note: 'Billed every month · renews automatically · cancel any time',
              beta: beta,
              onTap: () => tapPlan(Entitlements.premiumMonthly),
            ),
            _Plan(
              key: const ValueKey('plan-lifetime'),
              title: 'Lifetime',
              fa: 'مادام‌العمر، یک بار پرداخت',
              price: '${shown(Entitlements.premiumLifetime, '')} once',
              note: 'Premium for good · no subscription, no renewals',
              beta: beta,
              onTap: () => tapPlan(Entitlements.premiumLifetime),
            ),
            if (onePack != null)
              _Plan(
                key: const ValueKey('plan-pack'),
                title: PaywallCopy.packTitle(onePack, pk?.title),
                fa: PaywallCopy.packNote(onePack).$2,
                price: '${shown('${Entitlements.careerPackPrefix}$onePack', '')} once',
                note: PaywallCopy.packNote(onePack).$1,
                beta: beta,
                onTap: () => tapPlan('${Entitlements.careerPackPrefix}$onePack'),
              ),
            Text(
              hl(PaywallCopy.terms),
              key: const ValueKey('paywall-terms'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: BL.muted, height: 1.35),
            ),
            Text(
              hl(PaywallCopy.termsFa),
              textAlign: TextAlign.center,
              textDirection: helperDir,
              style: BL.fa(11, color: BL.muted),
            ),
            const SizedBox(height: 10),
            Text(
              hl('Always free: ${PremiumConfig.alwaysFree.map((e) => e.$1).join(' · ')}'),
              key: const ValueKey('always-free'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: BL.green),
            ),
            Text(
              hl('همیشه رایگان: ${PremiumConfig.alwaysFree.map((e) => e.$2).join('، ')}'),
              textAlign: TextAlign.center,
              textDirection: helperDir,
              style: BL.fa(11.5, color: BL.green),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('premium-continue'),
              style: FilledButton.styleFrom(
                backgroundColor: BL.red,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: close,
              child: Text(hl(beta ? 'Continue free (beta)' : 'Not now, keep learning free'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (paid) ...[
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('restore-purchases'),
                    onPressed: () async {
                      final r = await Billing.restore();
                      if (context.mounted) say(r == BillingOutcome.success ? 'Purchases restored.' : 'Could not restore purchases. Please try again later.');
                    },
                    child: Text(hl('Restore purchases · بازیابی خریدها')),
                  ),
                  TextButton(
                    key: const ValueKey('manage-subscription'),
                    onPressed: () => launchUrl(Billing.manageUrl('app.thetoms.newlifeuk'), mode: LaunchMode.externalApplication),
                    child: Text(hl('Manage or cancel in Google Play · مدیریت یا لغو')),
                  ),
                ],
              ),
              Text(
                hl('Payments are handled by Google Play. Cancel any time in Google Play; you keep access until the end of the paid period.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: BL.muted, height: 1.35),
              ),
              Text(
                hl('پرداخت با گوگل‌پلی است. هر وقت بخواهید از گوگل‌پلی لغو کنید؛ تا پایان دورهٔ پرداخت‌شده دسترسی دارید.'),
                textAlign: TextAlign.center,
                textDirection: helperDir,
                style: BL.fa(11, color: BL.muted),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                hl(
                  'Prices are examples only. No payment is taken in this version. When billing goes live: the real price comes from Google Play and is shown before you pay; cancel via the store; UK 14-day cooling-off (digital content may end early if you ask to start immediately and acknowledge that).',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: BL.muted, height: 1.35),
              ),
              Text(
                hl('قیمت‌ها نمونه‌اند. در این نسخه پولی گرفته نمی‌شود. با شروع پرداخت: قیمت واقعی از گوگل‌پلی، لغو از فروشگاه، مهلت ۱۴روزه بریتانیا.'),
                textAlign: TextAlign.center,
                textDirection: helperDir,
                style: BL.fa(11, color: BL.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// UK pre-contract information + express consent to start digital content inside the 14-day
/// cancellation period (Consumer Contracts Regulations 2013, reg. 37). Pay stays disabled until ticked.
class _Consent extends StatefulWidget {
  final String terms, termsFa;
  const _Consent({required this.terms, required this.termsFa});
  @override
  State<_Consent> createState() => _ConsentState();
}

class _ConsentState extends State<_Consent> {
  bool _agree = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('purchase-consent'),
    title: Text(hl('Before you pay')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hl(widget.terms), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 4),
          Text(
            hl(widget.termsFa),
            textDirection: helperDir,
            style: BL.fa(12, color: BL.muted),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            key: const ValueKey('consent-box'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            title: Text(hl('I want access to start now. I understand that once it starts I lose my 14-day right to cancel this purchase.'), style: const TextStyle(fontSize: 13)),
            subtitle: Text(hl('می‌خواهم دسترسی همین حالا شروع شود و می‌دانم با شروع آن، حق انصراف ۱۴ روزه این خرید را از دست می‌دهم.'), textDirection: helperDir, style: BL.fa(11.5)),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(hl('Not now'))),
      FilledButton(key: const ValueKey('consent-pay'), onPressed: _agree ? () => Navigator.pop(context, true) : null, child: Text(hl('Continue to Google Play'))),
    ],
  );
}

class _Plan extends StatelessWidget {
  final String title, fa, price, note;
  final bool best, beta;
  final VoidCallback onTap;
  const _Plan({super.key, required this.title, required this.fa, required this.price, required this.note, this.best = false, required this.beta, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: BL.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: best ? const Color(0xFFC9A04C) : BL.mist, width: best ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not Row: the pill drops to the next line on narrow phones / large text instead of overflowing.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(hl(title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        if (best) const PremiumPill('BEST VALUE'),
                      ],
                    ),
                    Text(
                      hl(fa),
                      textDirection: helperDir,
                      style: BL.fa(11.5, color: BL.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(hl(note), style: const TextStyle(fontSize: 12, color: BL.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // No crossed-out "was" prices: during the beta it's simply free.
                  if (beta)
                    const Text(
                      'FREE in beta',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: BL.green),
                    )
                  else
                    // Store price strings vary in length ("Price in Google Play" when the store is unreachable): wrap, never overflow.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        hl(price),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: BL.ink),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PremiumPill extends StatelessWidget {
  final String text;
  const PremiumPill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFE9C46A), borderRadius: BorderRadius.circular(99)),
    child: Text(
      hl(text),
      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .8, color: BL.ink),
    ),
  );
}
