
import '../../core/i18n/you.dart';
import 'package:flutter/material.dart';
import '../shared/nav.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/platform/voice.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/ai/dialogue_brain.dart';
import '../../core/engine/connected_speech.dart';
import '../../core/engine/level_profile.dart';
import '../../core/engine/narrative_srs.dart';
import '../../core/engine/politeness_engine.dart';
import '../../core/engine/recast_engine.dart';
import '../../core/models/user_progress.dart';
import '../../core/platform/speech.dart';
import '../../core/engine/emotion_engine.dart';
import '../../core/i18n/strings.dart';
import '../../core/engine/growth_engine.dart';
import '../../core/models/character.dart';
import '../../core/models/dialogue_node.dart';
import '../home/home_screen.dart' show ErrorState;
import '../shared/widgets.dart';
import '../speaking/speaking_widgets.dart';
import '../../core/engine/pronunciation.dart';
import '../place/place_screen.dart' show hitTest;
import '../../core/models/place.dart';
import '../leitner/leitner_add.dart' show LeitnerWords;

class ConversationScreen extends ConsumerWidget {
  final String sceneId;
  const ConversationScreen({super.key, required this.sceneId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: const Color(0xFF140E0A),
    body: ref
        .watch(contentProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator(color: BL.navy)),
          error: (e, _) => ErrorState(message: '$e', onRetry: () => ref.invalidate(contentProvider)),
          data: (c) {
            final role = ref.watch(progressProvider).role;
            // Full role switching: playing as a family member swaps in that member's version of the scene.
            final s = c.scenes['${sceneId}__as_$role'] ?? c.scenes[sceneId];
            if (s == null) return ErrorState(message: 'Story “$sceneId” not found.', onRetry: () => context.go('/'));
            if (!ref.read(progressProvider.notifier).canPlay(c.scenes[s.baseId ?? s.id] ?? s, c)) {
              return _Locked(c: c, s: s);
            }
            return _Chat(c: c, s: s);
          },
        ),
  );
}

class _Locked extends StatelessWidget {
  final ContentBundle c;
  final Scene s;
  const _Locked({required this.c, required this.s});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 52, color: BL.muted),
            const SizedBox(height: 12),
            Text(s.title, textAlign: TextAlign.center, style: BL.display(24, color: const Color(0xFFFBF3E4))),
            const SizedBox(height: 8),
            const Text(
              'This story is still locked. Spend more time with the family first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BL.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go('/'), child: const Text('Back home')),
          ],
        ),
      ),
    ),
  );
}


class _Msg {
  final String speaker; // character id or 'me'
  final String text;
  final DialogueNode? node;
  final String? system;
  /// Translation and the unreplaced text (the voice clip key) for replaying this bubble.
  final String? fa, raw;
  /// Inline feedback card ("Vida warmed to that") placed in the chat.
  final _Feedback? fb;
  /// For the learner's bubbles: the role they spoke as (null = their usual name).
  final String? asName;
  const _Msg(this.speaker, this.text, {this.node, this.system, this.fa, this.raw, this.fb, this.asName});
}

enum _Panel { none, xray, translate, culture, shadow }

enum _FbKind { recast, ghost, warm, cool, memory }

class _Feedback {
  final _FbKind kind;
  final String title, body;
  final String? fa;
  const _Feedback(this.kind, this.title, this.body, [this.fa]);
}

class _Chat extends ConsumerStatefulWidget {
  final ContentBundle c;
  final Scene s;
  const _Chat({required this.c, required this.s});
  @override
  ConsumerState<_Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<_Chat> {
  static const DialogueBrain brain = OfflineBrain(); // ← swap for a remote FastAPI/LLM brain later
  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _dictate = false; // the speech-service fallback note is showing
  DialogueNode? _node;
  String _lineSpeaker = '';
  Hotspot? _tapped;
  double? _pan; double _curAx = 0; bool _dragging = false;
  Offset? _tapAt;
  String _line = '';
  String _raw = '';
  double get _autoRate => const ['A0', 'A1'].contains(widget.s.level) ? Voice.rates[1] : 1.0;
  String? _lineFa;
  bool _typing = false, _ended = false, _hints = false, _listening = false, _recording = false;
  _Panel _panel = _Panel.none;
  // Setting feedback also drops it into the chat, right after the reply it is about.
  set _fb(_Feedback? f) {
    if (f != null) _msgs.add(_Msg('', '', fb: f));
  }
  /// The bubble whose tools are open (null = the latest line).
  int? _sel;
  final _scroll = ScrollController();
  int _misses = 0, _trustGained = 0, _said = 0, _correct = 0, _slips = 0;
  final _perChar = <String, int>{};
  final _recasts = <(String, String, String)>[];
  final _unlocked = <String>[];
  SrsItem? _srs;
  String? _myTake;
  // Speak-the-reply mode
  PronResult? _pron;
  int? _pronIdx;
  String _partial = '';
  String? _speakNote, _speakNoteFa;
  // "Play as": false = the learner plays their usual part, true = they swap and play the story's character
  // (the other side is then voiced for them). Switching never restarts the scene: it carries on from the
  // current line in the new role.
  bool _swap = false;
  /// While swapped: the line the learner now has to say.
  DialogueNode? _mine;
  /// Who the learner usually is in this story (and who speaks the replies once they swap).
  String get _partnerId => widget.s.playAs ?? widget.s.guest ?? 'learner';
  bool get _canSwap => widget.s.nodes.values.any((n) => n.speaker == ch.id) && ch.id != _partnerId;
  /// What the learner can say now: the reply options, or (swapped) the character's line.
  List<(String, String?)> get _targets => _swap
      ? [if (_mine != null) (_t(_mine!.text), _tFa(lineTranslation(_mine!.translations, _lang)))]
      : [for (final b in _node?.branches ?? const <Branch>[]) (_t(b.suggestion), _tFa(b.suggestionFa))];

  Character get ch => widget.c.character(widget.s.characterId);
  Character _who(String id) {
    final c = widget.c.characterOrNull(id) ?? ch;
    return id == 'learner' ? c.copyWithName(_learner.isEmpty ? 'Newcomer' : _learner) : c;
  }
  MoodInfo get _mood => EmotionEngine.label(ref.watch(progressProvider).moodMap[_lineSpeaker.isEmpty ? ch.id : _lineSpeaker] ?? 0);
  /// The learner's own name (empty: lines read with no name; the audio never says one).
  String get _learner => ref.read(progressProvider.notifier).pref('name');
  String get _meName {
    final id = widget.s.playAs ?? widget.s.guest ?? ref.read(progressProvider).role;
    if (id == 'me' || id == 'learner') return _learner.isEmpty ? 'You' : _learner;
    return widget.c.characterOrNull(id)?.name ?? (_learner.isEmpty ? 'You' : _learner);
  }
  String _t(String s) => widget.s.guest != null ? s.replaceAll('{you}', widget.c.character(widget.s.guest!).name) : fillYou(s, _learner);
  String? _tFa(String? s) => s == null ? null : widget.s.guest != null ? s.replaceAll('{you}', widget.c.character(widget.s.guest!).name) : fillYouFa(s, _learner);
  String get _lang => ref.read(progressProvider).lang;

  @override
  void initState() {
    super.initState();
    _ctrl; // capture the notifier while ref is valid
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final ctrl = ref.read(progressProvider.notifier);
    final p = ref.read(progressProvider);
    // Narrative SRS: the assigned character opens with a callback to yesterday.
    _srs = ctrl.srsDue(ch.id);
    if (_srs != null) {
      final cb = NarrativeSrs.callback(_srs!, widget.c.scenes[_srs!.sceneId]);
      await _show(ch.id, cb.$1, cb.$2, delay: 400);
      setState(() => _fb = _Feedback(_FbKind.memory, 'Yesterday’s phrase', _srs!.phrase, _srs!.fa));
      await Future.delayed(const Duration(milliseconds: 1600));
    }
    // Box-5 words show up in the next milestone dialogue.
    final mastered = [for (final e in p.pendingMilestoneWords.entries) if (e.value == ch.id) e.key];
    if (widget.s.isGated && mastered.isNotEmpty) {
      await _show(ch.id, 'I’ve been practising your words, you know — ${mastered.take(3).map((w) => '“$w”').join(', ')}!', 'کلمه‌هایت را تمرین کرده‌ام — ${mastered.take(3).join('، ')}!', delay: 400);
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    if (mounted) _say(widget.s.nodes[widget.s.start]!, first: true);
  }

  late final _ctrl = ref.read(progressProvider.notifier);

  @override
  void dispose() {
    // Auto-reset to the guest after a finished role story (unless the learner chose to keep the role).
    if (_ended && widget.s.playAs != null && !_ctrl.keepRole) {
      final ctrl = _ctrl;
      Future.microtask(() => ctrl.setRole('learner'));
    }
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    Voice.stop();
    super.dispose();
  }

  List<String> get _vocab => ref.read(progressProvider).leitnerBox.keys.toList();

  Future<void> _show(String speaker, String text, String? fa, {int delay = 700}) async {
    setState(() => _typing = true);
    await Future.delayed(Duration(milliseconds: delay));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _lineSpeaker = speaker;
      _pan = null;
      _line = _t(text);
      _raw = text;
      _lineFa = fa;
      _panel = _Panel.none;
      _sel = null;
      _msgs.add(_Msg(speaker, _t(text), fa: fa, raw: text));
    });
    // Wait for the whole clip so the next line never cuts this one off mid-sentence.
    await Voice.say(speaker, text, rate: _autoRate, shown: _t(text));
  }

