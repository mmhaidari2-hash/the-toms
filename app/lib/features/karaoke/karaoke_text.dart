import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/platform/voice.dart';

/// Word-by-word highlight while an Azure clip plays.
/// Timings are estimated from clip duration × character weight (no extra Azure spend).
/// If [timings] is provided (ms from start per word), those win.
class KaraokeText extends StatefulWidget {
  final String speaker;
  final String text;
  final TextStyle? style;
  final TextStyle? activeStyle;
  final List<int>? timings; // optional ms offsets, length == words
  final double rate;
  final VoidCallback? onDone;
  const KaraokeText({super.key, required this.speaker, required this.text, this.style, this.activeStyle, this.timings, this.rate = 1, this.onDone});
  @override
  State<KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<KaraokeText> with SingleTickerProviderStateMixin {
  late final List<String> _words;
  int _i = -1;
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    _words = widget.text.trim().isEmpty ? const [] : widget.text.split(RegExp(r'\s+'));
    _play();
  }

  Future<void> _play() async {
    if (_words.isEmpty) { widget.onDone?.call(); return; }
    final ok = await Voice.say(widget.speaker, widget.text, rate: widget.rate);
    if (!mounted) return;
    // Approximate total duration: ~160 wpm at rate 1 → ms/word
    final msPerWord = (60000 / (160 * widget.rate)).round().clamp(180, 900);
    final timings = widget.timings ?? [for (var i = 0; i < _words.length; i++) i * msPerWord];
    final total = timings.isEmpty ? msPerWord * _words.length : (timings.last + msPerWord);
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    _c!.addListener(() {
      final ms = (_c!.value * total).round();
      var idx = 0;
      for (var i = 0; i < timings.length; i++) {
        if (timings[i] <= ms) idx = i;
      }
      if (idx != _i && mounted) setState(() => _i = idx);
    });
    await _c!.forward();
    if (mounted) setState(() => _i = _words.length);
    if (ok) widget.onDone?.call();
  }

  @override
  void dispose() {
    _c?.dispose();
    Voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? const TextStyle(fontSize: 18, height: 1.45, color: BL.ink, fontWeight: FontWeight.w600);
    final active = widget.activeStyle ?? base.copyWith(color: BL.red, backgroundColor: const Color(0x33C45C26));
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < _words.length; i++)
          Text(_words[i], style: i == _i ? active : (i < _i ? base.copyWith(color: BL.muted) : base)),
      ],
    );
  }
}
