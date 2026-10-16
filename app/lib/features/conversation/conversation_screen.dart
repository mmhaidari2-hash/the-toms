import 'dart:ui';

import 'package:flutter/material.dart';
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
  const _Msg(this.speaker, this.text, {this.node, this.system});
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
  DialogueNode? _node;
  String _lineSpeaker = '';
  String _line = '';
  String _raw = '';
  double get _autoRate => const ['A0', 'A1'].contains(widget.s.level) ? Voice.rates[1] : 1.0;
  String? _lineFa;
  String? _myLast;
  bool _typing = false, _ended = false, _hints = false, _listening = false, _recording = false;
  _Panel _panel = _Panel.none;
  _Feedback? _fb;
  int _misses = 0, _trustGained = 0, _said = 0, _correct = 0, _slips = 0;
  final _perChar = <String, int>{};
  final _recasts = <(String, String, String)>[];
  final _unlocked = <String>[];
  SrsItem? _srs;
  String? _myTake;

  Character get ch => widget.c.character(widget.s.characterId);
  Character _who(String id) => widget.c.characterOrNull(id) ?? ch;
  MoodInfo get _mood => EmotionEngine.label(ref.watch(progressProvider).moodMap[_lineSpeaker.isEmpty ? ch.id : _lineSpeaker] ?? 0);
  String get _me => widget.s.playAs != null ? 'Mehdi' : (widget.c.characterOrNull(ref.read(progressProvider).role)?.name ?? 'Mehdi');
  String get _meName => widget.c.characterOrNull(widget.s.playAs ?? ref.read(progressProvider).role)?.name ?? 'Mehdi';
  String _t(String s) => s.replaceAll('{you}', _me);
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
      Future.microtask(() => ctrl.setRole('mehdi'));
    }
    _input.dispose();
    _focus.dispose();
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
      _line = _t(text);
      _raw = text;
      _lineFa = fa;
      _panel = _Panel.none;
      _msgs.add(_Msg(speaker, _t(text)));
    });
    Voice.say(speaker, text, rate: _autoRate, shown: _t(text));
  }

  Future<void> _say(DialogueNode n0, {bool first = false}) async {
    final n = n0.atChapter(_ctrl.chapterIndex(widget.c));
    setState(() => _typing = true);
    await Future.delayed(Duration(milliseconds: first ? 450 : 600 + n.text.length * 10));
    if (!mounted) return;
    ref.read(progressProvider.notifier).seeWords(n.newWords);
    if (n.event != null) HapticFeedback.mediumImpact();
    setState(() {
      _typing = false;
      _node = n;
      _lineSpeaker = n.speaker;
      _line = _t(n.text);
      _raw = n.text;
      _lineFa = lineTranslation(n.translations, _lang);
      _msgs.add(_Msg(n.speaker, _t(n.text), node: n));
      _misses = 0;
      _hints = false;
      _panel = _Panel.none;
      _myTake = null;
    });
    Voice.say(n.speaker, n.text, rate: _autoRate, shown: _t(n.text));
    if (n.isEnd) _finish();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    final node = _node;
    if (text.isEmpty || _typing || _ended || node == null) return;
    HapticFeedback.lightImpact();
    _input.clear();
    _said++;
    setState(() {
      _myLast = text;
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
        _fb = _Feedback(_FbKind.ghost, 'Ghost hint', ghost.replaceAll('You mean… ', ''), node.branches.first.suggestionFa);
      });
      await _show(speaker.id, _misses == 1 ? ghost : 'No worries — have a peek at these 👇', null);
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

  String _short(String s) => s.length > 28 ? '${s.substring(0, 26)}…' : s;

  Future<void> _speak(Speed sp) => Voice.say(_lineSpeaker, _raw, rate: Voice.rates[sp.index], shown: _line);

  Future<void> _speakText(String t, double rate) => Voice.say(_lineSpeaker, t, rate: rate);

  Future<void> _mic() async {
    if (!SpeechInput.sttSupported || _listening) return;
    setState(() => _listening = true);
    final heard = await SpeechInput.listen();
    if (!mounted) return;
    setState(() => _listening = false);
    if (heard != null && heard.trim().isNotEmpty) {
      _input.text = heard;
      _send();
    }
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
                      TextSpan(text: m.speaker == 'me' ? '$_meName  ' : '${_who(m.speaker).name}  ', style: TextStyle(fontWeight: FontWeight.w800, color: m.speaker == 'me' ? BL.navy : _who(m.speaker).color)),
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
    final host = widget.c.hostOf(widget.s.id);
    final cover = host?.image ?? widget.c.moments.where((m) => m.sceneId == widget.s.id).firstOrNull?.cover;
    final pad = MediaQuery.paddingOf(context);
    final h = MediaQuery.sizeOf(context).height;
    final trust = GrowthEngine.softTrust(p.trustMap[_lineSpeaker.isEmpty ? ch.id : _lineSpeaker] ?? 0);
    final sp = _who(_lineSpeaker.isEmpty ? ch.id : _lineSpeaker);
    return Stack(
      children: [
        // The painting is the hero.
        Positioned.fill(
          bottom: h * .30,
          child: cover != null
              ? Image.asset(cover, fit: BoxFit.cover, alignment: Alignment(_focusX(host, sp.id), 0))
              : Container(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ch.color.withValues(alpha: .55), const Color(0xFF1B140F)])),
                  child: Center(child: Avatar(sp, size: 150)),
                ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(8, pad.top + 4, 10, 26),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .55), Colors.transparent])),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BL.display(17, color: Colors.white)),
                      Text('${widget.s.level}  ·  ${tr(_lang, 'playingAs')} $_meName', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Transcript',
                  onPressed: _transcript,
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                  icon: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 19),
                ),
              ],
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _sheet(sp, trust, pad, h)),
      ],
    );
  }

  // Keep the active speaker in frame on narrow phones (painting pans to them).
  double _focusX(dynamic host, String id) {
    if (host == null) return 0;
    final hs = (host.hotspots as List).where((x) => x.characterId == id && x.rect != null).firstOrNull;
    if (hs == null) return 0;
    final cx = hs.rect![0] + hs.rect![2] / 2;
    return (cx * 2 - 1).clamp(-1.0, 1.0);
  }

  Widget _sheet(Character sp, double trust, EdgeInsets pad, double h) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: CustomPaint(
        painter: _WoodGrain(),
        child: Container(
          constraints: BoxConstraints(minHeight: h * .34, maxHeight: h * .62),
          padding: EdgeInsets.fromLTRB(18, 14, 18, pad.bottom + 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFC9A45C), width: 1.4)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE62A1D14), Color(0xF5140E0A)]),
          ),
          child: SingleChildScrollView(
            reverse: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_node?.event != null && _lineSpeaker == _node!.speaker) _eventBanner(_node!.event!),
                Row(
                  children: [
                    Avatar(sp, size: 34, ring: false),
                    const SizedBox(width: 10),
                    Text(sp.name, style: BL.display(16, color: const Color(0xFFE8C987))),
                    const SizedBox(width: 6),
                    Text(_mood.emoji, style: const TextStyle(fontSize: 15)),
                    const Spacer(),
                    _hearts(trust),
                  ],
                ),
                const SizedBox(height: 10),
                if (_myLast != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('$_meName: “$_myLast”', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12.5, fontStyle: FontStyle.italic)),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _typing
                      ? const Padding(key: ValueKey('t'), padding: EdgeInsets.symmetric(vertical: 8), child: _Dots())
                      : Text(_line, key: ValueKey(_line), style: BL.display(18.5, color: const Color(0xFFFBF3E4), w: FontWeight.w500).copyWith(height: 1.35)),
                ),
                const SizedBox(height: 8),
                if (_node != null && !_typing) _tools(),
                AnimatedSize(duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic, child: _panelView()),
                AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _fb == null ? const SizedBox.shrink() : _feedback(_fb!)),
                if (_hints && !_ended) _hintChips(),
                const SizedBox(height: 8),
                _composer(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

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

  Widget _tools() {
    final n = _node!;
    final onLine = _lineSpeaker == n.speaker && _line == _t(n.text);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in Speed.values) _pill(s == Speed.slow ? Icons.slow_motion_video_rounded : Icons.volume_up_rounded, tr(_lang, s.name), () => _speak(s)),
        if (onLine) _pill(Icons.blur_on_rounded, 'X-Ray', () => _togglePanel(_Panel.xray), on: _panel == _Panel.xray),
        if (_lineFa != null) _pill(Icons.translate_rounded, langOf(_lang).native, () => _togglePanel(_Panel.translate), on: _panel == _Panel.translate),
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

  Widget _panelView() {
    final n = _node;
    if (n == null || _panel == _Panel.none) return const SizedBox(width: double.infinity);
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
        final x = ConnectedSpeech.of(n);
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
        return box(SizedBox(width: double.infinity, child: Text(_lineFa ?? '', textDirection: _node!.translations.containsKey(_lang) ? dirOf(_lang) : TextDirection.rtl, style: BL.fa(14.5, color: Colors.white70))));
      case _Panel.culture:
        return box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🇬🇧  CULTURE NOTE', style: label),
              const SizedBox(height: 4),
              Text(n.cultureNote!.en, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
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

  Widget _feedback(_Feedback f) {
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
          InkWell(onTap: () => setState(() => _fb = null), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _hintChips() => Padding(
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
                onTap: () => _send(b.suggestion),
                child: Container(
                  width: 210,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x88E9B949))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(b.suggestion, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(b.suggestionFa, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: BL.fa(11, color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
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
      if (SpeechInput.sttSupported) ...[
        _round(_listening ? Icons.graphic_eq_rounded : Icons.mic_rounded, _listening ? BL.red : Colors.white.withValues(alpha: .1), _ended ? null : _mic, tip: 'Speak'),
        const SizedBox(width: 8),
      ],
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

