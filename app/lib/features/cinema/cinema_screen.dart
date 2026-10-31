import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../grammar/grammar_data.dart';
import '../library/library_data.dart';
import '../shared/nav.dart';
import 'cinema_data.dart';

const cinemaDark = Color(0xFF17110F), cinemaPanel = Color(0xFF241B17);

/// The Picture House: "now showing" posters per level; tap one to watch, dub and answer questions.
class CinemaScreen extends ConsumerWidget {
  const CinemaScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final scenes = ref.watch(cinemaProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (scenes == null || topics == null || content == null) return const NavLoading();
    final gate = CinemaGate(ctrl, content, topics, scenes, unlockAll: ref.read(progressProvider).gatesOpen);
    final pad = MediaQuery.paddingOf(context);
    final watched = scenes.where((s) => ctrl.sceneDone(s.id)).length;
    return Scaffold(
      backgroundColor: cinemaDark,
      body: ListView(
        key: const ValueKey('cinema-list'),
        padding: EdgeInsets.fromLTRB(0, pad.top + 6, 0, pad.bottom + 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [NavButtons(light: true), SizedBox(width: 10), Flexible(child: Text('THE PICTURE HOUSE', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.gold)))]),
              const SizedBox(height: 10),
              Text('Cinema & dubbing', style: BL.display(28, color: Colors.white)),
              Text(hl('سینما و دوبله · صحنه‌های کوتاه بریتانیایی؛ تماشا کن، بعد خودت دوبله کن'), textDirection: helperDir, style: BL.fa(13, color: Colors.white70)),
              const SizedBox(height: 6),
              Text(hl('$watched of ${scenes.length} scenes watched  ·  watch, dub, answer'), key: const ValueKey('cinema-count'), style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
          for (final lv in Library.levels)
            if (gate.of(lv.code).isNotEmpty) _Row(level: lv, scenes: gate.of(lv.code), open: gate.levelOpen(lv.code)),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  final LibraryLevel level;
  final List<Scene> scenes;
  final bool open;
  const _Row({required this.level, required this.scenes, required this.open});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    return Padding(
      key: ValueKey('cine-level-${level.code}'),
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: open ? BL.red : Colors.white24, borderRadius: BorderRadius.circular(8)),
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
            const SizedBox(width: 6),
            Text(hl(open ? '${scenes.where((s) => ctrl.sceneDone(s.id)).length}/${scenes.length}' : 'Locked · قفل'), key: ValueKey('cine-status-${level.code}'), style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final s in scenes)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _Poster(
                    scene: s,
                    open: open,
                    done: ctrl.sceneDone(s.id),
                    dub: ctrl.dubScore(s.id),
                    onTap: () {
                      if (open) {
                        context.push('/cinema/${s.id}');
                      } else {
                        final (en, fa) = CinemaGate.why(level.code);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4), content: Text(hl('$en\n$fa'), key: const ValueKey('cine-locked-snack'))));
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Poster extends StatelessWidget {
  final Scene scene;
  final bool open, done;
  final int? dub;
  final VoidCallback onTap;
  const _Poster({required this.scene, required this.open, required this.done, required this.dub, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: ValueKey('scene-${scene.id}'),
        onTap: onTap,
        child: Container(
          width: 236,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 10, offset: const Offset(0, 4))]),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            Opacity(opacity: open ? 1 : .4, child: Image.asset(scene.stillAsset, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: cinemaPanel))),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.35, 1], colors: [Color(0x00000000), Color(0xEE0D0907)]))),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(scene.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(17, color: Colors.white, w: FontWeight.w700)),
                Text(hl(scene.titleFa), maxLines: 1, textDirection: helperDir, style: BL.fa(12, color: Colors.white70)),
                const SizedBox(height: 2),
                Text(hl('${scene.lines.length} lines  ·  ${scene.seconds}s  ·  dub ${scene.cast.firstWhere((c) => c.sp == scene.dub).spName}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            Positioned(
              top: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(5)),
                child: Text(hl(scene.level), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: cinemaDark)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(children: [
                if (dub != null)
                  Container(
                    key: ValueKey('scene-dub-${scene.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: Text(hl('🎙 $dub%'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                if (done) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: ValueKey('scene-done-${scene.id}'),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: BL.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                  ),
                ],
              ]),
            ),
            if (!open) const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
          ]),
        ),
      );
}
