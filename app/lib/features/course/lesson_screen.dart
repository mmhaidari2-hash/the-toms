import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';

import '../shared/gloss.dart';
import '../shared/nav.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../shared/widgets.dart';
import '../premium/premium_screen.dart';

/// One lesson: painting, what you'll learn, the words, then Story → Practice.
class LessonScreen extends ConsumerWidget {
  final String lessonId;
  const LessonScreen({super.key, required this.lessonId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contentProvider).value;
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final l = c?.course.lesson(lessonId);
    if (c == null || l == null) {
      return const NavLoading();
    }
    final u = c.course.unitOf(l.id)!;
    final pk = c.course.packOf(u);
    if (pk != null && pk.gated && !ctrl.packUnitLevelOpen(c.course, u)) return _LevelLocked(cefr: u.cefr ?? 'A2'); // same level gate as everywhere
    if (pk != null && !ctrl.lessonOpen(c.course, l)) return PremiumScreen(pack: pk.id); // Career Pack beyond the free first lesson
    // Same picture rule as the conversation: a painting of this setting with no main character who isn't in it,
    // else the setting's blurred (people-free) painting.
    final art = l.sceneIds.isEmpty ? null : c.artOf(l.sceneIds.first);
    final img = art == null ? c.place(l.place)?.image : art.img;
    final storyDone = l.sceneIds.every(p.completedScenes.contains);
    final score = ctrl.practiceScore(l.id);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 250 + pad.top,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img != null)
                        Image.asset(img, fit: BoxFit.cover)
                      else if (art?.bg != null)
                        Image.asset(art!.bg!, key: const ValueKey('lesson-neutral-bg'), fit: BoxFit.cover),
                      if (img == null && art != null)
                        Align(alignment: const Alignment(.85, -.2), child: Icon(locationIcon(art.spot), size: 72, color: Colors.white.withValues(alpha: .9))),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Color(0x00000000),
                              Color(0xF2FBF7F0),
                            ],
                            stops: [0, .45, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: BL.cream.withValues(alpha: .92),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                hl('${u.title.toUpperCase()}  ·  LESSON ${u.lessons.indexOf(l) + 1}'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: BL.red,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(hl(l.title), style: BL.display(28)),
                            Text(
                              hl(l.titleFa),
                              textDirection: helperDir,
                              style: BL.fa(13.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverList.list(
                  children: [
                    _Card(
                      icon: Icons.auto_stories_rounded,
                      title: 'You’ll learn',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hl(l.grammar),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hl(l.grammarFa),
                            textDirection: helperDir,
                            style: BL.fa(13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      icon: Icons.translate_rounded,
                      title: '${l.words.length} words  ·  tap to hear',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in l.words)
                            Pressable(
                              onTap: () => Voice.say('narrator', w.word),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: BL.cream,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: BL.mist),
                                ),
                                child: GlossLabel(
                                  w.word,
                                  w.fa,
                                  enStyle: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink),
                                  glossStyle: BL.fa(12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Step(
                      n: 1,
                      title: 'Story',
                      sub: '${l.turns} turns with ${c.character(l.lead).name}',
                      done: storyDone,
                      onTap: () => context.push('/chat/${l.sceneIds.first}'),
                    ),
                    const SizedBox(height: 10),
                    _Step(
                      n: 2,
                      title: 'Practice',
                      sub: score == null
                          ? 'Listen, build, tap & fill — about 4 minutes'
                          : 'Best score $score%',
                      done: (score ?? 0) >= 60,
                      onTap: () => context.push('/practice/${l.id}'),
                    ),
                    if (c.variantsOf(l.sceneIds.first).isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _Card(
                        icon: Icons.theater_comedy_rounded,
                        title: 'Swap roles: play this story as…',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final r in [
                                  c.scenes[l.sceneIds.first]?.guest ?? 'learner',
                                  ...c.variantsOf(l.sceneIds.first).keys,
                                ])
                                  if (c.characterOrNull(r) != null)
                                    Pressable(
                                      onTap: () {
                                        ref
                                            .read(progressProvider.notifier)
                                            .setRole(
                                              r ==
                                                      c
                                                          .scenes[l
                                                              .sceneIds
                                                              .first]
                                                          ?.guest
                                                  ? 'learner'
                                                  : r,
                                            );
                                        context.push(
                                          '/chat/${l.sceneIds.first}',
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          4,
                                          4,
                                          12,
                                          4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              ref
                                                      .watch(progressProvider)
                                                      .role ==
                                                  (r ==
                                                          c
                                                              .scenes[l
                                                                  .sceneIds
                                                                  .first]
                                                              ?.guest
                                                      ? 'learner'
                                                      : r)
                                              ? BL.navy
                                              : BL.mist,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Avatar(
                                              c.character(r),
                                              size: 26,
                                              ring: false,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              hl(r == 'learner'
                                                  ? 'Me (guest)'
                                                  : c.character(r).name),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color:
                                                    ref
                                                            .watch(
                                                              progressProvider,
                                                            )
                                                            .role ==
                                                        (r ==
                                                                c
                                                                    .scenes[l
                                                                        .sceneIds
                                                                        .first]
                                                                    ?.guest
                                                            ? 'learner'
                                                            : r)
                                                    ? Colors.white
                                                    : BL.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  height: 28,
                                  child: Switch.adaptive(
                                    value: ref
                                        .watch(progressProvider.notifier)
                                        .keepRole,
                                    activeThumbColor: BL.green,
                                    onChanged: (v) => ref
                                        .read(progressProvider.notifier)
                                        .setKeepRole(v),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Stay in this role for other stories',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: BL.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 100 + pad.bottom),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + pad.bottom),
              decoration: BoxDecoration(
                color: BL.cream,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: FilledButton.icon(
                key: const ValueKey('lesson-start'),
                onPressed: () => storyDone
                    ? context.push('/practice/${l.id}')
                    : context.push('/chat/${l.sceneIds.first}'),
                style: FilledButton.styleFrom(
                  backgroundColor: BL.red,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  hl(storyDone
                      ? 'Practice  ·  تمرین'
                      : 'Start the story  ·  شروع داستان'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 6,
            left: 8,
            child: const NavButtons(light: true, fallback: '/course'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BL.paper,
      borderRadius: BorderRadius.circular(BL.radius),
      boxShadow: BL.shadow(),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: BL.green),
            const SizedBox(width: 6),
            Text(
              hl(title),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: BL.green,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  final int n;
  final String title, sub;
  final bool done;
  final VoidCallback onTap;
  const _Step({
    required this.n,
    required this.title,
    required this.sub,
    required this.done,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BL.radius),
        gradient: const LinearGradient(colors: [Color(0xFF22355C), BL.ink]),
        boxShadow: BL.shadow(.2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: done ? BL.gold : Colors.white12,
            child: done
                ? const Icon(Icons.check_rounded, color: BL.ink)
                : Text(
                    hl('$n'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hl(title), style: BL.display(20, color: Colors.white)),
                Text(
                  hl(sub),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFFFBF3E4),
            size: 34,
          ),
        ],
      ),
    ),
  );
}

class _LevelLocked extends StatelessWidget {
  final String cefr;
  const _LevelLocked({required this.cefr});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline_rounded, size: 40),
              const SizedBox(height: 12),
              Text(hl('Opens at Level $cefr'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text('Keep going with the main course to unlock it.', textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(hl('با پیشرفت در دورهٔ اصلی در سطح $cefr باز می‌شود.'), textDirection: helperDir, textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}
