import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';

IconData badgeIcon(String id) => switch (id) {
      'first' => Icons.flag_rounded,
      'streak3' || 'streak7' || 'streak30' => Icons.local_fire_department_rounded,
      'xp100' || 'xp500' || 'xp1000' => Icons.bolt_rounded,
      'lessons10' || 'lessons50' => Icons.school_rounded,
      'unit' => Icons.emoji_events_rounded,
      'perfect' => Icons.verified_rounded,
      'goal7' => Icons.track_changes_rounded,
      'words50' => Icons.auto_stories_rounded,
      'league' => Icons.military_tech_rounded,
      'book1' || 'book5' => Icons.local_library_rounded,
      'mission1' || 'mission5' => Icons.hiking_rounded,
      _ => Icons.star_rounded,
    };

/// Round badge medal; grey when locked.
class BadgeMedal extends StatelessWidget {
  final Achievement b;
  final bool earned;
  final double size;
  const BadgeMedal(this.b, {super.key, required this.earned, this.size = 56});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: earned ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF6D77A), Color(0xFFC9A04C)]) : null,
          color: earned ? null : BL.mist,
          border: Border.all(color: earned ? const Color(0xFFFFF1C4) : Colors.white, width: 3),
          boxShadow: earned ? const [BoxShadow(color: Color(0x33C9A04C), blurRadius: 10, offset: Offset(0, 4))] : null,
        ),
        child: Icon(badgeIcon(b.id), size: size * .48, color: earned ? BL.ink : const Color(0xFFB9B2A6)),
      );
}

/// Ring showing today's XP against the daily goal.
class GoalRing extends StatelessWidget {
  final int xp, goal;
  final double size;
  final Color track;
  const GoalRing({super.key, required this.xp, required this.goal, this.size = 30, this.track = BL.mist});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          CircularProgressIndicator(value: (xp / max(goal, 1)).clamp(0, 1).toDouble(), strokeWidth: size / 8, color: xp >= goal ? BL.green : BL.gold, backgroundColor: track),
          if (xp >= goal) Icon(Icons.check_rounded, size: size * .55, color: BL.green),
        ]),
      );
}

/// Light confetti burst for celebrations (no packages).
class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  final _bits = List.generate(70, (i) {
    final r = Random(i * 31 + 7);
    return (r.nextDouble(), r.nextDouble() * .5, (r.nextDouble() - .5) * .6, [BL.red, BL.gold, BL.green, BL.navy, const Color(0xFF5BC0DE)][i % 5], r.nextDouble() * 6);
  });
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c.value, _bits))),
      );
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<(double, double, double, Color, double)> bits;
  _ConfettiPainter(this.t, this.bits);
  @override
  void paint(Canvas canvas, Size s) {
    if (t >= 1) return;
    for (final (x, delay, drift, color, spin) in bits) {
      final p = ((t - delay * .4) / .8).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final dx = (x + drift * p) * s.width;
      final dy = -20 + p * p * (s.height * .9);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(spin + p * 8);
      canvas.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), Paint()..color = color.withValues(alpha: 1 - p * .6));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

