import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/platform/loop_video.dart';
import '../shared/widgets.dart' show locationIcon;
import 'driving_data.dart';

/// The "video" for a Driving School dialogue, until real footage exists. A real clip (DLesson.videoAsset) plays here
/// when present. Otherwise: in the car, a drawn road seen through the windscreen that moves, sways, indicates and brakes
/// in time with the lines; elsewhere, the matching painting with a slow pan, or a people-free blurred backdrop.
/// Subtitles (English, optional Persian) sit along the bottom. It only animates while the scene plays.
class DriveStage extends StatefulWidget {
  final DLesson lesson;
  final int line; // current line, -1 before playing
  final bool playing, fa;
  const DriveStage({super.key, required this.lesson, required this.line, required this.playing, required this.fa});
  @override
  State<DriveStage> createState() => _DriveStageState();
}

class _DriveStageState extends State<DriveStage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_tick);
  double _t = 0, _road = 0, _speed = 0, _brake = 0, _blinkFrom = -99;
  Duration? _last;
  int _seenLine = -1;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(DriveStage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.line != _seenLine) {
      _seenLine = widget.line;
      final fx = widget.line >= 0 && widget.line < widget.lesson.lines.length ? widget.lesson.lines[widget.line].fx : null;
      if (fx == 'indicator') _blinkFrom = _t;
      if (fx == 'brake') _brake = 1;
    }
    if (widget.playing && !_c.isAnimating) {
      _last = null;
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  void _tick() {
    final now = _c.lastElapsedDuration ?? Duration.zero;
    final dt = _last == null ? 0.016 : ((now - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final target = widget.lesson.movingAt(max(widget.line, 0)) ? 1.0 : 0.0;
    setState(() {
      _t += dt;
      _speed += (target - _speed) * min(1, dt * (target > _speed ? .8 : 1.6)); // pull away gently, brake firmer
      _road = (_road + _speed * dt * 1.6) % 1;
      _brake = max(0, _brake - dt * .5);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final cur = widget.line >= 0 && widget.line < l.lines.length ? l.lines[widget.line] : null;
    final blinking = _t - _blinkFrom < 3.2;
    Widget scene;
    if (l.videoAsset != null) {
      scene = LoopVideo(key: const ValueKey('drv-video'), asset: l.videoAsset!);
    } else if (l.inCar) {
      scene = CustomPaint(key: const ValueKey('drv-road'), painter: RoadPainter(t: _t, road: _road, speed: _speed, blinkOn: blinking && (_t * 2.5).floor().isEven, brake: _brake));
    } else if (l.img != null) {
      final k = sin(_t * .25);
      scene = ClipRect(child: Transform.scale(key: const ValueKey('drv-painting'), scale: 1.12, child: Transform.translate(offset: Offset(k * 14, 0), child: Image.asset(l.img!, fit: BoxFit.cover))));
    } else {
      scene = Stack(key: const ValueKey('drv-card'), fit: StackFit.expand, children: [
        if (l.bg != null) Image.asset(l.bg!, fit: BoxFit.cover) else const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B4636), Color(0xFF1B140F)]))),
        Align(alignment: const Alignment(0, -.35), child: Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: Color(0xEEFBF7F0), shape: BoxShape.circle), child: Icon(locationIcon(l.icon), size: 52, color: const Color(0xFF6B4A2B)))),
      ]);
    }
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          scene,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('drv-subtitle'),
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC000000)])),
              child: cur == null
                  ? Text(widget.playing ? '' : 'Press play to start the scene', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(cur.name, key: const ValueKey('drv-sub-name'), style: const TextStyle(color: BL.gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
                      Text(cur.en, key: const ValueKey('drv-sub-en'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3)),
                      if (widget.fa) Align(alignment: Alignment.centerRight, child: Text(cur.fa, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white70))),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A British road seen from the driver's seat (left-hand traffic, so the kerb is on the left): sky, hedges,
/// a moving dashed centre line, then the dashboard with the wheel. No people are drawn.
class RoadPainter extends CustomPainter {
  final double t, road, speed, brake;
  final bool blinkOn;
  RoadPainter({required this.t, required this.road, required this.speed, required this.blinkOn, required this.brake});
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, hz = h * .42;
    final sway = sin(t * 1.3) * 2.5 * speed;
    c.save();
    c.translate(sway, sin(t * 7) * .6 * speed);
    c.drawRect(Rect.fromLTWH(-10, 0, w + 20, hz), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9FB8CC), Color(0xFFDCE3E6)]).createShader(Rect.fromLTWH(0, 0, w, hz)));
    // Hedges and trees scrolling past on both sides.
    final hedge = Paint()..color = const Color(0xFF5E7B4A);
    c.drawRect(Rect.fromLTWH(-10, hz - h * .05, w + 20, h * .05), hedge);
    for (var i = 0; i < 9; i++) {
      final x = ((i / 9 + road * .15) % 1) * (w + 60) - 30;
      c.drawCircle(Offset(x, hz - h * .07), h * .045, Paint()..color = const Color(0xFF4D6B3C));
    }
    c.drawRect(Rect.fromLTWH(-10, hz, w + 20, h - hz), Paint()..color = const Color(0xFF7C8A5C));
    // Road (vanishing point slightly right of centre: we drive on the left).
    final vp = Offset(w * .56, hz);
    final tarmac = Path()
      ..moveTo(vp.dx - 6, hz)
      ..lineTo(vp.dx + 6, hz)
      ..lineTo(w * 1.25, h)
      ..lineTo(-w * .2, h)
      ..close();
    c.drawPath(tarmac, Paint()..color = const Color(0xFF55585C));
    final edge = Paint()
      ..color = const Color(0xFFEDEDED)
      ..strokeWidth = 2;
    c.drawLine(Offset(vp.dx - 5, hz), Offset(-w * .12, h), edge);
    c.drawLine(Offset(vp.dx + 5, hz), Offset(w * 1.18, h), edge);
    // Dashed centre line: dashes stream towards us (perspective: z from far 1 to near 0).
    final dash = Paint()..color = Colors.white;
    for (var i = 0; i < 8; i++) {
      final z0 = ((i + road) / 8), z1 = z0 + .045;
      double y(double z) => hz + (h - hz) * pow(z, 2.2);
      double x(double z) => vp.dx + (w * .62 - vp.dx) * pow(z, 2.2);
      final a = Offset(x(z0), y(z0)), b = Offset(x(min(z1, 1)), y(min(z1, 1)));
      c.drawLine(a, b, dash..strokeWidth = 1 + 5 * z0);
    }
    c.restore();
    // Dashboard and wheel (still: the camera is in the car).
    final dashTop = h * .70;
    c.drawPath(
      Path()
        ..moveTo(0, dashTop + h * .04)
        ..quadraticBezierTo(w * .5, dashTop - h * .05, w, dashTop + h * .04)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF1E1E22),
    );
    final wheel = Offset(w * .3, h * 1.02);
    c.drawCircle(wheel, h * .26, Paint()
      ..color = const Color(0xFF2C2C31)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * .05);
    // Instrument glow, indicator arrows and the brake cue.
    final ind = Paint()..color = blinkOn ? const Color(0xFF39D353) : const Color(0xFF2F3A2F);
    for (final dir in [-1, 1]) {
      final cx = w * .3 + dir * w * .07, cy = dashTop + h * .035;
      c.drawPath(Path()
        ..moveTo(cx + dir * 9, cy)
        ..lineTo(cx - dir * 3, cy - 7)
        ..lineTo(cx - dir * 3, cy + 7)
        ..close(), ind);
    }
    if (brake > 0) c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFB3261E).withValues(alpha: .12 * brake));
    final tp = TextPainter(text: TextSpan(text: speed > .05 ? '${(speed * 28).round()} mph' : 'P', style: const TextStyle(color: Color(0xFFF2C46D), fontSize: 11, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(w * .3 - tp.width / 2, dashTop + h * .035 - tp.height / 2));
  }

  @override
  bool shouldRepaint(RoadPainter o) => o.t != t || o.road != road || o.blinkOn != blinkOn || o.brake != brake;
}
