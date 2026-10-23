import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The glass loupe that follows a finger sliding over the map (press-and-hold, then drag) or the mouse on
/// desktop: the spot under it is magnified through a real lens, with a frosted rim, a shine, and a frosted
/// label with the place's full name and level. Only one blur (the label) so phones stay smooth.
class MapLoupe extends StatelessWidget {
  /// The point being magnified, in map coordinates.
  final Offset at;
  /// The spot under the lens (null: just the map).
  final String? title, titleFa, level;
  final bool open;
  /// The visible part of the map (map coordinates), so the lens and label never leave the screen or hide
  /// under the top bar.
  final double viewLeft, viewWidth, topSafe;
  const MapLoupe({super.key, required this.at, this.title, this.titleFa, this.level, this.open = true, this.viewLeft = 0, this.viewWidth = 1e9, this.topSafe = 96});

  static const size = 124.0;
  /// The lens floats above the finger so the finger never hides what it magnifies.
  static const lift = 92.0;

  @override
  Widget build(BuildContext context) {
    // Too near the top bar for the lens and its label: float below the finger instead.
    final below = at.dy - lift - size / 2 - (title == null ? 0 : 60) < topSafe;
    final dy = below ? lift : -lift;
    final cx = at.dx.clamp(viewLeft + size / 2 + 4, viewLeft + viewWidth - size / 2 - 4).toDouble();
    final centre = Offset(cx, at.dy + dy);
    final labelLeft = (cx - 110).clamp(viewLeft + 6, viewLeft + viewWidth - 226).toDouble();
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: centre.dx - size / 2,
        top: centre.dy - size / 2,
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .55, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          builder: (_, k, child) => Transform.scale(scale: k, child: Opacity(opacity: k.clamp(0, 1), child: child)),
          child: Stack(fit: StackFit.expand, children: [
            RawMagnifier(
              size: const Size(size, size),
              magnificationScale: 1.9,
              focalPointOffset: Offset(at.dx - cx, -dy),
              decoration: const MagnifierDecoration(
                shape: CircleBorder(side: BorderSide(color: Color(0xE6FFF4DC), width: 2.2)),
                shadows: [BoxShadow(color: Color(0x88000000), blurRadius: 18, offset: Offset(0, 8))],
              ),
            ),
            // Frosted rim: a soft white ring inside the edge.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: .10), Colors.white.withValues(alpha: .30)], stops: const [0, .8, .93, 1]),
                ),
              ),
            ),
            // Shine: a curved highlight top-left.
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 9, 50, 88),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(54, 26)),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (title != null)
        Positioned(
          left: labelLeft,
          width: 220,
          top: below ? centre.dy + size / 2 + 6 : centre.dy - size / 2 - 58,
          child: IgnorePointer(
            child: Center(
              child: ClipRRect(
                key: const ValueKey('loupe-label'),
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x8C3A2E26), Color(0xB3140E0A)]),
                      border: Border.all(color: const Color(0x66FFFFFF), width: .8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(15.5, color: Colors.white)),
                          if (titleFa != null) Text(titleFa!, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: BL.fa(11, color: Colors.white70)),
                        ]),
                      ),
                      if (level != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: open ? BL.gold : Colors.white24, borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!open) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 11, color: Colors.white)),
                            Text(level!, style: TextStyle(color: open ? BL.ink : Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
