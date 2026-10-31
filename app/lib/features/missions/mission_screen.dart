import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/voice.dart';
import '../grammar/grammar_data.dart';
import '../motivation/motivation_widgets.dart';
import '../shared/nav.dart';
import 'missions_data.dart';

/// One mission: prepare (phrases + British audio), "Ready? Go!", then check in (how it went, phrases used).
class MissionScreen extends ConsumerWidget {
  final String id;
  const MissionScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ms = ref.watch(missionsProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (ms == null || topics == null || content == null) return const NavLoading();
    final m = ms.where((x) => x.id == id).firstOrNull;
    if (m == null) {
      return Scaffold(backgroundColor: BL.cream, body: Center(child: TextButton(onPressed: () => context.go('/missions'), child: const Text('Mission not found — back to Missions'))));
    }
    final gate = MissionGate(ref.read(progressProvider.notifier), content, topics, ms, unlockAll: ref.read(progressProvider).gatesOpen);
    if (!gate.levelOpen(m.level)) return MissionLocked(m: m);
    return _Mission(key: ValueKey('mission-screen-${m.id}'), m: m);
  }
}

class MissionLocked extends StatelessWidget {
  final Mission m;
  const MissionLocked({super.key, required this.m});
  @override
  Widget build(BuildContext context) {
    final (en, fa) = MissionGate.why(m.level);
    return Scaffold(
      key: const ValueKey('mis-locked'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: NavBack(fallback: '/missions'))),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_rounded, size: 56, color: BL.muted),
                  const SizedBox(height: 14),
                  Text(hl(m.title), textAlign: TextAlign.center, style: BL.display(24)),
                  Text(hl(m.titleFa), textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
                  const SizedBox(height: 18),
                  Text(hl('This is a ${m.level} mission, which isn\'t open for you yet'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(hl(en), key: const ValueKey('mis-locked-why'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: BL.muted, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(hl(fa), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(13, color: BL.muted)),
                  const SizedBox(height: 18),
                  TextButton(key: const ValueKey('mis-locked-back'), onPressed: () => context.go('/missions'), child: const Text('Back to Missions')),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

enum _Stage { prep, go, checkin, done }

class _Mission extends ConsumerStatefulWidget {
  final Mission m;
  const _Mission({super.key, required this.m});
  @override
  ConsumerState<_Mission> createState() => _MissionState();
}

class _MissionState extends ConsumerState<_Mission> {
  Mission get m => widget.m;
  ProgressController get ctrl => ref.read(progressProvider.notifier);
  // Back from the real world: open straight on the check-in.
  late _Stage stage = ctrl.missionPending(m.id) ? _Stage.checkin : _Stage.prep;
  String? playing;
  int? rating;
  final used = <int>{};
  XpAward? award;

  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  Future<void> _play(String key, MPhrase p) async {
    setState(() => playing = key);
    await Voice.say(p.sp, p.en);
    if (mounted && playing == key) setState(() => playing = null);
  }

  void _go() {
    Voice.stop();
    ctrl.startMission(m.id);
    setState(() => stage = _Stage.go);
  }

  void _save() {
    final a = ctrl.checkInMission(m.id, rating!, rating == 0 ? 0 : used.length);
    setState(() {
      award = a;
      stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    if (stage == _Stage.done && award != null) {
      final ok = rating! >= 1;
      return Scaffold(
        backgroundColor: BL.cream,
        body: Celebration(
          key: const ValueKey('mis-celebrate'),
          award: award!,
          pass: ok,
          checkpoint: false,
          right: ok ? used.length : 0,
          total: m.say.length,
          scoreLabel: 'Phrases',
          title: rating == 2 ? 'Mission complete!' : (ok ? 'You did it!' : 'Brave try!'),
          titleFa: rating == 2 ? 'مأموریت انجام شد! عالی بود.' : (ok ? 'انجامش دادی! هر بار راحت‌تر می‌شود.' : 'اشکالی ندارد. یک روز دیگر دوباره امتحان کن.'),
          onRetry: ok ? null : () => setState(() => stage = _Stage.prep),
          onContinue: () => context.go('/missions'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: BL.cream,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 6),
          child: Row(children: [
            const NavBack(fallback: '/missions'),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(m.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(hl('${m.level}  ·  Real-life mission'), style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
            ClipOval(child: Image.asset(m.icon, width: 38, height: 38, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 38))),
          ]),
        ),
        Expanded(
          child: switch (stage) {
            _Stage.prep => _prep(pad.bottom),
            _Stage.go => _goCard(pad.bottom),
            _ => _checkin(pad.bottom),
          },
        ),
      ]),
    );
  }

  Widget _label(String en, String fa) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Row(children: [
          Expanded(child: Text(hl(en.toUpperCase()), style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: BL.red))),
          const SizedBox(width: 8),
          Text(hl(fa), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
        ]),
      );

  Widget _phrase(String key, MPhrase p, {bool you = true}) {
    final on = playing == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: BL.paper,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey(key),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _play(key, p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            child: Row(children: [
              Icon(on ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, color: on ? BL.red : BL.navy, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!you) Text(hl(p.spName.toUpperCase()), style: const TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: BL.muted)),
                  Text(hl(p.en), style: TextStyle(fontSize: 15.5, fontWeight: you ? FontWeight.w700 : FontWeight.w500, height: 1.3)),
                  Text(hl(p.fa), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _note(String key, IconData icon, Color c, (String, String) t) => Container(
        key: ValueKey(key),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(hl(t.$1), style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600)),
              Text(hl(t.$2), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
            ]),
          ),
        ]),
      );

  Widget _prep(double bottom) => ListView(
        key: const ValueKey('mis-prep'),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
        children: [
          Container(
            key: const ValueKey('mis-goal'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BL.navy, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('YOUR MISSION', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w900, color: BL.gold)),
              const SizedBox(height: 4),
              Text(hl(m.goal), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 4),
              Text(hl(m.goalFa), textDirection: helperDir, style: BL.fa(13, color: Colors.white70)),
            ]),
          ),
          _label('Phrases to use', 'عبارت‌هایی که می‌گویی'),
          for (var i = 0; i < m.say.length; i++) _phrase('mis-say-$i', m.say[i]),
          _label('You might hear', 'شاید بشنوی'),
          for (var i = 0; i < m.hear.length; i++) _phrase('mis-hear-$i', m.hear[i], you: false),
          _note('mis-tip', Icons.lightbulb_rounded, BL.gold, m.tip),
          if (m.safe != null) _note('mis-safe', Icons.shield_rounded, BL.green, m.safe!),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('mis-ready'),
            onPressed: _go,
            style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            icon: const Icon(Icons.directions_walk_rounded),
            label: Text(hl("I'm ready · آماده‌ام"), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          ),
        ],
      );

  Widget _goCard(double bottom) => ListView(
        key: const ValueKey('mis-go'),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD23A33), Color(0xFF9E1F1B)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(children: [
              const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 6),
              Text('Ready? Go!', key: const ValueKey('mis-go-title'), style: BL.display(32, color: Colors.white)),
              Text(hl('آماده‌ای؟ برو!'), textDirection: helperDir, style: BL.fa(15, color: Colors.white70)),
              const SizedBox(height: 14),
              Text(hl(m.goal), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              for (final p in m.say.take(3))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                  child: Text(hl('“${p.en}”'), style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Go and do it in real life, then come back here to check in. Nothing is recorded: it\'s just you.', textAlign: TextAlign.center, style: TextStyle(color: BL.muted, fontSize: 13, height: 1.4)),
          Text(hl('برو و در زندگی واقعی انجامش بده، بعد برگرد و گزارش بده. هیچ چیزی ضبط نمی‌شود.'), textDirection: helperDir, textAlign: TextAlign.center, style: BL.fa(12.5, color: BL.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('mis-checkin'),
            onPressed: () => setState(() => stage = _Stage.checkin),
            style: FilledButton.styleFrom(backgroundColor: BL.navy, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text("I'm back · check in", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          ),
          TextButton(key: const ValueKey('mis-later'), onPressed: () => context.go('/missions'), child: Text(hl("I'll do it later · بعداً"))),
        ],
      );

  Widget _checkin(double bottom) {
    Widget opt(int r, String emoji, String en, String fa) {
      final on = rating == r;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: on ? BL.navy : BL.paper,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey('mis-rate-$r'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => rating = r),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Text(hl(emoji), style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(hl(en), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: on ? Colors.white : BL.ink)),
                    Text(hl(fa), textDirection: helperDir, style: BL.fa(12.5, color: on ? Colors.white70 : BL.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('mis-checkin-view'),
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
      children: [
        Text('How did it go?', style: BL.display(24)),
        Text(hl('چطور پیش رفت؟'), textDirection: helperDir, style: BL.fa(14, color: BL.muted)),
        const SizedBox(height: 12),
        opt(2, '😀', 'It went well', 'خوب پیش رفت'),
        opt(1, '🙂', 'I did it, but it was hard', 'انجامش دادم، ولی سخت بود'),
        opt(0, '😬', "It didn't happen this time", 'این بار نشد'),
        if (rating != null && rating! >= 1) ...[
          _label('Which phrases did you use?', 'کدام عبارت‌ها را گفتی؟'),
          for (var i = 0; i < m.say.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: used.contains(i) ? BL.gold.withValues(alpha: .4) : BL.paper,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('mis-used-$i'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => used.contains(i) ? used.remove(i) : used.add(i)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Icon(used.contains(i) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20, color: used.contains(i) ? BL.ink : BL.muted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(hl(m.say[i].en), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey('mis-save'),
          onPressed: rating == null ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Text(hl('Save my check-in · ثبت'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ),
        TextButton(key: const ValueKey('mis-back-prep'), onPressed: () => setState(() => stage = _Stage.prep), child: Text(hl('Back to the phrases · برگشت به عبارت‌ها'))),
      ],
    );
  }
}
