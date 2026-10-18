import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../shared/nav.dart';
import 'lifeuk_data.dart';

Widget lukMissing(BuildContext context) => Scaffold(body: Center(child: TextButton(onPressed: () => context.go('/lifeuk'), child: const Text('Not found — back to Life in the UK prep'))));

const lukBlue = Color(0xFF1F3A68), lukBg = Color(0xFFF2F4F8);

Widget lukNote({required Key key, required IconData icon, required String en, required String fa, Color color = lukBlue}) => Container(
  key: key,
  margin: const EdgeInsets.only(top: 10),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .07),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: color.withValues(alpha: .25)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(en, style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              fa,
              textDirection: TextDirection.rtl,
              style: BL.fa(12, color: BL.muted),
            ),
          ],
        ),
      ),
    ],
  ),
);

/// Life in the UK test prep hub: notes, the mock test and four chapters. Always open (see MASTER_BOOK).
class LukScreen extends ConsumerWidget {
  const LukScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final cs = ref.watch(lukProvider).value;
    if (cs == null) return const NavLoading();
    final pad = MediaQuery.paddingOf(context);
    final mock = ctrl.lukMockBest;
    return Scaffold(
      backgroundColor: lukBg,
      body: ListView(
        key: const ValueKey('luk-hub'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Icon(Icons.account_balance_rounded, size: 16, color: lukBlue),
              SizedBox(width: 4),
              Text(
                'STUDY CORNER · LIBRARY',
                style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: lukBlue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Life in the UK test prep', style: BL.display(28)),
          Text(
            'آمادگی برای آزمون زندگی در بریتانیا',
            textDirection: TextDirection.rtl,
            style: BL.fa(13, color: BL.muted),
          ),
          lukNote(key: const ValueKey('luk-disclaimer'), icon: Icons.info_outline_rounded, en: Luk.disclaimer, fa: Luk.disclaimerFa, color: BL.red),
          lukNote(key: const ValueKey('luk-level-note'), icon: Icons.translate_rounded, en: Luk.levelNote, fa: Luk.levelNoteFa),
          const SizedBox(height: 14),
          Material(
            color: lukBlue,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: const ValueKey('luk-open-mock'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/lifeuk/mock'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: Colors.white, size: 30),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mock test',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                          Text('24 questions · 45 minutes · pass mark 75%', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          mock == null ? '–' : '$mock%',
                          key: const ValueKey('luk-mock-best'),
                          style: TextStyle(color: (mock ?? 0) >= Luk.passPct ? const Color(0xFF9BE3B5) : Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        const Text('best', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final (i, c) in cs.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('luk-ch-${c.id}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/lifeuk/${c.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: lukBlue.withValues(alpha: .1),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: lukBlue, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                              Text(
                                c.titleFa,
                                textDirection: TextDirection.rtl,
                                style: BL.fa(12, color: BL.muted),
                              ),
                              Text('${c.qs.length} questions · ${ctrl.lukCardsKnown(c.id)}/${c.cards.length} cards known', style: const TextStyle(fontSize: 12, color: BL.muted)),
                            ],
                          ),
                        ),
                        Text(
                          ctrl.lukQuizBest(c.id) == null ? '–' : '${ctrl.lukQuizBest(c.id)}%',
                          key: ValueKey('luk-ch-best-${c.id}'),
                          style: TextStyle(fontWeight: FontWeight.w900, color: (ctrl.lukQuizBest(c.id) ?? 0) >= Luk.passPct ? const Color(0xFF2E7D5B) : BL.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A chapter: short voiced explanations (+ Persian), then flashcards and the chapter quiz.
class LukChapterScreen extends ConsumerStatefulWidget {
  final String id;
  const LukChapterScreen({super.key, required this.id});
  @override
  ConsumerState<LukChapterScreen> createState() => _LukChapterState();
}

class _LukChapterState extends ConsumerState<LukChapterScreen> {
  int? playing;
  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  Future<void> _play(int i, LukExpl e) async {
    Voice.stop();
    if (playing == i) return setState(() => playing = null);
    setState(() => playing = i);
    await Voice.say('tutor', e.en);
    if (mounted && playing == i) setState(() => playing = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final cs = ref.watch(lukProvider).value;
    if (cs == null) return const NavLoading();
    final c = cs.where((x) => x.id == widget.id).firstOrNull;
    if (c == null) return lukMissing(context);
    final fa = ctrl.pref('lukFa', 'off') == 'on';
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: lukBg,
      body: ListView(
        key: const ValueKey('luk-chapter'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          Row(
            children: [
              const NavBack(fallback: '/lifeuk'),
              const Spacer(),
              FilterChip(
                key: const ValueKey('luk-fa'),
                selected: fa,
                showCheckmark: false,
                label: const Text('فارسی'),
                selectedColor: lukBlue,
                labelStyle: TextStyle(color: fa ? Colors.white : BL.ink, fontWeight: FontWeight.w800),
                onSelected: (_) => ctrl.setPref('lukFa', fa ? 'off' : 'on'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.title, style: BL.display(26)),
          Text(
            c.titleFa,
            textDirection: TextDirection.rtl,
            style: BL.fa(13, color: BL.muted),
          ),
          const SizedBox(height: 10),
          for (final (i, e) in c.expl.indexed)
            Container(
              key: ValueKey('luk-expl-$i'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    key: ValueKey('luk-play-$i'),
                    customBorder: const CircleBorder(),
                    onTap: () => _play(i, e),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: lukBlue,
                      child: Icon(playing == i ? Icons.stop_rounded : Icons.volume_up_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(e.en, style: const TextStyle(fontSize: 14.5, height: 1.4)),
                        if (fa)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              e.fa,
                              key: ValueKey('luk-expl-fa-$i'),
                              textDirection: TextDirection.rtl,
                              style: BL.fa(13, color: BL.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _btn('luk-open-cards', Icons.style_rounded, 'Flashcards', '${ctrl.lukCardsKnown(c.id)}/${c.cards.length} known', () => context.push('/lifeuk/${c.id}/cards'))),
              const SizedBox(width: 8),
              Expanded(
                child: _btn(
                  'luk-open-quiz',
                  Icons.quiz_rounded,
                  'Chapter quiz',
                  ctrl.lukQuizBest(c.id) == null ? '${Luk.chapterQuiz} questions' : 'best ${ctrl.lukQuizBest(c.id)}%',
                  () => context.push('/lifeuk/${c.id}/quiz'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            key: const ValueKey('luk-sources'),
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Sources we checked these facts against',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BL.muted),
            ),
            children: [
              for (final s in c.src)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(s, style: const TextStyle(fontSize: 12, color: lukBlue)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String key, IconData icon, String title, String sub, VoidCallback onTap) => Material(
    color: lukBlue,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: ValueKey(key),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
      ),
    ),
  );
}

/// Flashcards: tap to turn over; "Again" sends the card to the back of the pile.
class LukCardsScreen extends ConsumerStatefulWidget {
  final String id;
  const LukCardsScreen({super.key, required this.id});
  @override
  ConsumerState<LukCardsScreen> createState() => _LukCardsState();
}

class _LukCardsState extends ConsumerState<LukCardsScreen> {
  List<int>? pile;
  final known = <int>{};
  bool flipped = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(lukProvider).value;
    if (cs == null) return const NavLoading();
    final c = cs.where((x) => x.id == widget.id).firstOrNull;
    if (c == null) return lukMissing(context);
    pile ??= List.generate(c.cards.length, (i) => i);
    final pad = MediaQuery.paddingOf(context);
    final done = pile!.isEmpty;
    return Scaffold(
      backgroundColor: lukBg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NavBack(fallback: '/lifeuk'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${c.title} · flashcards',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${known.length}/${c.cards.length}',
                  key: const ValueKey('luk-cards-known'),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: lukBlue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (done)
              Expanded(
                child: Center(
                  key: const ValueKey('luk-cards-done'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 60, color: Color(0xFF2E7D5B)),
                      const SizedBox(height: 10),
                      Text('All ${c.cards.length} cards known!', style: BL.display(22)),
                      Text(
                        'همهٔ کارت‌ها را بلدی!',
                        textDirection: TextDirection.rtl,
                        style: BL.fa(14, color: BL.muted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('luk-cards-quiz'),
                        onPressed: () => context.go('/lifeuk/${c.id}/quiz'),
                        style: FilledButton.styleFrom(backgroundColor: lukBlue),
                        child: const Text('Try the chapter quiz'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('luk-card'),
                  onTap: () => setState(() => flipped = !flipped),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: flipped ? lukBlue : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
                    ),
                    child: Center(
                      child: flipped
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.cards[pile!.first].back,
                                  key: const ValueKey('luk-card-back'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.35),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  c.cards[pile!.first].fa,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: BL.fa(15, color: Colors.white70),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(c.cards[pile!.first].front, key: const ValueKey('luk-card-front'), textAlign: TextAlign.center, style: BL.display(28)),
                                const SizedBox(height: 12),
                                const Text('Tap to turn over', style: TextStyle(color: BL.muted, fontSize: 12.5)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('luk-again'),
                      onPressed: () => setState(() {
                        pile!.add(pile!.removeAt(0));
                        flipped = false;
                      }),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Again'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('luk-got'),
                      onPressed: () {
                        setState(() {
                          known.add(pile!.removeAt(0));
                          flipped = false;
                        });
                        ref.read(progressProvider.notifier).saveLukCards(c.id, known.length);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Got it'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D5B), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
