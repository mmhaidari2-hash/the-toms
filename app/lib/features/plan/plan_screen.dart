import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/data/study_plan.dart';
import '../shared/nav.dart';

/// "My study plan": pick a goal level, minutes a day and a target date; see the lessons left and the pace needed.
class PlanScreen extends ConsumerStatefulWidget {
  /// Opened straight after the placement test.
  final bool fromPlacement;
  const PlanScreen({super.key, this.fromPlacement = false});
  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  int? _goal, _minutes;
  DateTime? _target;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pad = MediaQuery.paddingOf(context);
    if (c == null) return const Scaffold(backgroundColor: BL.cream, body: Center(child: CircularProgressIndicator()));
    final course = c.course;
    final cur = ctrl.currentLevel(course);
    final saved = ctrl.plan;
    final today = StudyPlan.day(DateTime.now());
    final goal = (_goal ?? saved?.goal ?? (cur < 5 ? cur + 1 : 5)).clamp(cur, 5);
    final minutes = _minutes ?? saved?.minutes ?? 15;
    final left = StudyPlan.lessonsLeft(ctrl, course, goal);
    final proj = StudyPlan.projected(left, minutes, today);
    final target = _target ?? (saved != null && saved.goal == goal && _goal == null ? saved.target : proj);
    final need = StudyPlan.minutesNeeded(left, target, today);
    final tight = need > minutes;
    final g = ProgressController.cefrOf(goal);
    final hours = (left * StudyPlan.minutesPerLesson / 60).round();

