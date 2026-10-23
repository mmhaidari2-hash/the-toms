import '../models/course.dart';
import 'providers.dart';

/// Personal study plan: a goal level, minutes a day and a target date. Stored as pref:plan =
/// "goal|minutes|target yyyy-mm-dd|start yyyy-mm-dd|lessons left at start".
class StudyPlan {
  final int goal, minutes, startLeft;
  final DateTime target, start;
  const StudyPlan(this.goal, this.minutes, this.target, this.start, this.startLeft);

  /// Rough time for one lesson (story + practice), used only for estimates.
  static const minutesPerLesson = 12;
  static const minuteChoices = [10, 15, 20, 30, 45];

  String encode() => '$goal|$minutes|${ymd(target)}|${ymd(start)}|$startLeft';
  static StudyPlan? decode(String s) {
    final p = s.split('|');
    if (p.length < 5) return null;
    final g = int.tryParse(p[0]), m = int.tryParse(p[1]), t = DateTime.tryParse(p[2]), st = DateTime.tryParse(p[3]), l = int.tryParse(p[4]);
    if (g == null || m == null || t == null || st == null || l == null) return null;
    return StudyPlan(g, m, t, st, l);
  }

  /// Unfinished main-course lessons from the learner's current level up to and including [goal].
  static int lessonsLeft(ProgressController ctrl, Course c, int goal) {
    final cur = ctrl.currentLevel(c);
    return c.units.where((u) => u.level >= cur && u.level <= goal).expand((u) => u.lessons).where((l) => !ctrl.lessonDone(l)).length;
  }
  /// Days of study needed for [lessons] at [minutes] a day (at least 1 when anything is left).
  static int daysNeeded(int lessons, int minutes) => lessons <= 0 ? 0 : (lessons * minutesPerLesson / minutes).ceil();
  /// Minutes a day needed to finish [lessons] by [target], counting from [today] (inclusive).
  static int minutesNeeded(int lessons, DateTime target, DateTime today) {
    final days = daysBetween(today, target) + 1;
    if (lessons <= 0) return 0;
    if (days <= 0) return lessons * minutesPerLesson;
    return (lessons * minutesPerLesson / days).ceil();
  }
  static DateTime projected(int lessons, int minutes, DateTime today) => DateTime(today.year, today.month, today.day + daysNeeded(lessons, minutes));

  /// Lessons the plan expects to be still left today, falling evenly from the start to the target date.
  int expectedLeft(DateTime today) {
    final total = daysBetween(start, target);
    if (total <= 0) return 0;
    final gone = daysBetween(start, today).clamp(0, total);
    return (startLeft * (1 - gone / total)).ceil();
  }
  /// On track when no more than one lesson behind the even pace.
  bool onTrack(int leftNow, DateTime today) => leftNow <= expectedLeft(today) + 1;
  /// Lessons to aim for this week to stay on pace to the target.
  int perWeek(int leftNow, DateTime today) {
    final days = daysBetween(today, target) + 1;
    if (leftNow <= 0) return 0;
    if (days <= 7) return leftNow;
    return (leftNow * 7 / days).ceil();
  }

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  /// Whole calendar days from [a] to [b] (safe across clock changes).
  static int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  static String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _monFa = ['ژانویه', 'فوریه', 'مارس', 'آوریل', 'مه', 'ژوئن', 'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر'];
  /// "12 Mar 2027" (UK style).
  static String nice(DateTime d) => '${d.day} ${_mon[d.month - 1]} ${d.year}';
  static String niceFa(DateTime d) => '${d.day} ${_monFa[d.month - 1]} ${d.year}';
}

extension StudyPlanX on ProgressController {
  StudyPlan? get plan => StudyPlan.decode(pref('plan'));
  void savePlan(StudyPlan p) => setPref('plan', p.encode());
}
