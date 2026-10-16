import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Muted, looping, inline <video> drawn over the painting (poster = painting, so failure = still image).
/// pointer-events:none so the Flutter tap layer above keeps receiving every touch.
class LoopVideo extends StatelessWidget {
  final String asset; // e.g. assets/places/kitchen_loop.mp4
  final String? poster;
  const LoopVideo({super.key, required this.asset, this.poster});
  static final _registered = <String>{};

  @override
  Widget build(BuildContext context) {
    final type = 'loop-video-$asset';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
        final v = web.HTMLVideoElement()
          ..src = 'assets/$asset'
          ..muted = true
          ..autoplay = true
          ..loop = true
          ..preload = 'auto'
          ..setAttribute('playsinline', '')
          ..setAttribute('webkit-playsinline', '')
          ..setAttribute('muted', '')
          ..setAttribute('disablepictureinpicture', '');
        if (poster != null) v.poster = 'assets/$poster';
        v.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = 'fill'
          ..pointerEvents = 'none'
          ..backgroundColor = 'transparent';
        v.play();
        return v;
      });
    }
    return IgnorePointer(child: HtmlElementView(viewType: type));
  }
}
