import 'package:british_life/core/i18n/helper_text.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/platform/voice.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import '../shared/widgets.dart';
import 'grammar_data.dart';
import 'school_screen.dart';

/// One grammar topic: Mrs Ellis explains (voice + Persian) → examples → practice (instant feedback)
/// → mini test (scored, XP; passing opens the next topic) → celebration.
class TopicScreen extends ConsumerWidget {
  final String id;
  const TopicScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(grammarProvider).value;
    final content = ref.watch(contentProvider).value;
    if (topics == null || content == null) return const NavLoading();
    final t = topics.where((x) => x.id == id).firstOrNull;
    if (t == null) return Scaffold(backgroundColor: BL.cream, body: Center(child: TextButton(onPressed: () => context.go('/school'), child: const Text('Topic not found — back to school'))));
    ref.watch(progressProvider);
    final g = GrammarGate(ref.read(progressProvider.notifier), content, topics, unlockAll: ref.read(progressProvider).gatesOpen);
    // Strict lock: a deep link to a locked topic never shows the lesson.
    if (!g.topicOpen(t)) return TopicLocked(topic: t, gate: g);
    return _Topic(key: ValueKey('topic-screen-${t.id}'), topic: t, all: topics, content: content);
  }
}

/// Shown instead of a topic that isn't open yet: why it's locked and the way to open it.
class TopicLocked extends StatelessWidget {
  final GTopic topic;
  final GrammarGate gate;
  const TopicLocked({super.key, required this.topic, required this.gate});
  @override
  Widget build(BuildContext context) {
    final classOpen = gate.classOpen(topic.level);
    final l = gate.of(topic.level), i = l.indexOf(topic);
    final ci = Grammar.classes.indexWhere((c) => c.code == topic.level);
    final prevClass = ci > 0 ? Grammar.classes[ci - 1].code : 'A1';
    final GTopic? next = classOpen ? l.where((x) => gate.topicOpen(x) && !gate.ctrl.grammarPassed(x.id)).firstOrNull : null;
    final (en, fa) = classOpen
        ? ('Pass "${l[i - 1].title}" first. Topics open one by one.', 'اول درس قبلی را با موفقیت تمام کنید؛ درس‌ها به ترتیب باز می‌شوند.')
        : ('Class ${topic.level} opens when you pass Class $prevClass, or reach Level ${Grammar.courseLevel(topic.level)} in the course.', 'کلاس ${topic.level} وقتی باز می‌شود که کلاس $prevClass را تمام کنید یا در دوره به سطح ${Grammar.courseLevel(topic.level)} برسید.');
    return Scaffold(
      key: const ValueKey('topic-locked'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: NavBack(fallback: '/school'))),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_rounded, size: 56, color: BL.muted),
                  const SizedBox(height: 14),
                  Text(hl(topic.title), textAlign: TextAlign.center, style: BL.display(24)),
                  Text(hl(topic.titleFa), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(14, color: BL.muted)),
                  const SizedBox(height: 16),
                  Text('This topic is locked', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BL.ink)),
                  Text(hl('این درس هنوز قفل است'), textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
                  const SizedBox(height: 10),
                  Text(hl(en), key: const ValueKey('topic-locked-why'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: BL.ink, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(hl(fa), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(13, color: BL.muted)),
                  const SizedBox(height: 22),
                  if (next != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('topic-locked-next'),
                        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => context.go('/grammar/${next.id}'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(hl('Go to "${next.title}"'), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  TextButton(
                    key: const ValueKey('topic-locked-school'),
                    onPressed: () => context.go(classOpen ? '/school/${topic.level}' : '/school'),
                    child: Text(hl(classOpen ? 'Back to Class ${topic.level}' : 'Back to the Grammar School')),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Topic extends ConsumerStatefulWidget {
  final GTopic topic;
  final List<GTopic> all;
  final ContentBundle content;
  const _Topic({super.key, required this.topic, required this.all, required this.content});
  @override
  ConsumerState<_Topic> createState() => _TopicState();
}

enum _Stage { learn, practice, test, done }

class _TopicState extends ConsumerState<_Topic> {
  _Stage stage = _Stage.learn;
  int i = 0, right = 0;
  int? speaking;
  int _run = 0;
  XpAward? award;
  GTopic get t => widget.topic;
  List<GItem> get items => stage == _Stage.test ? t.test : t.practice;

  @override
  void dispose() {
    _run++;
    Voice.stop();
    super.dispose();
  }

  Future<void> _say(List<GLine> lines, int offset) async {
    final run = ++_run;
    Voice.stop();
    for (var k = 0; k < lines.length; k++) {
      if (run != _run || !mounted) return;
      setState(() => speaking = offset + k);
      if (!await Voice.say('ellis', lines[k].en)) {
        if (run == _run && mounted) setState(() => speaking = null);
        return;
      }
      if (!Voice.has('ellis', lines[k].en)) await Future.delayed(const Duration(milliseconds: 600));
    }
    if (run == _run && mounted) setState(() => speaking = null);
  }

  void _start(_Stage s) {
    _run++;
    Voice.stop();
    setState(() {
      stage = s;
      i = 0;
      right = 0;
      speaking = null;
    });
  }

  void _answered(bool ok) {
    if (ok) right++;
  }

  void _next() {
    if (i + 1 < items.length) return setState(() => i++);
    if (stage == _Stage.practice) return _start(_Stage.test);
    final pct = (right * 100 / t.test.length).round();
    final a = ref.read(progressProvider.notifier).saveGrammar(t.id, pct);
    setState(() {
      award = a;
      stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    if (stage == _Stage.done && award != null) {
      final pct = (right * 100 / max(t.test.length, 1)).round(), pass = pct >= Grammar.pass;
      final g = GrammarGate(ref.read(progressProvider.notifier), widget.content, widget.all, unlockAll: ref.read(progressProvider).gatesOpen);
      final same = g.of(t.level), idx = same.indexOf(t);
      final next = idx + 1 < same.length ? same[idx + 1] : null;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('grammar-celebrate'),
          award: award!,
          pass: pass,
          checkpoint: false,
          right: right,
          total: t.test.length,
          title: pass ? 'Topic passed!' : 'Nearly there!',
          titleFa: pass ? (next != null ? 'آفرین! موضوع بعدی باز شد: ${next.titleFa}' : 'آفرین! همهٔ موضوع‌های این کلاس را گذراندی.') : 'دوباره تمرین کن و آزمونک را تکرار کن (حداقل ${Grammar.pass}٪).',
          onRetry: pass ? null : () => _start(_Stage.practice),
          onNext: pass && next != null ? () => context.pushReplacement('/grammar/${next.id}') : null,
          nextLabel: 'Next topic',
          onContinue: () => goBack(context, '/school/${t.level}'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: BL.cream,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 6),
          child: Row(children: [
            NavBack(fallback: '/school/${t.level}'),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(t.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
                Text(hl('Class ${t.level} · ${switch (stage) { _Stage.learn => 'Lesson', _Stage.practice => 'Practice ${i + 1}/${items.length}', _ => 'Mini test ${i + 1}/${items.length}' }}'), key: const ValueKey('topic-stage'), style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        if (stage != _Stage.learn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (i + 1) / items.length, minHeight: 6, color: stage == _Stage.test ? BL.red : BL.green, backgroundColor: BL.mist)),
          ),
        Expanded(
          child: stage == _Stage.learn
              ? _learn()
              : ExerciseView(key: ValueKey('ex-${stage.name}-$i'), item: items[i], seed: t.id.hashCode + i * 7 + stage.index, test: stage == _Stage.test, onAnswered: _answered, onNext: _next),
        ),
      ]),
    );
  }

  Widget _line(GLine l, int k, {bool example = false}) {
    final on = speaking == k;
    return GestureDetector(
      onTap: () => _say([l], k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: on ? BL.gold.withValues(alpha: .28) : (example ? BL.paper : chalk),
          borderRadius: BorderRadius.circular(14),
          border: example ? Border.all(color: BL.mist) : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(hl(l.en), style: TextStyle(fontSize: example ? 16 : 15, height: 1.35, fontWeight: example ? FontWeight.w700 : FontWeight.w500, color: example || on ? BL.ink : Colors.white)),
              const SizedBox(height: 3),
              Text(hl(l.fa), textDirection: helperDir, style: BL.fa(12.5, color: example || on ? BL.muted : const Color(0xFFCFE3D6))),
            ]),
          ),
          Icon(on ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 20, color: example || on ? BL.red : BL.gold),
        ]),
      ),
    );
  }

  Widget _learn() {
    final ctrl = ref.read(progressProvider.notifier);
    final lessons = {for (final u in widget.content.course.units) for (final l in u.lessons) l.id: l};
    final rel = [for (final id in t.related) if (lessons[id] != null) lessons[id]!];
    return ListView(
      key: const ValueKey('topic-learn'),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        Row(children: [
          Avatar(widget.content.character('ellis'), size: 44),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(hl(t.title), style: BL.display(21)), Text(hl(t.titleFa), textDirection: helperDir, style: BL.fa(13))])),
          IconButton.filled(
            key: const ValueKey('listen-all'),
            tooltip: 'Listen to Mrs Ellis',
            style: IconButton.styleFrom(backgroundColor: BL.red),
            onPressed: () => speaking != null ? _start(_Stage.learn) : _say(t.teach, 0),
            icon: Icon(speaking != null ? Icons.stop_rounded : Icons.play_arrow_rounded),
          ),
        ]),
        const SizedBox(height: 12),
        for (var k = 0; k < t.teach.length; k++) _line(t.teach[k], k),
        const SizedBox(height: 10),
        const Text('EXAMPLES FROM THE THOMPSONS', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
        const SizedBox(height: 8),
        for (var k = 0; k < t.examples.length; k++) _line(t.examples[k], 100 + k, example: true),
        if (rel.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('SEE IT IN A LESSON', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in rel)
              ActionChip(
                key: ValueKey('related-${l.id}'),
                avatar: Icon(ctrl.lessonOpen(widget.content.course, l) ? Icons.play_circle_outline_rounded : Icons.lock_outline_rounded, size: 18),
                label: Text(hl(l.title), overflow: TextOverflow.ellipsis),
                onPressed: () {
                  if (ctrl.lessonOpen(widget.content.course, l)) {
                    context.push('/lesson/${l.id}');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), content: Text(hl('"${l.title}" unlocks as you go on the course.'))));
                  }
                },
              ),
          ]),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('start-practice'),
          onPressed: () => _start(_Stage.practice),
          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          icon: const Icon(Icons.edit_rounded),
          label: Text(hl('Practise · ${t.practice.length} exercises'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        TextButton(key: const ValueKey('skip-to-test'), onPressed: () => _start(_Stage.test), child: Text(hl('Skip to the mini test (${t.test.length} questions)'))),
      ],
    );
  }
}

