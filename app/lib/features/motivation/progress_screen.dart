import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/remind.dart';
import '../shared/nav.dart';
import 'motivation_widgets.dart';

/// One calm screen for streak, daily goal, league, badges and reminders.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pad = MediaQuery.paddingOf(context);
    final streak = ctrl.currentStreak, today = ctrl.xpToday, goal = ctrl.dailyGoal;
    final rows = ctrl.leagueBoard();
    final rank = Motivation.rank(rows);
    final tier = Motivation.tiers[ctrl.leagueTier];
    final earned = ctrl.badgesEarned;
    Widget card({required Widget child, Key? key}) => Container(
          key: key,
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(20), border: Border.all(color: BL.mist)),
          child: child,
        );
    Text h(String en, String fa) => Text.rich(TextSpan(children: [
          TextSpan(text: hl(en), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BL.ink)),
          TextSpan(text: hl('   $fa'), style: BL.fa(12, color: BL.muted)),
        ]));
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('YOUR PROGRESS', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          // Streak + today
          card(
            key: const ValueKey('progress-top'),
            child: Row(children: [
              const Icon(Icons.local_fire_department_rounded, size: 46, color: BL.red),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl('$streak-day streak'), style: BL.display(22)),
                Text(hl(streak == 0 ? 'Do one lesson today to start a streak.' : 'Freezes: ${ctrl.freezes} of ${Motivation.maxFreezes} · one for every 7 days'), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
              ])),
              Column(children: [GoalRing(xp: today, goal: goal, size: 46), const SizedBox(height: 4), Text(hl('$today/$goal XP'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))]),
            ]),
          ),
          // Daily goal
          card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h('Daily goal', 'هدف روزانه'),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (xp, name, fa) in Motivation.goals)
                  ChoiceChip(
                    key: ValueKey('goal-$xp'),
                    label: Text(hl('$name · $xp XP')),
                    tooltip: fa,
                    selected: goal == xp,
                    onSelected: (_) => ctrl.setDailyGoal(xp),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(hl('Total: ${ctrl.xpTotal} XP · this week: ${ctrl.xpWeek} XP'), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
            ]),
          ),
          // League
          card(
            key: const ValueKey('league'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.shield_rounded, color: Color(tier.$3), size: 26),
                const SizedBox(width: 8),
                Expanded(child: h('${tier.$1} League', 'لیگ ${tier.$2}')),
                Text(hl('#$rank'), style: BL.display(20, color: BL.navy)),
              ]),
              const SizedBox(height: 4),
              const Text('Weekly XP · top 3 move up, bottom 2 move down · ends Sunday night', style: TextStyle(fontSize: 12, color: BL.muted)),
              const SizedBox(height: 8),
              for (final (i, r) in rows.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: r.$3 ? const Color(0xFFFFF4D6) : (i < 3 ? const Color(0xFFF1F7F3) : Colors.transparent), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    SizedBox(width: 26, child: Text(hl('${i + 1}'), style: TextStyle(fontWeight: FontWeight.w800, color: i < 3 ? BL.green : BL.muted))),
                    Expanded(child: Text(hl(r.$1), style: TextStyle(fontWeight: r.$3 ? FontWeight.w900 : FontWeight.w600))),
                    Text(hl('${r.$2} XP'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              const Text('Practice league with friendly bots while online leagues are being built.', style: TextStyle(fontSize: 11, color: BL.muted, fontStyle: FontStyle.italic)),
            ]),
          ),
          // Badges
          card(
            key: const ValueKey('badges'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h('Badges  ${earned.length}/${Motivation.badges.length}', 'نشان‌ها'),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (_, c) {
                final w = (c.maxWidth - 3 * 10) / 4;
                return Wrap(spacing: 10, runSpacing: 12, children: [
                  for (final b in Motivation.badges)
                    SizedBox(
                      width: w,
                      child: Tooltip(
                        message: hl(b.how),
                        child: Column(children: [
                          BadgeMedal(b, earned: earned.contains(b.id), size: 50),
                          const SizedBox(height: 4),
                          Text(hl(b.title), textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: earned.contains(b.id) ? BL.ink : BL.muted)),
                        ]),
                      ),
                    ),
                ]);
              }),
            ]),
          ),
          // Reminders
          card(key: const ValueKey('reminders'), child: const _Reminders()),
        ],
      ),
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final t = ctrl.reminderTime.split(':');
    final time = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    final status = notificationStatus();
    void snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(hl(s))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text.rich(TextSpan(children: [
          const TextSpan(text: 'Daily reminder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BL.ink)),
          TextSpan(text: hl('   یادآور روزانه'), style: BL.fa(12, color: BL.muted)),
        ]))),
        Switch(key: const ValueKey('remind-switch'), value: ctrl.reminderOn, activeThumbColor: BL.green, onChanged: (v) async {
          ctrl.setReminder(ctrl.reminderTime, v);
          if (v && status == 'default') await requestNotifications();
        }),
      ]),
      OutlinedButton.icon(
        key: const ValueKey('remind-time'),
        icon: const Icon(Icons.schedule_rounded),
        label: Text(hl('Remind me at ${time.format(context)}')),
        onPressed: () async {
          final picked = await showTimePicker(context: context, initialTime: time);
          if (picked != null) ctrl.setReminder('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}', true);
        },
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (status != 'unsupported')
          FilledButton.tonalIcon(
            key: const ValueKey('remind-notify'),
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(hl(status == 'granted' ? 'Test notification' : 'Allow notifications')),
            onPressed: () async {
              final s = status == 'granted' ? 'granted' : await requestNotifications();
              if (s == 'granted') {
                final ok = await showNotification('New Life UK', 'Five minutes today keeps your streak going!');
                snack(ok ? 'Notifications are on.' : 'Notifications are blocked on this device. Use the calendar reminder.');
              } else {
                snack('Notifications are blocked. Use the calendar reminder instead.');
              }
              ref.invalidate(progressProvider);
            },
          ),
        FilledButton.icon(
          key: const ValueKey('remind-ics'),
          style: FilledButton.styleFrom(backgroundColor: BL.navy),
          icon: const Icon(Icons.event_rounded),
          label: const Text('Add to calendar'),
          onPressed: () {
            final ok = downloadFile('new-life-uk-daily-reminder.ics', 'text/calendar', reminderIcs(time.hour, time.minute, DateTime.now()));
            snack(ok ? 'Open the file to add a daily reminder to your calendar.' : 'Calendar reminders work in the web app.');
          },
        ),
      ]),
      const SizedBox(height: 8),
      const Text('On iPhone, web notifications only work after "Add to Home Screen" (iOS 16.4+). The calendar reminder works everywhere.',
          style: TextStyle(fontSize: 11.5, color: BL.muted)),
    ]);
  }
}
