import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../shared/widgets.dart';

/// The Level 1 path: calm storybook pages, one unit per painting, lessons as stepping stones.
class CourseScreen extends ConsumerStatefulWidget {
  /// Level to open on (from a level chip, the course card or `/course?level=N`).
  final int? level;
  const CourseScreen({super.key, this.level});
  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  final _levelKeys = <int, GlobalKey>{};
  bool _jumped = false;

  GlobalKey _keyFor(int level) => _levelKeys.putIfAbsent(level, () => GlobalKey(debugLabel: 'level-$level'));

  /// Scroll so that [level]'s header is at the top. Each level opens on its own units.
  void _goToLevel(int level) {
    final ctx = _levelKeys[level]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final course = c.course;
    final done = course.lessons.where(ctrl.lessonDone).length;
    final levels = course.units.map((u) => u.level).toSet().toList()..sort();
    final target = widget.level ?? (ctrl.startLevel > 1 ? ctrl.startLevel : null);
    if (!_jumped && target != null && target > levels.first) {
      _jumped = true;
      // Slivers build lazily: jump near the level first, then settle on its header.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final sc = PrimaryScrollController.maybeOf(context);
        for (var k = 0; k < 40 && mounted && _levelKeys[target]?.currentContext == null; k++) {
          if (sc == null || !sc.hasClients) break;
          await sc.animateTo(sc.offset + 1600, duration: const Duration(milliseconds: 60), curve: Curves.linear);
        }
        if (mounted) _goToLevel(target);
      });
    }
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: CustomScrollView(
        primary: true,
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
          // Level chips: tap a level to jump straight to its own units.
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                children: [
                  for (final lv in levels)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        key: ValueKey('levelchip-$lv'),
                        label: Text('Level $lv  ·  ${Course.levelInfo[lv]?.$1 ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        backgroundColor: lv == target ? BL.navy.withValues(alpha: .12) : BL.paper,
                        onPressed: () async {
                          final sc = PrimaryScrollController.maybeOf(context);
                          for (var k = 0; k < 40 && mounted && _levelKeys[lv]?.currentContext == null; k++) {
                            if (sc == null || !sc.hasClients) break;
                            final before = sc.offset;
                            await sc.animateTo((sc.offset + 1600).clamp(0, sc.position.maxScrollExtent), duration: const Duration(milliseconds: 60), curve: Curves.linear);
                            if (sc.offset == before) break;
                          }
                          _goToLevel(lv);
                        },
                      ),
                    ),
                  for (final pk in course.packs)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        key: ValueKey('packchip-${pk.id}'),
                        avatar: const Icon(Icons.work_outline_rounded, size: 16, color: BL.gold),
                        label: Text(pk.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        backgroundColor: BL.paper,
                        onPressed: () => context.push('/pack/${pk.id}'),
                      ),
                    ),
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
            if (i == 0 || course.units[i - 1].level != course.units[i].level) SliverToBoxAdapter(child: KeyedSubtree(key: _keyFor(course.units[i].level), child: _LevelHeader(level: course.units[i].level))),
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
    final pack = course.packOf(u);
    final current = (pack?.lessons ?? course.lessons).where((l) => ctrl.lessonOpen(course, l) && !ctrl.lessonDone(l)).firstOrNull;
    final ui = course.units.indexOf(u);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          for (final (i, (l, check)) in items.indexed)
            Builder(
              builder: (context) {
                final open = check ? (ui < 0 || ctrl.unitOpen(course, ui)) && u.lessons.every(ctrl.lessonDone) || p.unlockAll : ctrl.lessonOpen(course, l);
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


/// Small "PREMIUM" badge for Career Packs (packs are unlocked for now).
class PremiumBadge extends StatelessWidget {
  final bool dark;
  const PremiumBadge({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFC9A04C)]),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.workspace_premium_rounded, size: 12, color: BL.ink),
      SizedBox(width: 3),
      Text('PREMIUM', style: TextStyle(color: BL.ink, fontSize: 9.5, letterSpacing: 1.1, fontWeight: FontWeight.w900)),
    ]),
  );
}

/// One compact entry per Career Pack (home + course), opens the pack path.
class PackCard extends ConsumerWidget {
  final ContentBundle c;
  final Pack pack;
  const PackCard(this.c, this.pack, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final all = pack.lessons.toList();
    final done = all.where(ctrl.lessonDone).length;
    return Pressable(
      key: ValueKey('pack-${pack.id}'),
      onTap: () => context.push('/pack/${pack.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(22), boxShadow: BL.shadow(.08)),
        child: Row(children: [
          Avatar(c.character(pack.lead), size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Text('CAREER PACK', style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
                SizedBox(width: 8),
                PremiumBadge(),
              ]),
              const SizedBox(height: 2),
              Text(pack.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(18)),
              Text('${all.length} lessons · ${pack.levels} · $done done', style: const TextStyle(fontSize: 12.5, color: BL.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: BL.muted, size: 26),
        ]),
      ),
    );
  }
}

/// A Career Pack path: same stepping stones as the course, grouped by CEFR band, free order.
class PackScreen extends ConsumerWidget {
  final String id;
  const PackScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pack = c?.course.pack(id);
    if (c == null || pack == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pad = MediaQuery.paddingOf(context);
    final lead = c.character(pack.lead);
    final all = pack.lessons.toList();
    final done = all.where(ctrl.lessonDone).length;
    return Scaffold(
      backgroundColor: BL.cream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, pad.top + 6, 20, 0),
              child: Row(children: [
                IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/course'), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
                const Expanded(child: Text('CAREER PACK', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))),
                Text('$done/${all.length}', style: BL.display(18, color: BL.green)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(lead, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pack.title, style: BL.display(26)),
                    Text(pack.titleFa, textDirection: TextDirection.rtl, style: BL.fa(13, color: BL.muted)),
                    const SizedBox(height: 6),
                    Row(children: [const PremiumBadge(), const SizedBox(width: 8), Text('${pack.levels} · free for now', style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600))]),
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pack.blurb, style: const TextStyle(fontSize: 14, height: 1.35, color: BL.ink)),
                const SizedBox(height: 4),
                SizedBox(width: double.infinity, child: Text(pack.blurbFa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted))),
              ]),
            ),
          ),
          for (var i = 0; i < pack.units.length; i++) ...[
            if (i == 0 || pack.units[i - 1].cefr != pack.units[i].cefr)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: BL.navy, borderRadius: BorderRadius.circular(99)),
                      child: Text(pack.units[i].cefr ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
                    ),
                  ]),
                ),
              ),
            SliverPadding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), sliver: SliverToBoxAdapter(child: _UnitBanner(c: c, u: pack.units[i], index: i, open: true))),
            SliverToBoxAdapter(child: _Stones(c: c, u: pack.units[i])),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 40 + pad.bottom)),
        ],
      ),
    );
  }
}
