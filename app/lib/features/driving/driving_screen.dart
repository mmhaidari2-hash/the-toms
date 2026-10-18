import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../shared/nav.dart';
import '../library/library_data.dart';
import '../shared/widgets.dart' show locationIcon;
import 'drive_stage.dart';
import 'driving_data.dart';

const seaRed = Color(0xFF8A3B2E), seaBg = Color(0xFFF7F1EA);

/// Driving School at Mick's Motors: instructor dialogues by level (gated like the rest) and the theory test prep.
class DrivingScreen extends ConsumerWidget {
  const DrivingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final es = ref.watch(drivingProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (es == null || topics == null || content == null) return const NavLoading();
    final gate = DriveGate(ctrl, content, topics, es, unlockAll: ref.read(progressProvider).unlockAll);
    final pad = MediaQuery.paddingOf(context);
    final rows = <Widget>[];
    for (final lv in Library.levels) {
      final ls = gate.of(lv.code);
      if (ls.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text('LEVEL ${lv.code}${gate.levelOpen(lv.code) ? '' : ' · LOCKED'}', style: const TextStyle(fontSize: 11.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.muted)),
      ));
      for (final e in ls) {
        rows.add(_Row(e: e, open: gate.levelOpen(e.level), done: ctrl.driveDone(e.id)));
      }
    }
    return Scaffold(
      backgroundColor: seaBg,
      body: ListView(
        key: const ValueKey('drv-list'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Icon(Icons.directions_car_rounded, size: 16, color: BL.muted),
              SizedBox(width: 4),
              Flexible(
                child: Text("DRIVING SCHOOL · MICK'S MOTORS", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.muted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Driving School', style: BL.display(30)),
          Text('انگلیسی برای یادگیری رانندگی در بریتانیا: با مربی، در پمپ بنزین و تعمیرگاه', textDirection: TextDirection.rtl, style: BL.fa(13, color: BL.muted)),
          const SizedBox(height: 12),
          Material(
            color: seaRed,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const ValueKey('drv-theory'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/theory'),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.quiz_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Theory test prep', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Text('Original practice questions · always open · B1+', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white),
                ]),
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

void _locked(BuildContext context, String level) {
  final (en, fa) = DriveGate.why(level);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text('$en\n$fa', key: const ValueKey('drv-locked-snack')),
      ),
    );
}

class _Row extends StatelessWidget {
  final DLesson e;
  final bool open, done;
  const _Row({required this.e, required this.open, required this.done});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('drv-ev-${e.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => open ? context.push('/driving/${e.id}') : _locked(context, e.level),
        child: Opacity(
          opacity: open ? 1 : .5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: seaRed.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
                  child: Icon(e.inCar ? Icons.directions_car_rounded : e.scene == 'garage' ? Icons.car_repair_rounded : locationIcon(e.icon), color: seaRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(e.titleFa, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                      Text(
                        '${e.level} · ${e.inCar ? 'In the car' : 'Out and about'}',
                        style: const TextStyle(color: BL.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (done)
                  Icon(Icons.check_circle_rounded, key: ValueKey('drv-ev-done-${e.id}'), color: const Color(0xFF2E7D5B), size: 20)
                else if (!open)
                  const Icon(Icons.lock_rounded, color: BL.muted, size: 18)
                else
                  const Icon(Icons.chevron_right_rounded, color: BL.muted),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// One driving dialogue: the animated scene (or a real video when one exists) with sound cues and subtitles,
/// the culture note, the lines (voiced), words, and a 3-question quiz.
class DrivingLessonScreen extends ConsumerStatefulWidget {
  final String id;
  static int? seed; // tests fix the option order
  const DrivingLessonScreen({super.key, required this.id});
  @override
  ConsumerState<DrivingLessonScreen> createState() => _EventState();
}

class _EventState extends ConsumerState<DrivingLessonScreen> {
  String? playing;
  int line = -1;
  bool all = false;
  final picks = <int, int>{}; // question -> picked original index
  List<List<int>>? order;
  (int, int, bool)? result; // pct, xp, newBest

  @override
  void dispose() {
    Voice.stop();
    Voice.stopFx();
    super.dispose();
  }

  Future<void> _say(String k, String sp, String t) async {
    Voice.stop();
    if (playing == k) return setState(() => playing = null);
    setState(() => playing = k);
    await Voice.say(sp, t);
    if (mounted && playing == k) setState(() => playing = null);
  }

  Future<void> _playAll(DLesson e) async {
    if (all) {
      Voice.stop();
      Voice.stopFx();
      return setState(() => (all = false, playing = null));
    }
    setState(() => all = true);
    for (final (i, l) in e.lines.indexed) {
      if (!mounted || !all) return;
      setState(() => (playing = 'l$i', line = i));
      if (l.fx != null) {
        Voice.fx(l.fx!); // the cue starts with the line; the voice waits a beat for an engine start or a brake
        if (l.fx != 'indicator') await Future.delayed(const Duration(milliseconds: 700));
      }
      final sw = Stopwatch()..start();
      if (!await Voice.say(l.sp, l.en)) break;
      if (sw.elapsedMilliseconds < 300 && l.ms > 0) await Future.delayed(Duration(milliseconds: l.ms)); // no audio (tests, muted)
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => (all = false, playing = null));
  }

  void _pick(DLesson e, int q, int o) {
    if (picks.containsKey(q) || result != null) return;
    setState(() => picks[q] = o);
    if (picks.length == e.qs.length) {
      final ctrl = ref.read(progressProvider.notifier);
      final old = ctrl.driveScore(e.id);
      final pct = Drive.pct(picks.values.where((v) => v == 0).length);
      final xp = ctrl.saveDrive(e.id, pct);
      setState(() => result = (pct, xp.xp, old == null || pct > old));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final es = ref.watch(drivingProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (es == null || topics == null || content == null) return const NavLoading();
    final e = es.where((x) => x.id == widget.id).firstOrNull;
    final pad = MediaQuery.paddingOf(context);
    if (e == null) return Scaffold(body: Center(child: TextButton(onPressed: () => context.go('/driving'), child: const Text('Not found — back to the Driving School'))));
    final gate = DriveGate(ctrl, content, topics, es, unlockAll: ref.read(progressProvider).unlockAll);
    if (!gate.levelOpen(e.level)) {
      final (en, fa) = DriveGate.why(e.level);
      return Scaffold(
        backgroundColor: seaBg,
        body: Padding(
          padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NavBack(fallback: '/driving'),
              const SizedBox(height: 30),
              const Icon(Icons.lock_rounded, size: 40, color: BL.muted),
              const SizedBox(height: 10),
              Text(e.title, style: BL.display(26)),
              const SizedBox(height: 8),
              Text(en, key: const ValueKey('drv-locked')),
              Text(fa, textDirection: TextDirection.rtl, style: BL.fa(13)),
            ],
          ),
        ),
      );
    }
    order ??= [
      for (final (i, q) in e.qs.indexed) List.generate(q.options.length, (k) => k)..shuffle(Random(DrivingLessonScreen.seed ?? (e.id.hashCode + i + DateTime.now().millisecond))),
    ];
    final fa = ctrl.pref('drvFa', 'off') == 'on';
    return Scaffold(
      backgroundColor: seaBg,
      body: ListView(
        key: const ValueKey('drv-event'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          Row(
            children: [
              const NavBack(fallback: '/driving'),
              const Spacer(),
              FilterChip(
                key: const ValueKey('drv-fa'),
                selected: fa,
                showCheckmark: false,
                label: const Text('فارسی'),
                selectedColor: seaRed,
                labelStyle: TextStyle(color: fa ? Colors.white : BL.ink, fontWeight: FontWeight.w800),
                onSelected: (_) => ctrl.setPref('drvFa', fa ? 'off' : 'on'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(e.title, style: BL.display(28)),
          Text(e.titleFa, textDirection: TextDirection.rtl, style: BL.fa(14)),
          const SizedBox(height: 10),
          DriveStage(key: const ValueKey('drv-stage'), lesson: e, line: line, playing: all, fa: fa),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(e.inCar ? 'In the car with ${e.lines.first.name}' : 'Listen in', style: const TextStyle(fontWeight: FontWeight.w800, color: BL.muted))),
            FilledButton.icon(
              key: const ValueKey('drv-play-all'),
              style: FilledButton.styleFrom(backgroundColor: seaRed),
              onPressed: () => _playAll(e),
              icon: Icon(all ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(all ? 'Stop' : 'Play scene'),
            ),
          ]),
          const SizedBox(height: 10),
          Text(e.note, key: const ValueKey('drv-note'), style: const TextStyle(fontSize: 14.5, height: 1.45)),
          if (fa) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.noteFa, textDirection: TextDirection.rtl, style: BL.fa(13.5))),
          const SizedBox(height: 18),
          Text('The dialogue', style: BL.display(20)),
          const SizedBox(height: 6),
          for (final (i, l) in e.lines.indexed)
            Container(
              key: ValueKey('drv-line-$i'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: playing == 'l$i' ? seaRed : Colors.transparent, width: 1.5),
              ),
              child: InkWell(
                key: ValueKey('drv-play-$i'),
                onTap: () => _say('l$i', l.sp, l.en),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: BL.mist,
                      backgroundImage: l.avatar.isEmpty ? null : AssetImage(l.avatar),
                      child: l.avatar.isEmpty ? const Icon(Icons.person_rounded, size: 18, color: seaRed) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: seaRed)),
                          Text(l.en, style: const TextStyle(fontSize: 14.5, height: 1.35)),
                          if (fa) Text(l.fa, key: ValueKey('drv-line-fa-$i'), textDirection: TextDirection.rtl, style: BL.fa(13)),
                        ],
                      ),
                    ),
                    Icon(playing == 'l$i' ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 18, color: BL.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text('Words', style: BL.display(20)),
          const SizedBox(height: 6),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, w) in e.words.indexed)
                  ListTile(
                    key: ValueKey('drv-word-$i'),
                    dense: true,
                    onTap: () => _say('w$i', 'narrator', w.w),
                    leading: Icon(playing == 'w$i' ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, color: seaRed, size: 20),
                    title: Text(w.w, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.en),
                        Align(alignment: Alignment.centerRight, child: Text(w.fa, textDirection: TextDirection.rtl, style: BL.fa(12.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Quick quiz', key: const ValueKey('drv-quiz'), style: BL.display(20)),
          for (final (qi, q) in e.qs.indexed)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${qi + 1}. ${q.q}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 6),
                  for (final o in order![qi])
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _Opt(
                        key: ValueKey('drv-q$qi-opt-$o'),
                        text: q.options[o],
                        state: !picks.containsKey(qi) ? 0 : o == 0 ? 1 : picks[qi] == o ? 2 : 0,
                        onTap: () => _pick(e, qi, o),
                      ),
                    ),
                ],
              ),
            ),
          if (result != null) _result(e, ctrl),
        ],
      ),
    );
  }

  Widget _result(DLesson e, ProgressController ctrl) {
    final (pct, xp, best) = result!;
    final right = picks.values.where((v) => v == 0).length;
    final ok = pct >= Drive.pass;
    return Container(
      key: const ValueKey('drv-result'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ok ? const Color(0xFF2E7D5B) : seaRed, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$right / ${e.qs.length} · ${ok ? 'Lovely, well done!' : 'Nearly — have another go.'}',
            key: const ValueKey('drv-score'),
            style: BL.display(20, color: Colors.white),
          ),
          Text(ok ? 'آفرین، عالی بود!' : 'نزدیک بود؛ دوباره امتحان کن.', textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white70)),
          const SizedBox(height: 6),
          Text('+$xp XP${best ? ' · best score saved' : ''}', key: const ValueKey('drv-xp'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                key: const ValueKey('drv-retry'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                onPressed: () => setState(() {
                  picks.clear();
                  result = null;
                  order = null;
                }),
                child: const Text('Try again'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('drv-back-cal'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: BL.ink),
                onPressed: () => context.canPop() ? context.pop() : context.go('/driving'),
                child: const Text('Back to lessons'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Opt extends StatelessWidget {
  final String text;
  final int state; // 0 plain, 1 right, 2 wrong pick
  final VoidCallback onTap;
  const _Opt({super.key, required this.text, required this.state, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = state == 1 ? const Color(0xFF2E7D5B) : state == 2 ? const Color(0xFFB3261E) : BL.mist;
    return Material(
      color: state == 0 ? seaBg : c,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: state == 0 ? BL.ink : Colors.white))),
              if (state == 1) const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              if (state == 2) const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
