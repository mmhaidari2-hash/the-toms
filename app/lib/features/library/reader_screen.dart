import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/models/dialogue_node.dart';
import '../../core/platform/voice.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import 'library_data.dart';
import 'library_gate.dart';
import '../grammar/grammar_data.dart';

/// Reader: narrator reads aloud with sentence highlighting; tap a word for Persian (+ save it);
/// translation toggle; speed; a short quiz at the end of each chapter (XP, finished badge).
class ReaderScreen extends ConsumerWidget {
  final String bookId;
  final int chapter;
  const ReaderScreen({super.key, required this.bookId, this.chapter = 0});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    if (books == null || topics == null || content == null) return const NavLoading();
    final b = books.where((x) => x.id == bookId).firstOrNull;
    if (b == null) {
      return Scaffold(backgroundColor: BL.cream, body: Center(child: TextButton(onPressed: () => context.go('/library'), child: const Text('Book not found — back to the Library'))));
    }
    // Strict lock: a deep link to a book on a shut shelf never opens the reader.
    final gate = LibraryGate(ref.read(progressProvider.notifier), content, topics, books, unlockAll: ref.read(progressProvider).unlockAll);
    if (!gate.shelfOpen(b.level)) return BookLocked(book: b);
    return _Reader(key: ValueKey('reader-${b.id}-$chapter'), book: b, chapter: chapter.clamp(0, b.chapters.length - 1));
  }
}