/// One exercise: gap-fill, choose, reorder (tap the tiles) or transform (type it). Check → feedback → Next.
class ExerciseView extends StatefulWidget {
  final GItem item;
  final int seed;
  final bool test;
  final void Function(bool ok) onAnswered;
  final VoidCallback onNext;
  const ExerciseView({super.key, required this.item, required this.seed, required this.test, required this.onAnswered, required this.onNext});
  @override
  State<ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  String? pick;
  late final List<String> opts = widget.item.options(widget.seed);
  late final List<String> tiles = widget.item.kind == 'order' ? widget.item.tiles(widget.seed) : const [];
  final placed = <int>[];
  final text = TextEditingController();
  bool? ok;
  GItem get it => widget.item;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String get given => switch (it.kind) { 'order' => [for (final k in placed) tiles[k]].join(' '), 'transform' => text.text, _ => pick ?? '' };
  bool get ready => switch (it.kind) { 'order' => placed.length == tiles.length, 'transform' => text.text.trim().isNotEmpty, _ => pick != null };

  void _check() {
    final r = it.check(given);
    widget.onAnswered(r);
    setState(() => ok = r);
  }

  static const _how = {
    'gap': ('Fill the gap', 'جای خالی را پر کن'),
    'choose': ('Choose the right answer', 'گزینهٔ درست را انتخاب کن'),
    'order': ('Put the words in order', 'کلمه‌ها را مرتب کن'),
    'transform': ('Write the new sentence', 'جملهٔ جدید را بنویس'),
  };

