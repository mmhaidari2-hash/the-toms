import 'dart:math';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import 'grammar_data.dart';
import 'school_screen.dart';
import 'topic_screen.dart';

const reviewSize = 12;

/// Practice questions from the passed topics of a class, mixed round-robin so every topic appears.
List<GItem> reviewItems(List<GTopic> passed, int seed) {
  final r = Random(passed.length * 104729 + seed);
  final pools = [for (final t in passed) [...t.practice]..shuffle(r)];
  final out = <GItem>[];
  for (var round = 0; out.length < reviewSize && pools.any((p) => p.length > round); round++) {
    for (final p in [...pools]..shuffle(r)) {
      if (round < p.length && out.length < reviewSize) out.add(p[round]);
    }
  }
  return out;
}

/// Mixed review (Q43): spaced, interleaved practice across the topics already passed in a class.
/// Not graded and not saved as a score; it gives a little XP and shows the explanation after each answer.
class ClassReviewScreen extends ConsumerStatefulWidget {
  final String code;
  const ClassReviewScreen({super.key, required this.code});
  @override
  ConsumerState<ClassReviewScreen> createState() => _ClassReviewScreenState();
}

class _ClassReviewScreenState extends ConsumerState<ClassReviewScreen> {
  int round = 0, i = 0, right = 0;
  XpAward? award;
  List<GItem>? items;

  void _start(List<GTopic> passed) => setState(() {
        round++;
        items = reviewItems(passed, round + DateTime.now().millisecondsSinceEpoch ~/ 3600000);
        i = 0;
        right = 0;
        award = null;
      });

  void _next() {
    if (i + 1 < items!.length) return setState(() => i++);
    final pct = (right * 100 / max(items!.length, 1)).round();
    setState(() => award = ref.read(progressProvider.notifier).awardXp(Motivation.practiceXp(pct)));
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(grammarProvider).value;
    final content = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    if (topics == null || content == null) return const NavLoading();
    final ctrl = ref.read(progressProvider.notifier);
    final g = GrammarGate(ctrl, content, topics, unlockAll: ref.read(progressProvider).gatesOpen);
    final c = Grammar.classes.firstWhere((x) => x.code == widget.code, orElse: () => Grammar.classes.first);
    final passed = g.of(c.code).where((t) => ctrl.grammarPassed(t.id)).toList();
    final pad = MediaQuery.paddingOf(context);

    if (passed.length < 2) {
      return Scaffold(
        backgroundColor: BL.cream,
        body: ListView(padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, 32), children: [
          Row(children: [NavBack(fallback: '/school/${c.code}')]),
          const SizedBox(height: 20),
          Text(hl('Pass two topics first'), key: const ValueKey('review-locked'), style: BL.display(22)),
          Text(hl('مرور ترکیبی بعد از قبولی در دست‌کم دو درس این کلاس باز می‌شود.'), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
        ]),
      );
    }
    if (items == null) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && items == null) _start(passed); });
    final list = items;
    if (list == null || list.isEmpty) return const NavLoading();

    if (award != null) {
      final pct = (right * 100 / max(list.length, 1)).round();
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('review-celebrate'),
          award: award!,
          pass: pct >= 60,
          checkpoint: false,
          right: right,
          total: list.length,
          title: 'Mixed review done',
          titleFa: 'مرور ترکیبی تمام شد. ${passed.length} درس با هم مرور شد.',
          onRetry: () => _start(passed),
          onContinue: () => Navigator.of(context).maybePop(),
          autoNext: 0,
        ),
      );
    }

    return Scaffold(
      backgroundColor: BL.cream,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 6),
          child: Row(children: [
            NavBack(fallback: '/school/${c.code}'),
            const SizedBox(width: 8),
            Expanded(child: Text(hl('Class ${c.code} mixed review · ${i + 1}/${list.length}'), key: const ValueKey('review-stage'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (i + 1) / list.length, minHeight: 6, color: BL.green, backgroundColor: BL.mist)),
        ),
        Expanded(child: ExerciseView(key: ValueKey('review-$round-$i'), item: list[i], seed: round * 17 + i, test: false, onAnswered: (ok) { if (ok) right++; }, onNext: _next)),
      ]),
    );
  }
}
