import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/i18n/strings.dart';
import '../../core/models/character.dart';
import '../../core/models/user_progress.dart';
import 'home_screen.dart';
import '../shared/widgets.dart';

/// Chapter 1 — four painted episodes through one British day.
class ChapterStrip extends ConsumerWidget {
  final ContentBundle c;
  const ChapterStrip(this.c, {super.key});
  static const eps = [('ep1_morning_table', 'kitchen'), ('ep2_muddy_hallway', 'hallway'), ('ep3_high_street', 'bakery'), ('ep4_evening_tea', 'eveningtea')];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    return SizedBox(
      height: 214,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final (i, (sid, pid)) in eps.indexed)
            if (c.scenes[sid] != null && c.place(pid) != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Pressable(
                  onTap: () => context.push(ctrl.canPlay(c.scenes[sid]!, c) ? '/chat/$sid' : '/place/$pid'),
                  child: Container(
                    width: 290,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: BL.shadow(.18)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(c.place(pid)!.image!, fit: BoxFit.cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE6140E0A)], stops: [.35, 1])),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${tr(p.lang, 'episode').toUpperCase()} ${i + 1}  ·  ${c.scenes[sid]!.level}', style: const TextStyle(color: Color(0xFFE8C987), fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(c.scenes[sid]!.title.replaceFirst(RegExp(r'^Ep \d · '), ''), style: BL.display(18, color: Colors.white)),
                            ],
                          ),
                        ),
                        if (p.completedScenes.contains(sid))
                          const Positioned(top: 10, right: 10, child: CircleAvatar(radius: 12, backgroundColor: BL.green, child: Icon(Icons.check_rounded, size: 15, color: Colors.white))),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Sec 3.2 — play as the guest Mehdi, or step into Ryan, Tom or Leslie.
