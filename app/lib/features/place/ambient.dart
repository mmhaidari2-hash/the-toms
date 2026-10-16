import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Procedural ambient motion over a painted place (no video, no download: works offline by construction).
/// Layers: tea steam, rain on the window, warm light flicker, gentle breathing of each person.
/// Shown only when [enabled] and the OS does not ask for reduced motion.
class AmbientSpec {
  final List<Offset> steam; // cup/teapot mouths, normalised image coords
  final List<Rect> windows; // glass areas for rain (kept clear of people)
  final Offset? light; // light source for the warm flicker
  final List<Rect> breathe; // torso boxes (normalised) that rise and fall
  final String? video; // looping image-to-video clip of the painting itself (preferred over procedural layers)
  const AmbientSpec({this.video, this.steam = const [], this.windows = const [], this.light, this.breathe = const []});
}

const ambientSpecs = <String, AmbientSpec>{
  'kitchen': AmbientSpec(
    steam: [Offset(.455, .50), Offset(.36, .575), Offset(.54, .655), Offset(.73, .77)],
    windows: [Rect.fromLTRB(.04, .0, .25, .26), Rect.fromLTRB(.035, .26, .075, .46), Rect.fromLTRB(.225, .26, .25, .46)],
    light: Offset(.14, .2),
    breathe: [
      Rect.fromLTRB(.0, .28, .24, .78), // leslie
      Rect.fromLTRB(.32, .25, .58, .62), // tom
      Rect.fromLTRB(.56, .42, .71, .70), // nicola
      Rect.fromLTRB(.69, .37, .92, .76), // ryan
      Rect.fromLTRB(.19, .58, .42, 1.0), // william
    ],
  ),
};

bool ambientAllowed(BuildContext context, bool enabled) => enabled && !MediaQuery.of(context).disableAnimations;

class AmbientLayer extends StatefulWidget {
  final String image;
  final AmbientSpec spec;
  const AmbientLayer({super.key, required this.image, required this.spec});
  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends State<AmbientLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  ui.Image? _img;
  ImageStream? _stream;
  late final ImageStreamListener _l = ImageStreamListener((info, _) => setState(() => _img = info.image));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_l);
    _stream = AssetImage(widget.image).resolve(createLocalImageConfiguration(context))..addListener(_l);
  }

  @override
  void dispose() {
    _stream?.removeListener(_l);
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: _AmbientPainter(_t, widget.spec, _img), size: Size.infinite),
        ),
      );
}

class _AmbientPainter extends CustomPainter {
  final Animation<double> t;
  final AmbientSpec s;
  final ui.Image? img;
  _AmbientPainter(this.t, this.s, this.img) : super(repaint: t);

  @override
  void paint(Canvas c, Size z) {
    final sec = t.value * 60;
    // 1. Breathing: redraw each torso from the painting, scaled ~0.7% upward from its base, feathered edges.
    final im = img;
    if (im != null) {
      for (var i = 0; i < s.breathe.length; i++) {
        final r = s.breathe[i];
        final k = 1 + .007 * (.5 + .5 * math.sin(sec * 2 * math.pi / (3.6 + i * .35) + i * 1.7));
        final dst = Rect.fromLTRB(r.left * z.width, r.top * z.height, r.right * z.width, r.bottom * z.height);
        final src = Rect.fromLTRB(r.left * im.width, r.top * im.height, r.right * im.width, r.bottom * im.height);
        c.saveLayer(dst.inflate(4), Paint());
        c.save();
        c.translate(dst.center.dx, dst.bottom);
        c.scale(1 + (k - 1) * .4, k);
        c.translate(-dst.center.dx, -dst.bottom);
        c.drawImageRect(im, src, dst, Paint()..filterQuality = FilterQuality.medium);
        c.restore();
        c.drawRect(
          dst.inflate(4),
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.radial(dst.center, dst.shortestSide * .62, [Colors.white, Colors.white.withValues(alpha: 0)], [.55, 1]),
        );
        c.restore();
      }
    }
    // 2. Warm window light flicker (clouds passing).
    final l = s.light;
    if (l != null) {
      final a = .05 + .045 * (math.sin(sec * .9) * .6 + math.sin(sec * 2.3 + 1) * .4);
      final p = Offset(l.dx * z.width, l.dy * z.height);
      c.drawCircle(p, z.width * .45,
          Paint()
            ..blendMode = BlendMode.softLight
            ..shader = ui.Gradient.radial(p, z.width * .45, [const Color(0xFFFFE2A8).withValues(alpha: a.clamp(0, 1) * 4), const Color(0x00FFE2A8)]));
    }
    // 3. Rain on the window.
    for (final w in s.windows) {
      final r = Rect.fromLTRB(w.left * z.width, w.top * z.height, w.right * z.width, w.bottom * z.height);
      c.save();
      c.clipRect(r);
      c.drawRect(r, Paint()..color = const Color(0x1A5A6E80));
      final rain = Paint()
        ..color = const Color(0x70E8F0F8)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      final rnd = math.Random(7);
      for (var i = 0; i < (r.width * r.height / 900).clamp(6, 60).toInt(); i++) {
        final x0 = rnd.nextDouble(), sp = .55 + rnd.nextDouble() * .5, ph = rnd.nextDouble();
        final y = ((sec * sp + ph) % 1.0) * (r.height + 30) - 15;
        final x = r.left + x0 * r.width - y * .08;
        c.drawLine(Offset(x, r.top + y), Offset(x - 1.5, r.top + y + 9 + sp * 6), rain);
      }
      // slow drops running down the glass
      final drop = Paint()..color = const Color(0x55FFFFFF);
      for (var i = 0; i < 9; i++) {
        final x0 = rnd.nextDouble(), sp = .04 + rnd.nextDouble() * .05, ph = rnd.nextDouble();
        final y = ((sec * sp + ph) % 1.0) * r.height;
        c.drawCircle(Offset(r.left + x0 * r.width, r.top + y), 1.6, drop);
      }
      c.restore();
    }
    // 4. Tea steam: soft wisps rising and swaying.
    for (var i = 0; i < s.steam.length; i++) {
      final o = Offset(s.steam[i].dx * z.width, s.steam[i].dy * z.height);
      final h = z.height * .085;
      for (var j = 0; j < 7; j++) {
        final life = ((sec * .28 + j / 7 + i * .27) % 1.0);
        final y = o.dy - life * h;
        final x = o.dx + math.sin(life * 5 + sec * 1.3 + i + j) * z.width * .01 * (1 + life * 2);
        final rad = z.width * (.008 + life * .02);
        final alpha = (math.sin(life * math.pi) * .24).clamp(0.0, 1.0);
        final p = Offset(x, y);
        c.drawCircle(p, rad, Paint()..shader = ui.Gradient.radial(p, rad, [Colors.white.withValues(alpha: alpha), Colors.white.withValues(alpha: 0)]));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter o) => o.img != img;
}
