import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../shared/widgets.dart';

/// The Level 1 path: calm storybook pages, one unit per painting, lessons as stepping stones.
class CourseScreen extends ConsumerWidget {
  const CourseScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final course = c.course;
    final done = course.lessons.where(ctrl.lessonDone).length;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(8, pad.top + 6, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/'), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THE COURSE  ·  ${course.units.map((u) => u.level).toSet().length} LEVELS', style: const TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red)),
                        Text('British life, step by step', maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(24)),
                      ],
                    ),
                  ),
                  Text('$done/${course.lessons.length}', style: BL.display(18, color: BL.green)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            sliver: SliverToBoxAdapter(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: course.lessons.isEmpty ? 0 : done / course.lessons.length, minHeight: 6, backgroundColor: BL.mist, color: BL.green),
              ),
            ),
          ),
          for (var i = 0; i < course.units.length; i++) ...[
            if (i == 0 || course.units[i - 1].level != course.units[i].level) SliverToBoxAdapter(child: _LevelHeader(level: course.units[i].level)),
            SliverPadding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 0), sliver: SliverToBoxAdapter(child: FadeSlideIn(delayMs: 40 * i, child: _UnitBanner(c: c, u: course.units[i], index: i, open: ctrl.unitOpen(course, i))))),
            SliverToBoxAdapter(child: _Stones(c: c, u: course.units[i])),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 40 + pad.bottom)),
        ],
      ),
    );
  }
}

class _UnitBanner extends StatelessWidget {
  final ContentBundle c;
  final Unit u;
  final int index;
  final bool open;
  const _UnitBanner({required this.c, required this.u, required this.index, required this.open});
  @override
  Widget build(BuildContext context) {
    final img = c.place(u.place)?.image;
    return Container(
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: BL.shadow(.18)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (img != null) Image.asset(img, fit: BoxFit.cover, color: open ? null : Colors.black45, colorBlendMode: open ? null : BlendMode.darken),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00140E0A), Color(0xE6140E0A)], stops: [.3, 1]))),
          Positioned(
            left: 18,
            right: 18,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('UNIT ${c.course.numberInLevel(u)}', style: const TextStyle(color: Color(0xFFE8C987), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                    if (!open) ...[const SizedBox(width: 6), const Icon(Icons.lock_rounded, size: 13, color: Color(0xFFE8C987))],
                  ],
                ),
                Text(u.title, style: BL.display(23, color: Colors.white)),
                Text(u.titleFa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stones extends ConsumerWidget {
  final ContentBundle c;
  final Unit u;
  const _Stones({required this.c, required this.u});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final course = c.course;
    final items = [...u.lessons.map((l) => (l, false)), (u.lessons.first, true)];
    final current = course.lessons.where((l) => ctrl.lessonOpen(course, l) && !ctrl.lessonDone(l)).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          for (final (i, (l, check)) in items.indexed)
            Builder(
              builder: (context) {
                final open = check ? ctrl.unitOpen(course, course.units.indexOf(u)) && u.lessons.every(ctrl.lessonDone) || p.unlockAll : ctrl.lessonOpen(course, l);
                final done = check ? ctrl.unitPassed(u) : ctrl.lessonDone(l);
                final here = !check && l == current;
                final dx = const [0.0, .32, .5, .32, 0.0, -.32, -.5, -.32][i % 8];
                return Align(
                  alignment: Alignment(dx, 0),
                  child: Pressable(
                    onTap: open ? () => context.push(check ? '/practice/${u.id}' : '/lesson/${l.id}') : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          _Stone(done: done, open: open, here: here, check: check, child: check ? null : Avatar(c.character(l.lead), size: 46, ring: false)),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 150,
                            child: Text(check ? 'Unit review' : l.title, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: open ? BL.ink : BL.muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Stone extends StatefulWidget {
  final bool done, open, here, check;
  final Widget? child;
  const _Stone({required this.done, required this.open, required this.here, required this.check, this.child});
  @override
  State<_Stone> createState() => _StoneState();
}

class _StoneState extends State<_Stone> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.here && !calm && !_a.isAnimating) _a.repeat(reverse: true);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.done ? BL.gold : (widget.here ? BL.green : (widget.open ? BL.mist : const Color(0xFFDCD5C8)));
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.check ? (widget.done ? BL.gold : BL.navy) : BL.paper,
          border: Border.all(color: ring, width: 4),
          boxShadow: [BoxShadow(color: (widget.here ? BL.green : Colors.black).withValues(alpha: widget.here ? .18 + .22 * _a.value : .08), blurRadius: 10 + 10 * _a.value, spreadRadius: widget.here ? 2 * _a.value : 0)],
        ),
        child: child,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.check) Icon(widget.done ? Icons.emoji_events_rounded : Icons.star_rounded, color: Colors.white, size: 32) else Opacity(opacity: widget.open ? 1 : .45, child: widget.child),
          if (widget.done && !widget.check) const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 11, backgroundColor: BL.green, child: Icon(Icons.check_rounded, size: 14, color: Colors.white))),
          if (!widget.open) const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 11, backgroundColor: BL.muted, child: Icon(Icons.lock_rounded, size: 12, color: Colors.white))),
        ],
      ),
    );
  }
}


class _LevelHeader extends StatelessWidget {
  final int level;
  const _LevelHeader({required this.level});
  @override
  Widget build(BuildContext context) {
    final info = Course.levelInfo[level];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: BL.navy, borderRadius: BorderRadius.circular(99)),
            child: Text('LEVEL $level  ·  ${info?.$1 ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info?.$2 ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(19)),
                Text(info?.$3 ?? '', textDirection: TextDirection.rtl, style: BL.fa(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
