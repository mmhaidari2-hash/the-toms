import 'package:flutter/material.dart';
import '../shared/nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/voice.dart';
import '../home/home_extras.dart';
import '../home/home_screen.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/strings.dart';
import '../../core/models/user_progress.dart';
import '../shared/widgets.dart';

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final c = ref.watch(contentProvider).value;
    final lang = p.lang;
    return Scaffold(
      body: SafeArea(
        child: c == null
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  PinnedHeaderSliver(
                    child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 6),
                      child: Row(
                        children: [
                          const NavButtons(),
                          const SizedBox(width: 10),
                          Text('Diary', style: BL.display(30)),
                          const Spacer(),
                          Text(tr(lang, 'diary'), textDirection: dirOf(lang), style: BL.fa(13)),
                        ],
                      ),
                    )),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    sliver: SliverToBoxAdapter(
                      child: Text(tr(lang, 'diary_sub'), textDirection: dirOf(lang), style: BL.fa(13)),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.fromLTRB(20, 0, 20, 16), sliver: SliverToBoxAdapter(child: DiaryComposer())),
                  // Journal: the stats and extras that used to crowd the home screen.
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    sliver: SliverList.list(
                      children: [
                        PassportCard(c, p),
                        const SizedBox(height: 12),
                        WeeklyCard(p: p),
                        const SizedBox(height: 12),
                        WordBoxCard(p: p),
                        const SizedBox(height: 12),
                        RolePicker(c),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: CultureCorner(lang)),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (p.replayArchive.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      sliver: SliverToBoxAdapter(child: _Archive(entries: p.replayArchive, lang: lang)),
                    ),
                  if (p.diary.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 56, color: BL.muted),
                              const SizedBox(height: 12),
                              Text('A blank page', style: BL.display(22)),
                              const SizedBox(height: 6),
                              Text(tr(lang, 'diary_empty'), textAlign: TextAlign.center, textDirection: dirOf(lang), style: BL.fa(13)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
                      sliver: SliverList.separated(
                        itemCount: p.diary.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final e = p.diary[i];
                          final s = c.scenes[e.sceneId];
                          final ch = c.character(e.characterId);
                          final firstLine = e.sceneId == 'written' ? e.lines.first : e.lines.firstWhere((l) => l[0] != 'me', orElse: () => const ['', '', '']);
                          return FadeSlideIn(
                            delayMs: i * 50,
                            child: Pressable(
                              onTap: () => context.push('/replay/$i'),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: const Color(0xFFFFFCF5), borderRadius: BorderRadius.circular(BL.radius), boxShadow: BL.shadow()),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Avatar(ch, size: 48),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _date(e.at).toUpperCase(),
                                            style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: BL.red),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(e.sceneId == 'written' ? 'My diary' : (s?.title ?? e.sceneId), style: BL.display(18)),
                                          const SizedBox(height: 4),
                                          Text(
                                            '“${firstLine[1]}”',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontStyle: FontStyle.italic, color: BL.muted),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [_pill('♥ +${e.trust}', BL.red), _pill('${e.words.length} words', BL.green), _pill('${ch.name} · ${s?.level ?? ''}', BL.navy)],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.replay_rounded, color: BL.muted),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
    child: Text(
      t,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
    ),
  );
}

class ReplayScreen extends ConsumerStatefulWidget {
  final int index;
  const ReplayScreen({super.key, required this.index});
  @override
  ConsumerState<ReplayScreen> createState() => _ReplayState();
}

