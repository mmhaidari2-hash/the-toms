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

/// Premium / paywall. Beta: display-only, everything free. Paid build: Google Play Billing via RevenueCat
/// ([Billing]), with the UK pre-contract information and 14-day cancellation consent shown before paying.
class PremiumScreen extends ConsumerWidget {
  final String? pack;
  const PremiumScreen({super.key, this.pack});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final pad = MediaQuery.paddingOf(context);
    final beta = PremiumConfig.betaFree;
    final pk = pack == null ? null : c?.course.pack(pack!);
    final paid = Entitlements.paidBuild;
    void say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(hl(m))));
    Future<void> tapPlan(String what) async {
      if (!paid) return say(beta ? 'Free during the beta. No payment is taken. Enjoy!' : '$what: payments are coming soon.');
      final (productId, terms, termsFa) = switch (what) {
        'Yearly' => (Entitlements.premiumYearly,
            '${PremiumConfig.price(PremiumConfig.yearly)} a year after a ${PremiumConfig.trialDays}-day free trial (founding members: first year ${PremiumConfig.price(PremiumConfig.foundingYear)}). Renews automatically every year until you cancel in Google Play. Cancel before the trial ends and you pay nothing.',
            'سالانه ${PremiumConfig.price(PremiumConfig.yearly)} بعد از ${PremiumConfig.trialDays} روز رایگان. هر سال خودکار تمدید می‌شود تا در گوگل‌پلی لغو کنید. اگر قبل از پایان دورهٔ رایگان لغو کنید، چیزی پرداخت نمی‌کنید.'),
        'Monthly' => (Entitlements.premiumMonthly,
            '${PremiumConfig.price(PremiumConfig.monthly)} a month. Renews automatically every month until you cancel in Google Play.',
            'ماهانه ${PremiumConfig.price(PremiumConfig.monthly)}. هر ماه خودکار تمدید می‌شود تا در گوگل‌پلی لغو کنید.'),
        _ => ('${Entitlements.careerPackPrefix}${pk?.id ?? 'nursery'}',
            '${PremiumConfig.price(PremiumConfig.careerPack)} once. No subscription.', 'یک بار ${PremiumConfig.price(PremiumConfig.careerPack)}. بدون اشتراک.'),
      };
      final ok = await showDialog<bool>(context: context, builder: (_) => _Consent(terms: terms, termsFa: termsFa));
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
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), Spacer()]),
          const SizedBox(height: 8),
          Center(child: Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFC9A04C)])),
            child: const Icon(Icons.workspace_premium_rounded, size: 36, color: BL.ink),
          )),
          const SizedBox(height: 12),
          Text('New Life UK Premium', textAlign: TextAlign.center, style: BL.display(28)),
          Text(hl('اشتراک ویژهٔ New Life UK'), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('beta-banner'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: beta ? BL.green : BL.navy, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text(hl(beta ? 'Beta: everything is free' : 'Coming soon'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(hl(beta ? 'Premium and every Career Pack are open while we test. No card, no payment.' : 'Payments are not switched on yet. Your first lesson in every pack stays free.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
              const SizedBox(height: 4),
              Text(hl(beta ? 'در دورهٔ آزمایشی همه چیز رایگان است. بدون کارت و بدون پرداخت.' : 'پرداخت هنوز فعال نشده است. درس اول هر بسته رایگان است.'),
                  textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(12.5, color: Colors.white70)),
            ]),
          ),
          if (pk != null && !beta) ...[
            const SizedBox(height: 14),
            Text(hl('You tried the free first lesson of ${pk.title}. Unlock the rest with Premium or buy the pack once.'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: BL.ink, height: 1.3)),
          ],
          const SizedBox(height: 18),
          for (final p in PremiumConfig.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: BL.green, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hl(p.$1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(hl(p.$2), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
                ])),
              ]),
            ),
          const SizedBox(height: 10),
          _Plan(key: const ValueKey('plan-yearly'), title: 'Yearly', fa: 'سالانه', price: '${PremiumConfig.price(PremiumConfig.yearly)} / year',
              note: 'Save ${PremiumConfig.yearlySaving}% · ${PremiumConfig.trialDays}-day free trial · Founding members: first year ${PremiumConfig.price(PremiumConfig.foundingYear)} (first ${PremiumConfig.foundingSeats})', best: true, beta: beta, onTap: () => tapPlan('Yearly')),
          _Plan(key: const ValueKey('plan-monthly'), title: 'Monthly', fa: 'ماهانه', price: '${PremiumConfig.price(PremiumConfig.monthly)} / month',
              note: 'Cancel any time', beta: beta, onTap: () => tapPlan('Monthly')),
          _Plan(key: const ValueKey('plan-pack'), title: pk == null ? 'One Career Pack' : pk.title, fa: 'یک بستهٔ شغلی، یک بار پرداخت', price: '${PremiumConfig.price(PremiumConfig.careerPack)} once',
              note: 'Yours for good, no subscription', beta: beta, onTap: () => tapPlan('Career Pack')),
          Text(hl('Always free: ${PremiumConfig.alwaysFree.map((e) => e.$1).join(' · ')}'), key: const ValueKey('always-free'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: BL.green)),
          Text(hl('همیشه رایگان: ${PremiumConfig.alwaysFree.map((e) => e.$2).join('، ')}'), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(11.5, color: BL.green)),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('premium-continue'),
            style: FilledButton.styleFrom(backgroundColor: BL.red, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => pk != null ? context.go('/pack/${pk.id}') : (context.canPop() ? context.pop() : context.go('/')),
            child: Text(hl(beta ? 'Continue free (beta)' : 'Maybe later'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          if (paid) ...[
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, children: [
              TextButton(
                key: const ValueKey('restore-purchases'),
                onPressed: () async {
                  final r = await Billing.restore();
                  if (context.mounted) say(r == BillingOutcome.success ? 'Purchases restored.' : 'Could not restore purchases. Please try again later.');
                },
                child: Text(hl('Restore purchases')),
              ),
              TextButton(
                key: const ValueKey('manage-subscription'),
                onPressed: () => launchUrl(Billing.manageUrl('app.thetoms.newlifeuk'), mode: LaunchMode.externalApplication),
                child: Text(hl('Manage or cancel')),
              ),
            ]),
            Text(hl('Payments are handled by Google Play. Cancel any time in Google Play; you keep access until the end of the paid period.'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: BL.muted, height: 1.35)),
            Text(hl('پرداخت با گوگل‌پلی است. هر وقت بخواهید از گوگل‌پلی لغو کنید؛ تا پایان دورهٔ پرداخت‌شده دسترسی دارید.'),
                textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(11, color: BL.muted)),
          ] else ...[
          const SizedBox(height: 10),
          Text(hl('Prices are examples only. No payment is taken in this version. When billing goes live: clear price & period before pay; cancel via the store; UK 14-day cooling-off (digital content may end early if you ask to start immediately and acknowledge that).'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: BL.muted, height: 1.35)),
          Text(hl('قیمت‌ها نمونه‌اند. در این نسخه پولی گرفته نمی‌شود. با شروع پرداخت: قیمت روشن، لغو از فروشگاه، مهلت ۱۴روزه بریتانیا.'), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(11, color: BL.muted)),
          ],
        ],
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hl(widget.terms), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
            const SizedBox(height: 4),
            Text(hl(widget.termsFa), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
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
          ]),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: best ? const Color(0xFFC9A04C) : BL.mist, width: best ? 2 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Wrap, not Row: the pill drops to the next line on narrow phones / large text instead of overflowing.
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(hl(title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (best) const PremiumPill('BEST VALUE'),
                  ]),
                  Text(hl(fa), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
                  const SizedBox(height: 2),
                  Text(hl(note), style: const TextStyle(fontSize: 12, color: BL.muted)),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // No crossed-out "was" prices: during the beta it's simply free.
                  if (beta)
                    const Text('FREE in beta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: BL.green))
                  else
                    Text(hl(price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: BL.ink)),
                ]),
              ]),
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
        child: Text(hl(text), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .8, color: BL.ink)),
      );
}

