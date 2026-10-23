import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'map_spots.dart';

/// The glass loupe that follows a finger sliding over the map (press-and-hold, then drag) or the mouse on
/// desktop. It is drawn in screen space (above the scrolling map) and paints its own magnified view of the
/// map and of the pin, so the lens always sits exactly on the pin centre at any scroll offset, pixel ratio
/// or safe-area inset (no backdrop sampling). The lens glides between pins instead of jumping.
class MapLoupe extends StatelessWidget {
  /// The point being magnified, in MAP coordinates (a pin centre when [spot] is set).
  final Offset focal;
  /// Map scroll offset and painted map size, to turn map coordinates into screen ones.
  final double scrollX, mapW, mapH;
  final String mapImage;
  final MapSpot? spot;
  final String? level;
  final bool open;
  /// The visible screen width and the top area (title bar + level strip) the lens must stay clear of.
  final double viewWidth, topSafe;
  const MapLoupe({super.key, required this.focal, required this.scrollX, required this.mapW, required this.mapH, required this.mapImage, this.spot, this.level, this.open = true, required this.viewWidth, this.topSafe = 96});

  static const size = 124.0;
  static const zoom = 1.9;
  /// The lens floats above the finger so the finger never hides what it magnifies.
  static const lift = 92.0;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Offset>(
    tween: Tween(end: focal),
    duration: const Duration(milliseconds: 110),
    curve: Curves.easeOutCubic,
    builder: (context, f, _) => _lens(f),
  );

  Widget _lens(Offset f) {
    final at = Offset(f.dx - scrollX, f.dy); // screen position of the focal point
    final title = spot?.title;
    final below = at.dy - lift - size / 2 - (title == null ? 0 : 60) < topSafe;
    final dy = below ? lift : -lift;
    final cx = at.dx.clamp(size / 2 + 4, viewWidth - size / 2 - 4).toDouble();
    final centre = Offset(cx, at.dy + dy);
    final labelLeft = (cx - 110).clamp(6.0, viewWidth - 226).toDouble();
    return Stack(clipBehavior: Clip.none, children: [
      // A thin stem from the lens to the finger point, so it's clear what is being magnified.
      Positioned(
        left: at.dx - 1,
        top: below ? at.dy + 8 : centre.dy + size / 2,
        width: 2,
        height: (lift - size / 2 - 8).clamp(0, 100).toDouble(),
        child: const DecoratedBox(decoration: BoxDecoration(color: Color(0x99FFF4DC))),
      ),
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
          child: DecoratedBox(
            key: const ValueKey('loupe-lens'),
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 18, offset: Offset(0, 8))]),
            child: ClipOval(
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                // The map, magnified around the focal point.
                Positioned(
                  left: size / 2 - f.dx * zoom,
                  top: size / 2 - f.dy * zoom,
                  width: mapW * zoom,
                  height: mapH * zoom,
                  child: Image.asset(mapImage, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                ),
                // The pin, magnified and centred.
                if (spot != null)
                  Center(
                    child: Container(
                      width: 44 * zoom,
                      height: 44 * zoom,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: open ? BL.gold : Colors.white54, width: 3.2), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4))]),
                      child: ClipOval(child: SpotIcon(spot!, size: 44 * zoom, dim: !open)),
                    ),
                  ),
                // Frosted rim.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xE6FFF4DC), width: 2.2),
                      gradient: RadialGradient(colors: [Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: .10), Colors.white.withValues(alpha: .32)], stops: const [0, .8, .93, 1]),
                    ),
                  ),
                ),
                // Shine.
                const Positioned(
                  left: 20, top: 9, right: 50, height: 27,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(54, 26)),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      if (title != null)
        Positioned(
          left: labelLeft,
          width: 220,
          top: below ? centre.dy + size / 2 + 6 : centre.dy - size / 2 - 58,
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
                        Text(hl(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(15.5, color: Colors.white)),
                        Text(hl(spot!.titleFa), maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: helperDir, style: BL.fa(11, color: Colors.white70)),
                      ]),
                    ),
                    if (level != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: open ? BL.gold : Colors.white24, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!open) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 11, color: Colors.white)),
                          Text(hl(level!), style: TextStyle(color: open ? BL.ink : Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
