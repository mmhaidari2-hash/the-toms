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
import 'inbox_screen.dart';
import 'messages_data.dart';

/// One conversation: voice notes (transcript hidden until asked) and texts, texting talk explained,
/// a quick check, then the learner replies by picking, typing or saying it. Speech is only turned into
/// text for scoring; the learner's audio is never recorded, stored or uploaded by the app.
class ThreadScreen extends ConsumerWidget {
  final String id;
  const ThreadScreen({super.key, required this.id});

  /// Test hook: replaces the microphone.
  static Future<SpeechResult> Function(String target)? listenOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ts = ref.watch(messagesProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (ts == null || topics == null || content == null) return const NavLoading();
    final t = ts.where((x) => x.id == id).firstOrNull;
    if (t == null) {
      return Scaffold(
        backgroundColor: phoneBg,
        body: Center(
          child: TextButton(onPressed: () => context.go('/messages'), child: const Text('Message not found — back to Messages')),
        ),
      );
    }
    final gate = ThreadGate(ref.read(progressProvider.notifier), content, topics, ts, unlockAll: ref.read(progressProvider).unlockAll);
    if (!gate.levelOpen(t.level)) return ThreadLocked(t: t);
    return _Thread(key: ValueKey('thread-screen-${t.id}'), t: t);
  }
}

