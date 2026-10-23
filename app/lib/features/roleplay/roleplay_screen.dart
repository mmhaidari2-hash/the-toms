import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../missions/mission_screen.dart' show MissionLocked;
import '../missions/missions_data.dart';
import '../shared/nav.dart';
import 'roleplay_data.dart';

/// One role-play: brief (3 goals) → dialogue (pick a reply; hint, replay, slow replay, Persian) → report card.
class RoleplayScreen extends ConsumerWidget {
  final String id;
  const RoleplayScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rps = ref.watch(roleplaysProvider).value, ms = ref.watch(missionsProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (rps == null || ms == null || topics == null || content == null) return const NavLoading();
    final r = rps.where((x) => x.id == id).firstOrNull;
    if (r == null) {
      return Scaffold(backgroundColor: BL.cream, body: Center(child: TextButton(onPressed: () => context.go('/missions'), child: const Text('Role-play not found · back to Missions'))));
    }
    final gate = MissionGate(ref.read(progressProvider.notifier), content, topics, ms, unlockAll: ref.read(progressProvider).unlockAll);
    if (!gate.levelOpen(r.level)) {
      return MissionLocked(m: Mission(id: r.id, level: r.level, spot: r.spot, title: r.title, titleFa: r.titleFa, goal: '', goalFa: '', say: const [], hear: const [], tip: ('', '')));
    }
    return _Roleplay(key: ValueKey('rp-screen-${r.id}'), r: r);
  }
}

enum _Stage { brief, talk, report }

/// A line in the dialogue: the character's (with replay controls) or the learner's chosen reply.
class _Line {
  final bool npc;
  final String en, fa;
  final int q;
  final Tr? fb;
  const _Line(this.npc, this.en, this.fa, {this.q = 2, this.fb});
}

class _Roleplay extends ConsumerStatefulWidget {
  final Roleplay r;
  const _Roleplay({super.key, required this.r});
  @override
  ConsumerState<_Roleplay> createState() => _RoleplayState();
}

class _RoleplayState extends ConsumerState<_Roleplay> {
  Roleplay get r => widget.r;
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  _Stage stage = _Stage.brief;
  final lines = <_Line>[];
  final goals = <int>{};
  final tried = <int>{}; // wrong options tried on this turn
  int turn = 0, natural = 0, wrong = 0, hints = 0;
  bool hint = false, fa = false, finished = false;
  Tr? wrongFb;
  String? playing;
  XpAward? award;
  int stars = 0;
  final scroll = ScrollController();

