import 'package:british_life/core/i18n/helper_text.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/device_tts.dart';
import '../../core/platform/voice.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import 'library_data.dart';
import 'library_gate.dart';
import 'reading_state.dart';
import 'word_card.dart';
import '../grammar/grammar_data.dart';

/// The reader. Any book opens (a book above the learner's level shows a notice, never a lock).
/// Resumes at the exact sentence; narrator reads the chapter or the whole book with sentence + word highlight
/// (recorded British clips where they exist, otherwise the device's own voice, labelled); every word opens a
/// dictionary card (Persian, part of speech, English definition, example, pronunciation, Leitner); long-press
/// a sentence for its Persian; font size, line spacing, light/sepia/dark; chapter list; quiz per chapter.
class ReaderScreen extends ConsumerWidget {
  final String bookId;
  /// Null = resume where the learner left off.
  final int? chapter;
  const ReaderScreen({super.key, required this.bookId, this.chapter});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    if (books == null || topics == null || content == null) return const NavLoading();
    final b = books.where((x) => x.id == bookId).firstOrNull;
    if (b == null) {
      return Scaffold(
        backgroundColor: BL.cream,
        body: Center(child: TextButton(onPressed: () => context.go('/library'), child: const Text('Book not found — back to the Library'))),
      );
    }
    final ctrl = ref.read(progressProvider.notifier);
    final gate = LibraryGate(ctrl, content, topics, books, unlockAll: ref.read(progressProvider).gatesOpen);
    final pos = ctrl.readPos(b.id);
    final ch = (chapter ?? pos?.$1 ?? 0).clamp(0, b.chapters.length - 1);
    final start = pos != null && pos.$1 == ch ? pos.$2.clamp(0, b.chapters[ch].sentences.length - 1) : 0;
    return _Reader(key: ValueKey('reader-${b.id}-$ch'), book: b, chapter: ch, start: start, above: gate.aboveLevel(b));
  }
}

class _Reader extends ConsumerStatefulWidget {
  final Book book;
  final int chapter, start;
  final bool above;
  const _Reader({super.key, required this.book, required this.chapter, required this.start, required this.above});
  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

enum _Mode { read, quiz, done }

class _ReaderState extends ConsumerState<_Reader> {
  static const speeds = [0.75, 0.9, 1.0, 1.15];
  late int ch = widget.chapter;
  late int cur = widget.start > 0 ? widget.start : -1; // sentence being read / selected
  int wordIdx = -1;
  bool playing = false, aboveHidden = false;
  int _run = 0;
  Timer? _karaoke;
  _Mode mode = _Mode.read;
  final _keys = <int, GlobalKey>{};
  final _taps = <TapGestureRecognizer>[];
  final _revealed = <int>{};
  final _scroll = ScrollController();
  bool? _deviceOk;
  /// Shown once at the start of a book; decided when the reader opens so the page never jumps while reading.
  late final bool _fresh = widget.chapter == 0 && widget.start == 0 && ref.read(progressProvider.notifier).readMax(widget.book.id) <= 1;
  int qi = 0, right = 0;
  int? picked;
  List<List<int>> order = [];
  XpAward? award;