class ThreadLocked extends StatelessWidget {
  final Thread t;
  const ThreadLocked({super.key, required this.t});
  @override
  Widget build(BuildContext context) {
    final (en, fa) = ThreadGate.why(t.level);
    return Scaffold(
      key: const ValueKey('thread-locked'),
      backgroundColor: phoneBg,
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: NavBack(fallback: '/messages'),
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
                      Text(hl('A message from ${t.fromName}'), textAlign: TextAlign.center, style: BL.display(24)),
                      const SizedBox(height: 18),
                      Text(
                        hl('This is a ${t.level} message, which hasn\'t arrived for you yet'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hl(en),
                        key: const ValueKey('thread-locked-why'),
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
                      TextButton(key: const ValueKey('thread-locked-back'), onPressed: () => context.go('/messages'), child: const Text('Back to Messages')),
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

enum _Mode { pick, type, say }

class _Thread extends ConsumerStatefulWidget {
  final Thread t;
  const _Thread({super.key, required this.t});
  @override
  ConsumerState<_Thread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<_Thread> with SingleTickerProviderStateMixin {
  Thread get t => widget.t;
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  late final AnimationController _prog = AnimationController(vsync: this);
  final _sc = ScrollController();
  final _typed = TextEditingController();
  int? playing;
  bool transcript = false, listening = false;
  // quick check
  late final List<int> qOrder = List.generate(t.qOptions.length, (i) => i)..shuffle(Random(t.id.hashCode));
  late final List<int> rOrder = List.generate(t.replies.length, (i) => i)..shuffle(Random(t.id.hashCode + 7));
  int? qPicked;
  bool qFirst = false, qDone = false;
  // reply
  _Mode mode = _Mode.pick;
  final wrongPicks = <int>{};
  PronResult? tried;
  String? sent;
  int replyPts = 0;
  XpAward? award;
  int pct = 0;

  bool get showFa => ctrl.pref('msgFa', 'off') == 'on';

  @override
  void dispose() {
    Voice.stop();
    if (listening) SpeechInput.stop();
    _prog.dispose();
    _sc.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _play(int i) async {
    final m = t.msgs[i];
    if (playing == i) {
      Voice.stop();
      _prog.stop();
      setState(() => playing = null);
      return;
    }
    Voice.stop();
    setState(() => playing = i);
    _prog.duration = Duration(milliseconds: max(600, m.ms));
    _prog.forward(from: 0);
    final sw = Stopwatch()..start();
    await Voice.say(m.sp, m.en);
    final left = m.ms - sw.elapsedMilliseconds;
    if (sw.elapsedMilliseconds < 300 && left > 0) await Future.delayed(Duration(milliseconds: left));
    if (mounted && playing == i) setState(() => playing = null);
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  });

  void _answerQ(int o) {
    if (qDone) return;
    setState(() {
      qPicked = o;
      if (o == 0) {
        qFirst = qFirst || qPicked == o && wrongQ.isEmpty;
        qDone = true;
      } else {
        wrongQ.add(o);
      }
    });
    if (qDone) _scrollDown();
  }

  final wrongQ = <int>{};

  void _accept(String text, int pts) {
    HapticFeedback.lightImpact();
    setState(() {
      sent = text;
      replyPts = pts;
    });
    _scrollDown();
  }

  void _pick(int o) {
    if (sent != null) return;
    if (o == 0) {
      _accept(t.bestReply, wrongPicks.isEmpty ? 60 : 30);
    } else {
      setState(() => wrongPicks.add(o));
    }
  }

  void _checkTyped() {
    final s = _typed.text.trim();
    if (s.isEmpty) return;
    final r = Pronunciation.score(t.say, s);
    setState(() => tried = r);
    if (r.score >= Pronunciation.passScore) _accept(s, 60);
  }

  Future<void> _speak() async {
    if (ThreadScreen.listenOverride == null && !SpeechInput.sttSupported) {
      showMicHelp(context, 'unsupported', onType: () => setState(() => mode = _Mode.type));
      return;
    }
    Voice.stop();
    setState(() => listening = true);
    final r = ThreadScreen.listenOverride != null ? await ThreadScreen.listenOverride!(t.say) : await SpeechInput.listenDetailed();
    if (!mounted) return;
    setState(() => listening = false);
    if (r.permissionDenied) {
      showMicHelp(context, r.error, onType: () => setState(() => mode = _Mode.type));
      return;
    }
    final pr = (r.ok ? Pronunciation.bestOf([t.say], r.alternatives)?.$2 : null) ?? Pronunciation.score(t.say, '');
    setState(() => tried = pr);
    if (pr.score >= Pronunciation.passScore) _accept(t.bestReply, 60);
  }

  void _finish() {
    pct = Messages.score(qFirst: qFirst, reply: replyPts);
    final a = ctrl.saveThread(t.id, pct);
    setState(() => award = a);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    if (award != null) {
      final pass = pct >= Messages.pass;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('msg-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: false,
          right: pct,
          total: 100,
          title: pass ? 'Message sent!' : 'Nearly there!',
          titleFa: pass ? 'آفرین! خوب فهمیدی و خوب جواب دادی.' : 'دوباره گوش کن و دوباره جواب بده.',
          onRetry: pass ? null : () => context.go('/messages/${t.id}?r=${DateTime.now().millisecondsSinceEpoch}'),
          onContinue: () => context.go('/messages'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: phoneBg,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(12, pad.top + 6, 12, 8),
            child: Row(
              children: [
                const NavBack(fallback: '/messages'),
                const SizedBox(width: 8),
                CircleAvatar(radius: 19, backgroundColor: BL.mist, backgroundImage: AssetImage(t.avatar)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hl(t.fromName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                      ),
                      Text(
                        hl('${t.level}  ·  ${t.title}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('thread-scroll'),
              controller: _sc,
              padding: EdgeInsets.fromLTRB(12, 10, 12, pad.bottom + 24),
              children: [
                Row(
                  children: [
                    _chip('msg-transcript', Icons.subject_rounded, transcript ? 'Hide transcripts' : 'Show transcripts', transcript, () => setState(() => transcript = !transcript)),
                    const SizedBox(width: 8),
                    _chip('msg-fa', Icons.translate_rounded, 'فارسی', showFa, () => ctrl.setPref('msgFa', showFa ? 'off' : 'on')),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    hl('Today ${t.time}'),
                    style: const TextStyle(fontSize: 11.5, color: BL.muted, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < t.msgs.length; i++) _bubble(i),
                const SizedBox(height: 8),
                _glossCard(),
                const SizedBox(height: 10),
                _quick(),
                if (qDone) ...[const SizedBox(height: 10), _reply()],
                if (sent != null) ...[
                  const SizedBox(height: 10),
                  _mine(sent!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('msg-finish'),
                    onPressed: _finish,
                    style: FilledButton.styleFrom(
                      backgroundColor: bubbleMe,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(hl('Done · تمام'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, IconData icon, String label, bool on, VoidCallback onTap) => ActionChip(
    key: ValueKey(key),
    onPressed: onTap,
    avatar: Icon(icon, size: 16, color: on ? Colors.white : BL.ink),
    label: Text(hl(label)),
    visualDensity: VisualDensity.compact,
    backgroundColor: on ? bubbleMe : Colors.white,
    side: BorderSide.none,
    labelStyle: TextStyle(color: on ? Colors.white : BL.ink, fontWeight: FontWeight.w800, fontSize: 12.5),
  );

  Widget _bubble(int i) {
    final m = t.msgs[i], showName = m.sp != t.from;
    final Widget body;
    if (m.isVoice) {
      final on = playing == i;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: ValueKey('msg-play-$i'),
                customBorder: const CircleBorder(),
                onTap: () => _play(i),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: bubbleMe,
                  child: Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                height: 28,
                child: AnimatedBuilder(
                  animation: _prog,
                  builder: (_, _) {
                    final p = on ? _prog.value : 0.0, rnd = Random(i + t.id.hashCode);
                    return Row(
                      children: [
                        for (var b = 0; b < 26; b++)
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 3,
                                height: 6 + rnd.nextDouble() * 20,
                                decoration: BoxDecoration(color: b / 26 <= p ? bubbleMe : BL.muted.withValues(alpha: .45), borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hl(m.duration),
                style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (transcript) ...[
            const SizedBox(height: 6),
            Text(
              hl(m.en),
              key: ValueKey('msg-transcript-$i'),
              style: const TextStyle(fontSize: 14.5, height: 1.35, fontStyle: FontStyle.italic),
            ),
          ],
          if (transcript && showFa)
            Text(
              hl(m.fa),
              key: ValueKey('msg-fa-$i'),
              textDirection: helperDir,
              style: BL.fa(12.5, color: BL.muted),
            ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hl(m.en), key: ValueKey('msg-text-$i'), style: const TextStyle(fontSize: 15.5, height: 1.35)),
          if (showFa)
            Text(
              hl(m.fa),
              key: ValueKey('msg-fa-$i'),
              textDirection: helperDir,
              style: BL.fa(12.5, color: BL.muted),
            ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: ValueKey(m.isVoice ? 'msg-voice-$i' : 'msg-bubble-$i'),
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: bubbleThem,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showName)
              Text(
                hl(m.spName),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: BL.red),
              ),
            body,
          ],
        ),
      ),
    );
  }

  Widget _mine(String text) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      key: const ValueKey('msg-sent'),
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: const BoxDecoration(
        color: bubbleMe,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(4), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(hl(text), style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35)),
          if (showFa)
            Text(
              hl(t.replyFa),
              textDirection: helperDir,
              style: BL.fa(12.5, color: Colors.white70),
            ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delivered',
                style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 3),
              Icon(Icons.done_all_rounded, size: 14, color: Colors.white70),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _card({required Key key, required List<Widget> children}) => Container(
    key: key,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BL.mist),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _head(String en, String fa) => Row(
    children: [
      Expanded(
        child: Text(
          hl(en.toUpperCase()),
          style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: bubbleMe),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        hl(fa),
        textDirection: helperDir,
        style: BL.fa(12, color: BL.muted),
      ),
    ],
  );

  Widget _glossCard() => _card(
    key: const ValueKey('msg-gloss'),
    children: [
      _head('Texting talk', 'زبان پیامک'),
      const SizedBox(height: 6),
      for (final g in t.gloss)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: hl(g.term),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    TextSpan(
                      text: hl('  ${g.en}'),
                      style: const TextStyle(fontSize: 13.5, color: BL.ink),
                    ),
                  ],
                ),
              ),
              Text(
                hl(g.fa),
                textDirection: helperDir,
                style: BL.fa(12, color: BL.muted),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _quick() => _card(
    key: const ValueKey('msg-quick'),
    children: [
      _head('Quick check', 'بررسی سریع'),
      const SizedBox(height: 6),
      Text(
        hl(t.q),
        key: const ValueKey('msg-q'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      for (final o in qOrder)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: qDone && o == 0 ? bubbleMe : (wrongQ.contains(o) ? BL.red.withValues(alpha: .15) : phoneBg),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: ValueKey('msg-opt-$o'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _answerQ(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Text(
                  hl(t.qOptions[o]),
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: qDone && o == 0 ? Colors.white : BL.ink),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _reply() {
    Widget tab(_Mode m, IconData icon, String label) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          key: ValueKey('msg-mode-${m.name}'),
          selected: mode == m,
          onSelected: sent != null
              ? null
              : (_) => setState(() {
                  mode = m;
                  tried = null;
                }),
          showCheckmark: false,
          avatar: Icon(icon, size: 16, color: mode == m ? Colors.white : BL.ink),
          label: SizedBox(
            width: double.infinity,
            child: Text(hl(label), textAlign: TextAlign.center),
          ),
          selectedColor: bubbleMe,
          backgroundColor: phoneBg,
          side: BorderSide.none,
          labelStyle: TextStyle(color: mode == m ? Colors.white : BL.ink, fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
    return _card(
      key: const ValueKey('msg-reply'),
      children: [
        _head('Your reply', 'جواب تو'),
        const SizedBox(height: 8),
        Row(children: [tab(_Mode.pick, Icons.touch_app_rounded, 'Pick'), tab(_Mode.type, Icons.keyboard_rounded, 'Type'), tab(_Mode.say, Icons.mic_rounded, 'Say')]),
        const SizedBox(height: 10),
        if (sent != null)
          const Text(
            'Sent! Tap Done to finish.',
            style: TextStyle(color: BL.muted, fontWeight: FontWeight.w700),
          )
        else
          ...switch (mode) {
            _Mode.pick => [
              for (final o in rOrder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: wrongPicks.contains(o) ? BL.red.withValues(alpha: .15) : phoneBg,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: ValueKey('msg-pick-$o'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _pick(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Text(hl(t.replies[o]), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              if (wrongPicks.isNotEmpty)
                const Text(
                  'Hmm, that doesn\'t quite fit. Try another one.',
                  key: ValueKey('msg-pick-wrong'),
                  style: TextStyle(color: BL.red, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
            ],
            _Mode.type => [
              Text(hl('Write a reply like: “${t.bestReply}”'), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('msg-type'),
                      controller: _typed,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _checkTyped(),
                      decoration: InputDecoration(
                        hintText: 'Type your reply…',
                        isDense: true,
                        filled: true,
                        fillColor: phoneBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    key: const ValueKey('msg-send'),
                    onPressed: _checkTyped,
                    style: IconButton.styleFrom(backgroundColor: bubbleMe),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
              if (tried != null) _feedback(),
            ],
            _Mode.say => [
              Text(
                hl('Say: “${t.say}”'),
                key: const ValueKey('msg-say-target'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Center(
                child: FilledButton.icon(
                  key: const ValueKey('msg-mic'),
                  onPressed: listening ? null : _speak,
                  style: FilledButton.styleFrom(
                    backgroundColor: listening ? BL.red : bubbleMe,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  icon: Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_rounded),
                  label: Text(hl(listening ? 'Listening…' : 'Tap and say it'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              if (tried != null) _feedback(),
              const SizedBox(height: 6),
              const Text(
                'Your browser turns your speech into text for the score. New Life UK never records, keeps or uploads your voice.',
                key: ValueKey('msg-mic-note'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: BL.muted),
              ),
            ],
          },
      ],
    );
  }

  Widget _feedback() {
    final r = tried!, ok = r.score >= Pronunciation.passScore;
    return Padding(
      key: const ValueKey('msg-feedback'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                for (final w in r.words)
                  TextSpan(
                    text: hl('${w.word} '),
                    style: TextStyle(
                      color: switch (w.mark) {
                        WordMark.good => markGood,
                        WordMark.close => markClose,
                        WordMark.missed => markMissed,
                      },
                      decoration: w.mark == WordMark.missed ? TextDecoration.underline : null,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Text(
            hl(ok ? '${r.score}% · sent!' : '${r.score}% · nearly! Try again, or pick a reply.'),
            key: const ValueKey('msg-score'),
            style: TextStyle(color: ok ? markGood : BL.red, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