  @override
  void dispose() {
    Voice.stop();
    scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      });

  Future<void> _say(String key, String sp, String en, {double rate = 1}) async {
    setState(() => playing = key);
    await Voice.say(sp, en, rate: rate);
    if (mounted && playing == key) setState(() => playing = null);
  }

  void _start() {
    setState(() {
      stage = _Stage.talk;
      lines.add(_Line(true, r.turns[0].npc.en, r.turns[0].npc.fa));
    });
    _say('rp-play-0', r.sp, r.turns[0].npc.en);
  }

  Future<void> _pick(RpOption o) async {
    if (finished) return;
    final t = r.turns[turn];
    if (o.q == 0) {
      final i = t.opts.indexOf(o);
      if (tried.contains(i)) return;
      // The natural answer goes to My mistakes as a sentence to rebuild later.
      final b = t.best;
      ctrl.recordMistake('s:${b.en}', {'t': 's', 'a': b.en.split(' '), 'fa': b.fa, 'l': r.id});
      setState(() {
        tried.add(i);
        wrong++;
        wrongFb = o.fb;
      });
      return;
    }
    Voice.stop();
    setState(() {
      if (o.q == 2 && tried.isEmpty) natural++;
      if (o.goal >= 0) goals.add(o.goal);
      lines.add(_Line(false, o.en, o.fa, q: o.q, fb: o.fb));
      wrongFb = null;
      tried.clear();
      hint = false;
      turn++;
      if (turn >= r.turns.length) finished = true;
    });
    _toEnd();
    await _say('rp-me-${lines.length}', 'me', o.en);
    if (!mounted) return;
    final next = finished ? r.end : r.turns[turn].npc;
    setState(() => lines.add(_Line(true, next.en, next.fa)));
    _toEnd();
    _say('rp-play-${lines.length - 1}', r.sp, next.en);
  }

  void _report() {
    Voice.stop();
    final s = Roleplay.stars(turns: r.turns.length, natural: natural, wrong: wrong, hints: hints);
    setState(() {
      stars = s;
      award = ctrl.finishRoleplay(r.id, s);
      stage = _Stage.report;
    });
  }

  void _again() => setState(() {
        stage = _Stage.brief;
        lines.clear();
        goals.clear();
        tried.clear();
        turn = natural = wrong = hints = 0;
        hint = finished = false;
        wrongFb = null;
        award = null;
      });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 10, 6),
          child: Row(children: [
            const NavBack(fallback: '/missions'),
            const SizedBox(width: 8),
            ClipOval(child: Image.asset(r.icon, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 36))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('${r.level}  ·  Role-play  ·  ${r.npc}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (stage == _Stage.talk)
              IconButton(
                key: const ValueKey('rp-fa'),
                tooltip: fa ? 'Hide Persian' : 'Show Persian',
                onPressed: () => setState(() => fa = !fa),
                style: IconButton.styleFrom(backgroundColor: fa ? BL.navy : BL.paper),
                icon: Icon(Icons.translate_rounded, size: 20, color: fa ? Colors.white : BL.navy),
              ),
          ]),
        ),
        if (stage == _Stage.talk) _goalBar(),
        Expanded(
          child: switch (stage) {
            _Stage.brief => _briefPage(pad.bottom),
            _Stage.talk => _talk(pad.bottom),
            _Stage.report => _reportCard(pad.bottom),
          },
        ),
      ]),
    );
  }

  Widget _goalBar() => Padding(
        key: const ValueKey('rp-goals'),
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Row(children: [
          for (var i = 0; i < r.goals.length; i++)
            Expanded(
              child: AnimatedContainer(
                key: ValueKey('rp-goal-$i-${goals.contains(i) ? 'done' : 'open'}'),
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: i < r.goals.length - 1 ? 6 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(color: goals.contains(i) ? BL.green : BL.paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: goals.contains(i) ? BL.green : BL.mist)),
                child: Row(children: [
                  Icon(goals.contains(i) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 14, color: goals.contains(i) ? Colors.white : BL.muted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(r.goals[i].en, maxLines: 2, style: TextStyle(fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w700, color: goals.contains(i) ? Colors.white : BL.ink))),
                ]),
              ),
            ),
        ]),
      );

  Widget _brief(double bottom) => ListView(
        key: const ValueKey('rp-brief'),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: BL.navy, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('ROLE-PLAY', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w900, color: BL.gold)),
              const SizedBox(height: 4),
              Text(r.intro.en, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 4),
              Text(r.intro.fa, textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('YOUR 3 GOALS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: BL.red))),
            Text('سه هدف تو', textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          ]),
          const SizedBox(height: 6),
          for (var i = 0; i < r.goals.length; i++)
            Container(
              key: ValueKey('rp-brief-goal-$i'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                CircleAvatar(radius: 12, backgroundColor: BL.gold, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: BL.ink))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.goals[i].en, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    Text(r.goals[i].fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          _tipRow(Icons.lightbulb_rounded, 'Stuck? Tap Hint. Tap the speaker to replay, or Slow to hear it slowly.', 'گیر کردی؟ «راهنما» را بزن. برای شنیدن دوباره بلندگو، و برای آهسته «Slow» را بزن.'),
          _tipRow(Icons.translate_rounded, 'The translate button shows Persian for every line.', 'دکمهٔ ترجمه برای هر جمله فارسی را نشان می‌دهد.'),
        ],
      );

  /// The brief with its Start button pinned at the bottom (always in reach on small phones).
  Widget _briefPage(double bottom) => Column(children: [
        Expanded(child: _brief(0)),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FilledButton.icon(
              key: const ValueKey('rp-start'),
              onPressed: _start,
              style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.forum_rounded),
              label: const Text('Start the role-play · شروع', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            ),
            if (ctrl.roleplayStars(r.id) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(child: Text('Your best: ${'★' * ctrl.roleplayStars(r.id)}${'☆' * (3 - ctrl.roleplayStars(r.id))}', key: const ValueKey('rp-best'), style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w700))),
              ),
          ]),
        ),
      ]);

  Widget _tipRow(IconData i, String en, String f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: BL.navy),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(en, style: const TextStyle(fontSize: 13, height: 1.35, color: BL.ink)),
              Text(f, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
            ]),
          ),
        ]),
      );

  Widget _bubble(int i, _Line l) {
    final key = 'rp-play-$i', slow = 'rp-slow-$i';
    if (!l.npc) {
      final good = l.q == 2;
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              key: ValueKey('rp-me-$i'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: const BoxDecoration(color: BL.navy, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.en, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                if (fa) Text(l.fa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white70)),
              ]),
            ),
            if (l.fb != null)
              Container(
                key: ValueKey('rp-fb-$i-${good ? 'natural' : 'works'}'),
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: (good ? BL.green : BL.gold).withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${good ? 'Natural ✓' : 'Works · tip'}  ${l.fb!.en}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: good ? BL.green : const Color(0xFF7A5A00))),
                  if (fa) Text(l.fb!.fa, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
                ]),
              ),
          ]),
        ),
      );
    }
    Widget ctl(String k, IconData ic, String label, double rate) => InkWell(
          key: ValueKey(k),
          borderRadius: BorderRadius.circular(99),
          onTap: () => _say(k, r.sp, l.en, rate: rate),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(playing == k ? Icons.graphic_eq_rounded : ic, size: 17, color: playing == k ? BL.red : BL.navy),
              const SizedBox(width: 3),
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: BL.navy)),
            ]),
          ),
        );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Container(
          key: ValueKey('rp-npc-$i'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 4),
          decoration: BoxDecoration(color: BL.paper, border: Border.all(color: BL.mist), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.npc.split(' · ').first.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: BL.muted)),
            Text(l.en, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.3)),
            if (fa) Text(l.fa, key: ValueKey('rp-npc-fa-$i'), textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted)),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [ctl(key, Icons.volume_up_rounded, 'Replay', 1), ctl(slow, Icons.slow_motion_video_rounded, 'Slow', Voice.rates.first)]),
          ]),
        ),
      ),
    );
  }

  Widget _talk(double bottom) {
    final t = finished ? null : r.turns[turn];
    return Column(children: [
      Expanded(
        child: ListView(
          key: const ValueKey('rp-chat'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [for (var i = 0; i < lines.length; i++) _bubble(i, lines[i])],
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, bottom + 12),
        decoration: BoxDecoration(color: BL.paper, boxShadow: BL.shadow(.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: t == null
            ? FilledButton.icon(
                key: const ValueKey('rp-report'),
                onPressed: _report,
                style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: const Text('See my report card · کارنامه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              )
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Your reply · جواب تو', style: TextStyle(fontSize: 11.5, letterSpacing: .6, fontWeight: FontWeight.w900, color: BL.muted.withValues(alpha: .9)))),
                  TextButton.icon(
                    key: const ValueKey('rp-hint'),
                    onPressed: hint
                        ? null
                        : () => setState(() {
                              hint = true;
                              hints++;
                            }),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF8A6400)),
                    icon: const Icon(Icons.lightbulb_rounded, size: 17),
                    label: const Text('Hint · راهنما', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
                if (hint)
                  Container(
                    key: const ValueKey('rp-hint-text'),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: BL.gold.withValues(alpha: .22), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(t.hint.en, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
                      Text(t.hint.fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                    ]),
                  ),
                if (wrongFb != null)
                  Container(
                    key: const ValueKey('rp-wrong'),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: BL.red.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.replay_rounded, size: 17, color: BL.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Not quite. ${wrongFb!.en}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
                          Text(wrongFb!.fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                        ]),
                      ),
                    ]),
                  ),
                for (final (j, o) in _order(t).indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      color: tried.contains(t.opts.indexOf(o)) ? BL.mist.withValues(alpha: .6) : BL.cream,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        key: ValueKey('rp-opt-$j'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _pick(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: tried.contains(t.opts.indexOf(o)) ? BL.mist : BL.navy.withValues(alpha: .25))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(o.en, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: tried.contains(t.opts.indexOf(o)) ? BL.muted : BL.ink, decoration: tried.contains(t.opts.indexOf(o)) ? TextDecoration.lineThrough : null)),
                            if (fa) Text(o.fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
      ),
    ]);
  }

  /// Options in a stable shuffled order per turn (so the best answer isn't always first).
  List<RpOption> _order(RpTurn t) {
    final o = [...t.opts];
    final k = (turn + r.id.length) % 3;
    return [...o.skip(k), ...o.take(k)];
  }

  Widget _reportCard(double bottom) {
    final phrases = [for (final t in r.turns) t.best];
    return ListView(
      key: const ValueKey('rp-reportcard'),
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F3A5F), Color(0xFF14263F)]), borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            const Text('REPORT CARD · کارنامه', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w900, color: BL.gold)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++) Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, key: ValueKey('rp-star-$i-${i < stars ? 'on' : 'off'}'), size: 44, color: i < stars ? const Color(0xFFFFC83D) : Colors.white38),
            ]),
            const SizedBox(height: 4),
            Text(stars == 3 ? 'Brilliant!' : (stars == 2 ? 'Well done!' : 'Good practice!'), style: BL.display(26, color: Colors.white)),
            Text(stars == 3 ? 'عالی بود!' : (stars == 2 ? 'آفرین!' : 'تمرین خوبی بود!'), textDirection: TextDirection.rtl, style: BL.fa(14, color: Colors.white70)),
            const SizedBox(height: 12),
            Row(children: [
              _stat('rp-stat-natural', '$natural/${r.turns.length}', 'Natural', 'طبیعی'),
              _stat('rp-stat-hints', '$hints', 'Hints', 'راهنما'),
              _stat('rp-stat-tries', '$wrong', 'Retries', 'تکرار'),
              _stat('rp-stat-xp', '+${award?.xp ?? 0}', 'XP', 'امتیاز'),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < r.goals.length; i++)
          ListTile(
            key: ValueKey('rp-report-goal-$i'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(goals.contains(i) ? Icons.check_circle_rounded : Icons.cancel_rounded, color: goals.contains(i) ? BL.green : BL.muted),
            title: Text(r.goals[i].en, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            subtitle: Text(r.goals[i].fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          ),
        const SizedBox(height: 6),
        Row(children: [
          const Expanded(child: Text('PHRASES TO REMEMBER', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: BL.red))),
          Text('عبارت‌هایی برای یادگرفتن', textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
        ]),
        const SizedBox(height: 6),
        for (final (i, p) in phrases.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(p.en, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                  Text(p.fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                ]),
              ),
              Builder(builder: (_) {
                final inBox = ref.watch(progressProvider).leitnerBox.containsKey(p.en);
                return IconButton(
                  key: ValueKey('rp-leit-$i${inBox ? '-in' : ''}'),
                  tooltip: inBox ? 'In your Leitner box' : 'Add to Leitner',
                  onPressed: inBox ? null : () => ctrl.addToLeitner(p.en, p.fa, src: 'Role-play · ${r.title}'),
                  icon: Icon(inBox ? Icons.inventory_2_rounded : Icons.add_box_outlined, color: inBox ? BL.green : BL.navy),
                );
              }),
            ]),
          ),
        const SizedBox(height: 14),
        FilledButton(
          key: const ValueKey('rp-done'),
          onPressed: () => context.canPop() ? context.pop() : context.go('/missions'),
          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('Done · تمام', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ),
        TextButton(key: const ValueKey('rp-again'), onPressed: _again, child: const Text('Try again for 3 stars · دوباره')),
      ],
    );
  }

  Widget _stat(String k, String v, String en, String f) => Expanded(
        child: Column(key: ValueKey(k), children: [
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          Text(en, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(f, textDirection: TextDirection.rtl, style: BL.fa(10.5, color: Colors.white54)),
        ]),
      );
}