  Future<void> _say(DialogueNode n0, {bool first = false}) async {
    final n = n0.atChapter(_ctrl.chapterIndex(widget.c));
    setState(() => _typing = true);
    await Future.delayed(Duration(milliseconds: first ? 450 : (_swap ? 350 : 600 + n.text.length * 10)));
    if (!mounted) return;
    ref.read(progressProvider.notifier).seeWords(n.newWords);
    if (_swap && n.speaker != _partnerId) {
      // Swapped: this line is the learner's to say.
      setState(() {
        _typing = false;
        _node = n;
        _mine = n;
        _lineSpeaker = n.speaker;
        _misses = 0;
        _hints = true;
        _panel = _Panel.none;
        _sel = null;
      });
      return;
    }
    if (n.event != null) HapticFeedback.mediumImpact();
    setState(() {
      _typing = false;
      _node = n;
      _lineSpeaker = n.speaker;
      _pan = null;
      _line = _t(n.text);
      _raw = n.text;
      _lineFa = _tFa(lineTranslation(n.translations, _lang));
      _msgs.add(_Msg(n.speaker, _t(n.text), node: n, fa: _tFa(lineTranslation(n.translations, _lang)), raw: n.text));
      _sel = null;
      _misses = 0;
      _hints = false;
      _panel = _Panel.none;
      _myTake = null;
    });
    Voice.say(n.speaker, n.text, rate: _autoRate, shown: _t(n.text));
    if (n.isEnd) _finish();
  }

  Future<void> _send([String? preset]) async {
    _pron = null;
    _speakNote = null;
    final text = (preset ?? _input.text).trim();
    final node = _node;
    if (text.isEmpty || _typing || _ended || node == null) return;
    if (_swap && _mine != null) return _sendAsLine(text);
    HapticFeedback.lightImpact();
    _input.clear();
    _said++;
    setState(() {
      _msgs.add(_Msg('me', text));
    });
    final r = brain is OfflineBrain
        ? (brain as OfflineBrain).respondSync(BrainRequest(sceneId: widget.s.id, characterId: node.speaker, node: node, userText: text, level: widget.s.level, vocab: _vocab))
        : await brain.respond(BrainRequest(sceneId: widget.s.id, characterId: node.speaker, node: node, userText: text, level: widget.s.level, vocab: _vocab));
    final ctrl = ref.read(progressProvider.notifier);
    final speaker = _who(node.speaker);
    if (_srs != null && text.toLowerCase().contains(_srs!.phrase.toLowerCase().split(' / ').first.replaceAll(RegExp(r'[.!?]'), ''))) {
      ctrl.resolveSrs(_srs!);
      _srs = null;
      _fb = _Feedback(_FbKind.warm, 'You remembered!', 'That phrase from yesterday just came back naturally. Lovely.');
    }
    if (r.branch == null) {
      // Never a red X: the character half-guesses what you meant (in-story Ghost Hint).
      _misses++;
      _slips++;
      ctrl.applyTurn(widget.s, null, r.usedWords, widget.c, speaker: node.speaker);
      final ghost = RecastEngine.ghostHint(node);
      setState(() {
        _hints = _misses >= 2;
        _fb = _Feedback(_FbKind.ghost, 'Ghost hint', _t(ghost.replaceAll('You mean… ', '')), _tFa(node.branches.first.suggestionFa));
      });
      await _show(speaker.id, _misses == 1 ? _t(ghost) : 'No worries — have a peek at these 👇', null);
      return;
    }
    _correct += r.recastTip == null ? 1 : 0;
    final o = ctrl.applyTurn(widget.s, r.branch, r.usedWords, widget.c, speaker: node.speaker, trustDelta: r.trustDelta);
    _trustGained += o.trustDelta;
    _perChar[speaker.id] = (_perChar[speaker.id] ?? 0) + o.trustDelta;
    _unlocked.addAll(o.unlockedScenes);
    if (r.recastTip != null) {
      _slips++;
      _recasts.add((r.recastTip!.better.split(' / ').first, r.recastTip!.betterFa, speaker.id));
      setState(() => _fb = _Feedback(_FbKind.recast, 'In Britain, instead of “${_short(text)}” say:', r.recastTip!.better, r.recastTip!.betterFa));
    } else if (r.register == Register.blunt) {
      setState(() => _fb = _Feedback(_FbKind.cool, '${speaker.name} sounds a little cooler', 'Softeners like “please”, “cheers” or “could I…?” warm people up.'));
    } else if (r.register == Register.warm) {
      setState(() => _fb = _Feedback(_FbKind.warm, '${speaker.name} warmed to that', 'Polite and friendly — exactly how locals do it.'));
    } else {
      setState(() => _fb = null);
    }
    if (r.npcReply != null) await _show(speaker.id, r.npcReply!, null);
    if (o.reachedMilestone != null) {
      setState(() => _msgs.add(_Msg('', '', system: '${speaker.name} grew: ${o.reachedMilestone!.title} · Passport stamp earned')));
    }
    final next = r.branch!.next == null ? null : widget.s.nodes[r.branch!.next];
    if (r.npcReply != null) await Future.delayed(const Duration(milliseconds: 900));
    if (next != null) {
      _say(next);
    } else {
      _finish();
    }
  }

