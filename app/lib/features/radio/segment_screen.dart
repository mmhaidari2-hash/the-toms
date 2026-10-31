import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import 'radio_data.dart';
import 'radio_screen.dart';

/// One programme: listening first (no text), then an optional transcript with Persian, then questions.
class SegmentScreen extends ConsumerWidget {
  final String id;
  const SegmentScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final segs = ref.watch(radioProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (segs == null || topics == null || content == null) return const NavLoading();
    final s = segs.where((x) => x.id == id).firstOrNull;
    if (s == null) {
      return Scaffold(backgroundColor: radioDark, body: Center(child: TextButton(onPressed: () => context.go('/radio'), child: const Text('Programme not found — back to the radio'))));
    }
    // Strict lock: a deep link to a programme on a shut level never plays it.
    final gate = RadioGate(ref.read(progressProvider.notifier), content, topics, segs, unlockAll: ref.read(progressProvider).gatesOpen);
    if (!gate.levelOpen(s.level)) return SegmentLocked(seg: s);
    return _Player(key: ValueKey('seg-screen-${s.id}'), seg: s);
  }
}

class SegmentLocked extends StatelessWidget {
  final Segment seg;
  const SegmentLocked({super.key, required this.seg});
  @override
  Widget build(BuildContext context) {
    final (en, fa) = RadioGate.why(seg.level);
    return Scaffold(
      key: const ValueKey('seg-locked'),
      backgroundColor: radioDark,
      body: SafeArea(
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: NavBack(light: true, fallback: '/radio'))),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_rounded, size: 56, color: Colors.white54),
                  const SizedBox(height: 14),
                  Text(hl(seg.title), textAlign: TextAlign.center, style: BL.display(24, color: Colors.white)),
                  Text(hl(seg.titleFa), textDirection: helperDir, style: BL.fa(14, color: Colors.white60)),
                  const SizedBox(height: 18),
                  Text(hl('This is a ${seg.level} programme, which isn\'t on air for you yet'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(hl(en), key: const ValueKey('seg-locked-why'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(hl(fa), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(13, color: Colors.white54)),
                  const SizedBox(height: 18),
                  TextButton(key: const ValueKey('seg-locked-radio'), onPressed: () => context.go('/radio'), child: const Text('Back to the radio', style: TextStyle(color: BL.gold))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Player extends ConsumerStatefulWidget {
  final Segment seg;
  const _Player({super.key, required this.seg});
  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> with SingleTickerProviderStateMixin {
  Segment get s => widget.seg;
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  late final AnimationController _eq = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  final _keys = <int, GlobalKey>{};
  int cur = -1, _token = 0;
  bool playing = false, listened = false, transcript = false, quiz = false;
  int qi = 0, right = 0;
  int? picked;
  List<List<int>> order = [];
  XpAward? award;

  bool get showFa => ctrl.pref('radioFa', 'off') == 'on';
  bool get slow => ctrl.pref('radioSlow', 'off') == 'on';

  @override
  void dispose() {
    _token++;
    Voice.stop();
    _eq.dispose();
    super.dispose();
  }

  void _show(int i) {
    setState(() => cur = i);
    final c = _keys[i]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), alignment: .3);
  }

  /// Plays one line; without audio (muted, tests) it still keeps the programme's pace.
  Future<void> _say(int i) async {
    final l = s.lines[i], rate = slow ? .86 : 1.0;
    final sw = Stopwatch()..start();
    if (!await Voice.say(l.sp, l.en, rate: rate)) {
      _token++; // cut short by another clip: stop rather than talk over it
      if (mounted) setState(() => playing = false);
      _eq.stop();
      return;
    }
    final left = (l.ms / rate).round() - sw.elapsedMilliseconds;
    if (sw.elapsedMilliseconds < 300 && left > 0) await Future.delayed(Duration(milliseconds: left));
  }

  Future<void> _play({int from = 0}) async {
    final t = ++_token;
    setState(() => playing = true);
    _eq.repeat();
    for (var i = from; i < s.lines.length; i++) {
      if (!mounted || t != _token) return;
      _show(i);
      await _say(i);
      if (!mounted || t != _token) return;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted || t != _token) return;
    _eq.stop();
    setState(() {
      playing = false;
      listened = true;
      cur = -1;
    });
  }

  void _stop() {
    _token++;
    Voice.stop();
    _eq.stop();
    setState(() => playing = false);
  }

  Future<void> _playOne(int i) async {
    if (playing) return;
    final t = ++_token;
    _show(i);
    await _say(i);
    if (mounted && t == _token) setState(() => cur = -1);
  }

  void _startQuiz() {
    _stop();
    final rnd = Random(s.id.hashCode);
    order = [for (final q in s.quiz) (List.generate(q.options.length, (i) => i)..shuffle(rnd))];
    setState(() {
      quiz = true;
      award = null;
      qi = 0;
      right = 0;
      picked = null;
    });
  }

  void _pick(int opt) {
    if (picked != null) return;
    setState(() {
      picked = opt;
      if (opt == s.quiz[qi].answer) right++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (qi + 1 < s.quiz.length) {
        setState(() {
          qi++;
          picked = null;
        });
      } else {
        final a = ctrl.saveRadioQuiz(s.id, (right * 100 / s.quiz.length).round());
        setState(() => award = a);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final pad = MediaQuery.paddingOf(context);
    if (quiz && award != null) {
      final pct = (right * 100 / max(s.quiz.length, 1)).round(), pass = pct >= RadioStation.pass;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('radio-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: false,
          right: right,
          total: s.quiz.length,
          title: pass ? 'Programme understood!' : 'Good effort!',
          titleFa: pass ? 'آفرین! این برنامه را خوب فهمیدی.' : 'دوباره گوش کن و دوباره امتحان کن.',
          onRetry: pass ? null : () => setState(() => quiz = false),
          onContinue: () => setState(() => quiz = false),
        ),
      );
    }
    final (kind, _, _) = RadioStation.kinds[s.kind]!;
    return Scaffold(
      backgroundColor: radioDark,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 6),
          child: Row(children: [
            const NavBack(light: true, fallback: '/radio'),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(s.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                Text(hl('${s.level}  ·  $kind  ·  ${s.seconds}s'), style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        Expanded(child: quiz ? _quiz() : _listen(pad.bottom)),
      ]),
    );
  }

  Widget _listen(double bottom) => ListView(
        key: const ValueKey('radio-scroll'),
        padding: EdgeInsets.fromLTRB(14, 6, 14, bottom + 24),
        children: [
          _set(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('radio-quiz'),
                onPressed: _startQuiz,
                style: FilledButton.styleFrom(backgroundColor: listened ? onAirRed : radioPanel, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.quiz_rounded, size: 19),
                label: Text(hl('Questions · سؤال‌ها'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ]),
          if (!listened)
            Padding(
              key: const ValueKey('radio-hint'),
              padding: const EdgeInsets.only(top: 6),
              child: Column(children: [
                const Text('Listen first, without the text. Then answer.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(hl('اول بدون متن گوش کن، بعد جواب بده.'), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(12, color: Colors.white38)),
              ]),
            ),
          const SizedBox(height: 14),
          Row(children: [
            _chip('radio-transcript', Icons.subject_rounded, transcript ? 'Hide transcript' : 'Show transcript', transcript, () => setState(() => transcript = !transcript)),
            if (transcript) ...[const SizedBox(width: 8), _chip('radio-fa', Icons.translate_rounded, 'فارسی', showFa, () => ctrl.setPref('radioFa', showFa ? 'off' : 'on'))],
            const Spacer(),
            _chip('radio-slow', Icons.slow_motion_video_rounded, 'Slower', slow, () => ctrl.setPref('radioSlow', slow ? 'off' : 'on')),
          ]),
          const SizedBox(height: 10),
          if (transcript) for (var i = 0; i < s.lines.length; i++) _row(i) else ...[
            Text(hl(s.blurb), key: const ValueKey('radio-blurb'), style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
            Text(hl(s.blurbFa), textDirection: helperDir, style: BL.fa(12.5, color: Colors.white38)),
          ],
        ],
      );

  /// The radio set: speaker on air, equaliser, play/stop, progress through the programme.
  Widget _set() {
    final on = cur >= 0 ? s.lines[cur] : null;
    return Container(
      key: const ValueKey('radio-set'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF223446), Color(0xFF15222E)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300), width: 9, height: 9, decoration: BoxDecoration(color: playing ? onAirRed : Colors.white24, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(hl(playing ? 'ON AIR' : 'HACKNEY HUM'), style: TextStyle(color: playing ? onAirRed : Colors.white54, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
          const Spacer(),
          Text(hl(s.slot), style: const TextStyle(color: BL.gold, fontWeight: FontWeight.w900, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 46, child: AnimatedBuilder(animation: _eq, builder: (_, _) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [for (var b = 0; b < 26; b++) _bar(b)]))),
        const SizedBox(height: 8),
        Text(hl(on != null ? on.spName.toUpperCase() : (listened ? 'Listened · گوش دادی' : 'Press play and just listen')), key: const ValueKey('radio-onair'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: .8)),
        const SizedBox(height: 10),
        Row(children: [
          Material(
            color: playing ? Colors.white : onAirRed,
            shape: const CircleBorder(),
            child: InkWell(
              key: ValueKey(playing ? 'radio-stop' : 'radio-play'),
              customBorder: const CircleBorder(),
              onTap: playing ? _stop : () => _play(),
              child: Padding(padding: const EdgeInsets.all(10), child: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 32, color: playing ? radioDark : Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(key: const ValueKey('radio-progress'), value: listened && cur < 0 ? 1 : (cur + 1) / s.lines.length, minHeight: 5, backgroundColor: Colors.white12, color: BL.gold),
              ),
              const SizedBox(height: 5),
              Text(hl(cur >= 0 ? 'Part ${cur + 1} of ${s.lines.length}' : '${s.lines.length} parts  ·  ${s.seconds}s'), style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _bar(int b) {
    final t = _eq.value * 2 * pi;
    final h = playing ? 8 + 34 * (.5 + .5 * sin(t * (1 + b % 4) + b * 1.7)).abs() * (.55 + .45 * sin(b * .9 + t).abs()) : 5.0;
    return Expanded(child: Center(child: Container(width: 4, height: h, decoration: BoxDecoration(color: Color.lerp(BL.gold, onAirRed, b / 26), borderRadius: BorderRadius.circular(2)))));
  }

  Widget _chip(String key, IconData icon, String label, bool on, VoidCallback onTap) => ActionChip(
        key: ValueKey(key),
        onPressed: onTap,
        avatar: Icon(icon, size: 16, color: on ? radioDark : Colors.white70),
        label: Text(hl(label)),
        visualDensity: VisualDensity.compact,
        backgroundColor: on ? BL.gold : radioPanel,
        side: BorderSide.none,
        labelStyle: TextStyle(color: on ? radioDark : Colors.white70, fontWeight: FontWeight.w800, fontSize: 12.5),
      );

  Widget _row(int i) {
    final l = s.lines[i], on = cur == i;
    return GestureDetector(
      key: _keys.putIfAbsent(i, () => GlobalKey()),
      onTap: () => _playOne(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? BL.gold.withValues(alpha: .6) : Colors.transparent)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(hl(l.spName.toUpperCase()), style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: BL.gold)),
          Text(hl(l.en), key: ValueKey('radio-text-$i'), style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35)),
          if (showFa) Text(hl(l.fa), key: ValueKey('radio-fa-$i'), textDirection: helperDir, textAlign: TextAlign.right, style: BL.fa(13, color: Colors.white60)),
        ]),
      ),
    );
  }

  Widget _quiz() {
    final q = s.quiz[qi];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text(hl('Question ${qi + 1} of ${s.quiz.length}'), style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 6),
        Text(hl(q.q), key: const ValueKey('radio-q'), style: BL.display(22, color: Colors.white)),
        const SizedBox(height: 16),
        for (final o in order[qi])
          Builder(builder: (_) {
            final isAns = o == q.answer, isPicked = picked == o;
            final col = picked == null ? radioPanel : (isAns ? BL.green : (isPicked ? BL.red : radioPanel));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: col,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('radio-opt-$o'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pick(o),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), child: Text(hl(q.options[o]), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))),
                ),
              ),
            );
          }),
        TextButton(key: const ValueKey('radio-back-listen'), onPressed: () => setState(() => quiz = false), child: Text(hl('Listen again · دوباره گوش کن'), style: TextStyle(color: Colors.white70))),
      ],
    );
  }
}
