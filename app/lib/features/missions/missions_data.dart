import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Real-life missions (assets/data/missions.json, built by tool/make_missions.py): small offline challenges
/// in everyday UK life. Prepare the phrases (British audio), "Ready? Go!", then check in afterwards.
/// The app never records anyone: the check-in is the learner's own report.
class MPhrase {
  final String sp, spName, en, fa;
  final int ms;
  const MPhrase(this.sp, this.spName, this.en, this.fa, this.ms);
  factory MPhrase.fromJson(Map<String, dynamic> j) => MPhrase(j['sp'], j['spn'], j['en'], j['fa'], (j['ms'] as num?)?.toInt() ?? 0);
}

class Mission {
  final String id, level, spot, title, titleFa, goal, goalFa;
  final List<MPhrase> say, hear;
  final (String, String) tip;
  final (String, String)? safe;
  const Mission({required this.id, required this.level, required this.spot, required this.title, required this.titleFa, required this.goal, required this.goalFa, required this.say, required this.hear, required this.tip, this.safe});
  String get icon => 'assets/spots/$spot.webp';
  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        id: j['id'],
        level: j['level'],
        spot: j['spot'],
        title: j['title'],
        titleFa: j['titleFa'],
        goal: j['goal'],
        goalFa: j['goalFa'],
        say: [for (final l in j['say'] as List) MPhrase.fromJson(l)],
        hear: [for (final l in j['hear'] as List) MPhrase.fromJson(l)],
        tip: (j['tip']['en'] as String, j['tip']['fa'] as String),
        safe: j['safe'] == null ? null : (j['safe']['en'] as String, j['safe']['fa'] as String),
      );
}

class Missions {
  static List<Mission> parse(String raw) => [for (final m in (jsonDecode(raw) as Map)['missions'] as List) Mission.fromJson(m)];
  /// The ground rules, shown on the Missions screen (EN, FA).
  static const safety = [
    ('Only with people doing their job (café, shop, station or library staff) or people you already know.', 'فقط با کسانی که سر کارشان هستند (کارکنان کافه، مغازه، ایستگاه یا کتابخانه) یا کسانی که از قبل می‌شناسی.'),
    ('Busy public places, in the daytime. Never go anywhere with a stranger or share your address, phone number or bank details.', 'جاهای عمومی و شلوغ، در روز. هیچ‌وقت با غریبه جایی نرو و آدرس، شماره تلفن یا اطلاعات بانکی‌ات را نده.'),
    ('No recording, filming or photos of anyone. The app never uses your microphone on a mission: you just check in afterwards.', 'از هیچ‌کس صدا، فیلم یا عکس نگیر. برنامه در مأموریت هرگز از میکروفونت استفاده نمی‌کند: فقط بعدش گزارش می‌دهی.'),
    ('Not feeling it today? Skip it and practise the phrases at home. Under 18? Go with a parent or carer.', 'امروز حوصله‌اش را نداری؟ ردش کن و عبارت‌ها را در خانه تمرین کن. زیر ۱۸ سال هستی؟ با پدر، مادر یا سرپرستت برو.'),
  ];
  static int xp(int rating) => switch (rating) { 2 => 20, 1 => 15, _ => 3 };
}

final missionsProvider = FutureProvider<List<Mission>>((ref) async => Missions.parse(await rootBundle.loadString('assets/data/missions.json')));

/// Which mission levels are open. Same rule as the Library, Cinema, Radio and Grammar School:
/// A1 always; a higher level opens when the course reaches it, the previous Grammar class is passed,
/// every mission of the previous level is done, or a mission on it was already started.
class MissionGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<Mission> missions;
  MissionGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.missions, {bool unlockAll = false})
      : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<Mission> of(String code) => missions.where((m) => m.level == code).toList();

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((m) => ctrl.missionDone(m.id))) return true;
    if (of(code).any((m) => ctrl.missionRating(m.id) != null || ctrl.missionPending(m.id))) return true;
    return grammar.classOpen(code);
  }

  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code missions open at Level $lv of the course, when you pass Grammar Class $prev, or when you complete the $prev missions.',
      'مأموریت‌های $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با انجام مأموریت‌های $prev باز می‌شوند.',
    );
  }
}
