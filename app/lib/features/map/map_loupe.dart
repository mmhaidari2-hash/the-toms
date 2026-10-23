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
  const MapLoupe({super.key, required this.at, this.title, this.titleFa, this.level, this.open = true});

  static const size = 124.0;
  /// The lens floats above the finger so the finger never hides what it magnifies.
  static const lift = 92.0;

  @override
  Widget build(BuildContext context) {
    final below = at.dy - lift - size / 2 < 96; // too near the top bar: float below instead
    final dy = below ? lift : -lift;
    final centre = at + Offset(0, dy);
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
              focalPointOffset: Offset(0, -dy),
              decoration: const MagnifierDecoration(
                shape: CircleBorder(side: BorderSide(color: Color(0xE6FFF4DC), width: 2.2)),
                shadows: [BoxShadow(color: Color(0x88000000), blurRadius: 18, offset: Offset(0, 8)), BoxShadow(color: Color(0x55E9B949), blurRadius: 22, spreadRadius: 1)],
              ),
            ),
            // Frosted rim: a soft white ring inside the edge.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .38)], stops: const [0, .72, .9, 1]),
                ),
              ),
            ),
            // Shine: a curved highlight top-left.
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 44, 66),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(60, 34)),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (title != null)
        Positioned(
          left: centre.dx - 110,
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
