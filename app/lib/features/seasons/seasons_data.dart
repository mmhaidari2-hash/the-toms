import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Seasonal events (assets/data/seasons.json, built by tool/make_seasons.py): the Thompsons' year of
/// British celebrations, with a voiced family scene, Persian, vocab and a 3-question quiz each.
class SLine {
  final String sp, name, avatar, en, fa;
  final int ms;
  const SLine(this.sp, this.name, this.avatar, this.en, this.fa, this.ms);
}

class SWord {
  final String w, en, fa;
  const SWord(this.w, this.en, this.fa);
}

class SQ {
  final String q;
  final List<String> options; // options[0] is right (shuffled for display)
  const SQ(this.q, this.options);
}

class SEvent {
  final String id, level, rule, title, titleFa, when, whenFa, note, noteFa;
  final bool approx;
  final List<SLine> lines;
  final List<SWord> words;
  final List<SQ> qs;
  final List<String> src;
  const SEvent({
    required this.id,
    required this.level,
    required this.rule,
    required this.title,
    required this.titleFa,
    required this.when,
    required this.whenFa,
    required this.note,
    required this.noteFa,
    required this.approx,
    required this.lines,
    required this.words,
    required this.qs,
    required this.src,
  });
  factory SEvent.fromJson(Map<String, dynamic> j) => SEvent(
    id: j['id'],
    level: j['level'],
    rule: j['rule'],
    title: j['title'],
    titleFa: j['titleFa'],
    when: j['when'],
    whenFa: j['whenFa'],
    note: j['note'],
    noteFa: j['noteFa'],
    approx: j['approx'] == true,
    lines: [for (final l in j['lines'] as List) SLine(l['sp'], l['name'], l['avatar'], l['en'], l['fa'], (l['ms'] as num?)?.toInt() ?? 0)],
    words: [for (final w in j['words'] as List) SWord(w['w'], w['en'], w['fa'])],
    qs: [for (final q in j['qs'] as List) SQ(q['q'], List<String>.from(q['options']))],
    src: List<String>.from(j['src'] ?? const []),
  );

  /// Every date this event falls on in [year] (several for the May bank holidays; none if a table has no entry).
  List<DateTime> datesIn(int year) {
    final r = rule;
    if (r.startsWith('fixed:')) {
      final p = r.substring(6).split('-');
      return [DateTime(year, int.parse(p[0]), int.parse(p[1]))];
    }
    if (r.startsWith('easter:')) {
      final e = Seasons.easter(year);
      return [DateTime(year, e.month, e.day + int.parse(r.substring(7)))]; // calendar days, safe across clock changes
    }
    if (r.startsWith('nth:')) {
      return [
        for (final part in r.split(','))
          () {
            final p = part.substring(4).split(':');
            return Seasons.nthWeekday(year, int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
          }(),
      ];
    }
    return [
      for (final d in r.substring(6).split(','))
        if (int.parse(d.substring(0, 4)) == year) DateTime.parse(d),
    ];
  }

  /// The next date on or after [today], or null if we don't know it yet (a table that has run out).
  DateTime? next(DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    for (final y in [t.year, t.year + 1]) {
      final ds = datesIn(y).where((d) => !d.isBefore(t)).toList()..sort();
      if (ds.isNotEmpty) return ds.first;
    }
    return null;
  }
}

class Seasons {
  static List<SEvent> parse(String raw) => [for (final e in (jsonDecode(raw) as Map)['events'] as List) SEvent.fromJson(e)];

  /// Tests set this to fix "today".
  static DateTime? debugToday;
  static DateTime get today {
    final n = debugToday ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static const pass = 67; // 2 of 3
  static int pct(int right) => (right * 100 / 3).round();

  /// Easter Sunday (Gregorian, anonymous algorithm).
  static DateTime easter(int y) {
    final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30, i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451, month = (h + l - 7 * m + 114) ~/ 31, day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(y, month, day);
  }

  /// The [n]th [weekday] (1 = Mon … 7 = Sun) of [month]; n = -1 is the last one.
  static DateTime nthWeekday(int y, int month, int weekday, int n) {
    if (n > 0) {
      final first = DateTime(y, month, 1);
      return DateTime(y, month, 1 + (weekday - first.weekday + 7) % 7 + 7 * (n - 1));
    }
    final last = DateTime(y, month + 1, 0);
    return DateTime(y, month, last.day - (last.weekday - weekday + 7) % 7);
  }

  static int daysUntil(DateTime d, [DateTime? from]) {
    final f = from ?? today;
    return DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(f.year, f.month, f.day)).inDays;
  }

  /// Upcoming events, soonest first (events with no known next date go last).
  static List<(SEvent, DateTime?)> upcoming(List<SEvent> es, [DateTime? from]) {
    final t = from ?? today;
    final l = [for (final e in es) (e, e.next(t))];
    l.sort((a, b) => a.$2 == null ? 1 : b.$2 == null ? -1 : a.$2!.compareTo(b.$2!));
    return l;
  }

  /// The featured event: the one nearest to today (today's counts as nearest).
  static (SEvent, DateTime)? featured(List<SEvent> es, [DateTime? from]) {
    final u = upcoming(es, from).where((x) => x.$2 != null).firstOrNull;
    return u == null ? null : (u.$1, u.$2!);
  }

  static const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static String fmt(DateTime d) => '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
  static String countdown(DateTime d, [DateTime? from]) {
    final n = daysUntil(d, from);
    return n == 0 ? 'Today!' : n == 1 ? 'Tomorrow' : n < 14 ? 'In $n days' : n < 60 ? 'In ${(n / 7).round()} weeks' : 'In ${(n / 30.4).round()} months';
  }

  static String countdownFa(DateTime d, [DateTime? from]) {
    final n = daysUntil(d, from);
    return n == 0 ? 'امروز!' : n == 1 ? 'فردا' : n < 14 ? '$n روز دیگر' : n < 60 ? '${(n / 7).round()} هفتهٔ دیگر' : '${(n / 30.4).round()} ماه دیگر';
  }
}

final seasonsProvider = FutureProvider<List<SEvent>>((ref) async => Seasons.parse(await rootBundle.loadString('assets/data/seasons.json')));

/// Which event levels are open. Same rule as the Library, Cinema, Radio, Messages and Grammar School.
class SeasonGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<SEvent> events;
  SeasonGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.events, {bool unlockAll = false}) : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<SEvent> of(String code) => events.where((e) => e.level == code).toList();

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((e) => ctrl.seasonDone(e.id))) return true;
    if (of(code).any((e) => ctrl.seasonScore(e.id) != null)) return true;
    return grammar.classOpen(code);
  }

  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code celebrations open at Level $lv of the course, when you pass Grammar Class $prev, or when you finish the $prev celebrations.',
      'جشن‌های $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با تمام کردن جشن‌های $prev باز می‌شوند.',
    );
  }
}
