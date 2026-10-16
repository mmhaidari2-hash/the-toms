class WeeklyChallenge {
  static const chatsTarget = 5, trustTarget = 60;

  /// ISO-8601 week key, e.g. 2026-W42.
  static String weekKey(DateTime d) {
    final day = DateTime.utc(d.year, d.month, d.day);
    final thursday = day.add(Duration(days: 4 - (day.weekday)));
    final firstThursday = DateTime.utc(thursday.year, 1, 4);
    final week = 1 + (thursday.difference(firstThursday).inDays + (firstThursday.weekday - 1)) ~/ 7;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static double progress(int chats, int trust) => ((chats / chatsTarget).clamp(0, 1) + (trust / trustTarget).clamp(0, 1)) / 2;
}
