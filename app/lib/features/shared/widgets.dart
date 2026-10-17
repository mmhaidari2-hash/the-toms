import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../core/models/character.dart';

class Avatar extends StatelessWidget {
  final Character c;
  final double size;
  final bool ring;
  const Avatar(this.c, {super.key, this.size = 56, this.ring = true});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(ring ? size * .05 : 0),
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: ring ? BL.shadow(.10) : null),
    child: ClipOval(
      // Real painted portrait of this exact character (cropped from their painting); SVG only as a legacy fallback.
      child: c.avatar.endsWith('.svg')
          ? SvgPicture.asset(c.avatar, fit: BoxFit.cover, semanticsLabel: c.name)
          : Image.asset(c.avatar, fit: BoxFit.cover, semanticLabel: c.name, cacheWidth: (size * 3).round(), filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => ColoredBox(color: c.color, child: Center(child: Text(c.name.characters.first, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .4))))),
    ),
  );
}

/// Animated pill progress bar with label.
class MeterBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final String label;
  final String trailing;
  final IconData icon;
  const MeterBar({super.key, required this.value, required this.color, required this.label, required this.trailing, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      SizedBox(
        width: 46,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: BL.muted, fontWeight: FontWeight.w600),
        ),
      ),
      Expanded(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 8, color: color.withValues(alpha: .12)),
                FractionallySizedBox(
                  widthFactor: max(v, .02),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withValues(alpha: .75), color]),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 34,
        child: Text(
          trailing,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    ],
  );
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(scale: _down ? .97 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
  );
}

/// Lightweight confetti — no package, pure CustomPainter.
class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  final _rnd = Random(7);
  late final _bits = List.generate(90, (i) => [_rnd.nextDouble(), _rnd.nextDouble() * .5, _rnd.nextDouble(), i % 4]);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c.value, _bits)),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<List<num>> bits;
  _ConfettiPainter(this.t, this.bits);
  static const cols = [BL.red, BL.gold, BL.navy, Color(0xFFE8648A)];
  @override
  void paint(Canvas canvas, Size s) {
    for (final b in bits) {
      final x = b[0] * s.width + sin((t * 6) + b[2] * 10) * 18;
      final y = -20 + (t * 1.25 - b[1]) * s.height * 1.1;
      if (y < -20) continue;
      final p = Paint()..color = cols[b[3].toInt()].withValues(alpha: (1 - t).clamp(0, 1) * .95 + .05);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 12 * (b[2] - .5));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 520 + delayMs),
    curve: Interval(delayMs / (520 + delayMs), 1, curve: Curves.easeOutCubic),
    builder: (_, v, ch) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: ch),
    ),
    child: child,
  );
}

class LevelChip extends StatelessWidget {
  final String level;
  final bool dark;
  const LevelChip(this.level, {super.key, this.dark = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: dark ? Colors.white.withValues(alpha: .18) : BL.navy.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(99),
      border: dark ? Border.all(color: Colors.white30) : null,
    ),
    child: Text(
      level.replaceAll('-', '–'),
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: dark ? Colors.white : BL.navy),
    ),
  );
}
