import 'dart:math';

import 'weekly.dart';

/// Motivation layer: XP, daily goal, streak freezes, gentle streaks, calm family/buddy challenges (no toxic leagues), and badges.
/// Pure logic (no Flutter), stored by ProgressController in `missionsDone` under small prefixed keys.
class Motivation {
  static const List<(int, String, String)> goals = [(10, 'Casual', 'آرام'), (20, 'Regular', 'معمولی'), (30, 'Serious', 'جدی'), (50, 'Intense', 'فشرده')];
  static const defaultGoal = 20;
  static const maxFreezes = 2;
  static const storyXp = 10;
  static int practiceXp(int pct) => 5 + (pct / 10).round(); // 5–15 XP
  static String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "2026-10-17:30,2026-10-16:20" → map. Keeps the last 21 days.
  static Map<String, int> parseLog(String? s) => {
        for (final e in (s ?? '').split(',').where((e) => e.contains(':')))
          e.split(':')[0]: int.tryParse(e.split(':')[1]) ?? 0,
      };
  static String encodeLog(Map<String, int> m) {
    final ks = m.keys.toList()..sort();
    return ks.skip(max(0, ks.length - 21)).map((k) => '$k:${m[k]}').join(',');
  }

  static int weekXp(Map<String, int> log, DateTime now) {
    final wk = WeeklyChallenge.weekKey(now);
    return log.entries.where((e) => WeeklyChallenge.weekKey(DateTime.parse(e.key)) == wk).fold(0, (a, e) => a + e.value);
  }

  // ---- League (simulated: no server yet). Ten players, top 3 go up, bottom 2 go down.
  static const List<(String, String, int)> tiers = [('Bronze', 'برنز', 0xFFB87333), ('Silver', 'نقره', 0xFF9AA4B2), ('Gold', 'طلا', 0xFFE9B949), ('Sapphire', 'یاقوت کبود', 0xFF2F6FD6), ('Diamond', 'الماس', 0xFF5BC0DE)];
  static const _bots = ['Amira', 'Oliver', 'Sofia', 'Kenji', 'Zainab', 'Lukas', 'Chloe', 'Arash', 'Mateo', 'Hannah', 'Yusuf', 'Ola', 'Priyanka', 'Dmitri', 'Grace', 'Tariq'];

  /// Bots for this week and tier: deterministic names and week targets; their XP grows through the week.
  static List<(String, int)> bots(String week, int tier, DateTime now, {bool ended = false}) {
    final r = Random(week.hashCode ^ (tier * 7919));
    final names = [..._bots]..shuffle(r);
    // Fraction of the ISO week gone (Mon 00:00 → Sun 24:00).
    final f = ended ? 1.0 : ((now.weekday - 1) + (now.hour + now.minute / 60) / 24) / 7;
    final base = 60 + tier * 45;
    return [for (var i = 0; i < 9; i++) (names[i], (base * (0.3 + r.nextDouble() * 1.6) * f).round())];
  }

  /// Leaderboard rows sorted by XP: (name, xp, isYou).
  static List<(String, int, bool)> board(String week, int tier, int yourXp, DateTime now, {bool ended = false}) =>
      [for (final b in bots(week, tier, now, ended: ended)) (b.$1, b.$2, false), ('You', yourXp, true)]..sort((a, b) => b.$2.compareTo(a.$2));
  static int rank(List<(String, int, bool)> rows) => rows.indexWhere((r) => r.$3) + 1;
  static int nextTier(int tier, int rank) => rank <= 3 ? min(tier + 1, tiers.length - 1) : rank >= 9 ? max(tier - 1, 0) : tier;

  // ---- Badges
  static const badges = <Achievement>[
    Achievement('first', 'First steps', 'اولین قدم', 'Finish your first practice'),
    Achievement('streak3', 'On a roll', 'در مسیر', 'A 3-day streak'),
    Achievement('streak7', 'One week', 'یک هفته', 'A 7-day streak'),
    Achievement('streak30', 'Habit formed', 'عادت شد', 'A 30-day streak'),
    Achievement('xp100', '100 XP', '۱۰۰ امتیاز', 'Earn 100 XP'),
    Achievement('xp500', '500 XP', '۵۰۰ امتیاز', 'Earn 500 XP'),
    Achievement('xp1000', '1,000 XP', '۱۰۰۰ امتیاز', 'Earn 1,000 XP'),
    Achievement('lessons10', 'Ten lessons', 'ده درس', 'Pass 10 lessons'),
    Achievement('lessons50', 'Fifty lessons', 'پنجاه درس', 'Pass 50 lessons'),
    Achievement('unit', 'Unit champion', 'قهرمان واحد', 'Pass a unit review'),
    Achievement('perfect', 'Spot on!', 'بی‌نقص', 'Score 100% in a practice'),
    Achievement('goal7', 'Goal getter', 'هدف‌گیر', 'Hit your daily goal 7 times'),
    Achievement('words50', 'Word collector', 'کلکسیون واژه', 'Collect 50 words'),
    Achievement('league', 'Calm circle', 'حلقهٔ آرام', 'Hit a weekly calm-circle goal with family or a buddy'),
    Achievement('book1', 'Finished!', 'تمامش کردم!', 'Finish a book in the Library'),
    Achievement('book5', 'Bookworm', 'کتاب‌خوان', 'Finish 5 books in the Library'),
    Achievement('mission1', 'Out and about', 'بیرون از خانه', 'Complete a real-life mission'),
    Achievement('mission5', 'Real-life Brit', 'بریتانیایی واقعی', 'Complete 5 real-life missions'),
  ];
}

class Achievement {
  final String id, title, titleFa, how;
  const Achievement(this.id, this.title, this.titleFa, this.how);
}

/// What one activity earned, for the celebration screen.
class XpAward {
  final int xp, total, today, goal, streak, week;
  final bool streakUp, goalJustHit, freezeUsed;
  final List<Achievement> newBadges;
  const XpAward({this.xp = 0, this.total = 0, this.today = 0, this.goal = Motivation.defaultGoal, this.streak = 0, this.week = 0, this.streakUp = false, this.goalJustHit = false, this.freezeUsed = false, this.newBadges = const []});
}

/// A daily reminder as an .ics calendar event (works on iPhone, where web push is limited).
String reminderIcs(int hour, int minute, DateTime start, {String url = 'https://mmhaidari2-hash.github.io/the-toms/'}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final d = '${start.year}${two(start.month)}${two(start.day)}';
  final t = '${two(hour)}${two(minute)}00';
  final end = DateTime(2000, 1, 1, hour, minute).add(const Duration(minutes: 10));
  final stamp = '${start.toUtc().year}${two(start.toUtc().month)}${two(start.toUtc().day)}T000000Z';
  return [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//New Life UK//Daily reminder//EN', 'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT', 'UID:the-toms-daily-$d@thetoms.app', 'DTSTAMP:$stamp',
    'DTSTART:${d}T$t', 'DTEND:${d}T${two(end.hour)}${two(end.minute)}00', 'RRULE:FREQ=DAILY',
    'SUMMARY:New Life UK (5 minutes)', 'DESCRIPTION:Keep your streak going! $url', 'URL:$url',
    'BEGIN:VALARM', 'TRIGGER:PT0M', 'ACTION:DISPLAY', 'DESCRIPTION:Time for New Life UK', 'END:VALARM',
    'END:VEVENT', 'END:VCALENDAR', '',
  ].join('\r\n');
}
