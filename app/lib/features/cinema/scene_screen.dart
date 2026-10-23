import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/engine/pronunciation.dart';
import '../../core/platform/speech.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import '../speaking/speaking_widgets.dart';
import 'cinema_data.dart';
import 'cinema_screen.dart';

/// One scene: watch it with subtitles, dub a character (speech recognition + per-word scoring,
/// timed against the original clip), then answer comprehension questions.
class SceneScreen extends ConsumerWidget {
  final String id;
  const SceneScreen({super.key, required this.id});

  /// Test hook: replaces the microphone (gets the target line and a partial-result callback).
  static Future<SpeechResult> Function(String target, void Function(String partial) onPartial)? listenOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final scenes = ref.watch(cinemaProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (scenes == null || topics == null || content == null) return const NavLoading();
    final s = scenes.where((x) => x.id == id).firstOrNull;
    if (s == null) {
      return Scaffold(backgroundColor: cinemaDark, body: Center(child: TextButton(onPressed: () => context.go('/cinema'), child: const Text('Scene not found — back to the Cinema'))));
    }
    // Strict lock: a deep link to a scene on a shut level never plays it.
    final gate = CinemaGate(ref.read(progressProvider.notifier), content, topics, scenes, unlockAll: ref.read(progressProvider).unlockAll);
    if (!gate.levelOpen(s.level)) return SceneLocked(scene: s);
    return _Scene(key: ValueKey('scene-screen-${s.id}'), scene: s);
  }
}