  @override
  Widget build(BuildContext context) {
    final (how, howFa) = _how[it.kind]!;
    final pad = MediaQuery.paddingOf(context);
    final locked = ok != null;
    Widget chip(String s, {required bool on, required VoidCallback? tap, Key? key}) => Material(
          color: on ? BL.navy : BL.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: on ? BL.navy : BL.mist, width: 1.5)),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: tap,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Text(hl(s), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on ? Colors.white : BL.ink))),
          ),
        );
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          children: [
            Text(hl(how.toUpperCase()), style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: widget.test ? BL.red : BL.green)),
            Text(hl(howFa), textDirection: helperDir, style: BL.fa(12)),
            const SizedBox(height: 12),
            if (it.kind == 'gap')
              Text(hl(pick == null ? it.prompt.replaceAll('___', '_____') : it.fill(pick!)), key: const ValueKey('ex-prompt'), style: BL.display(24))
            else if (it.kind != 'order')
              Text(hl(it.prompt), key: const ValueKey('ex-prompt'), style: BL.display(22)),
            const SizedBox(height: 18),
            if (it.kind == 'gap' || it.kind == 'choose')
              for (final o in opts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(width: double.infinity, child: chip(o, key: ValueKey('opt-$o'), on: pick == o, tap: locked ? null : () => setState(() => pick = o))),
                ),
            if (it.kind == 'order') ...[
              Container(
                key: const ValueKey('order-answer'),
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.mist, width: 1.5)),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k in placed) chip(tiles[k], on: true, tap: locked ? null : () => setState(() => placed.remove(k))),
                ]),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var k = 0; k < tiles.length; k++)
                  Opacity(opacity: placed.contains(k) ? .25 : 1, child: chip(tiles[k], key: ValueKey('tile-$k'), on: false, tap: locked || placed.contains(k) ? null : () => setState(() => placed.add(k)))),
              ]),
            ],
            if (it.kind == 'transform')
              TextField(
                key: const ValueKey('ex-input'),
                controller: text,
                enabled: !locked,
                autocorrect: false,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => ready && !locked ? _check() : null,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(hintText: 'Type your answer', filled: true, fillColor: BL.paper, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
            if (locked) ...[
              const SizedBox(height: 16),
              Container(
                key: ValueKey(ok! ? 'feedback-right' : 'feedback-wrong'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: (ok! ? BL.green : BL.red).withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(ok! ? Icons.check_circle_rounded : Icons.info_rounded, color: ok! ? BL.green : BL.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(hl(ok! ? 'Spot on!  عالی!' : 'Not quite.  نه کاملاً.'), style: TextStyle(fontWeight: FontWeight.w800, color: ok! ? BL.green : BL.red)),
                      if (!ok!) Text(hl('Answer: ${it.shownAnswer}'), key: const ValueKey('feedback-answer'), style: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink)),
                    ]),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, pad.bottom + 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('ex-action'),
            onPressed: locked ? widget.onNext : (ready ? _check : null),
            style: FilledButton.styleFrom(backgroundColor: locked ? BL.navy : BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Text(hl(locked ? 'Next' : 'Check'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ),
    ]);
  }
}
