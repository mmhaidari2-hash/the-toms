import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../shared/nav.dart';
import 'seasons_data.dart';

const seaRed = Color(0xFF8A3B2E), seaBg = Color(0xFFF7F1EA);

/// The family calendar on the Thompsons' kitchen wall: British celebrations through the year,
/// the nearest one featured at the top.
class SeasonsScreen extends ConsumerWidget {
  const SeasonsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final es = ref.watch(seasonsProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (es == null || topics == null || content == null) return const NavLoading();
    final gate = SeasonGate(ctrl, content, topics, es, unlockAll: ref.read(progressProvider).unlockAll);
    final pad = MediaQuery.paddingOf(context);
    final up = Seasons.upcoming(es), feat = Seasons.featured(es);
    final rows = <Widget>[];
    String? month;
    for (final (e, d) in up) {
      final m = d == null ? 'Dates to be announced' : '${Seasons.months[d.month - 1]} ${d.year}';
      if (m != month) {
        month = m;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: Text(hl(m.toUpperCase()), style: const TextStyle(fontSize: 11.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.muted)),
          ),
        );
      }
      rows.add(_Row(e: e, d: d, open: gate.levelOpen(e.level), done: ctrl.seasonDone(e.id)));
    }
    return Scaffold(
      backgroundColor: seaBg,
      body: ListView(
        key: const ValueKey('sea-list'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Icon(Icons.calendar_month_rounded, size: 16, color: BL.muted),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'FAMILY CALENDAR · HOME',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Seasonal events', style: BL.display(30)),
          Text(hl('جشن‌ها و مناسبت‌های بریتانیا در طول سال، با خانوادهٔ تامسون'), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
          if (feat != null) ...[const SizedBox(height: 14), _Featured(e: feat.$1, d: feat.$2, open: gate.levelOpen(feat.$1.level), done: ctrl.seasonDone(feat.$1.id))],
          ...rows,
        ],
      ),
    );
  }
}

void _locked(BuildContext context, String level) {
  final (en, fa) = SeasonGate.why(level);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(hl('$en\n$fa'), key: const ValueKey('sea-locked-snack')),
      ),
    );
}

