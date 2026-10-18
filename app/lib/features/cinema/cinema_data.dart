import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Cinema & dubbing (assets/data/cinema.json, built by tool/make_cinema.py): short original scenes
/// with the Thompsons. Watch with subtitles, dub one character's lines, answer questions.
class SceneLine {
  final String sp, spName, en, fa;
  /// Length of the rendered clip in ms: the "in time" window when dubbing.
  final int ms;
  const SceneLine(this.sp, this.spName, this.en, this.fa, this.ms);
}

class SceneQuiz {
  final String q;
  final List<String> options; // options[answer] is correct (shuffled for display)
  final int answer;
  const SceneQuiz(this.q, this.options, this.answer);
}

class Scene {
  final String id, level, title, titleFa, still, blurb, blurbFa, dub;
  final List<SceneLine> lines;
  final List<SceneQuiz> quiz;
  const Scene({required this.id, required this.level, required this.title, required this.titleFa, required this.still, required this.blurb, required this.blurbFa, required this.dub, required this.lines, required this.quiz});
  String get stillAsset => 'assets/places/$still.webp';
  /// Characters in order of appearance (the roles you can dub).
  List<SceneLine> get cast {
    final seen = <String>{};
    return [for (final l in lines) if (seen.add(l.sp)) l];
  }
  int get seconds => (lines.fold<int>(0, (a, l) => a + l.ms) / 1000).round();
  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
        id: j['id'],
        level: j['level'],
        title: j['title'],
        titleFa: j['titleFa'],
        still: j['still'],
        blurb: j['blurb'],
        blurbFa: j['blurbFa'],
        dub: j['dub'],
        lines: [for (final l in j['lines'] as List) SceneLine(l['sp'], l['spn'], l['en'], l['fa'], (l['ms'] as num?)?.toInt() ?? 0)],
        quiz: [for (final q in j['quiz'] as List) SceneQuiz(q['q'], List<String>.from(q['options']), q['answer'])],
      );
}

class Cinema {
  static List<Scene> parse(String raw) => [for (final s in (jsonDecode(raw) as Map)['scenes'] as List) Scene.fromJson(s)];
  /// Questions pass mark (percent): 2 of 3.
  static const pass = 60;
  /// A dubbed line counts as "in time" if it ends within the original clip plus this grace.
  static const graceMs = 1200;
  static int quizXp(int pct) => pct >= pass ? (pct >= 100 ? 15 : 10) : 3;
  static int dubXp(int pct) => pct >= 70 ? (pct >= 90 ? 15 : 10) : 3;
}

final cinemaProvider = FutureProvider<List<Scene>>((ref) async => Cinema.parse(await rootBundle.loadString('assets/data/cinema.json')));

/// Which Cinema levels are showing. Same rule as the Library shelves and Grammar School classes:
/// A1 always; a higher level opens when the course reaches it, the previous Grammar class is passed,
/// every scene of the previous level is watched (questions passed), or a scene on it was already started.
class CinemaGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<Scene> scenes;
  CinemaGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.scenes, {bool unlockAll = false})
      : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<Scene> of(String code) => scenes.where((s) => s.level == code).toList();
  bool started(Scene s) => ctrl.cineScore(s.id) != null || ctrl.dubScore(s.id) != null;

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((s) => ctrl.sceneDone(s.id))) return true;
    if (of(code).any(started)) return true;
    return grammar.classOpen(code);
  }

  /// Why a level is shut (EN, FA).
  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code scenes open at Level $lv of the course, when you pass Grammar Class $prev, or when you finish the $prev scenes.',
      'صحنه‌های $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با تمام کردن صحنه‌های $prev باز می‌شوند.',
    );
  }
}
