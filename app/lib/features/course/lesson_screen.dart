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
import '../arrival/arrival_pack_screen.dart' show ArrivalAudioWarmer;
import '../arrival/arrival_prefetch.dart';
import '../../core/data/repository.dart' show ContentBundle;
import '../../core/models/course.dart';
import '../../core/models/dialogue_node.dart';
import '../../core/engine/role_switch.dart';

/// One lesson: painting, what you'll learn, the words, then Story → Practice.
class LessonScreen extends ConsumerWidget {
  final String lessonId;
  const LessonScreen({super.key, required this.lessonId});
  /// Test seam for the offline download (defaults to the same downloader the Arrival pack uses).
  static ArrivalAudioWarmer? warmer;
  /// Voice clip keys (KEY of assets/audio/KEY.mp3) of every line in this lesson's stories.
  static List<String> audioKeys(ContentBundle c, Lesson l) => {
        for (final id in l.sceneIds)
          for (final n in c.scenes[id]?.nodes.values ?? const <DialogueNode>[])
            for (final a in n.audioBySpeed.values)
              if (a.startsWith('assets/audio/') && !a.endsWith('silence.mp3')) a.split('/').last.replaceAll('.mp3', ''),
      }.toList();
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
    // Today's free lesson is used: the paywall replaces the lesson page, before anything starts (never mid-lesson).
    if (pk == null && ctrl.lessonLock(c.course, l) == LessonLock.daily) return const PremiumScreen(reason: 'daily');
    // Opening the story or practice of a new lesson outside the free zone spends today's free lesson.
    void start(String route) {
      if (!ctrl.claimDailyLesson(c.course, l)) {
        context.push('/premium?reason=daily');
        return;
      }
      context.push(route);
    }
    Future<void> download() async {
      if (!ctrl.offlineVoicesUnlocked) {
        context.push('/premium?reason=download');
        return;
      }
      final keys = audioKeys(c, l);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text(hl('Downloading lesson audio… · در حال دانلود صدای درس…'))));
      final n = await (warmer ?? warmArrivalAudio)(keys);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(hl(n >= keys.length ? 'Lesson audio saved for offline. · صدای درس برای آفلاین ذخیره شد.' : 'Saved $n of ${keys.length} clips. Try again on Wi‑Fi. · $n از ${keys.length} ذخیره شد.'))));
    }
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
                      onTap: () => start('/chat/${l.sceneIds.first}'),
                    ),
                    const SizedBox(height: 10),
                    _Step(
                      n: 2,
                      title: 'Practice',
                      sub: score == null
                          ? 'Listen, build, tap & fill — about 4 minutes'
                          : 'Best score $score%',
                      done: (score ?? 0) >= 60,
                      onTap: () => start('/practice/${l.id}'),
                    ),
                    if (l.sceneIds.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('lesson-download'),
                          onPressed: download,
                          icon: Icon(ctrl.offlineVoicesUnlocked ? Icons.download_rounded : Icons.workspace_premium_outlined, size: 18),
                          label: Text(hl('Download audio for offline · دانلود صدا برای آفلاین')),
                        ),
                      ),
                    if (c.scenes[l.sceneIds.first] case final sc? when RoleSwitch.playable(sc, c).isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _Card(
                        icon: Icons.theater_comedy_rounded,
                        title: 'Swap roles: play this story as…',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('هر کدام از شخصیت‌های این داستان را انتخاب کن؛ جمله‌های او مال توست و بقیه خودشان حرف می‌زنند.',
                                textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
                            const SizedBox(height: 8),
                            Wrap(
                              key: const ValueKey('role-picker'),
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final o in RoleSwitch.optionsOf(sc, c))
                                  if (o.playable && (o.id == 'learner' || c.characterOrNull(o.id) != null))
                                    Builder(builder: (context) {
                                      // Authored variants and the usual part keep the global role; any other part
                                      // plays this scene with a live swap (?as=), without changing the global role.
                                      final global = o.usual ? 'learner' : o.variant != null ? o.id : null;
                                      final on = global != null && ref.watch(progressProvider).role == global;
                                      final (best, runs) = RoleSwitch.readProgress(ctrl.pref(RoleSwitch.progressKey(sc, o.id)));
                                      final name = o.usual ? (o.id == 'learner' ? 'Me (guest)' : c.character(o.id).name) : o.id == 'learner' ? 'Guest' : c.character(o.id).name;
                                      return Pressable(
                                        key: ValueKey('role-pick-${o.id}'),
                                        onTap: () {
                                          if (global != null) {
                                            ref.read(progressProvider.notifier).setRole(global);
                                            start('/chat/${sc.id}');
                                          } else {
                                            start('/chat/${sc.id}?as=${o.id}');
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                                          decoration: BoxDecoration(color: on ? BL.navy : BL.mist, borderRadius: BorderRadius.circular(99)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Avatar(c.character(o.id), size: 26, ring: false),
                                              const SizedBox(width: 6),
                                              Text(
                                                hl(runs > 0 ? '$name · $best%' : name),
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : BL.ink),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                              ],
                            ),
                            if (RoleSwitch.hiddenSummary(RoleSwitch.optionsOf(sc, c), c) case final h?) ...[
                              const SizedBox(height: 8),
                              Text(hl('${h.$1}.'), key: const ValueKey('role-hidden'), style: const TextStyle(fontSize: 11.5, color: BL.muted)),
                              Text('${h.$2}.', textDirection: TextDirection.rtl, style: BL.fa(11, color: BL.muted)),
                            ],
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
                    ? start('/practice/${l.id}')
                    : start('/chat/${l.sceneIds.first}'),
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
            // Flexible: long card titles wrap on narrow phones instead of overflowing.
            Flexible(
              child: Text(
                hl(title),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: BL.green,
                  letterSpacing: .3,
                ),
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
