import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Driving School dialogues (assets/data/driving.json, built by tool/make_driving.py): English for learning to drive
/// in Britain, each an animated scene with British voices, sound cues, Persian, words and a 3-question quiz.
class DLine {
  final String sp, name, avatar, en, fa;
  final int ms;
  final String? fx; // engine | indicator | brake: played with this line
  const DLine(this.sp, this.name, this.avatar, this.en, this.fa, this.ms, this.fx);
}

class DWord {
  final String w, en, fa;
  const DWord(this.w, this.en, this.fa);
}

class DQ {
  final String q;
  final List<String> options; // options[0] is right (shuffled for display)
  const DQ(this.q, this.options);
}

class DLesson {
  final String id, level, title, titleFa, note, noteFa, icon;
  /// car (starts parked) · road (starts moving) · petrol · garage · home
  final String scene;
  /// A real video for this dialogue (e.g. assets/video/roundabout.mp4). When present it plays instead of the
  /// animated stage; the voices, subtitles and sound cues stay the same.
  final String? videoAsset;
  /// Painting that passes the scene-art rule (setting + no absent main character), else a people-free backdrop.
  final String? img, bg;
  final List<DLine> lines;
  final List<DWord> words;
  final List<DQ> qs;
  final List<String> src;
  const DLesson({required this.id, required this.level, required this.title, required this.titleFa, required this.note, required this.noteFa, required this.scene, this.videoAsset, this.img, this.bg, this.icon = 'garage', required this.lines, required this.words, required this.qs, required this.src});
  bool get inCar => scene == 'car' || scene == 'road';
  factory DLesson.fromJson(Map<String, dynamic> j) => DLesson(
    id: j['id'],
    level: j['level'],
    title: j['title'],
    titleFa: j['titleFa'],
    note: j['note'],
    noteFa: j['noteFa'],
    scene: j['scene'],
    videoAsset: j['video'],
    img: j['img'],
    bg: j['bg'],
    icon: j['icon'] ?? 'garage',
    lines: [for (final l in j['lines'] as List) DLine(l['sp'], l['name'], l['avatar'], l['en'], l['fa'], (l['ms'] as num?)?.toInt() ?? 0, l['fx'])],
    words: [for (final w in j['words'] as List) DWord(w['w'], w['en'], w['fa'])],
    qs: [for (final q in j['qs'] as List) DQ(q['q'], List<String>.from(q['options']))],
    src: List<String>.from(j['src'] ?? const []),
  );

  /// Is the car moving while line [i] plays? Follows the engine/brake cues from the scene's starting state.
  bool movingAt(int i) {
    var m = scene == 'road';
    for (var k = 0; k <= i && k < lines.length; k++) {
      if (lines[k].fx == 'engine') m = true;
      if (lines[k].fx == 'brake') m = false;
    }
    return inCar && m;
  }
}

class Drive {
  static List<DLesson> parse(String raw) => [for (final e in (jsonDecode(raw) as Map)['lessons'] as List) DLesson.fromJson(e)];
  static const pass = 67; // 2 of 3
  static int pct(int right) => (right * 100 / 3).round();
}

final drivingProvider = FutureProvider<List<DLesson>>((ref) async => Drive.parse(await rootBundle.loadString('assets/data/driving.json')));

/// Which dialogue levels are open. Same rule as the Library, Cinema, Radio, Messages, Seasons and Grammar School.
class DriveGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<DLesson> lessons;
  DriveGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.lessons, {bool unlockAll = false}) : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<DLesson> of(String code) => lessons.where((e) => e.level == code).toList();

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((e) => ctrl.driveDone(e.id))) return true;
    if (of(code).any((e) => ctrl.driveScore(e.id) != null)) return true;
    return grammar.classOpen(code);
  }

  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code driving lessons open at Level $lv of the course, when you pass Grammar Class $prev, or when you finish the $prev driving lessons.',
      'درس‌های رانندگی $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با تمام کردن درس‌های رانندگی $prev باز می‌شوند.',
    );
  }
}
