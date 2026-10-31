import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/models/dialogue_node.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import 'park_data.dart';
import 'park_screen.dart';

/// One park game at one level. Rounds are shuffled afresh each play.
class ParkGameScreen extends ConsumerStatefulWidget {
  final String level, game;
  const ParkGameScreen({super.key, required this.level, required this.game});

  /// Test hooks: a fixed shuffle, and the current right answer.
  static int? seed;
  static final answer = ValueNotifier<Object?>(null);

  @override
  ConsumerState<ParkGameScreen> createState() => _ParkGameScreenState();
}

class _ParkGameScreenState extends ConsumerState<ParkGameScreen> {
  XpAward? award;
  bool newBest = false;
  Widget? _body; // rounds are drawn once per play
  int pct = 0;
  late final Random rnd = Random(ParkGameScreen.seed ?? DateTime.now().microsecondsSinceEpoch);

  void _done(int p) {
    final (a, best) = ref.read(progressProvider.notifier).saveParkGame(widget.level, widget.game, p.clamp(0, 100));
    setState(() {
      pct = p.clamp(0, 100);
      award = a;
      newBest = best;
    });
  }

  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (topics == null || content == null) return const NavLoading();
    final g = Park.game(widget.game);
    final ctrl = ref.read(progressProvider.notifier);
    if (g == null || Park.courseLevel(widget.level) == 1 && widget.level != 'A1') {
      return Scaffold(
        backgroundColor: parkBg,
        body: Center(
          child: TextButton(onPressed: () => context.go('/park'), child: const Text('Game not found — back to the park')),
        ),
      );
    }
    final gate = ParkGate(ctrl, content, topics, unlockAll: ref.read(progressProvider).gatesOpen);
    if (!gate.levelOpen(widget.level)) return _Locked(level: widget.level, g: g);
    if (award != null) {
      final pass = pct >= Park.pass;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('park-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: false,
          right: pct,
          total: 100,
          title: newBest ? 'New best: $pct%!' : (pass ? 'Well played!' : 'Keep practising!'),
          titleFa: newBest ? 'رکورد تازه!' : (pass ? 'آفرین!' : 'باز هم تمرین کن.'),
          onRetry: () => context.go('/park/${widget.level}/${widget.game}?r=${DateTime.now().millisecondsSinceEpoch}'),
          onContinue: () => context.go('/park'),
        ),
      );
    }
    final pw = ParkWords.of(ctrl, content.course, widget.level);
    final pad = MediaQuery.paddingOf(context);
    final Widget body = _body ??= switch (g.id) {
      'match' => _Match(words: ParkRounds.match(pw.words, rnd), rnd: rnd, onDone: _done),
      'listen' => _Listen(rounds: ParkRounds.listen(pw.words, rnd), onDone: _done),
      'spell' => _Spell(words: ParkRounds.spell(pw, rnd), onDone: _done),
      'odd' => _Odd(sets: ParkRounds.odd(widget.level, rnd), rnd: rnd, onDone: _done),
      _ => _Build(phrases: ParkRounds.build(pw, rnd), rnd: rnd, onDone: _done),
    };
    return Scaffold(
      backgroundColor: parkBg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, pad.top + 6, 12, 4),
            child: Row(
              children: [
                const NavBack(fallback: '/park'),
                const SizedBox(width: 10),
                Icon(gameIcons[g.id], color: parkGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hl(g.name), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(hl('${widget.level} · ${g.nameFa}'), style: BL.fa(12, color: BL.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, pad.bottom + 16), child: body),
          ),
        ],
      ),
    );
  }
}

