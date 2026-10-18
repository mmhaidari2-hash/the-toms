import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../shared/nav.dart';
import 'theory_data.dart';

Widget thyMissing(BuildContext context) => Scaffold(body: Center(child: TextButton(onPressed: () => context.go('/theory'), child: const Text('Not found — back to theory test prep'))));

const thyBlue = Color(0xFF1F3A68), thyBg = Color(0xFFF2F4F8);

Widget thyNote({required Key key, required IconData icon, required String en, required String fa, Color color = thyBlue}) => Container(
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

/// Driving theory test prep hub: notes, hazard perception (text only), the mock test and five chapters. Always open (see MASTER_BOOK).
class ThyScreen extends ConsumerWidget {
  const ThyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final cs = ref.watch(thyProvider).value;
    if (cs == null) return const NavLoading();
    final pad = MediaQuery.paddingOf(context);
    final mock = ctrl.thyMockBest;
    return Scaffold(
      backgroundColor: thyBg,
      body: ListView(
        key: const ValueKey('thy-hub'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Icon(Icons.directions_car_rounded, size: 16, color: thyBlue),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  "DRIVING SCHOOL · MICK'S MOTORS",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: thyBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Driving theory test prep', style: BL.display(28)),
          Text(
            'آمادگی برای آزمون تئوری رانندگی',
            textDirection: TextDirection.rtl,
            style: BL.fa(13, color: BL.muted),
          ),
          thyNote(key: const ValueKey('thy-disclaimer'), icon: Icons.info_outline_rounded, en: Thy.disclaimer, fa: Thy.disclaimerFa, color: BL.red),
          thyNote(key: const ValueKey('thy-level-note'), icon: Icons.translate_rounded, en: Thy.levelNote, fa: Thy.levelNoteFa),
          const SizedBox(height: 14),
          Material(
            color: thyBlue,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: const ValueKey('thy-open-mock'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/theory/mock'),
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
                          Text('50 questions · 57 minutes · pass mark 43/50', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          mock == null ? '–' : '$mock%',
                          key: const ValueKey('thy-mock-best'),
                          style: TextStyle(color: (mock ?? 0) >= Thy.passPct ? const Color(0xFF9BE3B5) : Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        const Text('best', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _Hazard(),
          for (final (i, c) in cs.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('thy-ch-${c.id}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/theory/${c.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: thyBlue.withValues(alpha: .1),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: thyBlue, fontWeight: FontWeight.w900),
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
                              Text('${c.qs.length} questions · ${ctrl.thyCardsKnown(c.id)}/${c.cards.length} cards known', style: const TextStyle(fontSize: 12, color: BL.muted)),
                            ],
                          ),
                        ),
                        Text(
                          ctrl.thyQuizBest(c.id) == null ? '–' : '${ctrl.thyQuizBest(c.id)}%',
                          key: ValueKey('thy-ch-best-${c.id}'),
                          style: TextStyle(fontWeight: FontWeight.w900, color: (ctrl.thyQuizBest(c.id) ?? 0) >= Thy.passPct ? const Color(0xFF2E7D5B) : BL.muted),
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
class ThyChapterScreen extends ConsumerStatefulWidget {
  final String id;
  const ThyChapterScreen({super.key, required this.id});
  @override
  ConsumerState<ThyChapterScreen> createState() => _ThyChapterState();
}

class _ThyChapterState extends ConsumerState<ThyChapterScreen> {
  int? playing;
  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  Future<void> _play(int i, ThyExpl e) async {
    Voice.stop();
    if (playing == i) return setState(() => playing = null);
    setState(() => playing = i);
    await Voice.say('instructor', e.en);
    if (mounted && playing == i) setState(() => playing = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final cs = ref.watch(thyProvider).value;
    if (cs == null) return const NavLoading();
    final c = cs.where((x) => x.id == widget.id).firstOrNull;
    if (c == null) return thyMissing(context);
    final fa = ctrl.pref('thyFa', 'off') == 'on';
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: thyBg,
      body: ListView(
        key: const ValueKey('thy-chapter'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          Row(
            children: [
              const NavBack(fallback: '/theory'),
              const Spacer(),
              FilterChip(
                key: const ValueKey('thy-fa'),
                selected: fa,
                showCheckmark: false,
                label: const Text('فارسی'),
                selectedColor: thyBlue,
                labelStyle: TextStyle(color: fa ? Colors.white : BL.ink, fontWeight: FontWeight.w800),
                onSelected: (_) => ctrl.setPref('thyFa', fa ? 'off' : 'on'),
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
              key: ValueKey('thy-expl-$i'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    key: ValueKey('thy-play-$i'),
                    customBorder: const CircleBorder(),
                    onTap: () => _play(i, e),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: thyBlue,
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
                              key: ValueKey('thy-expl-fa-$i'),
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
              Expanded(child: _btn('thy-open-cards', Icons.style_rounded, 'Flashcards', '${ctrl.thyCardsKnown(c.id)}/${c.cards.length} known', () => context.push('/theory/${c.id}/cards'))),
              const SizedBox(width: 8),
              Expanded(
                child: _btn(
                  'thy-open-quiz',
                  Icons.quiz_rounded,
                  'Chapter quiz',
                  ctrl.thyQuizBest(c.id) == null ? '${Thy.chapterQuiz} questions' : 'best ${ctrl.thyQuizBest(c.id)}%',
                  () => context.push('/theory/${c.id}/quiz'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            key: const ValueKey('thy-sources'),
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
                    child: SelectableText(s, style: const TextStyle(fontSize: 12, color: thyBlue)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String key, IconData icon, String title, String sub, VoidCallback onTap) => Material(
    color: thyBlue,
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
class ThyCardsScreen extends ConsumerStatefulWidget {
  final String id;
  const ThyCardsScreen({super.key, required this.id});
  @override
  ConsumerState<ThyCardsScreen> createState() => _ThyCardsState();
}

class _ThyCardsState extends ConsumerState<ThyCardsScreen> {
  List<int>? pile;
  final known = <int>{};
  bool flipped = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(thyProvider).value;
    if (cs == null) return const NavLoading();
    final c = cs.where((x) => x.id == widget.id).firstOrNull;
    if (c == null) return thyMissing(context);
    pile ??= List.generate(c.cards.length, (i) => i);
    final pad = MediaQuery.paddingOf(context);
    final done = pile!.isEmpty;
    return Scaffold(
      backgroundColor: thyBg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NavBack(fallback: '/theory'),
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
                  key: const ValueKey('thy-cards-known'),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: thyBlue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (done)
              Expanded(
                child: Center(
                  key: const ValueKey('thy-cards-done'),
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
                        key: const ValueKey('thy-cards-quiz'),
                        onPressed: () => context.go('/theory/${c.id}/quiz'),
                        style: FilledButton.styleFrom(backgroundColor: thyBlue),
                        child: const Text('Try the chapter quiz'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('thy-card'),
                  onTap: () => setState(() => flipped = !flipped),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: flipped ? thyBlue : Colors.white,
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
                                  key: const ValueKey('thy-card-back'),
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
                                Text(c.cards[pile!.first].front, key: const ValueKey('thy-card-front'), textAlign: TextAlign.center, style: BL.display(28)),
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
                      key: const ValueKey('thy-again'),
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
                      key: const ValueKey('thy-got'),
                      onPressed: () {
                        setState(() {
                          known.add(pile!.removeAt(0));
                          flipped = false;
                        });
                        ref.read(progressProvider.notifier).saveThyCards(c.id, known.length);
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

/// Hazard perception, described in words only (no clips here). Facts from GOV.UK "Theory test: cars".
class _Hazard extends StatefulWidget {
  const _Hazard();
  @override
  State<_Hazard> createState() => _HazardState();
}

class _HazardState extends State<_Hazard> {
  bool open = false;
  static const points = [
    'The second part of the test: 14 video clips of everyday road scenes, filmed from a car.',
    'Each clip has at least one developing hazard; one clip has two. A developing hazard is something that would make you change speed or direction.',
    'Click as soon as you see it starting to develop. The earlier you respond, the more points: up to 5 for each hazard.',
    'Clicking all the time or in a pattern scores 0 for that clip.',
    'You cannot go back or change your answer. The pass mark is 44 out of 75.',
    'You take both parts at the same sitting, with up to a 3-minute break between them, and must pass both.',
  ];
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const ValueKey('thy-hazard'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => open = !open),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: thyBlue),
            const SizedBox(width: 10),
            const Expanded(child: Text('Hazard perception: how it works', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
            Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: BL.muted),
          ]),
          Text('بخش دوم آزمون: ۱۴ ویدیو، تشخیص خطر. نمرهٔ قبولی ۴۴ از ۷۵', textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          if (open)
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: TextStyle(color: thyBlue, fontWeight: FontWeight.w900)),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13.5, height: 1.35))),
                ]),
              ),
        ]),
      ),
    ),
  );
}