  Book get b => widget.book;
  BookChapter get c => b.chapters[ch];
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  bool get showFa => ctrl.pref('libFa', 'off') == 'on';
  bool get wholeBook => ctrl.pref('libCont', 'on') == 'on';
  double get rate => double.tryParse(ctrl.pref('libRate', '0.9')) ?? .9;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ctrl.saveReadPos(b, ch, max(widget.start, 0));
      if (widget.start > 0) _reveal(widget.start, animate: false);
    });
  }

  @override
  void dispose() {
    _run++;
    _karaoke?.cancel();
    _stopAudio();
    for (final t in _taps) {
      t.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _stopAudio() {
    Voice.stop();
    if (b.deviceVoice) DeviceTts.stop();
  }

  void _reveal(int i, {bool animate = true}) {
    final ctx = _keys[i]?.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx, alignment: .3, duration: animate ? const Duration(milliseconds: 350) : Duration.zero);
    }
  }

  void _stop() {
    _run++;
    _karaoke?.cancel();
    _stopAudio();
    if (mounted) {
      setState(() {
        playing = false;
        wordIdx = -1;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3), content: Text(hl(msg))));
  }

  /// One sentence aloud: the recorded clip, or the device voice for books without clips.
  Future<bool> _say(BookSentence s) async {
    if (!b.deviceVoice) return Voice.say(s.voice, s.en, rate: rate);
    _deviceOk ??= await DeviceTts.available;
    if (_deviceOk != true) {
      _snack('This book has no recorded voice and this device has no text-to-speech voice · این کتاب صدای ضبط‌شده ندارد و این دستگاه صدای متن‌خوان ندارد');
      return false;
    }
    return DeviceTts.speak(s.en, rate: rate);
  }

  /// Plays from sentence [from]. [once] = just that sentence (replay). Otherwise the narrator continues to the
  /// end of the chapter, or through the whole book when "whole book" is on.
  Future<void> _play([int? from, bool once = false]) async {
    final run = ++_run;
    _karaoke?.cancel();
    _stopAudio();
    setState(() {
      playing = true;
      wordIdx = -1;
    });
    var i = from ?? max(cur, 0);
    while (true) {
      if (i >= c.sentences.length) {
        if (once || !wholeBook || ch + 1 >= b.chapters.length) break;
        setState(() {
          ch++;
          i = 0;
          _keys.clear();
          _revealed.clear();
        });
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (run != _run || !mounted) return;
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
      if (run != _run || !mounted) return;
      setState(() {
        cur = i;
        wordIdx = 0;
      });
      ctrl.saveReadPos(b, ch, i);
      _reveal(i);
      final s = c.sentences[i];
      final words = s.en.trim().isEmpty ? <String>[] : s.en.split(RegExp(r'\s+'));
      // Follow-along highlight from estimated timing (no extra audio data needed).
      final msPer = (330 / rate).round().clamp(160, 700);
      _karaoke = Timer.periodic(Duration(milliseconds: msPer), (timer) {
        if (run != _run || !mounted || timer.tick >= words.length) {
          timer.cancel();
          return;
        }
        setState(() => wordIdx = timer.tick);
      });
      bool ok;
      try {
        ok = await _say(s);
      } finally {
        if (run == _run) _karaoke?.cancel();
      }
      if (!ok || once) break;
      if (run != _run || !mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      i++;
    }
    if (run == _run && mounted) {
      setState(() {
        playing = false;
        wordIdx = -1;
      });
    }
  }

  void _word(String surface, String key, int i) {
    setState(() => cur = i);
    ctrl.saveReadPos(b, ch, i);
    showWordCard(context, ref, book: b, surface: surface, key: key, sentence: c.sentences[i].en, onHearSentence: () => _play(i, true));
  }

  /// Saves the first visible sentence when the learner stops scrolling (exact resume point).
  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollEndNotification || playing || mode != _Mode.read) return false;
    final view = n.context?.findRenderObject();
    if (view is! RenderBox) return false;
    final top = view.localToGlobal(Offset.zero).dy;
    for (var i = 0; i < c.sentences.length; i++) {
      final box = _keys[i]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.localToGlobal(Offset(0, box.size.height)).dy > top + 8) {
        ctrl.saveReadPos(b, ch, i);
        break;
      }
    }
    return false;
  }

  Widget _karaokeLine(String en, int hi, TextStyle base, ReaderTheme th, {Key? key}) {
    final words = en.trim().isEmpty ? const <String>[] : en.split(RegExp(r'\s+'));
    return Wrap(
      key: key,
      spacing: base.fontSize! * .27,
      runSpacing: 2,
      children: [
        for (var w = 0; w < words.length; w++)
          Text(
            hl(words[w]),
            style: w == hi
                ? base.copyWith(color: th.isDark ? BL.gold : BL.red, fontWeight: FontWeight.w800, backgroundColor: BL.gold.withValues(alpha: th.isDark ? .18 : .45))
                : w < hi
                    ? base.copyWith(color: th.muted)
                    : base,
          ),
      ],
    );
  }

  Widget _sentence(int i, ReaderTheme th) {
    final s = c.sentences[i];
    final on = i == cur;
    final base = BL.display(ctrl.readerFont, w: FontWeight.w400).copyWith(height: ctrl.readerLine, letterSpacing: 0, color: th.text);
    final spans = <InlineSpan>[];
    for (final (txt, key) in s.segs) {
      if (key.isEmpty) {
        spans.add(TextSpan(text: hl(txt)));
      } else {
        final r = TapGestureRecognizer()..onTap = () => _word(txt, key, i);
        _taps.add(r);
        spans.add(TextSpan(text: hl(txt), recognizer: r));
      }
    }
    final fa = showFa || _revealed.contains(i);
    return GestureDetector(
      key: _keys.putIfAbsent(i, () => GlobalKey()),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => cur = i),
      onLongPress: () => setState(() {
        cur = i;
        _revealed.contains(i) ? _revealed.remove(i) : _revealed.add(i);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: on ? th.highlight : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (s.spName != null)
            Text(hl(s.spName!.toUpperCase()), key: ValueKey('spk-$i'), style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: th.isDark ? BL.gold : BL.red)),
          on && playing ? _karaokeLine(s.en, wordIdx, base, th, key: ValueKey('sent-$i')) : Text.rich(TextSpan(children: spans), key: ValueKey('sent-$i'), style: base),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: fa
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(hl(s.fa), key: ValueKey('fa-$i'), textDirection: helperDir, textAlign: helperRtl ? TextAlign.right : TextAlign.left, style: BL.fa(ctrl.readerFont * .76, color: th.muted)),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (on && !playing)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(spacing: 4, children: [
                _chip(th, Icons.replay_rounded, 'Replay · تکرار', () => _play(i, true), const ValueKey('sent-replay')),
                _chip(th, Icons.translate_rounded, _revealed.contains(i) || showFa ? 'Hide Persian · پنهان' : 'Persian · فارسی', () => setState(() => _revealed.contains(i) ? _revealed.remove(i) : _revealed.add(i)), const ValueKey('sent-fa')),
                _chip(th, Icons.play_arrow_rounded, 'Read from here · از اینجا بخوان', () => _play(i), const ValueKey('sent-from')),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _chip(ReaderTheme th, IconData icon, String label, VoidCallback onTap, Key key) => ActionChip(
        key: key,
        visualDensity: VisualDensity.compact,
        backgroundColor: th.bar,
        side: BorderSide(color: th.muted.withValues(alpha: .3)),
        avatar: Icon(icon, size: 16, color: th.text),
        label: Text(hl(label), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: th.text)),
        onPressed: onTap,
      );

  void _startQuiz() {
    _stop();
    final rnd = Random(b.id.hashCode + ch);
    order = [for (final q in c.quiz) (List.generate(q.options.length, (i) => i)..shuffle(rnd))];
    setState(() {
      mode = _Mode.quiz;
      qi = 0;
      right = 0;
      picked = null;
    });
  }

  void _pick(int opt) {
    if (picked != null) return;
    final ok = opt == c.quiz[qi].answer;
    setState(() {
      picked = opt;
      if (ok) right++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (qi + 1 < c.quiz.length) {
        setState(() {
          qi++;
          picked = null;
        });
      } else {
        final pct = (right * 100 / c.quiz.length).round();
        final a = ctrl.saveChapter(b.id, ch, pct, b.chapters.length);
        setState(() {
          award = a;
          mode = _Mode.done;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final pad = MediaQuery.paddingOf(context);
    final th = ctrl.readerTheme;
    if (mode == _Mode.done && award != null) {
      final pct = (right * 100 / max(c.quiz.length, 1)).round();
      final pass = pct >= Library.pass, last = ch + 1 >= b.chapters.length;
      final finished = ctrl.bookDone(b.id) && last && pass;
      final saved = savedFrom(ref, b);
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('reader-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: false,
          right: right,
          total: c.quiz.length,
          title: pass ? (finished ? 'Book finished!' : 'Chapter complete!') : 'Good effort!',
          titleFa: pass ? (finished ? 'کتاب تمام شد! نشان «تمامش کردم» برای توست.' : 'آفرین! فصل بعد آماده است.') : 'فصل را دوباره بخوان و دوباره امتحان کن.',
          extra: finished
              ? Padding(
                  key: const ValueKey('words-learned'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(hl('Words from this book in your Leitner box: $saved · واژه‌های این کتاب در جعبهٔ لایتنر تو: $saved'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink)),
                )
              : null,
          onRetry: pass ? null : () => setState(() => mode = _Mode.read),
          onNext: pass && !last ? () => context.pushReplacement('/read/${b.id}?ch=${ch + 1}') : null,
          nextLabel: 'Next chapter',
          onContinue: () => goBack(context, '/library'),
        ),
      );
    }
    final pctRead = ctrl.readPercent(b);
    return Scaffold(
      backgroundColor: th.page,
      body: Column(children: [
        Container(
          color: th.page,
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 6, 0),
          child: Column(children: [
            Row(children: [
              const NavBack(fallback: '/library'),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hl(b.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: th.text)),
                  Text(hl('Chapter ${ch + 1} of ${b.chapters.length}  ·  ${b.level}'), key: const ValueKey('reader-where'), style: TextStyle(fontSize: 12, color: th.muted, fontWeight: FontWeight.w600)),
                ]),
              ),
              IconButton(key: const ValueKey('toc'), tooltip: 'Chapters', onPressed: _toc, icon: Icon(Icons.format_list_bulleted_rounded, color: th.muted)),
              IconButton(key: const ValueKey('reader-settings'), tooltip: 'Reading settings', onPressed: _settings, icon: Icon(Icons.text_fields_rounded, color: th.muted)),
              IconButton(
                key: const ValueKey('toggle-fa'),
                tooltip: 'Persian translation',
                onPressed: () => ctrl.setPref('libFa', showFa ? 'off' : 'on'),
                icon: Icon(Icons.translate_rounded, color: showFa ? (th.isDark ? BL.gold : BL.red) : th.muted),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(key: const ValueKey('reader-progress'), value: pctRead / 100, minHeight: 4, backgroundColor: th.muted.withValues(alpha: .18), color: BL.green),
                ),
              ),
              const SizedBox(width: 8),
              Text(hl('$pctRead%'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: th.muted)),
              const SizedBox(width: 10),
            ]),
            const SizedBox(height: 4),
          ]),
        ),
        Expanded(child: mode == _Mode.quiz ? _quiz(th) : NotificationListener<ScrollNotification>(onNotification: _onScroll, child: _text(th))),
        if (mode == _Mode.read) _player(pad.bottom, th),
      ]),
    );
  }

  Widget _text(ReaderTheme th) {
    final fresh = _fresh && ch == 0;
    return ListView(
      key: const ValueKey('reader-text'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        if (widget.above && !aboveHidden) _aboveBanner(),
        if (b.deviceVoice)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(key: const ValueKey('device-voice-label'), children: [
              Icon(Icons.smartphone_rounded, size: 15, color: th.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(hl('Read aloud by your device\'s voice — not a recorded British voice · خوانش با صدای دستگاه؛ صدای ضبط‌شدهٔ بریتانیایی نیست'), style: TextStyle(fontSize: 11.5, color: th.muted, fontWeight: FontWeight.w600))),
            ]),
          ),
        if (fresh) NewWordsCard(book: b, dark: th.isDark),
        Text(hl(c.title), style: BL.display(26, color: th.text)),
        Text(hl(c.titleFa), textDirection: helperDir, style: BL.fa(14, color: th.muted)),
        const SizedBox(height: 4),
        Text(hl('Tap a word for its meaning · long-press a sentence for Persian · برای معنی روی کلمه بزن · برای ترجمه جمله را نگه دار'), style: TextStyle(fontSize: 11.5, color: th.muted)),
        const SizedBox(height: 14),
        for (var i = 0; i < c.sentences.length; i++) _sentence(i, th),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('start-quiz'),
          onPressed: _startQuiz,
          style: FilledButton.styleFrom(backgroundColor: BL.navy, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          icon: const Icon(Icons.quiz_rounded),
          label: Text(hl('Chapter quiz · ${c.quiz.length} questions'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _aboveBanner() {
    final (en, fa) = LibraryGate.aboveNotice(b.level);
    return Container(
      key: const ValueKey('above-level'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: BL.gold.withValues(alpha: .22), borderRadius: BorderRadius.circular(14), border: Border.all(color: BL.gold)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.trending_up_rounded, color: BL.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(hl(en), style: const TextStyle(fontSize: 13, height: 1.35, color: BL.ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(hl(fa), textDirection: helperDir, style: BL.fa(12.5, color: BL.ink)),
          ]),
        ),
        IconButton(key: const ValueKey('above-level-close'), tooltip: 'Hide', onPressed: () => setState(() => aboveHidden = true), icon: const Icon(Icons.close_rounded, size: 18)),
      ]),
    );
  }

  void _toc() {
    _stop();
    final th = ctrl.readerTheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: th.bar,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: ListView(key: const ValueKey('toc-sheet'), shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            Text(hl('Contents · فهرست'), style: BL.display(22, color: th.text)),
            const SizedBox(height: 8),
            for (var i = 0; i < b.chapters.length; i++)
              ListTile(
                key: ValueKey('toc-$i'),
                selected: i == ch,
                selectedTileColor: th.highlight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(radius: 14, backgroundColor: i == ch ? BL.red : th.muted.withValues(alpha: .2), child: Text(hl('${i + 1}'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: i == ch ? Colors.white : th.text))),
                title: Text(hl(b.chapters[i].title), style: TextStyle(fontWeight: FontWeight.w700, color: th.text)),
                subtitle: Text(hl(b.chapters[i].titleFa), textDirection: helperDir, style: BL.fa(12, color: th.muted)),
                trailing: Builder(builder: (_) {
                  final s = ctrl.readScore(b.id, i);
                  if (s == null) return Icon(Icons.chevron_right_rounded, color: th.muted);
                  return Text(hl('$s%'), style: TextStyle(fontWeight: FontWeight.w800, color: s >= Library.pass ? BL.green : BL.red));
                }),
                onTap: () {
                  Navigator.of(sheet).pop();
                  if (i != ch) context.pushReplacement('/read/${b.id}?ch=$i');
                },
              ),
          ]),
        ),
      ),
    );
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ctrl.readerTheme.bar,
      showDragHandle: true,
      builder: (_) => const ReaderSettingsSheet(),
    );
  }

  Widget _player(double bottom, ReaderTheme th) => Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 8),
        decoration: BoxDecoration(color: th.bar, boxShadow: BL.shadow(.12)),
        child: Row(children: [
          PopupMenuButton<double>(
            key: const ValueKey('speed'),
            tooltip: 'Reading speed',
            initialValue: rate,
            onSelected: (v) => ctrl.setPref('libRate', '$v'),
            itemBuilder: (_) => [for (final s in speeds) PopupMenuItem(value: s, child: Text(hl('$s×')))],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: th.muted.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
              child: Text(hl('$rate×'), style: TextStyle(fontWeight: FontWeight.w800, color: th.text)),
            ),
          ),
          const Spacer(),
          IconButton(key: const ValueKey('prev'), color: th.text, onPressed: cur <= 0 ? null : () => _play(cur - 1), icon: const Icon(Icons.skip_previous_rounded)),
          SizedBox(
            width: 58,
            height: 58,
            child: FilledButton(
              key: const ValueKey('play'),
              onPressed: () => playing ? _stop() : _play(cur >= c.sentences.length - 1 ? 0 : null),
              style: FilledButton.styleFrom(backgroundColor: BL.red, shape: const CircleBorder(), padding: EdgeInsets.zero),
              child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
            ),
          ),
          IconButton(key: const ValueKey('next'), color: th.text, onPressed: cur >= c.sentences.length - 1 ? null : () => _play(cur + 1), icon: const Icon(Icons.skip_next_rounded)),
          const Spacer(),
          Tooltip(
            message: 'Narrator: whole book or this chapter',
            child: InkWell(
              key: const ValueKey('narrator'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => ctrl.setPref('libCont', wholeBook ? 'off' : 'on'),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(wholeBook ? Icons.menu_book_rounded : Icons.article_rounded, size: 20, color: th.text),
                  Text(hl(wholeBook ? 'Book' : 'Chapter'), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: th.muted)),
                ]),
              ),
            ),
          ),
        ]),
      );

  Widget _quiz(ReaderTheme th) {
    final q = c.quiz[qi];
    return ListView(
      key: const ValueKey('reader-quiz'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(hl('QUESTION ${qi + 1} OF ${c.quiz.length}'), style: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
        const SizedBox(height: 8),
        Text(hl(q.q), key: const ValueKey('quiz-q'), style: BL.display(24, color: th.text)),
        const SizedBox(height: 18),
        for (final o in order[qi])
          Builder(builder: (_) {
            final isAns = o == q.answer, isPicked = o == picked;
            final col = picked == null ? BL.paper : (isAns ? BL.green.withValues(alpha: .14) : (isPicked ? BL.red.withValues(alpha: .12) : BL.paper));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: col,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: picked != null && isAns ? BL.green : BL.mist, width: 1.5)),
                child: InkWell(
                  key: ValueKey('opt-$o'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pick(o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Row(children: [
                      Expanded(child: Text(hl(q.options[o]), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: BL.ink))),
                      if (picked != null && isAns) const Icon(Icons.check_circle_rounded, color: BL.green),
                      if (isPicked && !isAns) const Icon(Icons.cancel_rounded, color: BL.red),
                    ]),
                  ),
                ),
              ),
            );
          }),
        TextButton(onPressed: () => setState(() => mode = _Mode.read), child: Text(hl('Back to the text · برگشت به متن'), style: TextStyle(color: th.text))),
      ],
    );
  }
}