class _Locked extends StatelessWidget {
  final String level;
  final ParkGame g;
  const _Locked({required this.level, required this.g});
  @override
  Widget build(BuildContext context) {
    final (en, fa) = ParkGate.why(level);
    return Scaffold(
      key: const ValueKey('park-locked'),
      backgroundColor: parkBg,
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: NavBack(fallback: '/park'),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 56, color: BL.muted),
                      const SizedBox(height: 14),
                      Text(hl('${g.name} · $level'), textAlign: TextAlign.center, style: BL.display(24)),
                      const SizedBox(height: 10),
                      Text(
                        hl(en),
                        key: const ValueKey('park-locked-why'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: BL.muted, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hl(fa),
                        textDirection: helperDir,
                        textAlign: TextAlign.center,
                        style: BL.fa(13, color: BL.muted),
                      ),
                      const SizedBox(height: 18),
                      TextButton(onPressed: () => context.go('/park'), child: const Text('Back to the park')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _say(String w, {double rate = 1}) => Voice.say('narrator', w, rate: rate);

Widget _progress(int i, int n, int right) => Row(
  children: [
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: i / n, minHeight: 8, color: parkGreen, backgroundColor: Colors.white),
      ),
    ),
    const SizedBox(width: 10),
    Text(
      hl('${min(i + 1, n)}/$n'),
      key: const ValueKey('park-round'),
      style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted),
    ),
    const SizedBox(width: 10),
    const Icon(Icons.star_rounded, size: 18, color: BL.gold),
    Text(
      hl('$right'),
      key: const ValueKey('park-right'),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ],
);

Widget _tile(String key, String text, {Color? color, Color fg = BL.ink, VoidCallback? onTap, bool fa = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: SizedBox(
    width: double.infinity,
    child: Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey(key),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Text(
            hl(text),
            textAlign: TextAlign.center,
            textDirection: fa ? helperDir : null,
            style: fa ? BL.fa(14.5, color: fg) : TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ),
    ),
  ),
);

Widget _next(VoidCallback onTap, bool last) => FilledButton(
  key: const ValueKey('park-next'),
  onPressed: onTap,
  style: FilledButton.styleFrom(
    backgroundColor: parkGreen,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  child: Text(hl(last ? 'See my score' : 'Next'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
);

/// Word match against the clock: tap an English word, then its Persian.
class _Match extends StatefulWidget {
  final List<NewWord> words;
  final Random rnd;
  final void Function(int) onDone;
  const _Match({required this.words, required this.rnd, required this.onDone});
  @override
  State<_Match> createState() => _MatchState();
}

class _MatchState extends State<_Match> {
  late final en = List.generate(widget.words.length, (i) => i)..shuffle(widget.rnd);
  late final fa = List.generate(widget.words.length, (i) => i)..shuffle(widget.rnd);
  final matched = <int>{};
  int? sel, wrong;
  int mistakes = 0, left = Park.matchSeconds;
  Timer? timer;
  bool started = false, over = false;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (started) return;
    started = true;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _end();
    });
  }

  int get score => max(0, (100 * matched.length / widget.words.length).round() - 5 * mistakes);

  void _end() {
    timer?.cancel();
    if (over) return;
    over = true;
    widget.onDone(score);
  }

  void _tapEn(int i) {
    if (matched.contains(i)) return;
    _start();
    _say(widget.words[i].word);
    setState(() => sel = i);
  }

  void _tapFa(int i) {
    if (matched.contains(i) || sel == null) return;
    if (sel == i) {
      HapticFeedback.lightImpact();
      setState(() {
        matched.add(i);
        sel = null;
        wrong = null;
      });
      if (matched.length == widget.words.length) Future.delayed(const Duration(milliseconds: 500), _end);
    } else {
      setState(() {
        mistakes++;
        wrong = i;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.words;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.timer_rounded, color: left <= 10 ? BL.red : parkGreen),
            const SizedBox(width: 4),
            Text(
              hl('0:${left.toString().padLeft(2, '0')}'),
              key: const ValueKey('match-timer'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: left <= 10 ? BL.red : BL.ink),
            ),
            const Spacer(),
            Text(
              hl('${matched.length}/${w.length} pairs'),
              key: const ValueKey('match-count'),
              style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(hl(started ? 'Tap a word, then its Persian.' : 'Tap a word to start the clock, then tap its Persian.'), style: const TextStyle(color: BL.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final i in en)
                        _tile(
                          'match-en-$i',
                          w[i].word,
                          color: matched.contains(i) ? parkGreen.withValues(alpha: .15) : (sel == i ? parkGreen : null),
                          fg: sel == i ? Colors.white : (matched.contains(i) ? BL.muted : BL.ink),
                          onTap: () => _tapEn(i),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      for (final i in fa)
                        _tile(
                          'match-fa-$i',
                          w[i].fa,
                          fa: true,
                          color: matched.contains(i) ? parkGreen.withValues(alpha: .15) : (wrong == i ? BL.red.withValues(alpha: .2) : null),
                          fg: matched.contains(i) ? BL.muted : BL.ink,
                          onTap: () => _tapFa(i),
                        ),
                    ],
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

/// Listen & tap: hear the word, tap it.
class _Listen extends StatefulWidget {
  final List<(NewWord, List<String>)> rounds;
  final void Function(int) onDone;
  const _Listen({required this.rounds, required this.onDone});
  @override
  State<_Listen> createState() => _ListenState();
}

class _ListenState extends State<_Listen> {
  int i = 0, right = 0;
  String? picked;

  @override
  void initState() {
    super.initState();
    _round();
  }

  void _round() {
    picked = null;
    ParkGameScreen.answer.value = widget.rounds[i].$1.word;
    WidgetsBinding.instance.addPostFrameCallback((_) => _say(widget.rounds[i].$1.word));
  }

  @override
  Widget build(BuildContext context) {
    final (w, opts) = widget.rounds[i];
    final last = i == widget.rounds.length - 1;
    return ListView(
      children: [
        _progress(i, widget.rounds.length, right),
        const SizedBox(height: 24),
        Center(
          child: InkWell(
            key: const ValueKey('listen-play'),
            customBorder: const CircleBorder(),
            onTap: () => _say(w.word),
            child: const CircleAvatar(
              radius: 42,
              backgroundColor: parkGreen,
              child: Icon(Icons.volume_up_rounded, size: 40, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Listen, then tap what you hear',
            style: TextStyle(color: BL.muted, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 18),
        for (final o in opts)
          _tile(
            'listen-opt-$o',
            o,
            color: picked == null ? null : (o == w.word ? parkGreen : (o == picked ? BL.red.withValues(alpha: .2) : null)),
            fg: picked != null && o == w.word ? Colors.white : BL.ink,
            onTap: picked != null
                ? null
                : () => setState(() {
                    picked = o;
                    if (o == w.word) right++;
                  }),
          ),
        if (picked != null) ...[
          Text(
            hl(w.fa),
            key: const ValueKey('listen-fa'),
            textAlign: TextAlign.center,
            textDirection: helperDir,
            style: BL.fa(15, color: BL.ink),
          ),
          const SizedBox(height: 10),
          _next(() {
            if (last) return widget.onDone((100 * right / widget.rounds.length).round());
            setState(() {
              i++;
              _round();
            });
          }, last),
        ],
      ],
    );
  }
}

/// Spelling bee: hear it (and see the Persian), spell it the British way.
class _Spell extends StatefulWidget {
  final List<NewWord> words;
  final void Function(int) onDone;
  const _Spell({required this.words, required this.onDone});
  @override
  State<_Spell> createState() => _SpellState();
}

class _SpellState extends State<_Spell> {
  int i = 0, right = 0;
  bool? ok;
  bool hint = false;
  final ctl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _round();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _round() {
    ok = null;
    hint = false;
    ctl.clear();
    ParkGameScreen.answer.value = widget.words[i].word;
    WidgetsBinding.instance.addPostFrameCallback((_) => _say(widget.words[i].word, rate: .85));
  }

  void _check() {
    if (ok != null || ctl.text.trim().isEmpty) return;
    final good = ctl.text.trim().toLowerCase() == widget.words[i].word.toLowerCase();
    setState(() {
      ok = good;
      if (good) right++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.words[i], last = i == widget.words.length - 1, us = Park.us[w.word.toLowerCase()];
    return ListView(
      children: [
        _progress(i, widget.words.length, right),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              key: const ValueKey('spell-play'),
              customBorder: const CircleBorder(),
              onTap: () => _say(w.word, rate: .85),
              child: const CircleAvatar(
                radius: 34,
                backgroundColor: parkGreen,
                child: Icon(Icons.volume_up_rounded, size: 32, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                hl(w.fa),
                key: const ValueKey('spell-fa'),
                textDirection: helperDir,
                style: BL.fa(17, color: BL.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (hint && ok == null)
          Text(
            hl('${w.word[0]}${' _' * (w.word.length - 1)}'),
            key: const ValueKey('spell-hint-text'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 2, fontWeight: FontWeight.w800),
          ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('spell-input'),
          controller: ctl,
          enabled: ok == null,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _check(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: 'Spell it…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        if (ok == null)
          Row(
            children: [
              TextButton.icon(
                key: const ValueKey('spell-hint'),
                onPressed: hint ? null : () => setState(() => hint = true),
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: const Text('Hint'),
              ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('spell-check'),
                onPressed: _check,
                style: FilledButton.styleFrom(backgroundColor: parkGreen),
                child: const Text('Check', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          )
        else ...[
          Container(
            key: const ValueKey('spell-result'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ok! ? parkGreen.withValues(alpha: .12) : BL.red.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text(
                  hl(ok! ? 'Spot on!' : 'It\'s spelt:'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: ok! ? parkGreen : BL.red),
                ),
                Text(hl(w.word), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                if (us != null)
                  Text(
                    hl('British "${w.word}" · American "$us"'),
                    key: const ValueKey('spell-us'),
                    style: const TextStyle(fontSize: 12.5, color: BL.muted, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _next(() {
            if (last) return widget.onDone((100 * right / widget.words.length).round());
            setState(() {
              i++;
              _round();
            });
          }, last),
        ],
      ],
    );
  }
}

/// Odd one out.
class _Odd extends StatefulWidget {
  final List<OddSet> sets;
  final Random rnd;
  final void Function(int) onDone;
  const _Odd({required this.sets, required this.rnd, required this.onDone});
  @override
  State<_Odd> createState() => _OddState();
}

class _OddState extends State<_Odd> {
  int i = 0, right = 0;
  String? picked;
  late List<String> opts;

  @override
  void initState() {
    super.initState();
    _round();
  }

  void _round() {
    picked = null;
    final s = widget.sets[i];
    opts = [...s.same, s.odd]..shuffle(widget.rnd);
    ParkGameScreen.answer.value = s.odd;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sets[i], last = i == widget.sets.length - 1;
    return ListView(
      children: [
        _progress(i, widget.sets.length, right),
        const SizedBox(height: 20),
        const Text(
          'Which one doesn\'t belong?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          hl('کدام به بقیه نمی‌خورد؟'),
          textAlign: TextAlign.center,
          textDirection: helperDir,
          style: BL.fa(13, color: BL.muted),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          crossAxisSpacing: 8,
          children: [
            for (final o in opts)
              _tile(
                'odd-opt-$o',
                o,
                color: picked == null ? null : (o == s.odd ? parkGreen : (o == picked ? BL.red.withValues(alpha: .2) : null)),
                fg: picked != null && o == s.odd ? Colors.white : BL.ink,
                onTap: picked != null
                    ? null
                    : () => setState(() {
                        picked = o;
                        if (o == s.odd) right++;
                      }),
              ),
          ],
        ),
        if (picked != null) ...[
          Container(
            key: const ValueKey('odd-why'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text(
                  hl(picked == s.odd ? 'Yes! ${s.why}' : s.why),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  hl(s.whyFa),
                  textAlign: TextAlign.center,
                  textDirection: helperDir,
                  style: BL.fa(13, color: BL.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _next(() {
            if (last) return widget.onDone((100 * right / widget.sets.length).round());
            setState(() {
              i++;
              _round();
            });
          }, last),
        ],
      ],
    );
  }
}

/// Phrase builder: the Persian is the prompt; tap the English words in order.
class _Build extends StatefulWidget {
  final List<NewWord> phrases;
  final Random rnd;
  final void Function(int) onDone;
  const _Build({required this.phrases, required this.rnd, required this.onDone});
  @override
  State<_Build> createState() => _BuildState();
}

class _BuildState extends State<_Build> {
  int i = 0, right = 0;
  late List<String> tokens;
  late List<int> order;
  final placed = <int>[];
  bool? ok;

  @override
  void initState() {
    super.initState();
    _round();
  }

  void _round() {
    ok = null;
    placed.clear();
    tokens = widget.phrases[i].word.split(' ');
    order = List.generate(tokens.length, (k) => k)..shuffle(widget.rnd);
    // Tile k shows tokens[order[k]]; the answer is the tiles whose tokens come in phrase order.
    ParkGameScreen.answer.value = [for (var t = 0; t < tokens.length; t++) order.indexOf(t)];
  }

  void _check() {
    final good = placed.map((k) => tokens[order[k]]).join(' ') == tokens.join(' ');
    setState(() {
      ok = good;
      if (good) right++;
    });
    _say(widget.phrases[i].word);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.phrases[i], last = i == widget.phrases.length - 1;
    return ListView(
      children: [
        _progress(i, widget.phrases.length, right),
        const SizedBox(height: 18),
        Text(
          'Say it in English:',
          textAlign: TextAlign.center,
          style: const TextStyle(color: BL.muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          hl(p.fa),
          key: const ValueKey('build-fa'),
          textAlign: TextAlign.center,
          textDirection: helperDir,
          style: BL.fa(19, color: BL.ink),
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('build-line'),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ok == null ? BL.mist : (ok! ? parkGreen : BL.red), width: 2),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in placed)
                ActionChip(
                  key: ValueKey('build-placed-$k'),
                  label: Text(hl(tokens[order[k]])),
                  onPressed: ok != null ? null : () => setState(() => placed.remove(k)),
                  backgroundColor: parkGreen.withValues(alpha: .12),
                  side: BorderSide.none,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var k = 0; k < order.length; k++)
              if (!placed.contains(k))
                ActionChip(
                  key: ValueKey('build-tile-$k'),
                  label: Text(hl(tokens[order[k]])),
                  onPressed: ok != null ? null : () => setState(() => placed.add(k)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: BL.mist),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
          ],
        ),
        const SizedBox(height: 14),
        if (ok == null)
          FilledButton(
            key: const ValueKey('build-check'),
            onPressed: placed.length == tokens.length ? _check : null,
            style: FilledButton.styleFrom(
              backgroundColor: parkGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Check', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          )
        else ...[
          Text(
            hl(ok! ? 'Brilliant!' : 'It goes: ${p.word}'),
            key: const ValueKey('build-result'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ok! ? parkGreen : BL.red),
          ),
          const SizedBox(height: 10),
          _next(() {
            if (last) return widget.onDone((100 * right / widget.phrases.length).round());
            setState(() {
              i++;
              _round();
            });
          }, last),
        ],
      ],
    );
  }
}
