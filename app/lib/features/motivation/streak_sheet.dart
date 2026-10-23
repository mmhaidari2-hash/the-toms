import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/remind.dart';

/// Streak at a glance (tap the 🔥 chip on the map): today's status, the last two weeks, freezes and the daily reminder.
Future<void> showStreakSheet(BuildContext context) => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _StreakSheet());

class _StreakSheet extends ConsumerWidget {
  const _StreakSheet();
  static const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final streak = ctrl.currentStreak, done = ctrl.practisedToday, fr = ctrl.freezes;
    final days = ctrl.streakDays(14);
    final pad = MediaQuery.paddingOf(context);
    final atRisk = streak > 0 && !done;
    final (msg, msgFa) = done
        ? ('Done for today. Come back tomorrow to make it ${streak + 1}.', 'امروز انجام شد. فردا برگرد تا ${streak + 1} روز شود.')
        : atRisk
        ? ('Your streak is waiting. One lesson today keeps it going.', 'پیوستگی‌ات منتظر است. یک درس امروز آن را نگه می‌دارد.')
        : ('Do one lesson today to start a streak.', 'امروز یک درس بخوان تا پیوستگی شروع شود.');
    final time = ctrl.reminderTime;
    return Container(
      key: const ValueKey('streak-sheet'),
      decoration: const BoxDecoration(
        color: BL.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, pad.bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(9)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded, size: 44, color: done ? BL.red : const Color(0xFFB8A99A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hl(streak == 1 ? '1-day streak' : '$streak-day streak'), key: const ValueKey('streak-count'), style: BL.display(26)),
                      Text(hl('$streak روز پشت سر هم'), textDirection: helperDir, style: BL.fa(12.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              key: ValueKey(
                done
                    ? 'streak-done'
                    : atRisk
                    ? 'streak-risk'
                    : 'streak-start',
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFFEAF6EF)
                    : atRisk
                    ? const Color(0xFFFFF1E6)
                    : BL.paper,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hl(msg),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: BL.ink),
                  ),
                  Text(hl(msgFa), textDirection: helperDir, style: BL.fa(12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'LAST 2 WEEKS',
              style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.muted),
            ),
            const SizedBox(height: 8),
            for (final row in [days.sublist(0, 7), days.sublist(7)])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (d, st) in row)
                      Column(
                        children: [
                          Container(
                            key: ValueKey('day-${Motivation.day(d)}-$st'),
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: st == 'done'
                                  ? BL.red
                                  : st == 'freeze'
                                  ? const Color(0xFF5AA9E6)
                                  : BL.paper,
                              border: Border.all(color: st == 'today' ? BL.red : const Color(0x22000000), width: st == 'today' ? 2 : 1),
                            ),
                            child: st == 'done'
                                ? const Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white)
                                : st == 'freeze'
                                ? const Icon(Icons.ac_unit_rounded, size: 17, color: Colors.white)
                                : Text(
                                    hl('${d.day}'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BL.muted),
                                  ),
                          ),
                          const SizedBox(height: 2),
                          Text(hl(_wd[d.weekday - 1]), style: const TextStyle(fontSize: 10, color: BL.muted)),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('streak-freezes'),
              children: [
                for (var i = 0; i < Motivation.maxFreezes; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.ac_unit_rounded, size: 22, color: i < fr ? const Color(0xFF5AA9E6) : const Color(0x33000000)),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hl('Streak freezes: $fr of ${Motivation.maxFreezes}'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: BL.ink),
                      ),
                      const Text('A freeze covers one missed day automatically. You earn one for every 7-day streak.', style: TextStyle(fontSize: 12, color: BL.muted)),
                      Text(hl('هر یخ‌زدگی یک روزِ جاافتاده را خودکار جبران می‌کند؛ هر ۷ روز یکی می‌گیری.'), textDirection: helperDir, style: BL.fa(11.5)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: BL.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hl(ctrl.reminderOn ? 'Daily reminder at $time' : 'Daily reminder is off'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: BL.ink),
                      ),
                      Text(hl('یادآور روزانه'), textDirection: helperDir, style: BL.fa(11.5)),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('streak-remind'),
                  value: ctrl.reminderOn,
                  activeThumbColor: BL.green,
                  onChanged: (v) async {
                    ctrl.setReminder(time, v);
                    if (v && notificationStatus() == 'default') await requestNotifications();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('streak-progress'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/progress');
                },
                child: const Text('Reminder time, goals & badges'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
