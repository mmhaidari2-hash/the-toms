import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/engine/growth_engine.dart';
import '../../core/engine/leitner.dart';
import '../../core/engine/emotion_engine.dart';
import '../../core/engine/weekly.dart';
import '../../core/i18n/strings.dart';
import '../../core/models/character.dart';
import '../../core/models/place.dart';
import '../place/place_widgets.dart';
import '../../core/models/user_progress.dart';
import '../shared/widgets.dart';
import '../shared/nav.dart';
import 'home_extras.dart';
import '../course/course_screen.dart' show PackCard;
import '../../core/engine/mission.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    return Scaffold(
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator(color: BL.navy)),
        error: (e, _) => ErrorState(message: '$e', onRetry: () => ref.invalidate(contentProvider)),
        data: (c) => _HomeBody(c),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: BL.muted),
          const SizedBox(height: 12),
          Text('The kettle’s gone cold', style: BL.display(22)),
          const SizedBox(height: 6),
          Text(
            'We couldn’t load the story. $message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: BL.muted),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _HomeBody extends ConsumerWidget {
  final ContentBundle c;
  const _HomeBody(this.c);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    if (!p.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/onboarding');
      });
    }
    final h = DateTime.now().hour;
    final family = c.characters.where((x) => x.family).toList();
    final greet = h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          PinnedHeaderSliver(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Padding(padding: EdgeInsets.fromLTRB(14, 8, 14, 6), child: Align(alignment: Alignment.centerLeft, child: NavButtons())),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverList.list(
              children: [
                FadeSlideIn(
                  child: _Header(
                    greet: greet,
                    p: p,
                    onDemo: () {
                      ctrl.setUnlockAll(!p.unlockAll);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(p.unlockAll ? 'Demo mode off' : 'Demo mode: every level unlocked')));
                    },
                  ),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(delayMs: 60, child: ContinueHero(c)),
                const SizedBox(height: 14),
                FadeSlideIn(delayMs: 90, child: CourseCard(c)),
                for (final pk in c.course.packs) ...[const SizedBox(height: 10), FadeSlideIn(delayMs: 100, child: PackCard(c, pk))],
                const SizedBox(height: 14),
                FadeSlideIn(delayMs: 110, child: FamilyTimelineCard(c)),
                const SizedBox(height: 28),
                _SectionTitle('Chapter 1', tr(p.lang, 'chapter1'), lang: p.lang),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverToBoxAdapter(child: FadeSlideIn(delayMs: 120, child: ChapterStrip(c))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 12),
            sliver: SliverToBoxAdapter(child: _SectionTitle('The family', tr(p.lang, 'family'), lang: p.lang)),
          ),
          SliverToBoxAdapter(child: FadeSlideIn(delayMs: 160, child: FamilyRow(c, family))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverToBoxAdapter(child: FadeSlideIn(delayMs: 200, child: _MissionCard(c: c, p: p))),
          ),
          for (var t = 0; t < c.tiers.length; t++) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
              sliver: SliverToBoxAdapter(
                child: _LevelHeader(c: c, index: t, current: ctrl.currentTier(c) == t, open: ctrl.tierUnlocked(t, c), done: ctrl.completedInTier(t, c)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 228,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final pl in c.tiers[t].places)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _PlaceCard(c: c, place: pl, open: ctrl.placeOpen(pl.id, c), tierOpen: ctrl.tierUnlocked(t, c), done: pl.sceneIds.where(p.completedScenes.contains).length),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
            sliver: SliverToBoxAdapter(child: _SectionTitle('Growing up', tr(p.lang, 'growingUp'), lang: p.lang)),
          ),
          SliverToBoxAdapter(child: GrowingUpStrip(c)),
          SliverToBoxAdapter(child: SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String en, fa;
  final String lang;
  const _SectionTitle(this.en, this.fa, {this.lang = 'fa'});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(en, style: BL.display(22)),
      const SizedBox(width: 12),
      Expanded(child: Text(fa, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: dirOf(lang), style: BL.fa(13))),
    ],
  );
}

