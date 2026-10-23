import '../../core/i18n/you.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import '../shared/nav.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/models/dialogue_node.dart';
import '../../core/models/place.dart';
import '../../core/platform/voice.dart';
import '../place/place_screen.dart' show hitTest;
import '../motivation/motivation_widgets.dart';
import '../shared/widgets.dart';

sealed class Item {
  const Item();
}

class ListenPick extends Item {
  final String word;
  final List<String> options;
  final bool review;
  const ListenPick(this.word, this.options, {this.review = false});
}

class FillGap extends Item {
  final String before, after, answer, fa;
  final List<String> options;
  const FillGap(this.before, this.after, this.answer, this.options, this.fa);
}

class BuildSentence extends Item {
  final List<String> answer, shuffled;
  final String fa;
  const BuildSentence(this.answer, this.shuffled, this.fa);
}

class TapObject extends Item {
  final Place place;
  final Hotspot target;
  final String label;
  const TapObject(this.place, this.target, this.label);
}

/// Builds a practice set from a lesson (or a whole unit for the checkpoint). Deterministic per id.
List<Item> buildPractice(ContentBundle c, String id, {List<NewWord> review = const [], String name = ''}) {
  final course = c.course;
  final unit = course.unit(id);
  final lessons = unit?.lessons ?? [course.lesson(id)!];
  final rnd = Random(id.hashCode);
  final words = {for (final l in lessons) for (final w in l.words) w.word.toLowerCase(): w}.values.where((w) => w.word.length > 1).toList()..shuffle(rnd);
  final pool = {for (final l in course.lessons) for (final w in l.words) w.word}.toList();
  final sugg = <(String, String)>[
    for (final l in lessons)
      for (final sid in l.sceneIds)
        if (c.scenes[sid] != null)
          for (final n in c.scenes[sid]!.nodes.values)
            for (final b in n.branches) (fillYou(b.suggestion, name), fillYouFa(b.suggestionFa, name)),
  ]..shuffle(rnd);
  List<String> opts(String right, Iterable<String> from) {
    final o = from.where((x) => x.toLowerCase() != right.toLowerCase()).toSet().toList()..shuffle(rnd);
    return ([right, ...o.take(2)])..shuffle(rnd);
  }

  final n = unit != null ? 3 : 1; // checkpoint = bigger set
  final out = <Item>[];
  for (final w in words.take(3 * n)) {
    out.add(ListenPick(w.word, opts(w.word, words.map((e) => e.word).followedBy(pool))));
  }
  var fills = 0;
  for (final (s, fa) in sugg) {
    if (fills >= 3 * n) break;
    for (final w in words) {
      final m = RegExp('\\b${RegExp.escape(w.word)}\\b', caseSensitive: false).firstMatch(s);
      if (m == null || w.word.contains(' ') && fills.isOdd) continue;
      out.add(FillGap(s.substring(0, m.start), s.substring(m.end), s.substring(m.start, m.end), opts(s.substring(m.start, m.end), words.map((e) => e.word)), fa));
      fills++;
      break;
    }
  }
  var builds = 0;
  for (final (s, fa) in sugg.reversed) {
    final t = s.split(' ');
    if (t.length < 3 || t.length > 7 || builds >= 2 * n) continue;
    final sh = [...t]..shuffle(rnd);
    if (sh.join(' ') == s) sh.insert(0, sh.removeLast());
    out.add(BuildSentence(t, sh, fa));
    builds++;
  }
  final places = {for (final l in lessons) l.place}.map(c.place).whereType<Place>().where((p) => p.image != null).toList();
  var taps = 0;
  for (final p in places) {
    final spots = p.hotspots.where((h) => h.rect != null && (h.isProp || c.characterOrNull(h.characterId) != null)).toList()..shuffle(rnd);
    for (final h in spots.take(2)) {
      if (taps >= 2 * n) break;
      out.add(TapObject(p, h, h.isProp ? 'the ${h.prop!.word}' : c.character(h.characterId).name));
      taps++;
    }
  }
  out.shuffle(rnd);
  for (final w in review.take(2)) {
    out.add(ListenPick(w.word, opts(w.word, pool), review: true));
  }
  return out;
}

class PracticeScreen extends ConsumerStatefulWidget {
  final String id;
  const PracticeScreen({super.key, required this.id});
  @override
  ConsumerState<PracticeScreen> createState() => _PracticeState();
}