class SceneLocked extends StatelessWidget {
  final Scene scene;
  const SceneLocked({super.key, required this.scene});
  @override
  Widget build(BuildContext context) {
    final (en, fa) = CinemaGate.why(scene.level);
    return Scaffold(
      key: const ValueKey('scene-locked'),
      backgroundColor: cinemaDark,
      body: SafeArea(
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: NavBack(light: true, fallback: '/cinema'))),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_rounded, size: 56, color: Colors.white54),
                  const SizedBox(height: 14),
                  Text(hl(scene.title), textAlign: TextAlign.center, style: BL.display(24, color: Colors.white)),
                  Text(hl(scene.titleFa), textDirection: helperDir, style: BL.fa(14, color: Colors.white60)),
                  const SizedBox(height: 18),
                  Text(hl('This is a ${scene.level} scene, which isn\'t showing for you yet'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(hl(en), key: const ValueKey('scene-locked-why'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(hl(fa), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(13, color: Colors.white54)),
                  const SizedBox(height: 18),
                  TextButton(key: const ValueKey('scene-locked-cinema'), onPressed: () => context.go('/cinema'), child: const Text('Back to the Cinema', style: TextStyle(color: BL.gold))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

enum _Mode { watch, dub, dubDone, quiz, quizDone }

class _Scene extends ConsumerStatefulWidget {
  final Scene scene;
  const _Scene({super.key, required this.scene});
  @override
  ConsumerState<_Scene> createState() => _SceneState();
}

class _SceneState extends ConsumerState<_Scene> with TickerProviderStateMixin {
  Scene get s => widget.scene;
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  late final AnimationController _kb = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);
  late final AnimationController _karaoke = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  final _keys = <int, GlobalKey>{};
  final _sc = ScrollController();
  _Mode mode = _Mode.watch;
  int cur = -1, _token = 0;
  bool playing = false, listening = false;
  int? yourTurn;
  String partial = '';
  late String role = s.dub;
  final dubbed = <int, (PronResult, bool)>{};
  // questions
  int qi = 0, right = 0;
  int? picked;
  List<List<int>> order = [];
  XpAward? award;

  bool get showFa => ctrl.pref('cineFa', 'off') == 'on';
  bool get canListen => SceneScreen.listenOverride != null || SpeechInput.sttSupported;

  @override
  void dispose() {
    _token++;
    Voice.stop();
    if (listening) SpeechInput.stop();
    _kb.dispose();
    _sc.dispose();
    _karaoke.dispose();
    super.dispose();
  }

  void _show(int i) {
    setState(() => cur = i);
    final c = _keys[i]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), alignment: .3);
  }

  /// Plays one line in its character's voice; without audio (muted, tests) it still keeps the scene's pace.
  Future<void> _say(int i) async {
    final l = s.lines[i];
    final sw = Stopwatch()..start();
    if (!await Voice.say(l.sp, l.en)) {
      _token++; // cut short by another clip: stop the scene rather than talk over it
      if (mounted) setState(() => playing = false);
      return;
    }
    final left = l.ms - sw.elapsedMilliseconds;
    if (sw.elapsedMilliseconds < 300 && left > 0) await Future.delayed(Duration(milliseconds: left));
  }

  Future<void> _watch() async {
    final t = ++_token;
    setState(() {
      mode = _Mode.watch;
      playing = true;
      yourTurn = null;
    });
    for (var i = 0; i < s.lines.length; i++) {
      if (!mounted || t != _token) return;
      _show(i);
      await _say(i);
      if (!mounted || t != _token) return;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted && t == _token) setState(() => playing = false);
  }

  Future<void> _playOne(int i) async {
    if (playing) return;
    final t = ++_token;
    _show(i);
    await _say(i);
    if (mounted && t == _token) setState(() => cur = -1);
  }

  void _stop() {
    _token++;
    Voice.stop();
    if (listening) SpeechInput.stop();
    _karaoke.stop();
    setState(() {
      playing = false;
      listening = false;
      yourTurn = null;
      if (mode == _Mode.dub) mode = _Mode.watch;
    });
  }

  Future<void> _dub() async {
    if (!canListen) {
      showMicHelp(context, 'unsupported');
      return;
    }
    final t = ++_token;
    setState(() {
      dubbed.clear();
      mode = _Mode.dub;
      playing = true;
    });
    for (var i = 0; i < s.lines.length; i++) {
      if (!mounted || t != _token) return;
      _show(i);
      final l = s.lines[i];
      if (l.sp != role) {
        await _say(i);
        if (!mounted || t != _token) return;
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      // The learner's line: words light up at the original pace while they speak.
      setState(() {
        yourTurn = i;
        listening = true;
        partial = '';
      });
      _karaoke.duration = Duration(milliseconds: max(800, (l.ms * .9).round()));
      _karaoke.forward(from: 0);
      final sw = Stopwatch()..start();
      var last = 0;
      void onPartial(String p) {
        last = sw.elapsedMilliseconds;
        if (mounted) setState(() => partial = p);
      }

      final r = SceneScreen.listenOverride != null ? await SceneScreen.listenOverride!(l.en, onPartial) : await SpeechInput.listenDetailed(onPartial: onPartial);
      if (!mounted || t != _token) return;
      if (r.permissionDenied) {
        _stop();
        showMicHelp(context, r.error);
        return;
      }
      final end = last > 0 ? last : sw.elapsedMilliseconds;
      final pr = (r.ok ? Pronunciation.bestOf([l.en], r.alternatives)?.$2 : null) ?? Pronunciation.score(l.en, '');
      HapticFeedback.lightImpact();
      setState(() {
        listening = false;
        dubbed[i] = (pr, r.ok && end <= l.ms + Cinema.graceMs);
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || t != _token) return;
      setState(() => yourTurn = null);
    }
    final pct = dubPct;
    final a = ctrl.saveDub(s.id, pct);
    setState(() {
      award = a;
      playing = false;
      cur = -1;
      mode = _Mode.dubDone;
    });
    if (_sc.hasClients) _sc.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  /// A line's dub score: the per-word pronunciation score, docked 20% when it ran over time.
  static int lineScore((PronResult, bool) d) => d.$2 ? d.$1.score : (d.$1.score * .8).round();
  int get dubPct => dubbed.isEmpty ? 0 : (dubbed.values.map(lineScore).reduce((a, b) => a + b) / dubbed.length).round();

  void _startQuiz() {
    _stop();
    final rnd = Random(s.id.hashCode);
    order = [for (final q in s.quiz) (List.generate(q.options.length, (i) => i)..shuffle(rnd))];
    setState(() {
      mode = _Mode.quiz;
      qi = 0;
      right = 0;
      picked = null;
    });
  }

  void _pick(int opt) {
    if (picked != null) return;
    final ok = opt == s.quiz[qi].answer;
    setState(() {
      picked = opt;
      if (ok) right++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (qi + 1 < s.quiz.length) {
        setState(() {
          qi++;
          picked = null;
        });
      } else {
        final a = ctrl.saveSceneQuiz(s.id, (right * 100 / s.quiz.length).round());
        setState(() {
          award = a;
          mode = _Mode.quizDone;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final pad = MediaQuery.paddingOf(context);
    if (mode == _Mode.quizDone && award != null) {
      final pct = (right * 100 / max(s.quiz.length, 1)).round(), pass = pct >= Cinema.pass;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('cine-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: false,
          right: right,
          total: s.quiz.length,
          title: pass ? 'Scene understood!' : 'Good effort!',
          titleFa: pass ? 'آفرین! این صحنه را کامل فهمیدی.' : 'صحنه را دوباره تماشا کن و دوباره امتحان کن.',
          onRetry: pass ? null : () => setState(() => mode = _Mode.watch),
          onContinue: () => setState(() => mode = _Mode.watch),
        ),
      );
    }
    return Scaffold(
      backgroundColor: cinemaDark,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 8, 6),
          child: Row(children: [
            const NavBack(light: true, fallback: '/cinema'),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(s.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                Text(hl('${s.level}  ·  ${s.lines.length} lines  ·  ${s.seconds}s'), style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
              ]),
            ),
            IconButton(
              key: const ValueKey('cine-fa'),
              tooltip: 'Persian subtitles',
              onPressed: () => ctrl.setPref('cineFa', showFa ? 'off' : 'on'),
              icon: Icon(Icons.translate_rounded, color: showFa ? BL.gold : Colors.white54),
            ),
          ]),
        ),
        if (mode == _Mode.quiz)
          Expanded(child: _quiz())
        else ...[
          _screen(),
          _controls(),
          Expanded(child: _script(pad.bottom)),
        ],
      ]),
    );
  }

  Widget _screen() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            key: const ValueKey('cine-screen'),
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              AnimatedBuilder(
                animation: _kb,
                builder: (_, child) => Transform.scale(scale: 1.05 + _kb.value * .08, alignment: Alignment(-.4 + _kb.value * .8, 0), child: child),
                child: Image.asset(s.stillAsset, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: cinemaPanel)),
              ),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.45, 1], colors: [Color(0x00000000), Color(0xCC000000)]))),
              if (cur >= 0) Positioned(left: 10, right: 10, bottom: 10, child: _subtitle(cur)),
              if (!playing && cur < 0)
                Center(
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('cine-play-overlay'),
                      customBorder: const CircleBorder(),
                      onTap: _watch,
                      child: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.play_arrow_rounded, size: 46, color: Colors.white)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _subtitle(int i) {
    final l = s.lines[i], mine = yourTurn == i, d = dubbed[i];
    final Widget text;
    if (mine && d != null) {
      text = _marked(d.$1, 17);
    } else if (mine) {
      final words = l.en.split(' ');
      text = AnimatedBuilder(
        animation: _karaoke,
        builder: (_, _) {
          final lit = (_karaoke.value * words.length).ceil();
          return Text.rich(
            key: const ValueKey('cine-karaoke'),
            TextSpan(children: [for (var w = 0; w < words.length; w++) TextSpan(text: hl('${words[w]} '), style: TextStyle(color: w < lit ? BL.gold : Colors.white))]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
          );
        },
      );
    } else {
      text = Text(hl(l.en), key: const ValueKey('cine-subtitle'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mine)
          Container(
            key: const ValueKey('your-line'),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: BL.red, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(listening ? Icons.mic_rounded : Icons.check_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(hl(d != null ? '${lineScore(d)}%  ${d.$2 ? '· in time' : '· a bit slow'}' : 'YOUR LINE · نوبت تو'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .6)),
            ]),
          )
        else
          Text(hl(l.spName.toUpperCase()), style: const TextStyle(color: BL.gold, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        text,
        if (showFa) Text(hl(l.fa), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(13, color: Colors.white70)),
      ]),
    );
  }

  Widget _marked(PronResult r, double size, {Color base = Colors.white}) => Text.rich(
        key: const ValueKey('dub-marks'),
        TextSpan(children: [
          for (final w in r.words)
            TextSpan(
              text: hl('${w.word} '),
              style: TextStyle(
                color: switch (w.mark) { WordMark.good => markGood, WordMark.close => markClose, WordMark.missed => markMissed },
                decoration: w.mark == WordMark.missed ? TextDecoration.underline : null,
              ),
            ),
        ]),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, height: 1.3, color: base),
      );

