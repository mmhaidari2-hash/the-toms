import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/bottom_nav.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/engine/leitner.dart';
import '../../core/models/user_progress.dart';
import '../../core/platform/voice.dart';

/// Today's Leitner review: 5 boxes (due after 0/1/3/7/14 days). Right moves a card up, wrong back to box 1.
class LeitnerScreen extends ConsumerStatefulWidget {
  const LeitnerScreen({super.key});
  @override
  ConsumerState<LeitnerScreen> createState() => _LeitnerScreenState();
}

class _LeitnerScreenState extends ConsumerState<LeitnerScreen> {
  bool shown = false;
  int right = 0, done = 0;

  void _answer(LeitnerCard c, bool ok) {
    ref.read(progressProvider.notifier).reviewLeitner(c.word, ok);
    setState(() {
      shown = false;
      done++;
      if (ok) right++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    final now = DateTime.now();
    final due = Leitner.due(p.leitnerBox.values, now);
    final counts = List.generate(5, (i) => p.leitnerBox.values.where((w) => w.box == i + 1).length);
    final c = due.isEmpty ? null : due.first;
    return Scaffold(
      backgroundColor: BL.cream,
      bottomNavigationBar: const TomsBottomNav(current: HomeTab.leitner),
      appBar: AppBar(
        backgroundColor: BL.cream,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/')),
        title: Text('Leitner box', style: BL.display(20)),
      ),
      body: ListView(key: const ValueKey('leitner-list'), padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Text(hl('جعبهٔ لایتنر · ${due.length} واژه برای امروز'), textDirection: helperDir, style: BL.fa(13)),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < 5; i++)
            Expanded(
              child: Container(
                key: ValueKey('leitner-box-${i + 1}'),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(BL.mist, BL.green, (i + 1) / 6)!.withValues(alpha: .55), Color.lerp(BL.mist, BL.green, (i + 1) / 5)!]),
                  border: Border.all(color: Colors.white.withValues(alpha: .7)),
                ),
                child: Column(children: [
                  Text(hl('${counts[i]}'), style: TextStyle(fontWeight: FontWeight.w800, color: i > 1 ? Colors.white : BL.ink)),
                  Text(hl('Box ${i + 1}'), style: TextStyle(fontSize: 10.5, color: i > 1 ? Colors.white70 : BL.muted)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        const Text('Box 1 every day · 2 after a day · 3 after 3 days · 4 after a week · 5 after a fortnight', style: TextStyle(fontSize: 11, color: BL.muted)),
        const SizedBox(height: 16),
        if (p.leitnerBox.isEmpty)
          _note('Your Leitner box is empty. In a conversation or role-play, press and hold any word in a line to add it here.', 'جعبهٔ لایتنر شما خالی است. در گفت‌وگو یا نقش‌آفرینی، روی هر واژه از یک جمله انگشت را نگه دارید تا به اینجا اضافه شود.')
        else if (c == null)
          _note(done > 0 ? 'All done for today: $right of $done right. Come back tomorrow.' : 'Nothing to review right now. Come back tomorrow.', 'برای امروز تمام شد.', key: 'leitner-done')
        else
          _card(c, due.length),
        if (p.leitnerBox.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Your words', style: BL.display(16)),
          const SizedBox(height: 6),
          for (final w in (p.leitnerBox.values.toList()..sort((a, b) => a.box.compareTo(b.box))))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(hl(w.word), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: w.fa.isEmpty ? null : Text(hl(w.fa), textDirection: helperDir, style: BL.fa(12.5)),
              trailing: Text(hl('Box ${w.box}'), style: const TextStyle(color: BL.muted, fontSize: 12)),
              onLongPress: () => ref.read(progressProvider.notifier).removeFromLeitner(w.word),
            ),
        ],
      ]),
    );
  }

  Widget _note(String en, String fa, {String? key}) => Container(
        key: key == null ? null : ValueKey(key),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: BL.shadow()),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hl(en), style: const TextStyle(height: 1.35)),
          const SizedBox(height: 6),
          Text(hl(fa), textDirection: helperDir, style: BL.fa(12.5)),
        ]),
      );

  Widget _card(LeitnerCard c, int left) => Container(
        key: const ValueKey('leitner-card'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: BL.shadow(.1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hl('$left to go · box ${c.box}'), style: const TextStyle(color: BL.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(hl(c.word), key: const ValueKey('leitner-front'), style: BL.display(26))),
            if (Voice.has('narrator', c.word)) IconButton.filledTonal(onPressed: () => Voice.say('narrator', c.word), icon: const Icon(Icons.volume_up_rounded)),
          ]),
          const SizedBox(height: 12),
          if (!shown)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(key: const ValueKey('leitner-show'), onPressed: () => setState(() => shown = true), child: Text(hl('Show meaning · نمایش معنی'))),
            )
          else ...[
            Text(hl(c.fa.isEmpty ? '—' : c.fa), key: const ValueKey('leitner-back'), textDirection: helperDir, style: BL.fa(18, color: BL.ink, w: FontWeight.w700)),
            if (c.ex.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(hl('“${c.ex}”'), style: const TextStyle(fontStyle: FontStyle.italic, height: 1.35))),
                if (Voice.has(c.exSp, c.ex)) IconButton(onPressed: () => Voice.say(c.exSp, c.ex), icon: const Icon(Icons.play_circle_rounded, color: BL.navy)),
              ]),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(key: const ValueKey('leitner-no'), onPressed: () => _answer(c, false), icon: const Icon(Icons.replay_rounded), label: const Text('Not yet'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(key: const ValueKey('leitner-yes'), style: FilledButton.styleFrom(backgroundColor: BL.green), onPressed: () => _answer(c, true), icon: const Icon(Icons.check_rounded), label: const Text('I knew it'))),
            ]),
          ],
        ]),
      );
}
