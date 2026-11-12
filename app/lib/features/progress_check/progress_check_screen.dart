import 'dart:math';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/engine/progress_check.dart';
import '../../core/platform/voice.dart';
import '../onboarding/placement_screen.dart';
import '../shared/nav.dart';

/// Shown everywhere the estimate appears.
const checkDisclaimer = 'Unofficial estimate from a short quiz in this app. It is not a CEFR certificate and not equivalent to IELTS, a Home Office English test (SELT) or Life in the UK.';
const checkDisclaimerFa = 'تخمین غیررسمی از یک آزمون کوتاه در همین اپ. گواهی CEFR نیست و معادل IELTS، آزمون انگلیسی وزارت کشور (SELT) یا Life in the UK نیست.';

/// Repeatable progress check (owner t306 item 5): new questions each time, adaptive A1–C1, history chart.
/// It never changes the learner's course level.
class ProgressCheckScreen extends ConsumerStatefulWidget {
  const ProgressCheckScreen({super.key});
  /// Test seam: fixed seed for the question draw.
  static int? seed;
  @override
  ConsumerState<ProgressCheckScreen> createState() => _ProgressCheckState();
}

class _ProgressCheckState extends ConsumerState<ProgressCheckScreen> {
  Map<int, List<CheckItem>>? _items;
  int _level = 2, _i = 0, _right = 0, _rightAll = 0, _totalAll = 0;
  final _passed = <int, bool>{};
  bool _intro = true, _done = false;
  String? _picked;
  int? _result;

  void _start() {
    final content = ref.read(contentProvider).value;
    final pl = ref.read(placementProvider).value?.$1 ?? const [];
    if (content == null) return;
    final placement = [
      for (final p in pl)
        if (p.type == 'grammar' || p.type == 'vocab') CheckItem(level: p.level, prompt: p.text, answer: p.answer, choices: p.choices, kind: 'placement'),
    ];
    setState(() {
      _items = ProgressCheck.build(content.scenes.values, placement: placement, seed: ProgressCheckScreen.seed ?? Random().nextInt(1 << 31));
      _intro = _done = false;
      _level = placementNext(const {})!;
      _i = _right = _rightAll = _totalAll = 0;
      _passed.clear();
      _result = null;
    });
  }

  List<CheckItem> get _block => _items?[_level] ?? const [];