class _PracticeState extends ConsumerState<PracticeScreen> {
  XpAward? _award;
  List<Item>? _items;
  int _i = 0, _right = 0;
  bool? _ok;
  String? _picked;
  final _built = <int>[];

  void _init(ContentBundle c) {
    if (_items != null) return;
    final p = ref.read(progressProvider);
    final mine = {for (final l in (c.course.unit(widget.id)?.lessons ?? [c.course.lesson(widget.id)!])) for (final w in l.words) w.word};
    // Narrative spaced review: the weakest earlier words come back.
    final review = [
      for (final l in c.course.lessons)
        for (final w in l.words)
          if (!mine.contains(w.word) && p.leitnerBox.containsKey(w.word)) w,
    ]..sort((a, b) => (p.leitnerBox[a.word]?.box ?? 1).compareTo(p.leitnerBox[b.word]?.box ?? 1));
    _items = buildPractice(c, widget.id, review: review, name: ref.read(progressProvider.notifier).pref('name'));
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoplay());
  }

  void _autoplay() {
    final it = _items![_i];
    if (it is ListenPick) Voice.say('narrator', it.word);
  }

  void _answer(bool ok, {String? picked, String? say}) {
    if (_ok != null) return;
    ok ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick();
    setState(() {
      _ok = ok;
      _picked = picked;
      if (ok) _right++;
    });
    if (say != null) Voice.say('narrator', say);
  }

  void _next() {
    if (_i + 1 >= _items!.length) {
      final pct = (_right * 100 / _items!.length).round();
      final c = ref.read(contentProvider).value!;
      final award = ref.read(progressProvider.notifier).savePractice(widget.id, pct, storyScenes: c.course.lesson(widget.id)?.sceneIds ?? const []);
      setState(() {
        _award = award;
        _i++;
      });
      return;
    }
    setState(() {
      _i++;
      _ok = null;
      _picked = null;
      _built.clear();
    });
    _autoplay();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contentProvider).value;
    if (c == null) return const NavLoading();
    _init(c);
    final items = _items!;
    final pad = MediaQuery.paddingOf(context);
    final checkpoint = c.course.unit(widget.id) != null;
    return Scaffold(
      backgroundColor: BL.cream,
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, pad.top + 8, 20, pad.bottom + 16),
        child: _i >= items.length
            ? _done(checkpoint)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NavBack(fallback: '/course'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: _i / items.length),
                            duration: const Duration(milliseconds: 400),
                            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: BL.mist, color: BL.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_i + 1}/${items.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (w, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a), child: w)),
                      child: KeyedSubtree(key: ValueKey(_i), child: _item(c, items[_i])),
                    ),
                  ),
                  AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _ok == null ? const SizedBox(height: 0) : _feedback(items[_i])),
                ],
              ),
      ),
    );
  }

  Widget _prompt(String en, String fa) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(en, style: BL.display(24)),
      Text(fa, textDirection: TextDirection.rtl, style: BL.fa(13)),
      const SizedBox(height: 18),
    ],
  );

  Widget _option(String o, String right) {
    final chosen = _picked == o, isRight = o == right;
    final col = _ok == null ? BL.paper : (isRight ? const Color(0xFFDDEFE5) : (chosen ? const Color(0xFFF6EBD9) : BL.paper));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => _answer(o == right, picked: o, say: right),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ok != null && isRight ? BL.green : BL.mist, width: 1.5)),
          child: Text(o, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BL.ink)),
        ),
      ),
    );
  }

  Widget _item(ContentBundle c, Item it) => switch (it) {
    ListenPick() => ListView(
      children: [
        _prompt(it.review ? 'Remember this one?' : 'Listen and pick', it.review ? 'یادته؟ گوش بده و انتخاب کن' : 'گوش بده و کلمه را انتخاب کن'),
        Center(
          child: Pressable(
            onTap: () => Voice.say('narrator', it.word),
            child: const CircleAvatar(radius: 46, backgroundColor: BL.navy, child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 40)),
          ),
        ),
        const SizedBox(height: 22),
        for (final o in it.options) _option(o, it.word),
      ],
    ),
    FillGap() => ListView(
      children: [
        _prompt('Fill the gap', 'جای خالی را پر کن'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(18), boxShadow: BL.shadow()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: BL.ink, height: 1.4),
                  children: [
                    TextSpan(text: it.before),
                    TextSpan(text: _ok == null ? ' ____ ' : it.answer, style: const TextStyle(color: BL.green, fontWeight: FontWeight.w800)),
                    TextSpan(text: it.after),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(it.fa, textDirection: TextDirection.rtl, style: BL.fa(13)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final o in it.options) _option(o, it.answer),
      ],
    ),
    BuildSentence() => ListView(
      children: [
        _prompt('Build the sentence', 'جمله را بساز'),
        Text(it.fa, textDirection: TextDirection.rtl, style: BL.fa(15, color: BL.ink)),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ok == null ? BL.mist : (_ok! ? BL.green : BL.gold), width: 1.5)),
          child: Wrap(spacing: 6, runSpacing: 6, children: [for (final k in _built) _chip(it.shuffled[k], () => _ok == null ? setState(() => _built.remove(k)) : null)]),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var k = 0; k < it.shuffled.length; k++)
              Opacity(
                opacity: _built.contains(k) ? .25 : 1,
                child: _chip(it.shuffled[k], () {
                  if (_ok != null || _built.contains(k)) return;
                  HapticFeedback.selectionClick();
                  setState(() => _built.add(k));
                  if (_built.length == it.shuffled.length) {
                    final s = _built.map((i) => it.shuffled[i]).join(' ');
                    _answer(s == it.answer.join(' '), say: null);
                    Voice.say('me', it.answer.join(' '));
                  }
                }),
              ),
          ],
        ),
      ],
    ),
    TapObject() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _prompt('Tap ${it.label}', 'در نقاشی روی «${it.label}» بزن'),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              var w = box.maxWidth, h = w / it.place.aspect;
              if (h > box.maxHeight) {
                h = box.maxHeight;
                w = h * it.place.aspect;
              }
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final hit = hitTest(it.place.hotspots, d.localPosition.dx / w, d.localPosition.dy / h);
                      _answer(hit == it.target, say: it.target.isProp ? it.target.prop!.word : null);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(it.place.image!, fit: BoxFit.fill),
                          if (_ok != null)
                            Positioned(
                              left: it.target.rect![0] * w,
                              top: it.target.rect![1] * h,
                              width: it.target.rect![2] * w,
                              height: it.target.rect![3] * h,
                              child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.gold, width: 3)))),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  };

  Widget _chip(String t, VoidCallback? onTap) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(14), boxShadow: BL.shadow(.08), border: Border.all(color: BL.mist)),
      child: Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: BL.ink)),
    ),
  );

  Widget _feedback(Item it) {
    final right = switch (it) {
      ListenPick() => it.word,
      FillGap() => it.answer,
      BuildSentence() => it.answer.join(' '),
      TapObject() => it.label,
    };
    return Container(
      key: ValueKey('fb$_i'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(color: _ok! ? const Color(0xFFDDEFE5) : const Color(0xFFF6EBD9), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(_ok! ? Icons.check_circle_rounded : Icons.lightbulb_rounded, color: _ok! ? BL.green : const Color(0xFFB7791F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_ok! ? ['Lovely!', 'Spot on!', 'Brilliant!', 'Well done!'][_i % 4] : 'Nearly! It’s “$right”.', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: BL.ink)),
          ),
          FilledButton(
            onPressed: _next,
            style: FilledButton.styleFrom(backgroundColor: BL.ink, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _done(bool checkpoint) {
    final pct = (_right * 100 / _items!.length).round();
    final pass = pct >= (checkpoint ? 70 : 60);
    final c = ref.read(contentProvider).value!;
    final ctrl = ref.read(progressProvider.notifier);
    final next = ProgressController.nextAfter(c.course, widget.id);
    final canNext = pass && next != null && ctrl.lessonOpen(c.course, next);
    return Celebration(
      key: const ValueKey('practice-celebrate'),
      onNext: canNext ? () => context.go('/lesson/${next.id}') : null,
      nextLabel: 'Next lesson',
      titleFa: pass && !canNext && next != null ? 'آفرین! درس بعدی هنوز قفل است.' : null,
      award: _award ?? const XpAward(),
      pass: pass,
      checkpoint: checkpoint,
      right: _right,
      total: _items!.length,
      onContinue: () => goBack(context, '/course'),
      onRetry: pass
          ? null
          : () => setState(() {
                _i = 0;
                _right = 0;
                _ok = null;
                _award = null;
                _built.clear();
              }),
    );
  }
}
