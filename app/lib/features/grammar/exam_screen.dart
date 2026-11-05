import 'dart:math';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../motivation/motivation_widgets.dart';
import '../premium/certificate_screen.dart';
import '../shared/nav.dart';
import 'grammar_data.dart';
import 'school_screen.dart';
import 'topic_screen.dart';

/// Every mini-test question of a class, mixed so each topic appears; the first [Grammar.examSize] are used.
List<GItem> examItems(List<GTopic> classTopics, int attempt) {
  final r = Random(classTopics.length * 7919 + attempt);
  final pools = [for (final t in classTopics) [...t.test]..shuffle(r)];
  final out = <GItem>[];
  for (var round = 0; out.length < Grammar.examSize && pools.any((p) => p.length > round); round++) {
    for (final p in [...pools]..shuffle(r)) {
      if (round < p.length && out.length < Grammar.examSize) out.add(p[round]);
    }
  }
  return out;
}

/// Class final exam (Q43): opens when every topic of the class is passed; 80% earns the class certificate.
class ClassExamScreen extends ConsumerStatefulWidget {
  final String code;
  const ClassExamScreen({super.key, required this.code});
  @override
  ConsumerState<ClassExamScreen> createState() => _ClassExamScreenState();
}

class _ClassExamScreenState extends ConsumerState<ClassExamScreen> {
  int attempt = 0, i = 0, right = 0;
  bool started = false;
  XpAward? award;
  List<GItem> items = const [];

  void _start(List<GTopic> ts) => setState(() {
        attempt++;
        items = examItems(ts, attempt + DateTime.now().millisecondsSinceEpoch ~/ 86400000);
        i = 0;
        right = 0;
        award = null;
        started = true;
      });

  void _next() {
    if (i + 1 < items.length) return setState(() => i++);
    final pct = (right * 100 / max(items.length, 1)).round();
    final a = ref.read(progressProvider.notifier).saveGrammarExam(widget.code, pct, passMark: Grammar.examPass);
    setState(() => award = a);
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
    final ts = g.of(c.code);
    final pad = MediaQuery.paddingOf(context);
    final ready = g.classDone(c.code) || g.unlockAll;

    if (award != null) {
      final pct = (right * 100 / max(items.length, 1)).round(), pass = pct >= Grammar.examPass;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('exam-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: true,
          right: right,
          total: items.length,
          title: pass ? 'Class ${c.code} passed!' : 'Not yet',
          titleFa: pass ? 'آفرین! کلاس ${c.code} را قبول شدی و گواهی‌اش آماده است.' : 'برای قبولی دست‌کم ${Grammar.examPass}٪ لازم است. درس‌ها را مرور کن و دوباره امتحان بده.',
          onRetry: pass ? null : () => _start(ts),
          onContinue: () => setState(() { started = false; award = null; }),
          autoNext: 0,
        ),
      );
    }

    if (started && items.isNotEmpty) {
      return Scaffold(
        backgroundColor: BL.cream,
        body: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 6),
            child: Row(children: [
              NavBack(fallback: '/school/${c.code}'),
              const SizedBox(width: 8),
              Expanded(child: Text(hl('Class ${c.code} final exam · ${i + 1}/${items.length}'), key: const ValueKey('exam-stage'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (i + 1) / items.length, minHeight: 6, color: BL.red, backgroundColor: BL.mist)),
          ),
          Expanded(child: ExerciseView(key: ValueKey('exam-$attempt-$i'), item: items[i], seed: attempt * 31 + i, test: true, onAnswered: (ok) { if (ok) right++; }, onNext: _next)),
        ]),
      );
    }

    final best = ctrl.grammarExamScore(c.code), date = ctrl.grammarExamDate(c.code), passed = date != null;
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          Row(children: [NavBack(fallback: '/school/${c.code}'), const SizedBox(width: 10), const Text('FINAL EXAM', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 14),
          Text(hl('Class ${c.code} final exam'), style: BL.display(26)),
          Text(hl('آزمون پایانی کلاس ${c.code}'), textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
          const SizedBox(height: 12),
          Text(hl('${Grammar.examSize} questions from every topic in this class. Pass mark ${Grammar.examPass}%. You can take it as often as you like.'), style: const TextStyle(height: 1.35)),
          Text(hl('${Grammar.examSize} سؤال از همهٔ درس‌های این کلاس. نمرهٔ قبولی ${Grammar.examPass}٪. هر چند بار بخواهی می‌توانی امتحان بدهی.'), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
          if (best != null) ...[const SizedBox(height: 10), Text(hl('Best score: $best%'), key: const ValueKey('exam-best'), style: TextStyle(fontWeight: FontWeight.w800, color: passed ? BL.green : BL.red))],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('exam-start'),
            style: FilledButton.styleFrom(backgroundColor: BL.red, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: ready ? () => _start(ts) : null,
            child: Text(hl(ready ? (best == null ? 'Start the exam' : 'Take it again') : 'Pass every topic first · اول همهٔ درس‌ها را قبول شو'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (passed) ...[
            const SizedBox(height: 20),
            _ClassCertificate(code: c.code, name: c.name, nameFa: c.nameFa, score: best!, date: date, learner: ctrl.certName),
          ],
        ],
      ),
    );
  }
}

class _ClassCertificate extends StatelessWidget {
  final String code, name, nameFa, date, learner;
  final int score;
  const _ClassCertificate({required this.code, required this.name, required this.nameFa, required this.score, required this.date, required this.learner});
  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('class-certificate'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFC9A04C), width: 2), boxShadow: BL.shadow(.08)),
        child: Column(children: [
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFC9A04C), size: 40),
          Text(hl('Certificate of completion'), style: BL.display(20), textAlign: TextAlign.center),
          Text(hl('گواهی پایان کلاس'), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
          const SizedBox(height: 10),
          if (learner.trim().isNotEmpty) Text(hl(learner), style: BL.display(22), textAlign: TextAlign.center),
          Text(hl('Grammar School · Class $code · $name'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(hl('کلاس $code · $nameFa'), textDirection: helperDir, style: BL.fa(12.5)),
          const SizedBox(height: 6),
          Text(hl('Final exam $score% · passed on $date'), style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(hl(CertificateScreen.disclaimer), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: BL.muted, height: 1.3)),
          Text(hl(CertificateScreen.disclaimerFa), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(10.5, color: BL.muted)),
        ]),
      );
}