  void _answer(String c) {
    if (_picked != null) return;
    final it = _block[_i];
    setState(() => _picked = c);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        final ok = c == it.answer;
        if (ok) {
          _right++;
          _rightAll++;
        }
        _totalAll++;
        _picked = null;
        _i++;
        if (_i >= _block.length) {
          _passed[_level] = _right >= placementPassMark(_block.length);
          final nx = placementNext(_passed);
          _i = _right = 0;
          if (nx != null && (_items?[nx]?.isNotEmpty ?? false)) {
            _level = nx;
          } else {
            _finish();
          }
        }
      });
    });
  }

  void _finish() {
    final lv = placementLevel(_passed);
    final ctrl = ref.read(progressProvider.notifier);
    ctrl.setPref('checkHistory', ProgressCheck.addResult(ctrl.pref('checkHistory'), CheckResult(Motivation.day(DateTime.now()), lv, _rightAll, _totalAll)));
    _result = lv;
    _done = true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ready = ref.watch(contentProvider).hasValue && ref.watch(placementProvider).hasValue;
    final history = ProgressCheck.history(ref.read(progressProvider.notifier).pref('checkHistory'));
    Widget body;
    if (_intro) {
      body = _introView(history, ready);
    } else if (_done) {
      body = _resultView(history);
    } else if (_block.isEmpty) {
      body = const NavLoading();
    } else {
      body = _question(_block[_i]);
    }
    return Scaffold(
      key: const ValueKey('progress-check'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              const NavBack(fallback: '/progress'),
              const SizedBox(width: 4),
              Expanded(child: Text(hl('Progress check'), style: BL.display(22))),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Widget _disclaimer() => Container(
        key: const ValueKey('check-disclaimer'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: BL.mist)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(checkDisclaimer, style: TextStyle(fontSize: 12, color: BL.muted, height: 1.35)),
          Text(checkDisclaimerFa, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
        ]),
      );

  Widget _introView(List<CheckResult> history, bool ready) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        const Text('About 10–20 questions: pick the best reply in real situations from the app. Every check uses new questions, so you can repeat it every few weeks and watch your progress. Your course level does not change.',
            style: TextStyle(fontSize: 14, height: 1.4)),
        const SizedBox(height: 6),
        Text('حدود ۱۰ تا ۲۰ سؤال: بهترین جواب را در موقعیت‌های واقعی اپ انتخاب کن. هر بار سؤال تازه است، پس می‌توانی هر چند هفته تکرارش کنی و پیشرفتت را ببینی. سطح دوره‌ات عوض نمی‌شود.',
            textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted)),
        const SizedBox(height: 12),
        _disclaimer(),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('check-start'),
          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: ready ? _start : null,
          child: Text(hl(history.isEmpty ? 'Start the check' : 'Check again'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (history.isNotEmpty) ...[const SizedBox(height: 20), _historyCard(history)],
      ]);

  Widget _question(CheckItem it) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        Text(hl('${ProgressController.cefrOf(_level)} · question ${_i + 1} of ${_block.length}'), key: const ValueKey('check-step'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: BL.red)),
        const SizedBox(height: 8),
        if (it.kind == 'reply') ...[
          Text(hl('Someone says:'), style: const TextStyle(color: BL.muted)),
          const SizedBox(height: 4),
        ],
        Row(children: [
          Expanded(child: Text(it.prompt, key: const ValueKey('check-prompt'), style: BL.display(20).copyWith(height: 1.3))),
          if (it.speaker != null) IconButton(onPressed: () => Voice.say(it.speaker!, it.prompt), icon: const Icon(Icons.volume_up_rounded), tooltip: 'Hear it'),
        ]),
        const SizedBox(height: 6),
        Text(hl(it.kind == 'reply' ? 'Choose the best reply · بهترین جواب را انتخاب کن' : 'Choose the right answer · جواب درست را انتخاب کن'), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
        const SizedBox(height: 10),
        for (final c in it.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: ValueKey('check-choice-${it.choices.indexOf(c)}'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
                backgroundColor: _picked == null ? Colors.white : (c == it.answer ? const Color(0xFFDFF5E8) : (c == _picked ? const Color(0xFFFFE1DE) : Colors.white)),
              ),
              onPressed: () => _answer(c),
              child: Text(c, style: const TextStyle(color: BL.ink, fontSize: 15)),
            ),
          ),
      ]);

  Widget _resultView(List<CheckResult> history) {
    final lv = _result ?? 1;
    final cmp = ProgressCheck.compare(history, ProgressController.cefrOf);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
      Container(
        key: ValueKey('check-result-$lv'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: BL.mist)),
        child: Column(children: [
          Text(hl('Estimated level (unofficial)'), style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted)),
          Text(hl('سطح تخمینی (غیررسمی)'), textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
          Text(ProgressController.cefrOf(lv), style: BL.display(46, color: BL.red)),
          Text(hl(placementCanDo[lv]!.$1), textAlign: TextAlign.center, style: const TextStyle(height: 1.35)),
          Text(placementCanDo[lv]!.$2, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          const SizedBox(height: 6),
          Text(hl('$_rightAll of $_totalAll right'), style: const TextStyle(color: BL.muted)),
        ]),
      ),
      const SizedBox(height: 10),
      Text(hl(cmp.$1), key: const ValueKey('check-compare'), style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(cmp.$2, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
      const SizedBox(height: 12),
      _disclaimer(),
      const SizedBox(height: 14),
      _historyCard(history),
      const SizedBox(height: 14),
      FilledButton(key: const ValueKey('check-done'), style: FilledButton.styleFrom(backgroundColor: BL.red), onPressed: () => Navigator.of(context).maybePop().then((popped) {
        if (!popped && mounted) setState(() => _intro = true);
      }), child: Text(hl('Done'))),
    ]);
  }

  Widget _historyCard(List<CheckResult> h) => Container(
        key: const ValueKey('check-history'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.mist)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hl('Your checks'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text(hl('سنجش‌های تو'), textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
          const SizedBox(height: 10),
          SizedBox(height: 140, width: double.infinity, child: CustomPaint(key: const ValueKey('check-chart'), painter: CheckChartPainter(h))),
          const SizedBox(height: 6),
          Text(hl([for (final r in h.reversed.take(5)) '${r.day}: ${ProgressController.cefrOf(r.level)}'].join(' · ')), style: const TextStyle(fontSize: 11.5, color: BL.muted)),
        ]),
      );
}

/// Level over time (A1 bottom … C1 top), one dot per check.
class CheckChartPainter extends CustomPainter {
  final List<CheckResult> history;
  CheckChartPainter(this.history);
  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0;
    final grid = Paint()..color = BL.mist..strokeWidth = 1;
    final w = size.width - left - 8, h = size.height - 8;
    for (var lv = 1; lv <= 5; lv++) {
      final y = 4 + h - (lv - 1) / 4 * h;
      canvas.drawLine(Offset(left, y), Offset(size.width - 4, y), grid);
      final tp = TextPainter(text: TextSpan(text: ProgressController.cefrOf(lv), style: const TextStyle(fontSize: 10, color: BL.muted)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    if (history.isEmpty) return;
    final pts = [
      for (var i = 0; i < history.length; i++) Offset(left + (history.length == 1 ? w / 2 : i / (history.length - 1) * w), 4 + h - (history[i].level - 1) / 4 * h),
    ];
    final line = Paint()..color = BL.red..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..addPolygon(pts, false), line);
    for (final p in pts) {
      canvas.drawCircle(p, 4.5, Paint()..color = BL.red);
    }
  }

  @override
  bool shouldRepaint(CheckChartPainter old) => old.history.length != history.length;
}
