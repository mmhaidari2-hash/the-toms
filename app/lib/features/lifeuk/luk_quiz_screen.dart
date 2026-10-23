import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';
import 'lifeuk_data.dart';
import 'lifeuk_screen.dart';

const _good = Color(0xFF2E7D5B);

/// A chapter quiz (feedback after each answer) or the timed mock test (answers can be changed until you
/// finish or time runs out), then the score and a review of every mistake.
class LukQuizScreen extends ConsumerStatefulWidget {
  /// Chapter id, or null for the mock test.
  final String? chapter;
  const LukQuizScreen({super.key, this.chapter});

  /// Test hooks: a fixed shuffle, and a shorter mock clock.
  static int? seed;
  static int? mockSeconds;

  @override
  ConsumerState<LukQuizScreen> createState() => _LukQuizState();
}

class _LukQuizState extends ConsumerState<LukQuizScreen> {
  late final Random rnd = Random(LukQuizScreen.seed ?? DateTime.now().microsecondsSinceEpoch);
  List<LukQ>? qs;
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

  void _setup(List<LukChapter> cs) {
    final c = cs.where((x) => x.id == widget.chapter).firstOrNull;
    qs = mock ? Luk.mockSet(cs, rnd) : (c == null ? <LukQ>[] : Luk.chapterSet(c, rnd));
    orders = [for (final q in qs!) Luk.order(q, rnd)];
    picked = List.filled(qs!.length, null);
    if (mock) {
      left = LukQuizScreen.mockSeconds ?? Luk.mockMinutes * 60;
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
    final ctrl = ref.read(progressProvider.notifier), pct = Luk.pct(right, qs!.length);
    setState(() {
      finished = true;
      award = mock ? ctrl.saveLukMock(pct) : ctrl.saveLukQuiz(widget.chapter!, pct);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final cs = ref.watch(lukProvider).value;
    if (cs == null) return const NavLoading();
    if (qs == null) _setup(cs);
    if (qs!.isEmpty) return lukMissing(context);
    final fa = ctrl.pref('lukFa', 'off') == 'on';
    final pad = MediaQuery.paddingOf(context);
    final title = mock ? 'Mock test' : cs.firstWhere((c) => c.id == widget.chapter).title;
    return Scaffold(
      backgroundColor: lukBg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NavBack(fallback: '/lifeuk'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hl(title),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mock && !finished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: left <= 300 ? BL.red : lukBlue, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          hl('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}'),
                          key: const ValueKey('luk-timer'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                FilterChip(
                  key: const ValueKey('luk-fa'),
                  selected: fa,
                  showCheckmark: false,
                  label: Text(hl('فارسی')),
                  selectedColor: lukBlue,
                  labelStyle: TextStyle(color: fa ? Colors.white : BL.ink, fontWeight: FontWeight.w800, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => ctrl.setPref('lukFa', fa ? 'off' : 'on'),
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
      key: const ValueKey('luk-quiz'),
      padding: EdgeInsets.only(top: 10, bottom: bottom + 24),
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: (i + 1) / qs!.length, minHeight: 7, color: lukBlue, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hl('${i + 1}/${qs!.length}'),
              key: const ValueKey('luk-pos'),
              style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          hl(q.q),
          key: const ValueKey('luk-q'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35),
        ),
        if (fa)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hl(q.fa),
              key: const ValueKey('luk-q-fa'),
              textDirection: helperDir,
              style: BL.fa(14, color: BL.muted),
            ),
          ),
        const SizedBox(height: 14),
        for (final o in orders[i])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: reveal ? (o == 0 ? _good : (o == picked[i] ? BL.red.withValues(alpha: .18) : Colors.white)) : (picked[i] == o ? lukBlue : Colors.white),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('luk-opt-$o'),
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
                          hl(q.options[o]),
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
                  key: const ValueKey('luk-prev'),
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
                key: ValueKey(last ? 'luk-finish' : 'luk-next'),
                onPressed: !answered && !mock
                    ? null
                    : () {
                        if (last) return _finish();
                        setState(() => i++);
                      },
                style: FilledButton.styleFrom(backgroundColor: lukBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(hl(last ? (mock ? 'Finish test' : 'See my score') : 'Next'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        if (mock) ...[
          const SizedBox(height: 10),
          Text(
            hl('${picked.where((p) => p != null).length} of ${qs!.length} answered · you can go back and change answers'),
            key: const ValueKey('luk-answered'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: BL.muted),
          ),
        ],
      ],
    );
  }

  Widget _why(LukQ q, bool fa, bool ok) => Container(
    key: const ValueKey('luk-why'),
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
          hl(ok ? 'Correct!' : 'Not quite. The answer is: ${q.right}'),
          style: TextStyle(fontWeight: FontWeight.w900, color: ok ? _good : BL.red),
        ),
        const SizedBox(height: 4),
        Text(hl(q.why), style: const TextStyle(fontSize: 13.5, height: 1.35)),
        if (fa)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              hl(q.whyFa),
              textDirection: helperDir,
              style: BL.fa(12.5, color: BL.muted),
            ),
          ),
      ],
    ),
  );

  Widget _results(bool fa, double bottom) {
    final n = qs!.length, pct = Luk.pct(right, n), pass = Luk.passed(right, n);
    final wrong = [
      for (var k = 0; k < n; k++)
        if (picked[k] != 0) k,
    ];
    return ListView(
      key: const ValueKey('luk-result'),
      padding: EdgeInsets.only(top: 14, bottom: bottom + 24),
      children: [
        Icon(pass ? Icons.emoji_events_rounded : Icons.menu_book_rounded, size: 56, color: pass ? BL.gold : lukBlue),
        const SizedBox(height: 6),
        Text(hl('$right / $n · $pct%'), key: const ValueKey('luk-score'), textAlign: TextAlign.center, style: BL.display(28)),
        Text(
          hl(pass ? (mock ? 'Pass! You reached the 75% pass mark.' : 'Great work!') : 'Not yet: the pass mark is 75% (${(n * .75).ceil()} of $n).'),
          key: const ValueKey('luk-verdict'),
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, color: pass ? _good : BL.red),
        ),
        Text(
          hl(pass ? 'آفرین! به نمرهٔ قبولی رسیدی.' : 'هنوز نه؛ نمرهٔ قبولی ۷۵٪ است.'),
          textAlign: TextAlign.center,
          textDirection: helperDir,
          style: BL.fa(13, color: BL.muted),
        ),
        if (award != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hl('+${award!.xp} XP'),
              key: const ValueKey('luk-xp'),
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
                key: const ValueKey('luk-done'),
                onPressed: () => context.go('/lifeuk'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Back to prep'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const ValueKey('luk-retry'),
                onPressed: () => context.go('${mock ? '/lifeuk/mock' : '/lifeuk/${widget.chapter}/quiz'}?r=${DateTime.now().millisecondsSinceEpoch}'),
                style: FilledButton.styleFrom(backgroundColor: lukBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
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
            hl('Review your mistakes (${wrong.length})'),
            key: const ValueKey('luk-review'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final k in wrong)
            Container(
              key: ValueKey('luk-review-$k'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(hl(qs![k].q), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (fa)
                    Text(
                      hl(qs![k].fa),
                      textDirection: helperDir,
                      style: BL.fa(12.5, color: BL.muted),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    hl(picked[k] == null ? 'Your answer: (none)' : 'Your answer: ${qs![k].options[picked[k]!]}'),
                    style: const TextStyle(color: BL.red, fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  Text(
                    hl('Right answer: ${qs![k].right}'),
                    style: const TextStyle(color: _good, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(hl(qs![k].why), style: const TextStyle(fontSize: 13, height: 1.35)),
                  if (fa)
                    Text(
                      hl(qs![k].whyFa),
                      textDirection: helperDir,
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
