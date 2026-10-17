import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/widgets.dart';
import '../shared/nav.dart';

class _Page {
  final String who, en, fa;
  final Widget Function() demo;
  const _Page(this.who, this.en, this.fa, this.demo);
}

Widget _chip(String t, {bool gold = false, IconData? icon}) => Container(
  margin: const EdgeInsets.only(right: 6, bottom: 6),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  decoration: BoxDecoration(color: gold ? BL.gold : Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    if (icon != null) Padding(padding: const EdgeInsets.only(right: 5), child: Icon(icon, size: 15, color: gold ? BL.ink : Colors.white)),
    Text(t, style: TextStyle(color: gold ? BL.ink : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
  ]),
);

/// 4 short pages, guided by Nicola and Tom: tap people/objects, reply, X-Ray, role swap.
class HowToPages extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const HowToPages({super.key, required this.onDone});
  @override
  ConsumerState<HowToPages> createState() => _HowToState();
}

class _HowToState extends ConsumerState<HowToPages> {
  final _pc = PageController();
  int _i = 0;

  late final _pages = <_Page>[
    _Page('tom', "Hiya, I'm Tom! Tap anyone in a painting to hear them. Tap things to learn the word.", 'سلام، من تامم! روی هر کسی تو نقاشی بزن تا صداش را بشنوی. روی چیزها بزن تا کلمه‌اش را یاد بگیری.', () => Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/places/kitchen.webp', height: 170, width: double.infinity, fit: BoxFit.cover)),
      Positioned(left: 112, top: 6, child: Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BL.gold, width: 3)))),
      Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xEE1E150F), borderRadius: BorderRadius.circular(14), border: Border.all(color: BL.gold)), child: const Text('✦ teapot  🔊', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
    ])),
    _Page('nicola', 'Your turn to talk! Tap a reply, type it, or press the mic and say it.', 'نوبت توئه! یه جواب را بزن، تایپش کن یا میکروفون را بزن و بگو.', () => Wrap(children: [
      _chip('Yes, please! White, no sugar.'), _chip("Ooh, I'd love one!"), _chip('Say it', icon: Icons.mic_rounded, gold: true),
    ])),
    _Page('tom', "Stuck? X-Ray shows what we Brits really mean — and how it sounds when we talk fast.", 'گیر کردی؟ ایکس‌ری نشون می‌ده بریتانیایی‌ها واقعاً منظورشون چیه و تند حرف زدن چطور شنیده می‌شه.', () => Wrap(children: [
      _chip('X-Ray', icon: Icons.blur_on_rounded, gold: true), _chip('"Fancy a cuppa?" = Do you want tea?'), _chip('slow', icon: Icons.slow_motion_video_rounded),
    ])),
    _Page('nicola', "Swap roles! Play as me, Mum or Ryan — you say our lines. It's well fun!", 'نقش‌ها را عوض کن! جای من، مامان یا رایان بازی کن و جمله‌های ما را بگو.', () => Consumer(builder: (context, ref, _) {
      final c = ref.watch(contentProvider).value;
      return Row(children: [
        if (c != null) for (final id in ['nicola', 'leslie', 'ryan', 'tom']) Padding(padding: const EdgeInsets.only(right: 10), child: Column(children: [Avatar(c.character(id), size: 54), const SizedBox(height: 4), Text(c.character(id).name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))])),
      ]);
    })),
  ];

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contentProvider).value;
    final last = _i == _pages.length - 1;
    return Column(children: [
      Expanded(
        child: PageView.builder(
          controller: _pc,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final pg = _pages[i];
            return ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), children: [
              Text('How it works  ${i + 1}/${_pages.length}', style: const TextStyle(color: BL.gold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c != null) Avatar(c.character(pg.who), size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: BL.cream, borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pg.who == 'tom' ? 'Tom' : 'Nicola', style: const TextStyle(color: BL.red, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(pg.en, style: BL.display(17)),
                      const SizedBox(height: 4),
                      SizedBox(width: double.infinity, child: Text(pg.fa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted))),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              pg.demo(),
            ]);
          },
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var k = 0; k < _pages.length; k++) AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.all(3), width: k == _i ? 18 : 7, height: 7, decoration: BoxDecoration(color: k == _i ? BL.gold : Colors.white24, borderRadius: BorderRadius.circular(9))),
      ]),
      Padding(
        padding: EdgeInsets.fromLTRB(24, 10, 24, 16 + MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          TextButton(key: const ValueKey('howto-skip'), onPressed: widget.onDone, child: const Text('Skip', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700))),
          const Spacer(),
          FilledButton(
            key: const ValueKey('howto-next'),
            style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
            onPressed: last ? widget.onDone : () => _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
            child: Text(last ? 'Got it!' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
      ),
    ]);
  }
}

/// Replay from the menu.
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF22355C), BL.ink])),
      child: SafeArea(bottom: false, child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(10, 6, 10, 0), child: Align(alignment: Alignment.centerLeft, child: NavButtons(light: true))),
        Expanded(child: HowToPages(onDone: () => goBack(context))),
      ])),
    ),
  );
}