  /// Swapped: the learner said the character's line; the other side answers and the story moves on.
  Future<void> _sendAsLine(String text) async {
    final n = _mine!;
    _mine = null;
    HapticFeedback.lightImpact();
    _input.clear();
    _said++;
    final target = _t(n.text);
    final score = Pronunciation.bestOf([target], [text])?.$2.score ?? 0;
    final name = _who(n.speaker).name;
    setState(() {
      _msgs.add(_Msg('me', text, asName: name));
      if (score >= 60) {
        _correct++;
      } else {
        _slips++;
        _fb = _Feedback(_FbKind.recast, '$name’s line was:', target, _tFa(lineTranslation(n.translations, _lang)));
      }
    });
    if (n.isEnd || n.branches.isEmpty) {
      _finish();
      return;
    }
    await _partnerReply(n);
  }

  /// The other side (the learner's usual part) answers [n] with its best reply, then the next line comes.
  Future<void> _partnerReply(DialogueNode n) async {
    final b = n.branches.firstWhere((b) => b.success, orElse: () => n.branches.first);
    await _show(_partnerId, b.suggestion, _tFa(b.suggestionFa), delay: 500);
    if (!mounted || _ended) return;
    final next = b.next == null ? null : widget.s.nodes[b.next];
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (next != null) {
      _say(next);
    } else {
      _finish();
    }
  }

  /// Switch who the learner plays, mid-scene, without restarting.
  void _setSwap(bool v) {
    if (v == _swap || _ended) return;
    HapticFeedback.selectionClick();
    Voice.stop();
    setState(() {
      _swap = v;
      _pron = null;
      _pronIdx = null;
      _speakNote = null;
      _tapped = null;
      _hints = v;
      _msgs.add(_Msg('', '', system: v ? 'Now you are ${ch.name}  ·  نقش عوض شد' : 'Back to your part  ·  نقش عوض شد'));
    });
    // Mid-line (someone is typing): the next line simply arrives in the new role.
    if (_typing) return;
    final n = _node;
    if (n == null) return;
    if (v) {
      // The reply the learner owed is now spoken by the other side; then it's the learner's line.
      if (!n.isEnd && n.branches.isNotEmpty) _partnerReply(n);
    } else {
      // Back to the usual part: the character says the line the learner was about to say.
      final m = _mine;
      _mine = null;
      if (m != null) _say(m);
    }
  }

  String _short(String s) => s.length > 28 ? '${s.substring(0, 26)}…' : s;

  /// Index of the bubble whose tools are showing: the tapped one, else the latest line from someone else.
  int get _active => _sel ?? _msgs.lastIndexWhere((m) => m.speaker != 'me' && m.system == null && m.fb == null && m.text.isNotEmpty);
  _Msg? get _activeMsg => _active < 0 || _active >= _msgs.length ? null : _msgs[_active];

  Future<void> _speak(Speed sp) {
    final m = _activeMsg;
    if (m == null) return Voice.say(_lineSpeaker, _raw, rate: Voice.rates[sp.index], shown: _line);
    return Voice.say(m.speaker, m.raw ?? m.text, rate: Voice.rates[sp.index], shown: m.text);
  }

  Future<void> _speakText(String t, double rate) => Voice.say(_activeMsg?.speaker ?? _lineSpeaker, t, rate: rate);

