import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';

/// Premium / paywall. Display-only: no payment is ever taken. During the beta everything is free.
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
    void tapPlan(String what) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(beta ? 'Free during the beta. No payment is taken. Enjoy!' : '$what: payments are coming soon.'),
        ));
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
          Text('The Toms Premium', textAlign: TextAlign.center, style: BL.display(28)),
          Text('اشتراک ویژهٔ تامز', textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: BL.fa(14, color: BL.muted)),
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('beta-banner'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: beta ? BL.green : BL.navy, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text(beta ? 'Beta: everything is free' : 'Coming soon', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(beta ? 'Premium and every Career Pack are open while we test. No card, no payment.' : 'Payments are not switched on yet. Your first lesson in every pack stays free.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
              const SizedBox(height: 4),
              Text(beta ? 'در دورهٔ آزمایشی همه چیز رایگان است. بدون کارت و بدون پرداخت.' : 'پرداخت هنوز فعال نشده است. درس اول هر بسته رایگان است.',
                  textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white70)),
            ]),
          ),
          if (pk != null && !beta) ...[
            const SizedBox(height: 14),
            Text('You tried the free first lesson of ${pk.title}. Unlock the rest with Premium or buy the pack once.',
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
                  Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(p.$2, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
                ])),
              ]),
            ),
          const SizedBox(height: 10),
          _Plan(key: const ValueKey('plan-yearly'), title: 'Yearly', fa: 'سالانه', price: '${PremiumConfig.price(PremiumConfig.yearly)} / year',
              note: 'Save ${PremiumConfig.yearlySaving}% · ${PremiumConfig.trialDays}-day free trial', best: true, beta: beta, onTap: () => tapPlan('Yearly')),
          _Plan(key: const ValueKey('plan-monthly'), title: 'Monthly', fa: 'ماهانه', price: '${PremiumConfig.price(PremiumConfig.monthly)} / month',
              note: 'Cancel any time', beta: beta, onTap: () => tapPlan('Monthly')),
          _Plan(key: const ValueKey('plan-pack'), title: pk == null ? 'One Career Pack' : pk.title, fa: 'یک بستهٔ شغلی، یک بار پرداخت', price: '${PremiumConfig.price(PremiumConfig.careerPack)} once',
              note: 'Yours for good, no subscription', beta: beta, onTap: () => tapPlan('Career Pack')),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('premium-continue'),
            style: FilledButton.styleFrom(backgroundColor: BL.red, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => pk != null ? context.go('/pack/${pk.id}') : (context.canPop() ? context.pop() : context.go('/')),
            child: Text(beta ? 'Continue free (beta)' : 'Maybe later', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          const Text('Prices are examples and may change. No payment is taken in this version.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: BL.muted)),
        ],
      ),
    );
  }
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
                  Row(children: [
                    Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    if (best) ...[const SizedBox(width: 8), const PremiumPill('BEST VALUE')],
                  ]),
                  Text(fa, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
                  const SizedBox(height: 2),
                  Text(note, style: const TextStyle(fontSize: 12, color: BL.muted)),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // No crossed-out "was" prices: during the beta it's simply free.
                  if (beta)
                    const Text('FREE in beta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: BL.green))
                  else
                    Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: BL.ink)),
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
        child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .8, color: BL.ink)),
      );
}