  Widget _controls() {
    if (playing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Row(children: [
          Expanded(
            child: Text(
              hl(mode == _Mode.dub ? (listening ? (partial.isEmpty ? 'Listening… say your line now' : '“$partial”') : 'Dubbing as ${s.cast.firstWhere((c) => c.sp == role).spName}') : 'Now playing'),
              key: const ValueKey('cine-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: listening ? BL.gold : Colors.white70, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          TextButton.icon(key: const ValueKey('cine-stop'), onPressed: _stop, icon: const Icon(Icons.stop_rounded, color: Colors.white), label: const Text('Stop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        ]),
      );
    }
    Widget btn(String key, IconData icon, String label, VoidCallback onTap, {bool primary = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              key: ValueKey(key),
              onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: primary ? BL.red : cinemaPanel, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: Icon(icon, size: 19),
              label: Text(hl(label), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(children: [
        Row(children: [
          btn('cine-watch', Icons.play_arrow_rounded, 'Watch', _watch),
          btn('cine-dub', Icons.mic_rounded, 'Dub', _dub, primary: true),
          btn('cine-quiz', Icons.quiz_rounded, 'Questions', _startQuiz),
        ]),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            const Text('Your role  ', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
            for (final c in s.cast)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: ValueKey('role-${c.sp}'),
                  label: Text(hl(c.spName)),
                  selected: role == c.sp,
                  onSelected: (_) => setState(() => role = c.sp),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cinemaPanel,
                  selectedColor: BL.gold,
                  side: BorderSide.none,
                  labelStyle: TextStyle(color: role == c.sp ? cinemaDark : Colors.white70, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _results() {
    final pct = dubPct, inTime = dubbed.values.where((d) => d.$2).length;
    final col = pct >= Pronunciation.passScore ? markGood : (pct >= 40 ? markClose : markMissed);
    return Container(
      key: const ValueKey('dub-results'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cinemaPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: col.withValues(alpha: .7), width: 1.5)),
      child: Row(children: [
        Text(hl('$pct%'), key: const ValueKey('dub-score'), style: BL.display(34, color: col, w: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hl(pct >= 90 ? 'Award-winning dub!' : pct >= Pronunciation.passScore ? 'Great dubbing!' : 'Nice try. Listen, then dub again.'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(hl('$inTime of ${dubbed.length} lines in time${award != null ? '  ·  +${award!.xp} XP' : ''}'), style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text(hl(pct >= Pronunciation.passScore ? 'دوبلهٔ عالی!' : 'گوش کن و دوباره دوبله کن.'), textDirection: helperDir, style: BL.fa(12.5, color: Colors.white54)),
          ]),
        ),
        IconButton(key: const ValueKey('dub-again'), tooltip: 'Dub again', onPressed: _dub, icon: const Icon(Icons.replay_rounded, color: Colors.white)),
      ]),
    );
  }

  Widget _script(double bottom) => ListView(
        key: const ValueKey('cine-script'),
        controller: _sc,
        padding: EdgeInsets.fromLTRB(14, 12, 14, bottom + 20),
        children: [
          if (mode == _Mode.dubDone) _results(),
          if (cur < 0 && mode == _Mode.watch) ...[
            Text(hl(s.blurb), style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.35)),
            Text(hl(s.blurbFa), textDirection: helperDir, style: BL.fa(12.5, color: Colors.white54)),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < s.lines.length; i++) _row(i),
        ],
      );

  Widget _row(int i) {
    final l = s.lines[i], on = cur == i, d = dubbed[i], mineRole = l.sp == role;
    return GestureDetector(
      key: _keys.putIfAbsent(i, () => GlobalKey()),
      onTap: () => _playOne(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? BL.gold.withValues(alpha: .6) : Colors.transparent)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(hl(l.spName.toUpperCase()), key: ValueKey('line-spk-$i'), style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: mineRole ? BL.red : BL.gold)),
            if (mineRole) const Text('  · you', style: TextStyle(fontSize: 10.5, color: Colors.white38, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (d != null) Text(hl('${lineScore(d)}%'), key: ValueKey('line-score-$i'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: lineScore(d) >= Pronunciation.passScore ? markGood : markClose)),
          ]),
          if (d != null)
            Align(alignment: Alignment.centerLeft, child: _marked(d.$1, 15.5))
          else
            Text(hl(l.en), key: ValueKey('line-$i'), style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35)),
          if (showFa) Text(hl(l.fa), key: ValueKey('line-fa-$i'), textDirection: helperDir, textAlign: TextAlign.right, style: BL.fa(13, color: Colors.white60)),
        ]),
      ),
    );
  }

  Widget _quiz() {
    final q = s.quiz[qi];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text(hl('Question ${qi + 1} of ${s.quiz.length}'), style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 6),
        Text(hl(q.q), key: const ValueKey('cine-q'), style: BL.display(22, color: Colors.white)),
        const SizedBox(height: 16),
        for (final o in order[qi])
          Builder(builder: (_) {
            final isAns = o == q.answer, isPicked = picked == o;
            final col = picked == null ? cinemaPanel : (isAns ? BL.green : (isPicked ? BL.red : cinemaPanel));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: col,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('cine-opt-$o'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pick(o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Text(hl(q.options[o]), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            );
          }),
        TextButton(onPressed: () => setState(() => mode = _Mode.watch), child: Text(hl('Back to the scene · برگشت به صحنه'), style: TextStyle(color: Colors.white70))),
      ],
    );
  }
}
