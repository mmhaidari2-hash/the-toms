import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/remind.dart';
import '../shared/nav.dart';
import 'package:go_router/go_router.dart';
import 'motivation_widgets.dart';

/// One calm screen for streak, daily goal, calm circle, badges and reminders.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final pad = MediaQuery.paddingOf(context);
    final streak = ctrl.currentStreak, today = ctrl.xpToday, goal = ctrl.dailyGoal;
    final circle = ctrl.calmCircle;
    final family = ctrl.familyChallengeRows();
    final earned = ctrl.badgesEarned;
    final kid = ctrl.kidMode;
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
          Row(children: [
            const NavButtons(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(kid ? 'KID MODE' : 'YOUR PROGRESS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: kid ? BL.navy : BL.red)),
            ),
            IconButton(
              key: const ValueKey('progress-profiles'),
              tooltip: hl('Profiles'),
              onPressed: () => context.push('/profiles'),
              icon: const Icon(Icons.manage_accounts_rounded, color: BL.navy),
            ),
          ]),
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
          // Calm circle (no toxic leagues)
          card(
            key: const ValueKey('calm-circle'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.favorite_rounded, color: BL.red, size: 26),
                const SizedBox(width: 8),
                Expanded(child: h('Calm circle', 'حلقهٔ آرام')),
                TextButton(onPressed: () => context.push('/profiles'), child: Text(hl('Profiles'))),
              ]),
              Text(hl('Private family challenge and study-buddy codes — no public leagues, no shame.'), style: const TextStyle(fontSize: 12.5, color: BL.muted)),
              Text(hl('چالش خانوادگی خصوصی و کد هم‌مطالعه — بدون لیگ عمومی و بدون شرمساری.'), textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
              const SizedBox(height: 8),
              Text(hl('This week · goal ${circle.goalXp} XP each'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 6),
              for (final (name, xp, isYou, isChild) in family)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isYou ? const Color(0xFFFFF4D6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(isChild ? Icons.child_care_rounded : Icons.person_rounded, size: 18, color: BL.navy),
                    const SizedBox(width: 8),
                    Expanded(child: Text(hl(name + (isYou ? ' · you' : '')), style: TextStyle(fontWeight: isYou ? FontWeight.w900 : FontWeight.w600))),
                    Text(hl('$xp / ${circle.goalXp} XP'), style: TextStyle(fontWeight: FontWeight.w700, color: xp >= circle.goalXp ? BL.green : BL.ink)),
                  ]),
                ),
              if (circle.buddyCode != null) ...[
                const SizedBox(height: 6),
                Text(hl('Study buddy: ${circle.buddyLabel ?? 'Buddy'} · code ${circle.buddyCode} (progress stays on each device)'),
                    style: const TextStyle(fontSize: 12.5, color: BL.muted)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonal(
                  key: const ValueKey('buddy-share'),
                  onPressed: () async {
                    final code = await ctrl.ensureBuddyCode();
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(hl('Your study-buddy code')),
                        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SelectableText(code, style: BL.display(28, color: BL.navy)),
                          const SizedBox(height: 8),
                          Text(hl('Share this private code with one person. They enter it on their device to join the same weekly XP goal. Progress does not sync online yet.'), style: const TextStyle(fontSize: 13)),
                          Text(hl('این کد خصوصی را با یک نفر شریک شوید. همان هدف هفتگی را روی دستگاه خودشان وارد می‌کنند. پیشرفت فعلاً آنلاین همگام نمی‌شود.'), textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                        ]),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(hl('Done')))],
                      ),
                    );
                  },
                  child: Text(hl('Share buddy code')),
                ),
                OutlinedButton(
                  key: const ValueKey('buddy-join'),
                  onPressed: () async {
                    final c = TextEditingController();
                    final ok = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(hl('Join a buddy code')),
                        content: TextField(controller: c, decoration: InputDecoration(labelText: hl('6-letter code')), textCapitalization: TextCapitalization.characters),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(hl('Cancel'))),
                          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(hl('Join'))),
                        ],
                      ),
                    );
                    if (ok == null || !context.mounted) return;
                    try {
                      await ctrl.joinBuddyCode(ok);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('Could not join that code.'))));
                      }
                    }
                  },
                  child: Text(hl('Enter code')),
                ),
                if (!kid)
                  TextButton(onPressed: () => context.push('/profiles'), child: Text(hl(family.length < 2 ? 'Add child profile' : 'Manage profiles'))),
              ]),
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