/// Font size, line spacing, page colour, translation and narrator scope.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final th = ctrl.readerTheme;
    final ts = TextStyle(fontWeight: FontWeight.w700, color: th.text);
    return SafeArea(
      child: Padding(
        key: const ValueKey('settings-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(hl('Reading settings · تنظیمات خواندن'), style: BL.display(20, color: th.text)),
          const SizedBox(height: 10),
          Text(hl('Text size · اندازهٔ متن'), style: ts),
          Row(children: [
            Text('A', style: TextStyle(fontSize: 13, color: th.text)),
            Expanded(child: Slider(key: const ValueKey('font-slider'), min: 14, max: 30, divisions: 8, value: ctrl.readerFont, onChanged: (v) => ctrl.setPref('libFont', v.toStringAsFixed(0)))),
            Text('A', style: TextStyle(fontSize: 24, color: th.text)),
          ]),
          Text(hl('Line spacing · فاصلهٔ خطوط'), style: ts),
          Slider(key: const ValueKey('line-slider'), min: 1.2, max: 2.2, divisions: 5, value: ctrl.readerLine, onChanged: (v) => ctrl.setPref('libLine', v.toStringAsFixed(1))),
          Text(hl('Page · صفحه'), style: ts),
          const SizedBox(height: 6),
          Row(children: [
            for (final t in ReaderTheme.all)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    key: ValueKey('theme-${t.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ctrl.setPref('libTheme', t.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: t.page, borderRadius: BorderRadius.circular(14), border: Border.all(color: th.id == t.id ? BL.red : t.muted.withValues(alpha: .4), width: th.id == t.id ? 2 : 1)),
                      child: Column(children: [
                        Text('Aa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
                        Text(hl('${t.name} · ${t.nameFa}'), style: TextStyle(fontSize: 11, color: t.muted, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('settings-fa'),
            contentPadding: EdgeInsets.zero,
            title: Text(hl('Show Persian under every sentence · ترجمهٔ فارسی زیر همهٔ جمله‌ها'), style: ts),
            value: ctrl.pref('libFa', 'off') == 'on',
            onChanged: (v) => ctrl.setPref('libFa', v ? 'on' : 'off'),
          ),
          SwitchListTile(
            key: const ValueKey('settings-cont'),
            contentPadding: EdgeInsets.zero,
            title: Text(hl('Narrator reads the whole book · راوی کل کتاب را بخواند'), style: ts),
            value: ctrl.pref('libCont', 'on') == 'on',
            onChanged: (v) => ctrl.setPref('libCont', v ? 'on' : 'off'),
          ),
        ]),
      ),
    );
  }
}