class _Header extends StatelessWidget {
  final String greet;
  final UserProgress p;
  final VoidCallback onDemo;
  const _Header({required this.greet, required this.p, required this.onDemo});
  @override
  Widget build(BuildContext context) {
        return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greet.toUpperCase(),
                style: const TextStyle(fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: BL.red),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onLongPress: onDemo,
                child: Text('New Life UK', style: BL.display(32)),
              ),
            ],
          ),
        ),
        Pressable(
          onTap: () => context.push('/diary'),
          child: const _Chip(icon: Icons.menu_book_rounded, color: BL.navy, label: '', tooltip: 'Diary'),
        ),
        const SizedBox(width: 8),
        _Chip(icon: Icons.local_fire_department_rounded, color: BL.red, label: '${p.streak}', tooltip: 'Day streak'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, tooltip;
  const _Chip({required this.icon, required this.color, required this.label, required this.tooltip});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(99), boxShadow: BL.shadow(.06)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

class _MissionCard extends StatelessWidget {
  final ContentBundle c;
  final UserProgress p;
  const _MissionCard({required this.c, required this.p});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final convos = p.daily.date == today ? p.daily.conversations : 0;
    final words = p.daily.date == today ? p.daily.wordsUsed : 0;
    final m = Missions.today(now);
    final host = c.hostOf(m.sceneIds.first);
    final done = Missions.done(p, now);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BL.radius + 4),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22355C), BL.ink]),
        boxShadow: BL.shadow(.25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: CustomPaint(size: const Size(160, 160), painter: _UnionPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        done ? 'MISSION COMPLETE' : 'TODAY’S MISSION',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: BL.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(done ? 'Brilliant — you’ve smashed it!' : m.en, style: BL.display(22, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  done ? tr(p.lang, 'mission_done') : (p.lang == 'fa' ? m.fa : tr(p.lang, 'mission')),
                  textDirection: p.lang == 'fa' || done ? dirOf(p.lang) : dirOf(p.lang),
                  style: BL.fa(12.5, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Ring(value: min(1, convos / 2), label: '$convos/2', caption: 'chats'),
                    const SizedBox(width: 14),
                    _Ring(value: min(1, words / 3), label: '$words/3', caption: 'words'),
                    const Spacer(),
                    Pressable(
                      onTap: () => context.push(host != null ? '/place/${host.id}' : '/chat/${m.sceneIds.first}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(color: BL.red, borderRadius: BorderRadius.circular(99)),
                        child: const Row(
                          children: [
                            Text(
                              'Start',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .06)
      ..strokeWidth = 18;
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), p);
    p.strokeWidth = 8;
    canvas.drawLine(Offset.zero, Offset(s.width, s.height), p);
    canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Ring extends StatelessWidget {
  final double value;
  final String label, caption;
  const _Ring({required this.value, required this.label, required this.caption});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 38,
        height: 38,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => CircularProgressIndicator(value: v, strokeWidth: 4.5, color: BL.gold, backgroundColor: Colors.white12, strokeCap: StrokeCap.round),
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          Text(caption, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    ],
  );
}

class CharacterCard extends ConsumerWidget {
  final ContentBundle c;
  final Character ch;
  final UserProgress p;
  const CharacterCard({super.key, required this.c, required this.ch, required this.p});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trust = GrowthEngine.softTrust(p.trustMap[ch.id] ?? 0);
    final growth = p.growthMap[ch.id] ?? 0;
    final m = GrowthEngine.milestoneFor(growth, c.milestonesFor(ch.id));
    final available = ch.starterScene != null;
    // Growth over time: age and life stage follow the family calendar.
    final tl = c.timeline.chapters;
    final chap = tl.isEmpty ? null : tl[ref.read(progressProvider.notifier).chapterIndex(c)];
    final age = chap?.ages[ch.id] ?? ch.age;
    final stage = chap?.stages[ch.id]?.$1;
    return Pressable(
      onTap: () => available ? context.push('/chat/${ch.starterScene}') : _comingSoon(context, ch),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(BL.radius), boxShadow: BL.shadow()),
        child: Row(
          children: [
            Avatar(ch, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(ch.name, style: BL.display(19)),
                      const SizedBox(width: 6),
                      Text('· ${age == 1 ? '1 yr' : '$age'}', style: const TextStyle(color: BL.muted, fontSize: 12.5)),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: tr(p.lang, 'mood'),
                        child: Text(EmotionEngine.label(p.moodMap[ch.id] ?? 0).emoji, style: const TextStyle(fontSize: 14)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: ch.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          available ? m.id : 'Soon',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ch.color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(stage == null ? ch.role : '${ch.role} · $stage', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BL.muted, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  MeterBar(value: trust / 100, color: BL.red, label: 'Trust', trailing: '${trust.round()}', icon: Icons.favorite_rounded),
                  const SizedBox(height: 6),
                  MeterBar(value: growth / 100, color: BL.green, label: 'Growth', trailing: '${growth.round()}%', icon: Icons.spa_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, Character ch) => showModalBottomSheet(
    context: context,
    backgroundColor: BL.cream,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(ch, size: 96),
            const SizedBox(height: 12),
            Text(ch.name, style: BL.display(24)),
            const SizedBox(height: 6),
            Text(
              ch.bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BL.muted),
            ),
            Text(ch.bioFa, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: BL.fa(13)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: BL.mist, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: BL.navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${ch.name}’s stories are being written — coming in the next update.', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

ProgressController ctrlOf(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(progressProvider.notifier);

class _LevelHeader extends StatelessWidget {
  final ContentBundle c;
  final int index, done;
  final bool current, open;
  const _LevelHeader({required this.c, required this.index, required this.current, required this.open, required this.done});
  @override
  Widget build(BuildContext context) {
    final t = c.tiers[index];
    final total = t.sceneIds.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LevelChip(t.id),
                  const SizedBox(width: 8),
                  if (current)
                    const Text(
                      'YOU ARE HERE',
                      style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: BL.red),
                    ),
                  if (!open) const Icon(Icons.lock_rounded, size: 15, color: BL.muted),
                ],
              ),
              const SizedBox(height: 6),
              Text(t.title, style: BL.display(22, color: open ? BL.ink : BL.muted)),
              Text(open ? t.subtitle : 'Finish ${ProgressController.tierGate} chats in ${c.tiers[index - 1].id.replaceAll('-', '–')} to open', style: const TextStyle(color: BL.muted, fontSize: 12.5)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(t.titleFa, textDirection: TextDirection.rtl, style: BL.fa(12.5)),
            Text(
              '$done/$total',
              style: const TextStyle(fontWeight: FontWeight.w800, color: BL.green, fontSize: 12.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final ContentBundle c;
  final Place place;
  final bool open, tierOpen;
  final int done;
  const _PlaceCard({required this.c, required this.place, required this.open, required this.tierOpen, required this.done});
  @override
  Widget build(BuildContext context) {
    final people = place.hotspots.where((h) => !h.isProp).map((h) => c.character(h.characterId)).toList();
    final total = place.sceneIds.length;
    return Pressable(
      onTap: open
          ? () => context.push('/place/${place.id}')
          : () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                  place.season != null
                      ? 'A seasonal event — opens in December, or early after ${Place.earlyAccessChats} chats.'
                      : tierOpen
                      ? 'Reach “Best playmate” with Nicola to unlock the party.'
                      : 'Finish more chats in the level before to open ${place.title}.',
                ),
              ),
            ),
      child: Container(
        width: 186,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(BL.radius), boxShadow: open ? BL.shadow(.16) : null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BL.radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: open
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix(<double>[.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, .55, 0]),
                child: PlaceImage(place),
              ),
              if (place.image == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: Icon(placeIcons[place.icon] ?? Icons.place_rounded, size: 54, color: Colors.white.withValues(alpha: .9)),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [.35, 1], colors: [Colors.transparent, Colors.black.withValues(alpha: .72)]),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), shape: BoxShape.circle),
                  child: Icon(!open ? Icons.lock_rounded : (done >= total && total > 0 ? Icons.check_rounded : Icons.play_arrow_rounded), color: Colors.white, size: 16),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 28,
                      child: Stack(
                        children: [
                          for (var i = 0; i < people.length && i < 5; i++)
                            Positioned(
                              left: i * 18.0,
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                padding: const EdgeInsets.all(1.5),
                                child: Avatar(people[i], size: 25, ring: false),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BL.display(16.5, color: Colors.white),
                    ),
                    Text(
                      place.titleFa,
                      textDirection: TextDirection.rtl,
                      style: BL.fa(11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WordBoxCard extends StatelessWidget {
  final UserProgress p;
  const WordBoxCard({super.key, required this.p});
  @override
  Widget build(BuildContext context) {
    final counts = List.generate(5, (i) => p.leitnerBox.values.where((w) => w.box == i + 1).length);
    final due = Leitner.due(p.leitnerBox.values, DateTime.now()).length;
    final maxC = max(1, counts.reduce(max));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(BL.radius), boxShadow: BL.shadow()),
      child: p.leitnerBox.isEmpty
          ? const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: BL.muted),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Your word box is empty. Words you meet in conversations land here — use them again to move them up a box.', style: TextStyle(color: BL.muted)),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${p.leitnerBox.length} words', style: BL.display(18)),
                    const Spacer(),
                    Text(
                      '$due ready to practise',
                      style: const TextStyle(color: BL.red, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 84,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${counts[i]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  height: 6 + 40 * counts[i] / maxC,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Color.lerp(BL.mist, BL.green, (i + 1) / 5)),
                                ),
                                const SizedBox(height: 4),
                                Text('Box ${i + 1}', style: const TextStyle(fontSize: 10, color: BL.muted)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in p.leitnerBox.values.take(12))
                      Tooltip(
                        message: w.fa,
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          backgroundColor: BL.cream,
                          label: Text(w.word, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class WeeklyCard extends StatelessWidget {
  final UserProgress p;
  const WeeklyCard({super.key, required this.p});
  @override
  Widget build(BuildContext context) {
    final wk = WeeklyChallenge.weekKey(DateTime.now());
    final w = p.weekly.week == wk ? p.weekly : null;
    final chats = w?.chats ?? 0, trust = w?.trust ?? 0;
    final won = p.rewards.contains(wk);
    final v = WeeklyChallenge.progress(chats, trust);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(BL.radius), boxShadow: BL.shadow()),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: won ? BL.gold : BL.gold.withValues(alpha: .18)),
            child: Icon(won ? Icons.emoji_events_rounded : Icons.flag_rounded, color: won ? BL.ink : const Color(0xFFB8860B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Weekly challenge', style: BL.display(17)),
                    const Spacer(),
                    Text(
                      wk.split('-').last,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: BL.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(tr(p.lang, won ? 'weekly_won' : 'weekly_sub'), textDirection: dirOf(p.lang), style: BL.fa(12)),
                const SizedBox(height: 8),
                MeterBar(value: v, color: const Color(0xFFB8860B), label: 'Week', trailing: '$chats/${WeeklyChallenge.chatsTarget}', icon: Icons.bolt_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
