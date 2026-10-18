import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../grammar/grammar_data.dart';
import '../library/library_data.dart';
import '../shared/nav.dart';
import 'missions_data.dart';

/// Real-life missions: the ground rules, then the missions per level.
class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final ms = ref.watch(missionsProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (ms == null || topics == null || content == null) return const NavLoading();
    final gate = MissionGate(ctrl, content, topics, ms, unlockAll: ref.read(progressProvider).unlockAll);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: const ValueKey('missions-list'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('OUT & ABOUT', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 10),
          Text('Real-life missions', style: BL.display(28)),
          Text('مأموریت‌های زندگی واقعی · آماده شو، برو، بعد گزارش بده', textDirection: TextDirection.rtl, style: BL.fa(13, color: BL.muted)),
          const SizedBox(height: 6),
          Text('${ctrl.missionsCompleted} of ${ms.length} missions done  ·  prepare, go, check in', key: const ValueKey('missions-count'), style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
          const SizedBox(height: 14),
          const _Safety(),
          for (final lv in Library.levels)
            if (gate.of(lv.code).isNotEmpty) _Block(level: lv, ms: gate.of(lv.code), open: gate.levelOpen(lv.code)),
        ],
      ),
    );
  }
}

class _Safety extends StatelessWidget {
  const _Safety();
  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('missions-safety'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.mist)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.shield_rounded, size: 18, color: BL.green),
            const SizedBox(width: 6),
            const Text('Stay safe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            const Spacer(),
            Text('ایمن بمان', textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted)),
          ]),
          const SizedBox(height: 6),
          for (final (en, fa) in Missions.safety)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: BL.muted)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(en, style: const TextStyle(fontSize: 12.5, height: 1.35)),
                    Text(fa, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}

class _Block extends ConsumerWidget {
  final LibraryLevel level;
  final List<Mission> ms;
  final bool open;
  const _Block({required this.level, required this.ms, required this.open});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    return Padding(
      key: ValueKey('mis-level-${level.code}'),
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: open ? BL.red : BL.muted.withValues(alpha: .5), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!open) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 12, color: Colors.white)),
              Text(level.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: level.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const TextSpan(text: '  '),
                TextSpan(text: level.nameFa, style: BL.fa(13, color: BL.muted)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(open ? '${ms.where((m) => ctrl.missionDone(m.id)).length}/${ms.length}' : 'Locked · قفل', key: ValueKey('mis-status-${level.code}'), style: const TextStyle(color: BL.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        for (final m in ms)
          _Card(
            m: m,
            open: open,
            done: ctrl.missionDone(m.id),
            pending: ctrl.missionPending(m.id),
            onTap: () {
              if (open) {
                context.push('/missions/${m.id}');
              } else {
                final (en, fa) = MissionGate.why(level.code);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4), content: Text('$en\n$fa', key: const ValueKey('mis-locked-snack'))));
              }
            },
          ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final Mission m;
  final bool open, done, pending;
  final VoidCallback onTap;
  const _Card({required this.m, required this.open, required this.done, required this.pending, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: BL.paper,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey('mis-${m.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Opacity(
              opacity: open ? 1 : .5,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  ClipOval(child: Image.asset(m.icon, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 46, height: 46))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(m.titleFa, maxLines: 1, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                      Text(m.goal, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BL.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  if (!open)
                    const Icon(Icons.lock_rounded, color: BL.muted, size: 20)
                  else if (done)
                    Container(
                      key: ValueKey('mis-done-${m.id}'),
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: BL.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                    )
                  else if (pending)
                    Container(
                      key: ValueKey('mis-pending-${m.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(99)),
                      child: const Text('Check in', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: BL.ink)),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: BL.muted),
                ]),
              ),
            ),
          ),
        ),
      );
}
