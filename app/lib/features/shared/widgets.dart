import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/data/repository.dart' show SceneArt;
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

/// A plain, people-free symbol for a setting (the painted map icons show people, so they can't be used here).
IconData locationIcon(String spot) => switch (spot.split('/').last.replaceAll('.webp', '')) {
      'home' => Icons.home_rounded,
      'school' => Icons.school_rounded,
      'nursery' => Icons.child_care_rounded,
      'playdate' => Icons.toys_rounded,
      'bus' => Icons.directions_bus_rounded,
      'station' => Icons.train_rounded,
      'shops' || 'shoppingcentre' => Icons.storefront_rounded,
      'supermarket' => Icons.shopping_cart_rounded,
      'gp' || 'hospital' => Icons.local_hospital_rounded,
      'pharmacy' => Icons.local_pharmacy_rounded,
      'bank' => Icons.account_balance_rounded,
      'postoffice' => Icons.local_post_office_rounded,
      'library' => Icons.local_library_rounded,
      'park' => Icons.park_rounded,
      'cafe' => Icons.local_cafe_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'pub' => Icons.sports_bar_rounded,
      'gym' => Icons.fitness_center_rounded,
      'barber' => Icons.content_cut_rounded,
      'garage' => Icons.local_gas_station_rounded,
      'museum' => Icons.museum_rounded,
      'cinema' => Icons.movie_rounded,
      'university' => Icons.account_balance_rounded,
      'work' => Icons.work_rounded,
      _ => Icons.place_rounded,
    };

/// Neutral, people-free backdrop for a conversation with no matching painting yet: the setting's painting
/// blurred beyond recognition (or a plain colour) under a plain symbol and its name. Never a wrong person.
class LocationCard extends StatelessWidget {
  final SceneArt? art;
  final Color color;
  const LocationCard({super.key, required this.art, required this.color});
  @override
  Widget build(BuildContext context) {
    final a = art;
    return Stack(key: const ValueKey('location-card'), fit: StackFit.expand, children: [
      if (a?.bg != null)
        Image.asset(a!.bg!, fit: BoxFit.cover)
      else
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .55), const Color(0xFF1B140F)]))),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33000000), Color(0x88000000)]))),
      if (a != null)
        Align(
          alignment: const Alignment(0, -.1),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: const Color(0xFFFBF7F0).withValues(alpha: .92), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)]),
              child: Icon(locationIcon(a.spot), size: 64, color: const Color(0xFF6B4A2B)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(a.label, key: const ValueKey('location-label'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
            ),
            if (a.labelFa.isNotEmpty) Text(a.labelFa, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
    ]);
  }
}
