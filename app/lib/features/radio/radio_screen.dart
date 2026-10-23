import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../grammar/grammar_data.dart';
import '../library/library_data.dart';
import '../shared/nav.dart';
import 'radio_data.dart';

const radioDark = Color(0xFF0F1A24), radioPanel = Color(0xFF1A2733), onAirRed = Color(0xFFE5483B);

/// Hackney Hum: today's schedule, one block per level. Tap a programme to listen.
class RadioScreen extends ConsumerWidget {
  const RadioScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final segs = ref.watch(radioProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (segs == null || topics == null || content == null) return const NavLoading();
    final gate = RadioGate(ctrl, content, topics, segs, unlockAll: ref.read(progressProvider).unlockAll);
    final pad = MediaQuery.paddingOf(context);
    final done = segs.where((s) => ctrl.segmentDone(s.id)).length;
    return Scaffold(
      backgroundColor: radioDark,
      body: ListView(
        key: const ValueKey('radio-list'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          Row(children: [
            const NavButtons(light: true),
            const SizedBox(width: 10),
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: onAirRed, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('ON AIR · LOCAL RADIO', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.gold)),
          ]),
          const SizedBox(height: 10),
          Text(hl(RadioStation.station), style: BL.display(30, color: Colors.white)),
          Text(hl('رادیو محلی هاکنی · اول گوش کن، بعد جواب بده'), textDirection: helperDir, style: BL.fa(13, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(hl('$done of ${segs.length} programmes understood  ·  listen, then answer'), key: const ValueKey('radio-count'), style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600, fontSize: 12.5)),
          for (final lv in Library.levels)
            if (gate.of(lv.code).isNotEmpty) _Block(level: lv, segs: gate.of(lv.code), open: gate.levelOpen(lv.code)),
        ],
      ),
    );
  }
}

class _Block extends ConsumerWidget {
  final LibraryLevel level;
  final List<Segment> segs;
  final bool open;
  const _Block({required this.level, required this.segs, required this.open});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    return Padding(
      key: ValueKey('radio-level-${level.code}'),
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: open ? onAirRed : Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!open) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 12, color: Colors.white)),
              Text(hl(level.code), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: hl(level.name), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                const TextSpan(text: '  '),
                TextSpan(text: hl(level.nameFa), style: BL.fa(13, color: Colors.white60)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(hl(open ? '${segs.where((s) => ctrl.segmentDone(s.id)).length}/${segs.length}' : 'Locked · قفل'), key: ValueKey('radio-status-${level.code}'), style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        for (final s in segs)
          _Card(
            seg: s,
            open: open,
            done: ctrl.segmentDone(s.id),
            onTap: () {
              if (open) {
                context.push('/radio/${s.id}');
              } else {
                final (en, fa) = RadioGate.why(level.code);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4), content: Text(hl('$en\n$fa'), key: const ValueKey('radio-locked-snack'))));
              }
            },
          ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final Segment seg;
  final bool open, done;
  final VoidCallback onTap;
  const _Card({required this.seg, required this.open, required this.done, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final (kind, _, icon) = RadioStation.kinds[seg.kind]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: radioPanel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('seg-${seg.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Opacity(
            opacity: open ? 1 : .45,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                SizedBox(
                  width: 50,
                  child: Column(children: [
                    Text(hl(seg.slot), style: const TextStyle(color: BL.gold, fontWeight: FontWeight.w900, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(height: 3),
                    Icon(open ? icon : Icons.lock_rounded, size: 18, color: Colors.white60),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hl(seg.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(hl(seg.titleFa), maxLines: 1, textDirection: helperDir, style: BL.fa(12, color: Colors.white60)),
                    Text(hl('$kind  ·  ${seg.seconds}s  ·  ${seg.voices.join(', ')}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (done)
                  Container(
                    key: ValueKey('seg-done-${seg.id}'),
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: BL.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                  )
                else if (open)
                  const Icon(Icons.play_circle_fill_rounded, color: Colors.white38, size: 26),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