class RolePicker extends ConsumerWidget {
  final ContentBundle c;
  const RolePicker(this.c, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    return Row(
      children: [
        Text(tr(p.lang, 'playAs'), style: const TextStyle(fontWeight: FontWeight.w700, color: BL.muted)),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in c.roles)
                  if (c.characterOrNull(r.id) != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pressable(
                        onTap: () {
                          ref.read(progressProvider.notifier).setRole(r.id);
                          if (r.scenes.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Now playing as ${c.character(r.id).name} — new story: ${c.scenes[r.scenes.first]?.title ?? ''}'),
                                action: SnackBarAction(label: 'Play', onPressed: () => context.push('/chat/${r.scenes.first}')),
                              ),
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                          decoration: BoxDecoration(
                            color: p.role == r.id ? BL.navy : BL.paper,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: BL.shadow(.06),
                          ),
                          child: Row(
                            children: [
                              Avatar(c.character(r.id), size: 28, ring: false),
                              const SizedBox(width: 6),
                              Text(c.character(r.id).name, style: TextStyle(fontWeight: FontWeight.w700, color: p.role == r.id ? Colors.white : BL.ink)),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sec 6 growth set-pieces (birthday, first school day, Mia, sports day…), gated by milestones.
class GrowingUpStrip extends ConsumerWidget {
  final ContentBundle c;
  const GrowingUpStrip(this.c, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final m in c.moments)
            if (c.scenes[m.sceneId] != null)
              Builder(
                builder: (_) {
                  final s = c.scenes[m.sceneId]!;
                  final open = ctrl.canPlay(s, c);
                  final who = c.character(s.requiresCharacter ?? s.characterId);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Pressable(
                      onTap: open ? () => context.push('/chat/${s.id}') : null,
                      child: Container(
                        width: 150,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: who.color.withValues(alpha: .25)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (m.cover != null) Image.asset(m.cover!, fit: BoxFit.cover, color: open ? null : Colors.black.withValues(alpha: .55), colorBlendMode: BlendMode.darken),
                            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC140E0A)]))),
                            Positioned(top: 8, left: 8, child: Avatar(who, size: 30)),
                            if (!open) const Positioned(top: 12, right: 10, child: Icon(Icons.lock_rounded, color: Colors.white70, size: 18)),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${who.name} · ${s.requiresMilestone ?? ''}', style: const TextStyle(color: Color(0xFFE8C987), fontSize: 10.5, fontWeight: FontWeight.w800)),
                                  Text(s.title, maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.15)),
                                ],
                              ),
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

/// Sec 7.12 — short culture notes: queuing, weather, sorry, love…
class CultureCorner extends StatelessWidget {
  final String lang;
  const CultureCorner(this.lang, {super.key});
  static const notes = [
    ('🧍‍♂️🧍‍♀️', 'Queuing', 'Never jump a queue. If unsure, ask: “Are you in the queue?”', 'هرگز از صف جلو نزن. اگر مطمئن نیستی بپرس: «Are you in the queue?»'),
    ('🌦️', 'Weather', 'Weather is the national small talk: “Lovely day, isn’t it?” works anywhere.', 'آب‌وهوا گپ ملی است: «Lovely day, isn’t it?» همه‌جا جواب می‌دهد.'),
    ('🙏', 'Sorry', '“Sorry” means excuse me, pardon, and I apologise — Brits say it when YOU bump into THEM.', '«Sorry» یعنی ببخشید، چی گفتی و عذر می‌خواهم — حتی وقتی تو به آن‌ها می‌خوری!'),
    ('❤️', 'Love', '“Alright, love?” from a shopkeeper or bus driver is friendly, not romantic.', '«Alright, love?» از مغازه‌دار یا راننده صمیمیت است، نه عاشقانه.'),
    ('☕', 'Tea', 'Offer tea to anyone who comes to the house — even the plumber.', 'به هر کسی که به خانه می‌آید چای تعارف کن — حتی لوله‌کش.'),
    ('🍺', 'Rounds', 'At the pub, friends take turns buying a “round” for the group.', 'در پاب دوستان به نوبت برای همه «round» می‌خرند.'),
  ];
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (final n in notes)
          Container(
            width: 230,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(18), boxShadow: BL.shadow(.05)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${n.$1}  ${n.$2}', style: BL.display(16)),
                const SizedBox(height: 4),
                Text(n.$3, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.3)),
                const Spacer(),
                Text(n.$4, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: BL.fa(11)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Accent Passport — one stamp per character milestone.
class PassportCard extends StatelessWidget {
  final ContentBundle c;
  final UserProgress p;
  const PassportCard(this.c, this.p, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(colors: [Color(0xFF6E1423), Color(0xFF4A0D18)]),
      boxShadow: BL.shadow(.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFFE8C987), size: 18),
            const SizedBox(width: 8),
            Text(tr(p.lang, 'passport'), style: BL.display(18, color: const Color(0xFFE8C987))),
            const Spacer(),
            Text('${p.stamps.length}', style: BL.display(18, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 10),
        if (p.stamps.isEmpty)
          const Text('Help a character reach a new milestone to earn your first stamp.', style: TextStyle(color: Colors.white70, fontSize: 12.5))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in p.stamps)
                Transform.rotate(
                  angle: (s.characterId.hashCode % 7 - 3) / 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8C987), width: 1.5), borderRadius: BorderRadius.circular(8)),
                    child: Text('${s.accent.toUpperCase()}\n${c.characterOrNull(s.characterId)?.name ?? s.characterId} · ${s.milestoneId}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE8C987), fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.2)),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}


/// The one thing to do next — a big painting card, like opening a storybook at the bookmark.
class ContinueHero extends ConsumerWidget {
  final ContentBundle c;
  const ContinueHero(this.c, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final eps = ChapterStrip.eps.where((e) => c.scenes[e.$1] != null && c.place(e.$2) != null).toList();
    final i = eps.indexWhere((e) => !p.completedScenes.contains(e.$1));
    final (sid, pid) = eps[i < 0 ? 0 : i];
    final s = c.scenes[sid]!;
    final pl = c.place(pid)!;
    final playable = ctrl.canPlay(s, c);
    // Learners who started above Level 1 continue their own level, not the Level 1 breakfast episode.
    final nl = ctrl.startLevel > 1 ? ctrl.nextLesson(c.course) : null;
    final nu = nl == null ? null : c.course.unitOf(nl.id)!;
    final img = nl == null ? pl.image! : (c.place(nl.place)?.image ?? pl.image!);
    final label = nl == null ? '${i < 0 ? 'PLAY AGAIN' : 'CONTINUE'}  ·  EPISODE ${eps.indexOf((sid, pid)) + 1}' : 'CONTINUE  ·  LEVEL ${nu!.level}  ·  UNIT ${c.course.numberInLevel(nu)}';
    final title = nl == null ? s.title.replaceFirst(RegExp(r'^Ep \d · '), '') : nl.title;
    final titleFa = nl == null ? s.titleFa : nl.titleFa;
    final meta = nl == null ? '${s.nodes.length * 2} turns  ·  ${s.level}' : '${nl.turns} turns  ·  ${c.scenes[nl.sceneIds.first]?.level ?? ''}';
    return Pressable(
      key: ValueKey('hero-${nl?.id ?? sid}'),
      onTap: () => context.push(nl != null ? '/lesson/${nl.id}' : playable ? '/chat/$sid' : '/place/$pid'),
      child: Container(
        height: 330,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: BL.shadow(.28)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.08),
              duration: const Duration(seconds: 14),
              curve: Curves.easeOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Image.asset(img, fit: BoxFit.cover),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00140E0A), Color(0x22140E0A), Color(0xF0140E0A)], stops: [0, .45, 1]),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Color(0xFFE8C987), fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BL.display(30, color: Colors.white).copyWith(height: 1.1)),
                  const SizedBox(height: 4),
                  Text(titleFa, textDirection: TextDirection.rtl, style: BL.fa(13.5, color: Colors.white70)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                        decoration: BoxDecoration(color: const Color(0xFFFBF3E4), borderRadius: BorderRadius.circular(99)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: BL.ink, size: 22),
                            SizedBox(width: 6),
                            Text('Play', style: TextStyle(color: BL.ink, fontWeight: FontWeight.w800, fontSize: 15.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(meta, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The family as portraits — tap one for their story, growth and chat.
class FamilyRow extends ConsumerWidget {
  final ContentBundle c;
  final List<Character> family;
  const FamilyRow(this.c, this.family, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final ch in family)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Pressable(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + MediaQuery.paddingOf(context).bottom),
                    child: CharacterCard(c: c, ch: ch, p: p),
                  ),
                ),
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD9B26A), width: 2), boxShadow: BL.shadow(.10)),
                        child: Avatar(ch, size: 64, ring: false),
                      ),
                      const SizedBox(height: 7),
                      Text(ch.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: BL.ink)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Entry to the full course path (Level 1 …).
class CourseCard extends ConsumerWidget {
  final ContentBundle c;
  const CourseCard(this.c, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final all = c.course.lessons.toList();
    if (all.isEmpty) return const SizedBox.shrink();
    final done = all.where(ctrl.lessonDone).length;
    final next = ctrl.nextLesson(c.course);
    return Pressable(
      onTap: () => context.push(next == null ? '/course' : '/course?level=${c.course.unitOf(next.id)!.level}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(24), boxShadow: BL.shadow(.08)),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: done / all.length, strokeWidth: 5, backgroundColor: BL.mist, color: BL.green)),
                  Text('$done', style: BL.display(19, color: BL.green)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LEVEL ${next == null ? c.course.units.last.level : c.course.unitOf(next.id)!.level} COURSE  ·  ${Course.levelInfo[next == null ? c.course.units.last.level : c.course.unitOf(next.id)!.level]!.$1}', style: const TextStyle(fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
                  const SizedBox(height: 2),
                  Text(next == null ? 'All lessons done!' : 'Next: ${next.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(19)),
                  Text('${c.course.units.map((u) => u.level).toSet().length} levels · ${c.course.units.length} units · ${all.length} lessons', style: const TextStyle(fontSize: 12.5, color: BL.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BL.muted, size: 28),
          ],
        ),
      ),
    );
  }
}

/// Character growth over time (#6): the family calendar. Ages and stages advance with your progress;
/// crossing into a new chapter shows a one-off "time passes" card.
class FamilyTimelineCard extends ConsumerStatefulWidget {
  final ContentBundle c;
  const FamilyTimelineCard(this.c, {super.key});
  @override
  ConsumerState<FamilyTimelineCard> createState() => _FamilyTimelineCardState();
}

class _FamilyTimelineCardState extends ConsumerState<FamilyTimelineCard> {
  static const family = ['tom', 'leslie', 'ryan', 'nicola', 'william', 'weda'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(progressProvider.notifier);
      final i = ctrl.chapterIndex(widget.c);
      if (i > ctrl.seenChapter && mounted) {
        ctrl.markChapterSeen(i);
        showTimePasses(context, widget.c, i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final c = widget.c;
    final chs = c.timeline.chapters;
    if (chs.isEmpty) return const SizedBox.shrink();
    final ctrl = ref.read(progressProvider.notifier);
    final pts = ctrl.growthPoints(c);
    final i = ctrl.chapterIndex(c);
    final ch = chs[i];
    final next = i + 1 < chs.length ? chs[i + 1] : null;
    final frac = next == null ? 1.0 : ((pts - ch.threshold) / (next.threshold - ch.threshold)).clamp(0.0, 1.0);
    return Pressable(
      onTap: () => showTimePasses(context, c, i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(24), boxShadow: BL.shadow(.08)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THE FAMILY YEAR  ·  YEAR ${ch.year} · ${ch.season.toUpperCase()}', style: const TextStyle(fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
            const SizedBox(height: 2),
            Text(ch.title, style: BL.display(19)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final id in family)
                  if (c.characterOrNull(id) != null)
                    Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Avatar(c.character(id), size: 40, ring: false),
                            if (ch.ages[id] != null)
                              Positioned(
                                right: -6,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: BL.navy, borderRadius: BorderRadius.circular(99), border: Border.all(color: BL.paper, width: 1.5)),
                                  child: Text('${ch.ages[id]}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(c.character(id).name.split(' ').last, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BL.muted)),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: BL.mist, color: BL.green),
            ),
            const SizedBox(height: 6),
            Text(next == null ? 'You’ve grown up with the Toms.' : 'Next: ${next.season}, Year ${next.year} — keep chatting and passing units', style: const TextStyle(fontSize: 12, color: BL.muted)),
          ],
        ),
      ),
    );
  }
}

Future<void> showTimePasses(BuildContext context, ContentBundle c, int i) {
  final ch = c.timeline.chapters[i];
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(color: const Color(0xFF1E1610), borderRadius: BorderRadius.circular(28)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i == 0 ? 'CHAPTER 1' : 'TIME PASSES…', style: const TextStyle(color: Color(0xFFE8C987), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${ch.season}, Year ${ch.year} · ${ch.title}', style: BL.display(22, color: Colors.white)),
            Text('${ch.seasonFa} · ${ch.titleFa}', textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white60)),
            const SizedBox(height: 12),
            Text(ch.story, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            const SizedBox(height: 4),
            Text(ch.storyFa, textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white60)),
            const SizedBox(height: 14),
            for (final e in ch.stages.entries)
              if (c.characterOrNull(e.key) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Avatar(c.character(e.key), size: 30, ring: false),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${c.character(e.key).name}${ch.ages[e.key] == null ? '' : ', ${ch.ages[e.key]}'} — ${e.value.$1}', style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: BL.green, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Carry on')),
            ),
          ],
        ),
      ),
    ),
  );
}