  Future<void> _mic() async {
    if (_listening) {
      SpeechInput.stop();
      return;
    }
    if (!SpeechInput.sttSupported || SpeechInput.sttBroken) {
      _setSpeakMode(true); // -> keyboard dictation fallback
      return;
    }
    SpeechInput.stopClip(); // never listen to our own voice clip
    setState(() {
      _listening = true;
      _partial = '';
      _speakNote = null;
    });
    final r = await SpeechInput.listenDetailed(onPartial: (p) {
      if (mounted) setState(() => _partial = p);
    });
    if (!mounted) return;
    setState(() {
      _listening = false;
      _partial = '';
    });
    if (!r.ok) {
      if (r.permissionDenied && !SpeechInput.sttBroken) {
        showMicHelp(context, r.error, onType: () => _setSpeakMode(false));
      } else if (SpeechInput.sttBroken) {
        // The speech service doesn't run here (often the iPhone Home Screen app): fall back to the keyboard's
        // own dictation mic, which works everywhere, and say so once.
        ref.read(progressProvider.notifier).setSpeakMode(false);
        _dictateNote();
      } else if (r.error != 'aborted') {
        setState(() {
          _speakNote = speechErrorText(r.error);
          _speakNoteFa = speechErrorFa(r.error);
        });
      }
      return;
    }
    final targets = [for (final t in _targets) t.$1];
    final best = targets.isEmpty ? null : Pronunciation.bestOf(targets, r.alternatives);
    if (best == null || best.$2.score < 35) {
      // Free speech that matches no option: send what was heard, like typing it.
      _input.text = r.best;
      _send();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _pron = best.$2;
      _pronIdx = best.$1;
    });
    if (best.$2.passed) {
      final mine = best.$2;
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted && _pron == mine) _sendPron();
    }
  }

  void _sendPron() {
    final i = _pronIdx, ts = _targets;
    if (i == null || i >= ts.length) return;
    setState(() => _pron = null);
    _send(ts[i].$1);
  }

  /// Fallback note: speak with the keyboard's dictation mic instead (typed text is matched like a spoken reply).
  void _dictateNote() => setState(() {
    _dictate = true;
    _speakNote = 'Speech recognition isn\'t available in this browser mode. Tap “Keyboard mic”, then the 🎤 on your keyboard and say your reply — or just type it.';
    _speakNoteFa = 'تشخیص گفتار در این حالت مرورگر در دسترس نیست. «Keyboard mic» را بزن، بعد 🎤 روی کیبورد را بزن و جوابت را بگو — یا فقط تایپش کن.';
  });

  void _setSpeakMode(bool on) {
    if (on && (SpeechInput.sttBroken || !SpeechInput.sttSupported)) {
      _focus.requestFocus(); // inside the tap, so iOS opens the keyboard (with its dictation mic)
      _dictateNote();
      return;
    }
    ref.read(progressProvider.notifier).setSpeakMode(on);
    setState(() {
      _pron = null;
      _speakNote = null;
    });
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final url = await SpeechInput.stopRecording();
      setState(() {
        _recording = false;
        _myTake = url;
      });
    } else {
      try {
        await SpeechInput.startRecording();
        setState(() => _recording = true);
      } catch (_) {}
    }
  }

  Future<void> _finish() async {
    if (_ended) return;
    _ended = true;
    final transcript = <List<String>>[
      for (final m in _msgs)
        if (m.system == null) [m.speaker, m.text, m.node?.translations['fa'] ?? ''],
    ];
    final learned = [for (final m in _msgs) ...?m.node?.newWords];
    ref.read(progressProvider.notifier).completeScene(widget.s, ch.accent, transcript: transcript, words: learned.map((w) => w.word).toList(), trustGained: _trustGained, slips: _slips, recasts: _recasts, learned: learned);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    if (_unlocked.isNotEmpty) await _celebrate();
    if (!mounted) return;
    await _summary();
  }

  Future<void> _celebrate() => showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'celebration',
    barrierColor: BL.ink.withValues(alpha: .6),
    transitionDuration: const Duration(milliseconds: 450),
    transitionBuilder: (_, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: child,
    ),
    pageBuilder: (ctx, _, _) {
      final s = widget.c.scenes[_unlocked.first]!;
      return Stack(
        children: [
          const Positioned.fill(child: Confetti()),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(28), boxShadow: BL.shadow(.3)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(ch, size: 110),
                        const Positioned(right: -8, top: -6, child: Text('🎂', style: TextStyle(fontSize: 36))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'NEW STORY UNLOCKED',
                      style: TextStyle(letterSpacing: 1.6, fontSize: 11, fontWeight: FontWeight.w800, color: BL.red),
                    ),
                    const SizedBox(height: 6),
                    Text(s.title, textAlign: TextAlign.center, style: BL.display(26)),
                    Text(s.titleFa, textDirection: TextDirection.rtl, style: BL.fa(14)),
                    const SizedBox(height: 10),
                    Text(
                      '${ch.name} trusts you now — you’re invited to the party!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: BL.muted),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Brilliant!', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );


  Future<void> _summary() {
    final p = ref.read(progressProvider);
    final words = {for (final m in _msgs) ...?m.node?.newWords}.toList();
    final lang = p.lang;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BL.cream,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(lang, 'lovelyChat'), style: BL.display(28)),
              const SizedBox(height: 14),
              Row(children: [_Stat('$_said', tr(lang, 'said'), BL.navy), _Stat('$_correct', tr(lang, 'spotOn'), BL.green), _Stat('$_slips', tr(lang, 'recasts'), BL.gold)]),
              const SizedBox(height: 14),
              Text(tr(lang, 'trustBy'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              for (final e in _perChar.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Avatar(_who(e.key), size: 30, ring: false),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_who(e.key).name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(e.value >= 0 ? '+${e.value} ♥' : '${e.value} ♥', style: TextStyle(color: e.value > 0 ? BL.red : BL.muted, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              if (_recasts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(tr(lang, 'tomorrow'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                for (final r in _recasts) Text('• ${r.$1}', style: const TextStyle(color: BL.green)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final w in words) Chip(side: BorderSide.none, backgroundColor: BL.paper, label: Text('${w.word} · ${w.fa}', style: BL.fa(12, color: BL.ink)))],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pushReplacement('/chat/${widget.s.id}');
                      },
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr(lang, 'playAgain'))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: BL.navy),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (_unlocked.isNotEmpty) {
                          context.pushReplacement('/chat/${_unlocked.first}');
                        } else {
                          context.canPop() ? context.pop() : context.go('/');
                        }
                      },
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_unlocked.isNotEmpty ? tr(lang, 'nextStory') : tr(lang, 'done'))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _transcript() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: BL.cream,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(widget.s.title, style: BL.display(22)),
          const SizedBox(height: 10),
          for (final m in _msgs)
            if (m.system != null)
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('🌱 ${m.system}', style: const TextStyle(fontWeight: FontWeight.w700)))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: m.speaker == 'me' ? '${m.asName ?? _meName}  ' : '${_who(m.speaker).name}  ', style: TextStyle(fontWeight: FontWeight.w800, color: m.speaker == 'me' ? BL.navy : _who(m.speaker).color)),
                      TextSpan(text: m.text),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    final cv = widget.c.coverOf(widget.s.id);
    final host = cv.host;
    final cover = cv.image;
    final pad = MediaQuery.paddingOf(context);
    final trust = GrowthEngine.softTrust(p.trustMap[_lineSpeaker.isEmpty ? ch.id : _lineSpeaker] ?? 0);
    final sp = _who(_lineSpeaker.isEmpty ? ch.id : _lineSpeaker);
    // The painting is a proper hero: about 16:9 of the phone width, never a thin strip.
    // Tall while the chat is short (no empty dark gap), then it settles to about 16:9 as lines arrive.
    final scr = MediaQuery.sizeOf(context);
    final early = _msgs.where((m) => m.system == null && m.fb == null).length <= 2;
    final bannerH = pad.top + (early ? (scr.width * .8).clamp(128.0, scr.height * .42) : (scr.width * .5).clamp(128.0, scr.height * .24));
    final strip = _strip(cover, host);
    return CustomPaint(
      painter: _WoodGrain(),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF22A1D14), Color(0xFA140E0A)])),
        child: Stack(children: [
          Column(children: [
            // Compact header banner: the painting (or a people-free location card) with title, speaker and hearts.
            AnimatedContainer(
              key: const ValueKey('chat-banner'),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: bannerH,
              child: Stack(fit: StackFit.expand, children: [
                cover != null ? _paintingLayer(cover, host, sp) : LocationCard(art: widget.c.artOf(widget.s.id), color: ch.color, compact: true),
                IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .6), Colors.transparent, Colors.black.withValues(alpha: .55)])))),
                Positioned(
                  left: 8,
                  right: 10,
                  top: pad.top + 4,
                  child: Row(children: [
                    const NavButtons(light: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(17, color: Colors.white)),
                        Text(_canSwap ? '${widget.s.level}  ·  ${widget.s.setting}' : '${widget.s.level}  ·  ${tr(_lang, 'playingAs')} $_meName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Transcript',
                      onPressed: _transcript,
                      style: IconButton.styleFrom(backgroundColor: Colors.black26),
                      icon: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 19),
                    ),
                  ]),
                ),
                Positioned(
                  left: 12,
                  bottom: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Avatar(sp, size: 24, ring: false),
                        const SizedBox(width: 6),
                        Text(sp.name, style: const TextStyle(color: Color(0xFFE8C987), fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(_mood.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        _hearts(trust),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            ?strip,
            Expanded(child: _chatList()),
            _bottom(pad),
          ]),
          if (_tapped != null) Positioned(left: 12, right: 12, top: bannerH + (strip == null ? 6 : 50), child: _tapCard(_tapped!)),
        ]),
      ),
    );
  }

  /// WhatsApp-style transcript: everyone else on the left with a face and name, the learner on the right,
  /// newest at the bottom (a reversed list keeps the latest line in view).
  Widget _chatList() {
    final items = <Widget>[
      if (_typing) Align(key: const ValueKey('typing'), alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 42, top: 4, bottom: 4), child: _bubbleBox(const _Dots(), const Color(0xFFFBF3E4), left: true))),
      for (var i = _msgs.length - 1; i >= 0; i--) _row(i),
    ];
    return ListView(key: const ValueKey('chat-list'), controller: _scroll, reverse: true, padding: const EdgeInsets.fromLTRB(10, 10, 10, 8), children: items);
  }

  Widget _bubbleBox(Widget child, Color color, {required bool left}) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.only(topLeft: Radius.circular(left ? 4 : 16), topRight: Radius.circular(left ? 16 : 4), bottomLeft: const Radius.circular(16), bottomRight: const Radius.circular(16)),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: child,
  );

  Widget _row(int i) {
    final m = _msgs[i];
    final maxW = MediaQuery.sizeOf(context).width * .78;
    if (m.fb != null) {
      return Padding(key: ValueKey('fb-$i'), padding: const EdgeInsets.fromLTRB(42, 0, 24, 6), child: _feedback(m.fb!, index: i));
    }
    if (m.system != null) {
      return Center(
        child: Container(
          key: ValueKey('sys-$i'),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0x33E9B949), borderRadius: BorderRadius.circular(99)),
          child: Text(m.system!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF2D891), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );
    }
    if (m.speaker == 'me') {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          key: ValueKey('bubble-me-$i'),
          padding: const EdgeInsets.only(left: 48, bottom: 6),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Padding(padding: const EdgeInsets.only(right: 4, bottom: 2), child: Text(m.asName ?? _meName, style: const TextStyle(color: Color(0xFF9FE0BC), fontSize: 11, fontWeight: FontWeight.w800))),
              _bubbleBox(LeitnerWords(m.text, speaker: 'me', style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.3)), const Color(0xFF2F6B5A), left: false),
            ]),
          ),
        ),
      );
    }
    final who = _who(m.speaker);
    final active = i == _active && !_typing;
    return Padding(
      key: ValueKey('bubble-$i'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2, right: 6), child: Avatar(who, size: 34, ring: false)),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.node?.event != null) _eventBanner(m.node!.event!),
              GestureDetector(
                onTap: () => setState(() {
                  _sel = i;
                  _panel = _Panel.none;
                }),
                child: _bubbleBox(
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(who.name, style: TextStyle(color: Color.lerp(who.color, Colors.black, .25), fontSize: 11.5, fontWeight: FontWeight.w800)),
                    LeitnerWords(m.text, speaker: m.speaker, style: BL.display(16.5, color: BL.ink, w: FontWeight.w500).copyWith(height: 1.32)),
                  ]),
                  active ? const Color(0xFFFFF8EA) : const Color(0xFFEFE6D8),
                  left: true,
                ),
              ),
              if (active && !_ended) Padding(padding: const EdgeInsets.only(top: 6), child: _tools(m)),
              if (active) AnimatedSize(duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic, child: _panelView(m)),
            ]),
          ),
        ),
      ]),
    );
  }

  /// The fixed bottom: hints, pronunciation result, notes and the composer.
  Widget _bottom(EdgeInsets pad) => Container(
    padding: EdgeInsets.fromLTRB(14, 6, 14, pad.bottom + 10),
    decoration: const BoxDecoration(color: Color(0xF5140E0A), border: Border(top: BorderSide(color: Color(0x55C9A45C)))),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .45),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((_hints || _speaking) && !_ended && _pron == null) _hintChips(),
          if (_pron != null)
            PronunciationCard(
              result: _pron!,
              onRetry: _ended ? null : _mic,
              onListen: () => Voice.say('me', _pron!.target),
              onSend: _ended ? null : _sendPron,
            ),
          if (_speakNote != null) _speakFallback(),
          const SizedBox(height: 6),
          _speaking ? _speakComposer() : _composer(),
        ]),
      ),
    ),
  );

  /// The place whose hotspots match this cover painting (the story's host, or the place that owns a
  /// special story-cover painting), so every painting gets tap areas.
  bool get _borrowed => widget.c.artOf(widget.s.id)?.borrowed ?? false;

  Place? _tapHost(String cover, Place? host) =>
      host?.image == cover ? host : widget.c.places.where((p) => p.image == cover).firstOrNull;

  /// People in the painting the learner can reach (not the role they're playing).
  List<Hotspot> _people(Place? th) {
    if (th == null || _borrowed) return const [];
    final me = widget.s.playAs ?? ref.read(progressProvider).role;
    final seen = <String>{};
    return [for (final h in th.hotspots) if (!h.isProp && h.characterId != me && h.rect != null && widget.c.characterOrNull(h.characterId) != null && seen.add(h.characterId)) h];
  }

  /// The painting with live tap areas. BoxFit.cover + alignment, so taps are mapped back into
  /// image space using the same scale/offset Flutter uses to paint it. On narrow phones the
  /// painting is wider than the screen: it pans to the speaker, and the learner can drag it
  /// sideways (or tap a portrait chip) to reach everyone else.
  Widget _paintingLayer(String cover, Place? host, Character sp) {
    final th = _tapHost(cover, host);
    final target = (_pan ?? _focusX(th, sp.id)).clamp(-1.0, 1.0);
    return LayoutBuilder(builder: (context, box) {
      final bw = box.maxWidth, bh = box.maxHeight, ar = th?.aspect ?? 1.6;
      // BoxFit.cover: scale so the image covers the box; overflow is cropped per alignment.
      final iw = bw / bh > ar ? bw : bh * ar, ih = iw / ar;
      final canPan = iw - bw > 1;
      return TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, ax, _) {
          _curAx = ax;
          final ox = (bw - iw) * (ax + 1) / 2, oy = (bh - ih) / 2;
          final img = Image.asset(cover, fit: BoxFit.cover, alignment: Alignment(ax, 0));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: canPan ? (_) => setState(() { _dragging = true; _pan = _curAx; }) : null,
            onHorizontalDragUpdate: canPan ? (d) => setState(() => _pan = ((_pan ?? _curAx) + 2 * d.delta.dx / (bw - iw)).clamp(-1.0, 1.0)) : null,
            onHorizontalDragEnd: canPan ? (_) => setState(() => _dragging = false) : null,
            onTapUp: th == null || th.hotspots.isEmpty ? null : (d) {
              final x = (d.localPosition.dx - ox) / iw, y = (d.localPosition.dy - oy) / ih;
              final me = widget.s.playAs ?? ref.read(progressProvider).role;
              final hs = hitTest(th.hotspots.where((h) => h.isProp || (!_borrowed && h.characterId != me)), x, y);
              if (hs != null) _onPaintingTap(hs, d.localPosition);
            },
            child: Stack(fit: StackFit.expand, children: [
              img,
              if (_tapAt != null) Positioned(left: _tapAt!.dx - 22, top: _tapAt!.dy - 22, width: 44, height: 44, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE9B949), width: 2.5))))),
            ]),
          );
        },
      );
    });
  }

  /// The labelled role switch: "Play as · در نقش  [You] [Siân]".
  Widget _playAs() {
    final me = _who(_partnerId);
    Widget opt(Character c, String label, bool on, VoidCallback tap, Key key) => Semantics(
      button: true,
      selected: on,
      label: 'Play as $label',
      child: GestureDetector(
        key: key,
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
          decoration: BoxDecoration(color: on ? const Color(0xFFE9B949) : Colors.transparent, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Avatar(c, size: 22, ring: false),
            const SizedBox(width: 5),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 64), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? BL.ink : Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))),
          ]),
        ),
      ),
    );
    return Container(
      key: const ValueKey('play-as'),
      padding: const EdgeInsets.fromLTRB(8, 3, 3, 3),
      decoration: BoxDecoration(color: const Color(0xCC140E0A), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x99E9B949))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Play as', style: TextStyle(color: Color(0xFFE8C987), fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.1)),
          Text('در نقش', textDirection: TextDirection.rtl, style: BL.fa(10, color: Colors.white60).copyWith(height: 1.2)),
        ]),
        const SizedBox(width: 6),
        opt(me, _partnerId == 'learner' ? 'You' : me.name, !_swap, () => _setSwap(false), const ValueKey('playas-me')),
        opt(ch, ch.name, _swap, () => _setSwap(true), const ValueKey('playas-them')),
      ]),
    );
  }

  /// One tidy row under the painting: the "Play as" switch, then everyone in the painting as a
  /// horizontally scrolling row of portraits (never a cluster over the picture).
  Widget? _strip(String? cover, Place? host) {
    final chips = cover == null ? const <Hotspot>[] : _people(_tapHost(cover, host));
    final showChips = chips.length >= 2;
    if (!_canSwap && !showChips) return null;
    return Container(
      key: const ValueKey('chat-strip'),
      height: 44,
      padding: const EdgeInsets.fromLTRB(10, 5, 0, 5),
      decoration: const BoxDecoration(color: Color(0xF0140E0A), border: Border(bottom: BorderSide(color: Color(0x33C9A45C)))),
      child: Row(children: [
        if (_canSwap) _playAs(),
        if (_canSwap && showChips) const SizedBox(width: 8),
        if (showChips) Expanded(child: _peopleChips(_tapHost(cover!, host))) else const Spacer(),
      ]),
    );
  }

  /// Portrait chips for everyone in the painting: tap one to pan to them and hear them.
  Widget _peopleChips(Place? th) {
    final ps = _people(th);
    if (ps.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      key: const ValueKey('people-chips'),
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Tooltip(message: 'Tap someone to hear them', child: Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.hearing_rounded, size: 16, color: Colors.white70))),
        for (final h in ps)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              key: ValueKey('chip-${h.characterId}'),
              onTap: () {
                final r = h.rect!;
                setState(() => _pan = ((r[0] + r[2] / 2) * 2 - 1).clamp(-1.0, 1.0));
                _onPaintingTap(h, null);
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black38, border: Border.all(color: _tapped == h ? const Color(0xFFE9B949) : Colors.white24, width: 1.5)),
                child: Avatar(widget.c.character(h.characterId), size: 26, ring: false),
              ),
            ),
          ),
        const SizedBox(width: 4),
      ]),
    );
  }

  void _onPaintingTap(Hotspot h, Offset? at) {
    HapticFeedback.selectionClick();
    final dup = !h.isProp && h.characterId == _lineSpeaker && _raw.isNotEmpty;
    // The speaker's line is already in the chat: replay it, no duplicate card over the chat.
    setState(() { _tapAt = at; _tapped = dup ? null : h; });
    if (!dup) Future.delayed(const Duration(seconds: 6), () { if (mounted && _tapped == h) setState(() => _tapped = null); });
    if (at != null) Future.delayed(const Duration(milliseconds: 500), () { if (mounted && _tapAt == at) setState(() => _tapAt = null); });
    if (h.isProp) {
      Voice.say('narrator', h.prop!.word, rate: .9).then((_) { if (mounted && _tapped == h) Voice.say('narrator', h.prop!.phrase, rate: .9); });
    } else if (h.characterId == _lineSpeaker && _raw.isNotEmpty) {
      Voice.say(_lineSpeaker, _raw, rate: _autoRate, shown: _line); // tap the speaker = hear the line again
    } else {
      final l = _personLine(h);
      if (l.raw.isNotEmpty) Voice.say(h.characterId, l.raw, shown: l.en);
    }
  }

  /// What a tapped (non-speaking) person says: their ambient line, else their latest line in
  /// this story, else their first line in it, so every person in the painting answers with audio.
  ({String en, String raw, String? fa}) _personLine(Hotspot h) {
    if (h.ambientEn != null) return (en: h.ambientEn!, raw: h.ambientEn!, fa: h.ambientFa);
    final m = _msgs.lastWhere((m) => m.speaker == h.characterId && m.system == null && m.text.isNotEmpty, orElse: () => const _Msg('', ''));
    DialogueNode? firstBy(String? sid) => widget.c.scenes[sid]?.nodes.values.where((n) => n.speaker == h.characterId).firstOrNull;
    final n = m.node ?? firstBy(widget.s.id) ?? firstBy(h.sceneId) ?? firstBy(widget.c.characterOrNull(h.characterId)?.starterScene);
    if (n != null) return (en: _t(n.text), raw: n.text, fa: _tFa(lineTranslation(n.translations, _lang)));
    if (m.text.isNotEmpty) return (en: m.text, raw: m.text, fa: null);
    return (en: '', raw: '', fa: null);
  }

  /// "Switch to them": the tapped person's own story, when it's a different, playable one.
  String? _switchScene(Hotspot h) {
    final sid = h.sceneId;
    if (h.isProp || sid == null || sid == (widget.s.baseId ?? widget.s.id)) return null;
    final s = widget.c.scenes[sid];
    return s != null && ref.read(progressProvider.notifier).canPlay(s, widget.c) ? sid : null;
  }

  Widget _tapCard(Hotspot h) {
    const gold = Color(0xFFE8C987);
    final prop = h.prop;
    final ch = prop == null ? widget.c.characterOrNull(h.characterId) : null;
    final speaking = prop == null && h.characterId == _lineSpeaker;
    final pl = prop == null && !speaking ? _personLine(h) : null;
    final en = prop != null ? prop.word : speaking ? _line : pl!.en;
    final fa = prop != null ? prop.fa : speaking ? _lineFa : pl!.fa;
    final sw = _switchScene(h);
    // Only the buttons take touches: the rest of the card lets taps through to the painting,
    // so the card can never block a person or object behind it.
    return Stack(
      key: ValueKey('tapcard-${prop?.id ?? h.characterId}'),
      children: [
      Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xEE1E150F), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFC9A45C), width: 1.1))))),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IgnorePointer(child: ch != null ? Padding(padding: const EdgeInsets.only(right: 10), child: Avatar(ch, size: 32, ring: false)) : const Padding(padding: EdgeInsets.only(right: 10, top: 2), child: Text('✦', style: TextStyle(color: gold, fontSize: 18)))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            IgnorePointer(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(ch?.name ?? 'WORD', style: const TextStyle(color: gold, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
            if (en.isNotEmpty) Text(en, style: BL.display(15.5, color: const Color(0xFFFBF3E4), w: FontWeight.w500)),
            if (fa != null && fa.isNotEmpty) SizedBox(width: double.infinity, child: Text(fa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white60))),
            if (prop != null) ...[
              const SizedBox(height: 4),
              Text('“${prop.phrase}”', style: const TextStyle(color: Colors.white, fontSize: 13.5)),
              SizedBox(width: double.infinity, child: Text(prop.phraseFa, textDirection: TextDirection.rtl, style: BL.fa(12, color: Colors.white54))),
            ],
            ])),
            if (sw != null && ch != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () { setState(() => _tapped = null); context.push('/chat/$sw'); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x33E8C987), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold, width: .8)),
                    child: Text('Talk to ${ch.name} ›', style: const TextStyle(color: gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ])),
          Material(type: MaterialType.transparency, child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(visualDensity: VisualDensity.compact, tooltip: tr(_lang, 'listen'), onPressed: () => _onPaintingTap(h, null), icon: const Icon(Icons.volume_up_rounded, color: gold, size: 20)),
            IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _tapped = null), icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18)),
          ])),
        ]),
      ),
    ]);
  }

  // Keep the active speaker in frame on narrow phones (painting pans to them).
  double _focusX(dynamic host, String id) {
    if (host == null) return 0;
    final hs = (host.hotspots as List).where((x) => x.characterId == id && x.rect != null).firstOrNull;
    if (hs == null) return 0;
    final cx = hs.rect![0] + hs.rect![2] / 2;
    return (cx * 2 - 1).clamp(-1.0, 1.0);
  }

  Widget _hearts(double trust) => Row(
    children: [
      for (var i = 0; i < 5; i++)
        Icon(
          trust >= (i + 1) * 20 ? Icons.favorite_rounded : (trust >= i * 20 + 10 ? Icons.favorite_rounded : Icons.favorite_border_rounded),
          size: 14,
          color: trust >= i * 20 + 10 ? const Color(0xFFE0564F) : Colors.white24,
        ),
    ],
  );

  Widget _eventBanner(CultureNote e) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0x33E9B949), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const Text('💥', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(e.en, style: const TextStyle(color: Color(0xFFF2D891), fontStyle: FontStyle.italic, fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _tools(_Msg m) {
    final n = m.node;
    final onLine = n != null && m.text == _t(n.text);
    return Wrap(
      key: const ValueKey('bubble-tools'),
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in Speed.values) _pill(s == Speed.slow ? Icons.slow_motion_video_rounded : Icons.volume_up_rounded, tr(_lang, s.name), () => _speak(s)),
        if (onLine) _pill(Icons.blur_on_rounded, 'X-Ray', () => _togglePanel(_Panel.xray), on: _panel == _Panel.xray),
        if (m.fa != null && m.fa!.isNotEmpty) _pill(Icons.translate_rounded, langOf(_lang).native, () => _togglePanel(_Panel.translate), on: _panel == _Panel.translate),
        if (onLine && n.cultureNote != null) _pill(Icons.emoji_objects_outlined, tr(_lang, 'culture'), () => _togglePanel(_Panel.culture), on: _panel == _Panel.culture),
        if (SpeechInput.recordSupported) _pill(Icons.record_voice_over_rounded, tr(_lang, 'shadow'), () => _togglePanel(_Panel.shadow), on: _panel == _Panel.shadow),
      ],
    );
  }

  void _togglePanel(_Panel p) => setState(() => _panel = _panel == p ? _Panel.none : p);

  Widget _pill(IconData i, String l, VoidCallback f, {bool on = false}) => Pressable(
    onTap: f,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? const Color(0x55E9B949) : Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: on ? const Color(0xFFE9B949) : Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 14, color: const Color(0xFFE8C987)),
          const SizedBox(width: 4),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );

  Widget _panelView(_Msg m) {
    final n = m.node;
    if (_panel == _Panel.none || (n == null && _panel != _Panel.translate && _panel != _Panel.shadow)) return const SizedBox(width: double.infinity);
    Widget box(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
      child: child,
    );
    const label = TextStyle(color: Color(0xFFC9A45C), fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800);
    switch (_panel) {
      case _Panel.xray:
        final x = ConnectedSpeech.of(n!);
        return box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WRITTEN', style: label),
              Text(x.formal, style: const TextStyle(color: Colors.white60, fontSize: 13.5)),
              const SizedBox(height: 8),
              const Text('HOW BRITS SAY IT', style: label),
              Text(x.connected, style: BL.display(17, color: const Color(0xFFFBF3E4))),
              const SizedBox(height: 2),
              Text(x.ipa, style: const TextStyle(color: Color(0xFF9FD3B4), fontSize: 13.5, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _pill(Icons.bolt_rounded, tr(_lang, 'native'), () => _speakText(x.connected, 1.0)),
                  _pill(Icons.slow_motion_video_rounded, tr(_lang, 'slowed'), () => _speakText(x.connected, .68)),
                ],
              ),
            ],
          ),
        );
      case _Panel.translate:
        return box(SizedBox(width: double.infinity, child: Text(m.fa ?? '', textDirection: (n?.translations.containsKey(_lang) ?? false) ? dirOf(_lang) : TextDirection.rtl, style: BL.fa(14.5, color: Colors.white70))));
      case _Panel.culture:
        return box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🇬🇧  CULTURE NOTE', style: label),
              const SizedBox(height: 4),
              Text(n!.cultureNote!.en, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
              SizedBox(width: double.infinity, child: Text(n.cultureNote!.fa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: Colors.white60))),
            ],
          ),
        );
      case _Panel.shadow:
        return box(
          Row(
            children: [
              Expanded(child: Text(tr(_lang, 'shadowHelp'), style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
              _pill(_recording ? Icons.stop_rounded : Icons.mic_rounded, _recording ? 'Stop' : 'Record', _toggleRecord, on: _recording),
              if (_myTake != null) ...[const SizedBox(width: 6), _pill(Icons.play_arrow_rounded, 'Me', () => SpeechInput.play(_myTake!))],
            ],
          ),
        );
      case _Panel.none:
        return const SizedBox.shrink();
    }
  }

  Widget _feedback(_Feedback f, {int? index}) {
    final (bg, fg, icon) = switch (f.kind) {
      _FbKind.recast => (const Color(0x2E3FAF7A), const Color(0xFF9FE0BC), Icons.tips_and_updates_rounded),
      _FbKind.ghost => (const Color(0x26B9C3FF), const Color(0xFFD3D8FF), Icons.auto_awesome_rounded),
      _FbKind.warm => (const Color(0x26E0564F), const Color(0xFFF4B4AE), Icons.favorite_rounded),
      _FbKind.cool => (const Color(0x1FFFFFFF), Colors.white70, Icons.ac_unit_rounded),
      _FbKind.memory => (const Color(0x33E9B949), const Color(0xFFF2D891), Icons.history_rounded),
    };
    return Container(
      key: ValueKey('${f.kind}${f.body}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.title, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(f.body, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3)),
                if (f.fa != null && f.fa!.isNotEmpty) SizedBox(width: double.infinity, child: Text(f.fa!, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: Colors.white54))),
              ],
            ),
          ),
          InkWell(onTap: () => setState(() { if (index != null && index < _msgs.length) _msgs.removeAt(index); }), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white38)),
        ],
      ),
    );
  }

  // Swapped and the other side is still talking: no stale reply chips from the usual part.
  Widget _hintChips() => _swap ? (_mine != null ? _lineCard() : const SizedBox.shrink()) : Padding(
    padding: const EdgeInsets.only(top: 10),
    child: SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final b in _node?.branches ?? const <Branch>[])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                key: ValueKey('reply-chip-${b.next}'),
                onTap: () => _send(_t(b.suggestion)),
                child: Container(
                  width: 210,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x88E9B949))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_t(b.suggestion), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(_tFa(b.suggestionFa)!, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: BL.fa(11, color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  /// Swapped: the character's line for the learner to say (tap it to say it, or tap the speaker to hear it first).
  Widget _lineCard() {
    final t = _targets.first;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Pressable(
        key: const ValueKey('my-line'),
        onTap: () => _send(t.$1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(color: const Color(0x22E9B949), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xAAE9B949))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR LINE AS ${ch.name.toUpperCase()}', style: const TextStyle(color: Color(0xFFE8C987), fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(t.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5, height: 1.3)),
              if (t.$2 != null && t.$2!.isNotEmpty) SizedBox(width: double.infinity, child: Text(t.$2!, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: Colors.white54))),
            ])),
            IconButton(tooltip: 'Hear it', onPressed: () => Voice.say(ch.id, _mine?.text ?? t.$1, rate: _autoRate, shown: t.$1), icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFE8C987), size: 20)),
          ]),
        ),
      ),
    );
  }

  bool get _speaking => ref.read(progressProvider.notifier).speakMode && SpeechInput.sttSupported && !SpeechInput.sttBroken;

  /// When speech fails: say why (English + helper language) and offer the other two ways to answer.
  Widget _speakFallback() => Container(
    key: const ValueKey('speak-note'),
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
    decoration: BoxDecoration(color: const Color(0x33E9B949), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x66E9B949))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.mic_off_rounded, size: 18, color: Color(0xFFE8C987)),
        const SizedBox(width: 8),
        Expanded(child: Text(_speakNote!, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3))),
        InkWell(onTap: () => setState(() { _speakNote = null; _dictate = false; }), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white38)),
      ]),
      if (_speakNoteFa != null) SizedBox(width: double.infinity, child: Text(_speakNoteFa!, textDirection: TextDirection.rtl, style: BL.fa(12, color: Colors.white60))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton.icon(
          key: const ValueKey('speak-note-type'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), visualDensity: VisualDensity.compact),
          onPressed: () {
            _setSpeakMode(false);
            _focus.requestFocus();
          },
          icon: Icon(_dictate ? Icons.keyboard_voice_rounded : Icons.keyboard_rounded, size: 16),
          label: Text(_dictate ? 'Keyboard mic' : 'Type it · بنویس'),
        ),
        if (_dictate)
          TextButton(
            key: const ValueKey('speak-retry'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8C987), visualDensity: VisualDensity.compact),
            onPressed: () {
              SpeechInput.setBroken(false);
              setState(() => _dictate = false);
              _setSpeakMode(true);
            },
            child: const Text('Try app mic again'),
          )
        else
          const Text('or tap a reply above · یا یک جواب را بزن', style: TextStyle(color: Colors.white60, fontSize: 11.5)),
      ]),
    ]),
  );

  /// Speak-the-reply composer: one big mic; the reply options above are the targets.
  Widget _speakComposer() => Row(
    children: [
      _round(Icons.keyboard_rounded, Colors.white.withValues(alpha: .1), () => _setSpeakMode(false), tip: 'Type instead'),
      const SizedBox(width: 8),
      Expanded(
        child: Pressable(
          onTap: _ended ? null : _mic,
          child: AnimatedContainer(
            key: const ValueKey('speak-mic'),
            duration: const Duration(milliseconds: 250),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: _listening ? BL.red : Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(99), border: Border.all(color: _listening ? BL.red : const Color(0x88E9B949))),
            child: Row(children: [
              Icon(_listening ? Icons.graphic_eq_rounded : Icons.mic_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _ended ? tr(_lang, 'storyDone') : _listening ? (_partial.isEmpty ? (_swap ? 'Listening… say your line' : 'Listening… say one of the replies') : _partial) : (_swap ? 'Tap and say ${ch.name}’s line' : 'Tap and say your reply'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _listening ? Colors.white : Colors.white70, fontWeight: FontWeight.w700, fontSize: 15),
              )),
              if (_listening) const Text('Tap to stop', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
        ),
      ),
    ],
  );

  Widget _composer() => Row(
    children: [
      _round(Icons.lightbulb_rounded, _hints ? BL.gold : Colors.white.withValues(alpha: .1), _ended ? null : () => setState(() => _hints = !_hints), iconColor: _hints ? BL.ink : const Color(0xFFE8C987), tip: 'Ghost hint'),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: _input,
          focusNode: _focus,
          enabled: !_ended,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) {
            _send();
            _focus.requestFocus();
          },
          style: const TextStyle(fontSize: 16, color: Colors.white), // ≥16 avoids iOS zoom
          cursorColor: BL.gold,
          decoration: InputDecoration(
            hintText: _ended ? tr(_lang, 'storyDone') : tr(_lang, 'replyHint'),
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: .08),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(width: 8),
      _round(Icons.mic_rounded, Colors.white.withValues(alpha: .1), _ended ? null : () => _setSpeakMode(true), tip: SpeechInput.sttSupported && !SpeechInput.sttBroken ? 'Speak your replies' : 'Speak with the keyboard mic'),
      const SizedBox(width: 8),
      _round(Icons.arrow_upward_rounded, BL.red, _ended ? null : _send, tip: 'Send'),
    ],
  );

  Widget _round(IconData i, Color bg, VoidCallback? f, {Color iconColor = Colors.white, String? tip}) => IconButton(
    tooltip: tip,
    onPressed: f,
    style: IconButton.styleFrom(backgroundColor: bg, minimumSize: const Size(46, 46), disabledBackgroundColor: Colors.white10),
    icon: Icon(i, color: iconColor, size: 21),
  );
}

class _WoodGrain extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0x0FE8C987)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 6.0; y < s.height; y += 9) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= s.width; x += 40) {
        path.quadraticBezierTo(x + 20, y + ((x ~/ 40).isEven ? 2.2 : -2.2), x + 40, y);
      }
      c.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Row(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(right: 5),
            width: 7,
            height: 7,
            transform: Matrix4.translationValues(0, -3.0 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0), 0),
            decoration: const BoxDecoration(color: Color(0x99E8C987), shape: BoxShape.circle),
          ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String v, l;
  final Color c;
  const _Stat(this.v, this.l, this.c);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(v, style: BL.display(24, color: c)),
          Text(l, style: const TextStyle(color: BL.muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

