import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';
import 'theory_data.dart';
import 'theory_screen.dart';

const _good = Color(0xFF2E7D5B);

/// A chapter quiz (feedback after each answer) or the timed mock test (answers can be changed until you
/// finish or time runs out), then the score and a review of every mistake.
class ThyQuizScreen extends ConsumerStatefulWidget {
  /// Chapter id, or null for the mock test.
  final String? chapter;
  const ThyQuizScreen({super.key, this.chapter});

  /// Test hooks: a fixed shuffle, and a shorter mock clock.
  static int? seed;
  static int? mockSeconds;

  @override
  ConsumerState<ThyQuizScreen> createState() => _ThyQuizState();
}

class _ThyQuizState extends ConsumerState<ThyQuizScreen> {
  late final Random rnd = Random(ThyQuizScreen.seed ?? DateTime.now().microsecondsSinceEpoch);
  List<ThyQ>? qs;
  late List<List<int>> orders;
  late List<int?> picked;
  int i = 0;
  bool finished = false;
  XpAward? award;
  Timer? timer;
  int left = 0;
  bool get mock => widget.chapter == null;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _setup(List<ThyChapter> cs) {
    final c = cs.where((x) => x.id == widget.chapter).firstOrNull;
    qs = mock ? Thy.mockSet(cs, rnd) : (c == null ? <ThyQ>[] : Thy.chapterSet(c, rnd));
    orders = [for (final q in qs!) Thy.order(q, rnd)];
    picked = List.filled(qs!.length, null);
    if (mock) {
      left = ThyQuizScreen.mockSeconds ?? Thy.mockMinutes * 60;
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || finished) return;
        setState(() => left--);
        if (left <= 0) _finish();
      });
    }
  }

  int get right => [for (var k = 0; k < qs!.length; k++) picked[k] == 0].where((x) => x).length;

  void _finish() {
    timer?.cancel();
    if (finished) return;
    final ctrl = ref.read(progressProvider.notifier), pct = Thy.pct(right, qs!.length);
    setState(() {
      finished = true;
      award = mock ? ctrl.saveThyMock(pct) : ctrl.saveThyQuiz(widget.chapter!, pct);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final cs = ref.watch(thyProvider).value;
    if (cs == null) return const NavLoading();
    if (qs == null) _setup(cs);
    if (qs!.isEmpty) return thyMissing(context);
    final fa = ctrl.pref('thyFa', 'off') == 'on';
    final pad = MediaQuery.paddingOf(context);
    final title = mock ? 'Mock test' : cs.firstWhere((c) => c.id == widget.chapter).title;
    return Scaffold(
      backgroundColor: thyBg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NavBack(fallback: '/theory'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mock && !finished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: left <= 300 ? BL.red : thyBlue, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                          key: const ValueKey('thy-timer'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                FilterChip(
                  key: const ValueKey('thy-fa'),
                  selected: fa,
                  showCheckmark: false,
                  label: const Text('فارسی'),
                  selectedColor: thyBlue,
                  labelStyle: TextStyle(color: fa ? Colors.white : BL.ink, fontWeight: FontWeight.w800, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => ctrl.setPref('thyFa', fa ? 'off' : 'on'),
                ),
              ],
            ),
            Expanded(child: finished ? _results(fa, pad.bottom) : _question(fa, pad.bottom)),
          ],
        ),
      ),
    );
  }

  Widget _question(bool fa, double bottom) {
    final q = qs![i], answered = picked[i] != null, last = i == qs!.length - 1;
    final reveal = !mock && answered;
    return ListView(
      key: const ValueKey('thy-quiz'),
      padding: EdgeInsets.only(top: 10, bottom: bottom + 24),
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: (i + 1) / qs!.length, minHeight: 7, color: thyBlue, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${i + 1}/${qs!.length}',
              key: const ValueKey('thy-pos'),
              style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          q.q,
          key: const ValueKey('thy-q'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35),
        ),
        if (fa)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              q.fa,
              key: const ValueKey('thy-q-fa'),
              textDirection: TextDirection.rtl,
              style: BL.fa(14, color: BL.muted),
            ),
          ),
        const SizedBox(height: 14),
        for (final o in orders[i])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: reveal ? (o == 0 ? _good : (o == picked[i] ? BL.red.withValues(alpha: .18) : Colors.white)) : (picked[i] == o ? thyBlue : Colors.white),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('thy-opt-$o'),
                borderRadius: BorderRadius.circular(14),
                onTap: reveal ? null : () => setState(() => picked[i] = o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        reveal
                            ? (o == 0 ? Icons.check_circle_rounded : (o == picked[i] ? Icons.cancel_rounded : Icons.circle_outlined))
                            : (picked[i] == o ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                        size: 20,
                        color: (reveal && o == 0) || (!reveal && picked[i] == o) ? Colors.white : BL.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          q.options[o],
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: (reveal && o == 0) || (!reveal && picked[i] == o) ? Colors.white : BL.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (reveal) _why(q, fa, picked[i] == 0),
        const SizedBox(height: 10),
        Row(
          children: [
            if (mock && i > 0) ...[
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('thy-prev'),
                  onPressed: () => setState(() => i--),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                key: ValueKey(last ? 'thy-finish' : 'thy-next'),
                onPressed: !answered && !mock
                    ? null
                    : () {
                        if (last) return _finish();
                        setState(() => i++);
                      },
                style: FilledButton.styleFrom(backgroundColor: thyBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(last ? (mock ? 'Finish test' : 'See my score') : 'Next', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        if (mock) ...[
          const SizedBox(height: 10),
          Text(
            '${picked.where((p) => p != null).length} of ${qs!.length} answered · you can go back and change answers',
            key: const ValueKey('thy-answered'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: BL.muted),
          ),
        ],
      ],
    );
  }

  Widget _why(ThyQ q, bool fa, bool ok) => Container(
    key: const ValueKey('thy-why'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ok ? _good : BL.red, width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ok ? 'Correct!' : 'Not quite. The answer is: ${q.right}',
          style: TextStyle(fontWeight: FontWeight.w900, color: ok ? _good : BL.red),
        ),
        const SizedBox(height: 4),
        Text(q.why, style: const TextStyle(fontSize: 13.5, height: 1.35)),
        if (fa)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              q.whyFa,
              textDirection: TextDirection.rtl,
              style: BL.fa(12.5, color: BL.muted),
            ),
          ),
      ],
    ),
  );

  Widget _results(bool fa, double bottom) {
    final n = qs!.length, pct = Thy.pct(right, n), pass = Thy.passed(right, n);
    final wrong = [
      for (var k = 0; k < n; k++)
        if (picked[k] != 0) k,
    ];
    return ListView(
      key: const ValueKey('thy-result'),
      padding: EdgeInsets.only(top: 14, bottom: bottom + 24),
      children: [
        Icon(pass ? Icons.emoji_events_rounded : Icons.menu_book_rounded, size: 56, color: pass ? BL.gold : thyBlue),
        const SizedBox(height: 6),
        Text('$right / $n · $pct%', key: const ValueKey('thy-score'), textAlign: TextAlign.center, style: BL.display(28)),
        Text(
          pass ? (mock ? 'Pass! You reached the pass mark of 43 out of 50.' : 'Great work!') : 'Not yet: aim for ${(n * Thy.passMark / Thy.mockQuestions).ceil()} of $n (the real test needs 43 of 50).',
          key: const ValueKey('thy-verdict'),
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, color: pass ? _good : BL.red),
        ),
        Text(
          pass ? 'آفرین! به نمرهٔ قبولی رسیدی.' : 'هنوز نه؛ در آزمون واقعی باید ۴۳ از ۵۰ درست باشد.',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: BL.fa(13, color: BL.muted),
        ),
        if (award != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '+${award!.xp} XP',
              key: const ValueKey('thy-xp'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, color: BL.gold, fontSize: 16),
            ),
          ),
        if (mock)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Practice only: this is not the official test.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: BL.muted),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('thy-done'),
                onPressed: () => context.go('/theory'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Back to prep'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const ValueKey('thy-retry'),
                onPressed: () => context.go('${mock ? '/theory/mock' : '/theory/${widget.chapter}/quiz'}?r=${DateTime.now().millisecondsSinceEpoch}'),
                style: FilledButton.styleFrom(backgroundColor: thyBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (wrong.isEmpty)
          const Text(
            'No mistakes to review. Brilliant!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          )
        else ...[
          Text(
            'Review your mistakes (${wrong.length})',
            key: const ValueKey('thy-review'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final k in wrong)
            Container(
              key: ValueKey('thy-review-$k'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(qs![k].q, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (fa)
                    Text(
                      qs![k].fa,
                      textDirection: TextDirection.rtl,
                      style: BL.fa(12.5, color: BL.muted),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    picked[k] == null ? 'Your answer: (none)' : 'Your answer: ${qs![k].options[picked[k]!]}',
                    style: const TextStyle(color: BL.red, fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  Text(
                    'Right answer: ${qs![k].right}',
                    style: const TextStyle(color: _good, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(qs![k].why, style: const TextStyle(fontSize: 13, height: 1.35)),
                  if (fa)
                    Text(
                      qs![k].whyFa,
                      textDirection: TextDirection.rtl,
                      style: BL.fa(12.5, color: BL.muted),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