/// Shown instead of the reader for a book whose shelf isn't open yet.
class BookLocked extends StatelessWidget {
  final Book book;
  const BookLocked({super.key, required this.book});
  @override
  Widget build(BuildContext context) {
    final (en, fa) = LibraryGate.why(book.level);
    return Scaffold(
      key: const ValueKey('book-locked'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: NavBack(fallback: '/library'))),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_rounded, size: 56, color: BL.muted),
                  const SizedBox(height: 14),
                  Text(book.title, textAlign: TextAlign.center, style: BL.display(24)),
                  Text(book.titleFa, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: BL.fa(14, color: BL.muted)),
                  const SizedBox(height: 16),
                  Text('This book is on the ${book.level} shelf, which is still locked', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: BL.ink)),
                  const SizedBox(height: 10),
                  Text(en, key: const ValueKey('book-locked-why'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: BL.ink, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(fa, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: BL.fa(13, color: BL.muted)),
                  const SizedBox(height: 22),
                  TextButton(key: const ValueKey('book-locked-library'), onPressed: () => context.go('/library'), child: const Text('Back to the Library')),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Reader extends ConsumerStatefulWidget {
  final Book book;
  final int chapter;
  const _Reader({super.key, required this.book, required this.chapter});
  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

enum _Mode { read, quiz, done }

class _ReaderState extends ConsumerState<_Reader> {
  static const speeds = [0.75, 0.9, 1.0, 1.15];
  late int ch = widget.chapter;
  int cur = -1; // sentence being read / last tapped
  bool playing = false;
  int _run = 0;
  _Mode mode = _Mode.read;
  final _keys = <int, GlobalKey>{};
  final _taps = <TapGestureRecognizer>[];
  // quiz
  int qi = 0, right = 0;
  int? picked;
  List<List<int>> order = [];
  XpAward? award;

  BookChapter get c => widget.book.chapters[ch];
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  bool get showFa => ctrl.pref('libFa', 'off') == 'on';
  double get rate => double.tryParse(ctrl.pref('libRate', '0.9')) ?? .9;

  @override
  void dispose() {
    _run++;
    Voice.stop();
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  void _stop() {
    _run++;
    Voice.stop();
    if (mounted) setState(() => playing = false);
  }

  Future<void> _play([int? from]) async {
    final run = ++_run;
    Voice.stop();
    setState(() => playing = true);
    for (var i = from ?? max(cur, 0); i < c.sentences.length; i++) {
      if (run != _run || !mounted) return;
      setState(() => cur = i);
      final ctx = _keys[i]?.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: .3, duration: const Duration(milliseconds: 350));
      final s = c.sentences[i];
      final t0 = DateTime.now();
      await Voice.say(s.voice, s.en, rate: rate);
      // No clip (or audio blocked): give a reading pause so highlighting still flows.
      final min = Duration(milliseconds: (s.en.split(' ').length * 330 / rate).round());
      final left = min - DateTime.now().difference(t0);
      if (!Voice.has(s.voice, s.en) && left > Duration.zero) await Future.delayed(left);
      if (run != _run || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (run == _run && mounted) setState(() => playing = false);
  }

  void _word(String surface, String key) {
    final fa = widget.book.gloss[key] ?? '';
    final saved = ref.read(progressProvider).leitnerBox.containsKey(key);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BL.cream,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          key: const ValueKey('word-sheet'),
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(key.contains(' ') ? key : surface.replaceAll(RegExp(r"^\W+|\W+$"), ''), style: BL.display(28)),
            const SizedBox(height: 6),
            Text(fa.isEmpty ? '—' : fa, key: const ValueKey('word-fa'), textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: BL.fa(20, color: BL.ink, w: FontWeight.w600)),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('word-save'),
              onPressed: saved || fa.isEmpty || fa.startsWith('اسم:')
                  ? null
                  : () {
                      ctrl.seeWords([NewWord(key, fa)]);
                      Navigator.of(sheet).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), content: Text('“$key” saved to your words · به واژه‌هایت اضافه شد')));
                    },
              style: FilledButton.styleFrom(backgroundColor: BL.green, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: Icon(saved ? Icons.check_rounded : Icons.bookmark_add_rounded),
              label: Text(saved ? 'Already in your words' : 'Save to my words', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sentence(int i) {
    final s = c.sentences[i];
    final on = i == cur;
    final spans = <InlineSpan>[];
    for (final (txt, key) in s.segs) {
      if (key.isEmpty) {
        spans.add(TextSpan(text: txt));
      } else {
        final r = TapGestureRecognizer()..onTap = () => _word(txt, key);
        _taps.add(r);
        spans.add(TextSpan(text: txt, recognizer: r));
      }
    }
    return GestureDetector(
      key: _keys.putIfAbsent(i, () => GlobalKey()),
      onLongPress: () => _play(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: on ? BL.gold.withValues(alpha: .32) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (s.spName != null) Text(s.spName!.toUpperCase(), key: ValueKey('spk-$i'), style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: BL.red)),
          Text.rich(TextSpan(children: spans), key: ValueKey('sent-$i'), style: BL.display(19, w: FontWeight.w400).copyWith(height: 1.5, letterSpacing: 0)),
          if (showFa) Text(s.fa, key: ValueKey('fa-$i'), textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: BL.fa(14.5, color: BL.muted)),
        ]),
      ),
    );
  }

  void _startQuiz() {
    _stop();
    final rnd = Random(widget.book.id.hashCode + ch);
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
        final a = ctrl.saveChapter(widget.book.id, ch, pct, widget.book.chapters.length);
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
    final b = widget.book;
    if (mode == _Mode.done && award != null) {
      final pct = (right * 100 / max(c.quiz.length, 1)).round();
      final pass = pct >= Library.pass, last = ch + 1 >= b.chapters.length;
      final finished = ctrl.bookDone(b.id) && last && pass;
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
          onRetry: pass ? null : () => setState(() => mode = _Mode.read),
          onContinue: () {
            if (pass && !last) {
              context.pushReplacement('/read/${b.id}?ch=${ch + 1}');
            } else {
              goBack(context, '/library');
            }
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F1),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 4),
          child: Row(children: [
            const NavBack(fallback: '/library'),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
                Text('Chapter ${ch + 1} of ${b.chapters.length}  ·  ${b.level}', style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
            IconButton(
              key: const ValueKey('toggle-fa'),
              tooltip: 'Persian translation',
              onPressed: () => ctrl.setPref('libFa', showFa ? 'off' : 'on'),
              icon: Icon(Icons.translate_rounded, color: showFa ? BL.red : BL.muted),
            ),
          ]),
        ),
        Expanded(child: mode == _Mode.quiz ? _quiz() : _text()),
        if (mode == _Mode.read) _player(pad.bottom),
      ]),
    );
  }

  Widget _text() => ListView(
        key: const ValueKey('reader-text'),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Text(c.title, style: BL.display(26)),
          Text(c.titleFa, textDirection: TextDirection.rtl, style: BL.fa(14)),
          const SizedBox(height: 4),
          const Text('Tap a word for its meaning · برای معنی روی هر کلمه بزن', style: TextStyle(fontSize: 11.5, color: BL.muted)),
          const SizedBox(height: 14),
          for (var i = 0; i < c.sentences.length; i++) _sentence(i),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('start-quiz'),
            onPressed: _startQuiz,
            style: FilledButton.styleFrom(backgroundColor: BL.navy, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            icon: const Icon(Icons.quiz_rounded),
            label: Text('Chapter quiz · ${c.quiz.length} questions', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      );

  Widget _player(double bottom) => Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 8),
        decoration: BoxDecoration(color: BL.paper, boxShadow: BL.shadow(.12)),
        child: Row(children: [
          PopupMenuButton<double>(
            key: const ValueKey('speed'),
            tooltip: 'Reading speed',
            initialValue: rate,
            onSelected: (v) => ctrl.setPref('libRate', '$v'),
            itemBuilder: (_) => [for (final s in speeds) PopupMenuItem(value: s, child: Text('$s×'))],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: BL.mist, borderRadius: BorderRadius.circular(12)),
              child: Text('$rate×', style: const TextStyle(fontWeight: FontWeight.w800, color: BL.ink)),
            ),
          ),
          const Spacer(),
          IconButton(key: const ValueKey('prev'), onPressed: cur <= 0 ? null : () => _play(cur - 1), icon: const Icon(Icons.skip_previous_rounded)),
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
          IconButton(key: const ValueKey('next'), onPressed: cur >= c.sentences.length - 1 ? null : () => _play(cur + 1), icon: const Icon(Icons.skip_next_rounded)),
          const Spacer(),
          const SizedBox(width: 52),
        ]),
      );

  Widget _quiz() {
    final q = c.quiz[qi];
    return ListView(
      key: const ValueKey('reader-quiz'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('QUESTION ${qi + 1} OF ${c.quiz.length}', style: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
        const SizedBox(height: 8),
        Text(q.q, key: const ValueKey('quiz-q'), style: BL.display(24)),
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
                      Expanded(child: Text(q.options[o], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: BL.ink))),
                      if (picked != null && isAns) const Icon(Icons.check_circle_rounded, color: BL.green),
                      if (isPicked && !isAns) const Icon(Icons.cancel_rounded, color: BL.red),
                    ]),
                  ),
                ),
              ),
            );
          }),
        TextButton(onPressed: () => setState(() => mode = _Mode.read), child: const Text('Back to the text · برگشت به متن')),
      ],
    );
  }
}