class _Featured extends StatelessWidget {
  final SEvent e;
  final DateTime d;
  final bool open, done;
  const _Featured({required this.e, required this.d, required this.open, required this.done});
  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('sea-featured'),
    color: seaRed,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      key: const ValueKey('sea-featured-open'),
      borderRadius: BorderRadius.circular(22),
      onTap: () => open ? context.push('/seasons/${e.id}') : _locked(context, e.level),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    hl('${Seasons.countdown(d).toUpperCase()} · ${Seasons.countdownFa(d)}'),
                    key: const ValueKey('sea-featured-when'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: BL.ink, letterSpacing: .6),
                  ),
                ),
                const Spacer(),
                if (done) const Icon(Icons.check_circle_rounded, color: BL.gold) else if (!open) const Icon(Icons.lock_rounded, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 10),
            Text(hl(e.title), key: const ValueKey('sea-featured-title'), style: BL.display(28, color: Colors.white)),
            Text(hl(e.titleFa), textDirection: helperDir, style: BL.fa(14, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              hl('${e.approx ? 'Around ' : ''}${Seasons.fmt(d)} · ${e.level}'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(open ? Icons.play_circle_fill_rounded : Icons.lock_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  hl(open ? 'Join the Thompsons' : 'Opens at ${e.level}'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  final SEvent e;
  final DateTime? d;
  final bool open, done;
  const _Row({required this.e, required this.d, required this.open, required this.done});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('sea-ev-${e.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => open ? context.push('/seasons/${e.id}') : _locked(context, e.level),
        child: Opacity(
          opacity: open ? 1 : .5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: seaRed.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      Text(hl(d == null ? '?' : '${d!.day}'), style: BL.display(19, color: seaRed)),
                      Text(hl(d == null ? 'TBA' : Seasons.months[d!.month - 1].substring(0, 3).toUpperCase()), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: seaRed)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hl(e.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        hl('${e.level} · ${d == null ? '' : Seasons.countdown(d!)}${e.approx ? ' (typical date)' : ''}'),
                        style: const TextStyle(color: BL.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Flexible(child: Text(hl(e.titleFa), maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: helperDir, style: BL.fa(12, color: BL.muted))),
                const SizedBox(width: 8),
                if (done)
                  Icon(Icons.check_circle_rounded, key: ValueKey('sea-ev-done-${e.id}'), color: const Color(0xFF2E7D5B), size: 20)
                else if (!open)
                  const Icon(Icons.lock_rounded, color: BL.muted, size: 18)
                else
                  const Icon(Icons.chevron_right_rounded, color: BL.muted),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// One celebration: date and culture note, the family scene (voiced), words, and a 3-question quiz.
class SeasonEventScreen extends ConsumerStatefulWidget {
  final String id;
  static int? seed; // tests fix the option order
  const SeasonEventScreen({super.key, required this.id});
  @override
  ConsumerState<SeasonEventScreen> createState() => _EventState();
}

class _EventState extends ConsumerState<SeasonEventScreen> {
  String? playing;
  bool all = false;
  final picks = <int, int>{}; // question -> picked original index
  List<List<int>>? order;
  (int, int, bool)? result; // pct, xp, newBest

  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  Future<void> _say(String k, String sp, String t) async {
    Voice.stop();
    if (playing == k) return setState(() => playing = null);
    setState(() => playing = k);
    await Voice.say(sp, t);
    if (mounted && playing == k) setState(() => playing = null);
  }

  Future<void> _playAll(SEvent e) async {
    if (all) {
      Voice.stop();
      return setState(() => (all = false, playing = null));
    }
    setState(() => all = true);
    for (final (i, l) in e.lines.indexed) {
      if (!mounted || !all) return;
      setState(() => playing = 'l$i');
      if (!await Voice.say(l.sp, l.en)) break;
    }
    if (mounted) setState(() => (all = false, playing = null));
  }

  void _pick(SEvent e, int q, int o) {
    if (picks.containsKey(q) || result != null) return;
    setState(() => picks[q] = o);
    if (picks.length == e.qs.length) {
      final ctrl = ref.read(progressProvider.notifier);
      final old = ctrl.seasonScore(e.id);
      final pct = Seasons.pct(picks.values.where((v) => v == 0).length);
      final xp = ctrl.saveSeason(e.id, pct);
      setState(() => result = (pct, xp.xp, old == null || pct > old));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final es = ref.watch(seasonsProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (es == null || topics == null || content == null) return const NavLoading();
    final e = es.where((x) => x.id == widget.id).firstOrNull;
    final pad = MediaQuery.paddingOf(context);
    if (e == null) return Scaffold(body: Center(child: TextButton(onPressed: () => context.go('/seasons'), child: const Text('Not found — back to the calendar'))));
    final gate = SeasonGate(ctrl, content, topics, es, unlockAll: ref.read(progressProvider).unlockAll);
    if (!gate.levelOpen(e.level)) {
      final (en, fa) = SeasonGate.why(e.level);
      return Scaffold(
        backgroundColor: seaBg,
        body: Padding(
          padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NavBack(fallback: '/seasons'),
              const SizedBox(height: 30),
              const Icon(Icons.lock_rounded, size: 40, color: BL.muted),
              const SizedBox(height: 10),
              Text(hl(e.title), style: BL.display(26)),
              const SizedBox(height: 8),
              Text(hl(en), key: const ValueKey('sea-locked')),
              Text(hl(fa), textDirection: helperDir, style: BL.fa(13)),
            ],
          ),
        ),
      );
    }
    order ??= [
      for (final (i, q) in e.qs.indexed) List.generate(q.options.length, (k) => k)..shuffle(Random(SeasonEventScreen.seed ?? (e.id.hashCode + i + DateTime.now().millisecond))),
    ];
    final fa = ctrl.pref('seaFa', 'off') == 'on';
    final d = e.next(Seasons.today);
    return Scaffold(
      backgroundColor: seaBg,
      body: ListView(
        key: const ValueKey('sea-event'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          Row(
            children: [
              const NavBack(fallback: '/seasons'),
              const Spacer(),
              FilterChip(
                key: const ValueKey('sea-fa'),
                selected: fa,
                showCheckmark: false,
                label: Text(hl('فارسی')),
                selectedColor: seaRed,
                labelStyle: TextStyle(color: fa ? Colors.white : BL.ink, fontWeight: FontWeight.w800),
                onSelected: (_) => ctrl.setPref('seaFa', fa ? 'off' : 'on'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(hl(e.title), style: BL.display(28)),
          Text(hl(e.titleFa), textDirection: helperDir, style: BL.fa(14)),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('sea-when'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: seaRed.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 18, color: seaRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hl(d == null ? 'Date to be announced' : '${e.approx ? 'Around ' : 'Next: '}${Seasons.fmt(d)} · ${Seasons.countdown(d)}'),
                        key: const ValueKey('sea-date'),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: seaRed),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(hl(e.when), style: const TextStyle(fontSize: 13, color: BL.muted)),
                if (fa) Text(hl(e.whenFa), textDirection: helperDir, style: BL.fa(12.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(hl(e.note), key: const ValueKey('sea-note'), style: const TextStyle(fontSize: 14.5, height: 1.45)),
          if (fa) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hl(e.noteFa), textDirection: helperDir, style: BL.fa(13.5))),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('At the Thompsons\'', style: BL.display(20))),
              TextButton.icon(
                key: const ValueKey('sea-play-all'),
                onPressed: () => _playAll(e),
                icon: Icon(all ? Icons.stop_rounded : Icons.play_arrow_rounded, color: seaRed),
                label: Text(hl(all ? 'Stop' : 'Play scene'), style: const TextStyle(color: seaRed, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          for (final (i, l) in e.lines.indexed)
            Container(
              key: ValueKey('sea-line-$i'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: playing == 'l$i' ? seaRed : Colors.transparent, width: 1.5),
              ),
              child: InkWell(
                key: ValueKey('sea-play-$i'),
                onTap: () => _say('l$i', l.sp, l.en),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: BL.mist,
                      backgroundImage: l.avatar.isEmpty ? null : AssetImage(l.avatar),
                      child: l.avatar.isEmpty ? const Icon(Icons.person_rounded, size: 18, color: seaRed) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(hl(l.name), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: seaRed)),
                          Text(hl(l.en), style: const TextStyle(fontSize: 14.5, height: 1.35)),
                          if (fa) Text(hl(l.fa), key: ValueKey('sea-line-fa-$i'), textDirection: helperDir, style: BL.fa(13)),
                        ],
                      ),
                    ),
                    Icon(playing == 'l$i' ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 18, color: BL.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text('Words', style: BL.display(20)),
          const SizedBox(height: 6),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, w) in e.words.indexed)
                  ListTile(
                    key: ValueKey('sea-word-$i'),
                    dense: true,
                    onTap: () => _say('w$i', 'narrator', w.w),
                    leading: Icon(playing == 'w$i' ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, color: seaRed, size: 20),
                    title: Text(hl(w.w), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hl(w.en)),
                        Align(alignment: Alignment.centerRight, child: Text(hl(w.fa), textDirection: helperDir, style: BL.fa(12.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Quick quiz', key: const ValueKey('sea-quiz'), style: BL.display(20)),
          for (final (qi, q) in e.qs.indexed)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(hl('${qi + 1}. ${q.q}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 6),
                  for (final o in order![qi])
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _Opt(
                        key: ValueKey('sea-q$qi-opt-$o'),
                        text: q.options[o],
                        state: !picks.containsKey(qi) ? 0 : o == 0 ? 1 : picks[qi] == o ? 2 : 0,
                        onTap: () => _pick(e, qi, o),
                      ),
                    ),
                ],
              ),
            ),
          if (result != null) _result(e, ctrl),
        ],
      ),
    );
  }

  Widget _result(SEvent e, ProgressController ctrl) {
    final (pct, xp, best) = result!;
    final right = picks.values.where((v) => v == 0).length;
    final ok = pct >= Seasons.pass;
    return Container(
      key: const ValueKey('sea-result'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ok ? const Color(0xFF2E7D5B) : seaRed, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hl('$right / ${e.qs.length} · ${ok ? 'Lovely, well done!' : 'Nearly — have another go.'}'),
            key: const ValueKey('sea-score'),
            style: BL.display(20, color: Colors.white),
          ),
          Text(hl(ok ? 'آفرین، عالی بود!' : 'نزدیک بود؛ دوباره امتحان کن.'), textDirection: helperDir, style: BL.fa(13, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(hl('+$xp XP${best ? ' · best score saved' : ''}'), key: const ValueKey('sea-xp'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                key: const ValueKey('sea-retry'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                onPressed: () => setState(() {
                  picks.clear();
                  result = null;
                  order = null;
                }),
                child: const Text('Try again'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('sea-back-cal'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: BL.ink),
                onPressed: () => context.canPop() ? context.pop() : context.go('/seasons'),
                child: const Text('Back to the calendar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Opt extends StatelessWidget {
  final String text;
  final int state; // 0 plain, 1 right, 2 wrong pick
  final VoidCallback onTap;
  const _Opt({super.key, required this.text, required this.state, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = state == 1 ? const Color(0xFF2E7D5B) : state == 2 ? const Color(0xFFB3261E) : BL.mist;
    return Material(
      color: state == 0 ? seaBg : c,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Expanded(child: Text(hl(text), style: TextStyle(fontWeight: FontWeight.w700, color: state == 0 ? BL.ink : Colors.white))),
              if (state == 1) const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              if (state == 2) const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