/// End-of-lesson celebration: XP count-up, streak, daily goal and new badges.
/// When [onNext] is given and the learner passed, a big "Next …" button leads on, and the app moves
/// there by itself after [autoNext] seconds unless the learner taps "Stay here".
class Celebration extends StatefulWidget {
  final XpAward award;
  final bool pass, checkpoint;
  final int right, total;
  final VoidCallback onContinue;
  final VoidCallback? onRetry;
  /// Goes to the next lesson / topic / chapter (only offered on a pass).
  final VoidCallback? onNext;
  final String nextLabel;
  final int autoNext;
  /// Overrides for non-lesson uses (e.g. a Library chapter quiz).
  final String? title, titleFa;
  /// Tests can switch the timed auto-advance off.
  static bool autoAdvance = true;
  const Celebration({super.key, this.title, this.titleFa, required this.award, required this.pass, required this.checkpoint, required this.right, required this.total, required this.onContinue, this.onRetry, this.scoreLabel = 'Score', this.onNext, this.nextLabel = 'Next lesson', this.autoNext = 3});
  /// Label under the percentage stat (e.g. 'Phrases' for a mission check-in).
  final String scoreLabel;
  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> {
  Timer? _t;
  int _left = 0;
  bool get _hasNext => widget.pass && widget.onNext != null;
  @override
  void initState() {
    super.initState();
    if (_hasNext && Celebration.autoAdvance && widget.autoNext > 0) {
      _left = widget.autoNext;
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left <= 1) {
          _stop();
          widget.onNext!();
        } else {
          setState(() => _left--);
        }
      });
    }
  }
  void _stop() {
    _t?.cancel();
    _t = null;
    if (mounted) setState(() => _left = 0);
  }
  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.right * 100 / max(widget.total, 1)).round();
    return Stack(children: [
      if (widget.pass) const Positioned.fill(child: Confetti()),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.pass ? Icons.emoji_events_rounded : Icons.auto_stories_rounded, size: 64, color: widget.pass ? BL.gold : BL.navy),
            const SizedBox(height: 8),
            Text(hl(widget.title ?? (widget.pass ? (widget.checkpoint ? 'Unit complete!' : 'Lesson complete!') : 'Good effort!')), key: const ValueKey('celebrate-title'), style: BL.display(30), textAlign: TextAlign.center),
            Text(hl(widget.titleFa ?? (widget.pass ? (widget.checkpoint ? 'واحد تمام شد! واحد بعدی باز شد.' : 'آفرین! درس بعدی باز شد.') : 'یک بار دیگر تمرین کن تا به ${widget.checkpoint ? 70 : 60}٪ برسی.')),
                textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(14, color: BL.muted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Stat(key: const ValueKey('celebrate-xp'), color: BL.gold, icon: Icons.bolt_rounded, label: 'XP', child: TweenAnimationBuilder<int>(tween: IntTween(begin: 0, end: widget.award.xp), duration: const Duration(milliseconds: 900), builder: (_, v, _) => Text(hl('+$v'), style: BL.display(24))))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(color: BL.green, icon: Icons.track_changes_rounded, label: widget.scoreLabel, child: Text(hl('$pct%'), style: BL.display(24)))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(color: BL.red, icon: Icons.local_fire_department_rounded, label: widget.award.streak == 1 ? 'day' : 'days', child: Text(hl('${widget.award.streak}'), style: BL.display(24)))),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: BL.mist)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(hl(widget.award.today >= widget.award.goal ? 'Daily goal reached!' : 'Daily goal'), style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(hl('${min(widget.award.today, widget.award.goal)} / ${widget.award.goal} XP'), style: const TextStyle(fontWeight: FontWeight.w700, color: BL.muted)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: max(0, widget.award.today - widget.award.xp) / max(widget.award.goal, 1), end: widget.award.today / max(widget.award.goal, 1)),
                    duration: const Duration(milliseconds: 900),
                    builder: (_, v, _) => LinearProgressIndicator(value: v.clamp(0, 1), minHeight: 10, color: widget.award.today >= widget.award.goal ? BL.green : BL.gold, backgroundColor: BL.mist),
                  ),
                ),
                if (widget.award.streakUp) ...[
                  const SizedBox(height: 10),
                  Text(hl(widget.award.freezeUsed ? 'A streak freeze saved your ${widget.award.streak}-day streak.' : (widget.award.streak == 1 ? 'Streak started. Come back tomorrow!' : '${widget.award.streak}-day streak. Keep it going!')),
                      style: const TextStyle(color: BL.red, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
            if (widget.award.newBadges.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('NEW BADGE', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w900, color: BL.red)),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 8, alignment: WrapAlignment.center, children: [
                for (final b in widget.award.newBadges)
                  Column(key: ValueKey('new-badge-${b.id}'), children: [BadgeMedal(b, earned: true, size: 60), const SizedBox(height: 4), Text(hl(b.title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))]),
              ]),
            ],
            const SizedBox(height: 20),
            if (_hasNext) ...[
              FilledButton(
                key: const ValueKey('celebrate-next'),
                onPressed: () {
                  _stop();
                  widget.onNext!();
                },
                style: FilledButton.styleFrom(backgroundColor: BL.red, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(hl('${widget.nextLabel}  →'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              if (_left > 0)
                Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(hl('Opening in $_left…'), key: const ValueKey('celebrate-countdown'), style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w700)),
                  TextButton(key: const ValueKey('celebrate-stay'), onPressed: _stop, child: const Text('Stay here')),
                ]),
              TextButton(key: const ValueKey('celebrate-continue'), onPressed: () {
                _stop();
                widget.onContinue();
              }, child: const Text('Back')),
            ] else
              FilledButton(
                key: const ValueKey('celebrate-continue'),
                onPressed: widget.onContinue,
                style: FilledButton.styleFrom(backgroundColor: BL.red, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            if (widget.onRetry != null) TextButton(onPressed: widget.onRetry, child: const Text('Try again')),
          ]),
        ),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Widget child;
  const _Stat({super.key, required this.color, required this.icon, required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .5), width: 1.5)),
        child: Column(children: [Icon(icon, color: color, size: 22), child, Text(hl(label), style: const TextStyle(fontSize: 11.5, color: BL.muted, fontWeight: FontWeight.w700))]),
      );
}