class _ReplayState extends ConsumerState<ReplayScreen> {
  bool _subs = true, _playing = false;
  int _speed = 1, _current = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _playing = false;
    Voice.stop();
    super.dispose();
  }

  Future<void> _playAll(DiaryEntry e, String level) async {
    if (_playing) {
      setState(() => _playing = false);
      Voice.stop();
      return;
    }
    setState(() => _playing = true);
    for (var i = 0; i < e.lines.length && _playing && mounted; i++) {
      setState(() => _current = i);
      if (!await Voice.say(e.lines[i][0], e.lines[i][1], rate: Voice.rates[_speed])) break;
      await Future.delayed(const Duration(milliseconds: 350));
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    final c = ref.watch(contentProvider).value;
    if (c == null || widget.index >= p.diary.length) {
      return Scaffold(
        body: Center(
          child: TextButton(onPressed: () => context.go('/diary'), child: const Text('Back to diary')),
        ),
      );
    }
    final e = p.diary[widget.index];
    final s = c.scenes[e.sceneId];
    final ch = c.character(e.characterId);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  const NavBack(fallback: '/diary'),
                  const SizedBox(width: 8),
                  Avatar(ch, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Replay · ${s?.title ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(17)),
                        Text(_date(e.at), style: const TextStyle(fontSize: 12, color: BL.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  FilterChip(selected: _subs, onSelected: (v) => setState(() => _subs = v), label: const Text('Subtitles'), side: BorderSide.none, selectedColor: BL.gold.withValues(alpha: .4)),
                  const SizedBox(width: 8),
                  ActionChip(
                    side: BorderSide.none,
                    avatar: const Icon(Icons.speed_rounded, size: 16),
                    label: Text(const ['Slow', 'Level', 'Native'][_speed]),
                    onPressed: () => setState(() => _speed = (_speed + 1) % 3),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: BL.red),
                    onPressed: () => _playAll(e, s?.level ?? 'A1'),
                    icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_playing ? 'Stop' : 'Play all'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: e.lines.length,
                itemBuilder: (_, i) {
                  final l = e.lines[i];
                  final me = l[0] == 'me';
                  final sp = me ? null : c.characters.where((x) => x.id == l[0]).firstOrNull;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.only(bottom: 10, left: me ? 50 : 0, right: me ? 0 : 50),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: me ? BL.navy : BL.paper,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _current == i ? BL.gold : Colors.transparent, width: 2),
                      boxShadow: BL.shadow(.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sp != null)
                          Text(
                            sp.name,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: sp.color),
                          ),
                        Text(l[1], style: TextStyle(fontSize: 15, height: 1.35, color: me ? Colors.white : BL.ink)),
                        if (_subs && l.length > 2 && l[2].isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              l[2],
                              textDirection: TextDirection.rtl,
                              style: BL.fa(13, color: me ? Colors.white70 : BL.muted),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sec 7.7 — the learner WRITES in English; the family reacts (offline coach).
class DiaryComposer extends ConsumerStatefulWidget {
  const DiaryComposer({super.key});
  @override
  ConsumerState<DiaryComposer> createState() => _DiaryComposerState();
}

class _DiaryComposerState extends ConsumerState<DiaryComposer> {
  final _c = TextEditingController();
  dynamic _fb;
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(progressProvider).lang;
    final content = ref.watch(contentProvider).value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFFCF5), borderRadius: BorderRadius.circular(BL.radius), boxShadow: BL.shadow(), border: Border.all(color: BL.gold.withValues(alpha: .5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'writeDiary'), style: BL.display(18)),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 16, height: 1.4),
            decoration: InputDecoration(hintText: 'Today I…', filled: true, fillColor: BL.paper, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: BL.navy),
              onPressed: content == null
                  ? null
                  : () {
                      if (_c.text.trim().isEmpty) return;
                      final fb = ref.read(progressProvider.notifier).writeDiary(_c.text.trim(), content.characters.where((x) => x.family).toList());
                      setState(() {
                        _fb = fb;
                        _c.clear();
                      });
                    },
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text(tr(lang, 'save')),
            ),
          ),
          if (_fb != null && content != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(content.character(_fb.reactorId), size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('“${_fb.reaction}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14.5)),
                      Text(_fb.reactionFa, textDirection: TextDirection.rtl, style: BL.fa(12)),
                      const SizedBox(height: 6),
                      Text('${_fb.words} words${_fb.vocabUsed.isEmpty ? '' : ' · used: ${_fb.vocabUsed.join(', ')}'}', style: const TextStyle(color: BL.green, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      for (final t in _fb.tips) Text('💡 $t', style: const TextStyle(fontSize: 12.5, color: BL.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sec 7.11 — milestone archive: how each character spoke before they grew.
class _Archive extends ConsumerWidget {
  final List<ArchiveEntry> entries;
  final String lang;
  const _Archive({required this.entries, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contentProvider).value;
    if (c == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(lang, 'archive'), style: BL.display(20)),
        const SizedBox(height: 8),
        for (final e in entries.reversed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(c.character(e.characterId), size: 34, ring: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.character(e.characterId).name} at ${e.milestoneId} · ${_date(e.at)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      for (final l in e.lines.take(3)) Text('“${l[1]}”', style: const TextStyle(fontStyle: FontStyle.italic, color: BL.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