    Widget section(String en, String fa) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(children: [
        Expanded(child: Text(hl(en), style: BL.display(18))),
        Text(hl(fa), textDirection: helperDir, style: BL.fa(12.5)),
      ]),
    );
    Widget chip(String key, String label, bool on, VoidCallback tap) => ChoiceChip(
      key: ValueKey(key),
      label: Text(hl(label), style: TextStyle(fontWeight: FontWeight.w800, color: on ? Colors.white : BL.ink)),
      selected: on,
      showCheckmark: false,
      selectedColor: BL.red,
      backgroundColor: BL.paper,
      onSelected: (_) => setState(tap),
    );

    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 8, 20, pad.bottom + 28),
        children: [
          Row(children: [
            NavBack(fallback: '/'),
            const SizedBox(width: 10),
            const Expanded(child: Text('MY STUDY PLAN', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))),
          ]),
          const SizedBox(height: 14),
          Text(hl(widget.fromPlacement ? 'Now make a plan' : 'Your plan'), style: BL.display(30)),
          Text(hl(widget.fromPlacement ? 'حالا برای خودت برنامه بریز' : 'برنامهٔ تو'), textDirection: helperDir, style: BL.fa(14)),
          const SizedBox(height: 8),
          Text(hl('You are at ${ProgressController.cefrOf(cur)}. Choose where you want to get to, how long you can study each day and when you want to be there.'),
              style: const TextStyle(fontSize: 14.5, height: 1.35, color: BL.ink)),
          section('Goal level', 'سطح هدف'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var lv = cur; lv <= 5; lv++) chip('plan-goal-${ProgressController.cefrOf(lv)}', ProgressController.cefrOf(lv), lv == goal, () { _goal = lv; _target = null; }),
          ]),
          section('Minutes a day', 'دقیقه در روز'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in StudyPlan.minuteChoices) chip('plan-min-$m', '$m min', m == minutes, () => _minutes = m),
          ]),
          section('Target date', 'تاریخ هدف'),
          Material(
            color: BL.paper,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: const ValueKey('plan-date'),
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: target.isBefore(today) ? today : target, firstDate: today, lastDate: DateTime(today.year + 5, 12, 31), helpText: 'Reach $g by…');
                if (d != null) setState(() => _target = d);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.event_rounded, color: BL.red),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hl(StudyPlan.nice(target)), key: const ValueKey('plan-target'), style: BL.display(20)),
                    Text(hl(StudyPlan.niceFa(target)), textDirection: helperDir, style: BL.fa(12)),
                  ])),
                  const Text('Change', style: TextStyle(color: BL.red, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('plan-summary'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: tight ? const Color(0xFFFFF1E6) : const Color(0xFFEAF6EF), borderRadius: BorderRadius.circular(18), border: Border.all(color: tight ? const Color(0xFFE5A15A) : const Color(0xFF7CC59D))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hl(left == 0 ? 'You have already finished $g. Pick a higher goal.' : '$left lessons to reach $g — about $hours hours.'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
              const SizedBox(height: 4),
              Text(hl(left == 0 ? '' : 'At $minutes min a day you would finish around ${StudyPlan.nice(proj)}.'), style: const TextStyle(fontSize: 14, color: BL.ink)),
              if (left > 0) Text(hl(tight ? 'To reach $g by ${StudyPlan.nice(target)} you need about $need min a day.' : 'That is on time for ${StudyPlan.nice(target)}.'),
                  key: const ValueKey('plan-pace'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tight ? const Color(0xFFB35A00) : const Color(0xFF1F7A4D))),
              const SizedBox(height: 6),
              Text(hl(left == 0 ? '' : '$left درس تا $g، حدود $hours ساعت. با روزی $minutes دقیقه حدوداً ${StudyPlan.niceFa(proj)} تمام می‌کنی.${tight ? ' برای رسیدن تا ${StudyPlan.niceFa(target)} روزی حدود $need دقیقه لازم است.' : ''}'),
                  textDirection: helperDir, style: BL.fa(12.5)),
              const SizedBox(height: 6),
              const Text('Estimates use about 12 minutes per lesson. Your real pace may differ.', style: TextStyle(fontSize: 11.5, color: BL.muted)),
            ]),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('plan-save'),
            style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
            onPressed: left == 0 ? null : () {
              ctrl.savePlan(StudyPlan(goal, tight ? need.clamp(minutes, 240) : minutes, target, today, left));
              if (widget.fromPlacement) {
                context.go('/');
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: Text(hl(tight ? 'Save plan · $need min a day' : 'Save my plan'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          if (widget.fromPlacement) TextButton(key: const ValueKey('plan-skip'), onPressed: () => context.go('/'), child: const Text('Not now', style: TextStyle(color: BL.muted))),
        ],
      ),
    );
  }
}

/// Compact plan status for My path: goal, target date, on-track and this week's lessons. Tap to edit.
class PlanCard extends ConsumerWidget {
  /// One slim line (for the pinned My path header) instead of the full card.
  final bool compact;
  const PlanCard({super.key, this.compact = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contentProvider).value;
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    if (c == null) return const SizedBox.shrink();
    final p = ctrl.plan;
    final today = StudyPlan.day(DateTime.now());
    if (p == null) {
      return _shell(context, key: 'plan-card-new', icon: Icons.flag_rounded, title: 'Make a study plan', sub: 'Set a goal level and a target date', fa: 'هدف و تاریخ خودت را تعیین کن');
    }
    final left = StudyPlan.lessonsLeft(ctrl, c.course, p.goal);
    final g = ProgressController.cefrOf(p.goal);
    if (left == 0) return _shell(context, key: 'plan-card', icon: Icons.emoji_events_rounded, title: 'Goal reached: $g 🎉', sub: 'Set a new goal', fa: 'به هدفت رسیدی! هدف تازه بگذار', ok: true);
    final ok = p.onTrack(left, today);
    final wk = p.perWeek(left, today);
    return _shell(context, key: 'plan-card', icon: ok ? Icons.trending_up_rounded : Icons.schedule_rounded,
        title: '$g by ${StudyPlan.nice(p.target)}',
        sub: '${ok ? 'On track' : 'A little behind'} · $wk lessons this week · ${p.minutes} min a day',
        fa: '${ok ? 'طبق برنامه' : 'کمی عقب'} · این هفته $wk درس',
        ok: ok);
  }

  Widget _shell(BuildContext context, {required String key, required IconData icon, required String title, required String sub, required String fa, bool? ok}) => compact
      ? Material(
          key: ValueKey(key),
          color: ok == null ? BL.navy.withValues(alpha: .08) : ok ? const Color(0x1A1F7A4D) : const Color(0x1FE08A2E),
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => context.push('/plan'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(children: [
                Icon(icon, size: 16, color: ok == null ? BL.navy : ok ? const Color(0xFF1F7A4D) : const Color(0xFFB35A00)),
                const SizedBox(width: 6),
                Text(hl(title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: BL.ink)),
                const SizedBox(width: 6),
                Expanded(child: Text(hl(sub), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: BL.muted))),
                const Icon(Icons.chevron_right_rounded, size: 18, color: BL.muted),
              ]),
            ),
          ),
        )
      : Material(
    key: ValueKey(key),
    color: BL.paper,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/plan'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ok == null ? BL.navy : ok ? const Color(0xFF1F7A4D) : const Color(0xFFE08A2E)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hl(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
            Text(hl(sub), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: BL.muted)),
            Text(hl(fa), maxLines: 1, textDirection: helperDir, style: BL.fa(11.5)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: BL.muted),
        ]),
      ),
    ),
  );
}
