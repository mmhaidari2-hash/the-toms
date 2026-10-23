import '../../core/platform/asset_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Hackney Hum, an invented local radio station (assets/data/radio.json, built by tool/make_radio.py).
/// Short segments per level: news, weather, travel, phone-in, adverts. Listening first, then an
/// optional transcript (+ Persian), then comprehension questions.
class RadioLine {
  final String sp, spName, en, fa;
  final int ms;
  const RadioLine(this.sp, this.spName, this.en, this.fa, this.ms);
}

class RadioQuiz {
  final String q;
  final List<String> options; // options[answer] is correct (shuffled for display)
  final int answer;
  const RadioQuiz(this.q, this.options, this.answer);
}

class Segment {
  final String id, level, kind, slot, title, titleFa, blurb, blurbFa;
  final List<RadioLine> lines;
  final List<RadioQuiz> quiz;
  const Segment({required this.id, required this.level, required this.kind, required this.slot, required this.title, required this.titleFa, required this.blurb, required this.blurbFa, required this.lines, required this.quiz});
  int get seconds => (lines.fold<int>(0, (a, l) => a + l.ms) / 1000).round();
  /// Who's on air, in order of appearance.
  List<String> get voices => [...{for (final l in lines) l.spName}];
  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
        id: j['id'],
        level: j['level'],
        kind: j['kind'],
        slot: j['slot'],
        title: j['title'],
        titleFa: j['titleFa'],
        blurb: j['blurb'],
        blurbFa: j['blurbFa'],
        lines: [for (final l in j['lines'] as List) RadioLine(l['sp'], l['spn'], l['en'], l['fa'], (l['ms'] as num?)?.toInt() ?? 0)],
        quiz: [for (final q in j['quiz'] as List) RadioQuiz(q['q'], List<String>.from(q['options']), q['answer'])],
      );
}

class RadioStation {
  static const station = 'Hackney Hum';
  static List<Segment> parse(String raw) => [for (final s in (jsonDecode(raw) as Map)['segments'] as List) Segment.fromJson(s)];
  static const pass = 60;
  static const kinds = {
    'news': ('News', 'اخبار', Icons.article_rounded),
    'weather': ('Weather', 'هواشناسی', Icons.wb_cloudy_rounded),
    'travel': ('Travel', 'رفت‌وآمد', Icons.directions_bus_rounded),
    'phonein': ('Phone-in', 'برنامهٔ تلفنی', Icons.phone_in_talk_rounded),
    'advert': ('Advert', 'آگهی', Icons.campaign_rounded),
  };
}

final radioProvider = FutureProvider<List<Segment>>((ref) async => RadioStation.parse(await loadAssetText('assets/data/radio.json')));

/// Which radio levels are on air. Same rule as the Library, Cinema and Grammar School:
/// A1 always; a higher level opens when the course reaches it, the previous Grammar class is passed,
/// every segment of the previous level is passed, or a segment on it was already started.
class RadioGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<Segment> segments;
  RadioGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.segments, {bool unlockAll = false})
      : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<Segment> of(String code) => segments.where((s) => s.level == code).toList();

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((s) => ctrl.segmentDone(s.id))) return true;
    if (of(code).any((s) => ctrl.radioScore(s.id) != null)) return true;
    return grammar.classOpen(code);
  }

  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code programmes open at Level $lv of the course, when you pass Grammar Class $prev, or when you finish the $prev programmes.',
      'برنامه‌های $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با تمام کردن برنامه‌های $prev باز می‌شوند.',
    );
  }
}
