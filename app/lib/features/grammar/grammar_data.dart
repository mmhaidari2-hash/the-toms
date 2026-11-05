import '../../core/platform/asset_text.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Grammar School content (assets/data/grammar.json, built by tool/make_grammar.py).
class GLine {
  final String en, fa;
  const GLine(this.en, this.fa);
}

class GItem {
  /// gap | choose | order | transform
  final String kind, prompt;
  /// gap/choose: answers[0] is right; transform: every accepted answer; order: the sentence.
  final List<String> answers;
  const GItem(this.kind, this.prompt, this.answers);

  List<String> options(int seed) => [...answers]..shuffle(Random(seed));
  List<String> tiles(int seed) {
    final w = answers.first.split(' ');
    for (var s = seed;; s++) {
      final t = [...w]..shuffle(Random(s));
      if (w.length < 2 || t.join(' ') != answers.first) return t;
    }
  }

  static String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[’‘`]'), "'")
      .replaceAll(RegExp(r'[“”"]'), '')
      .replaceAll(RegExp(r'[.!?,;:]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  bool check(String given) => switch (kind) {
        'gap' || 'choose' => given == answers.first,
        _ => answers.any((a) => norm(a) == norm(given)),
      };
  String get shownAnswer => kind == 'gap' ? fill(answers.first) : answers.first;
  /// The gap sentence with [word] in the blank ("I ___ hungry" + "'m" → "I'm hungry").
  String fill(String word) => word.startsWith("'") ? prompt.replaceAll(' ___', word) : prompt.replaceAll('___', word);
}

class GTopic {
  final String id, level, title, titleFa;
  final List<GLine> teach, examples;
  final List<GItem> practice, test;
  final List<String> related;
  const GTopic({required this.id, required this.level, required this.title, required this.titleFa, required this.teach, required this.examples, required this.practice, required this.test, required this.related});
  factory GTopic.fromJson(Map<String, dynamic> j) {
    List<GLine> lines(String k) => [for (final x in j[k] as List) GLine(x['en'], x['fa'])];
    List<GItem> items(String k) => [for (final x in j[k] as List) GItem(x['kind'], x['prompt'], List<String>.from(x['answers']))];
    return GTopic(id: j['id'], level: j['level'], title: j['title'], titleFa: j['titleFa'], teach: lines('teach'), examples: lines('examples'), practice: items('practice'), test: items('test'), related: List<String>.from(j['related'] ?? const []));
  }
}

class GClass {
  final String code, name, nameFa, blurb;
  const GClass(this.code, this.name, this.nameFa, this.blurb);
}

class Grammar {
  static const classes = [
    GClass('A1', 'Beginner', 'مبتدی', 'be, this/that, possessives, there is, have got, present simple & questions, can, imperatives, prepositions, would like'),
    GClass('A2', 'Elementary', 'مقدماتی', 'present continuous, past simple & past continuous, used to, going to & will, countable nouns, comparatives, adverbs, should, verb patterns'),
    GClass('B1', 'Intermediate', 'متوسط', 'present perfect (simple & continuous), past perfect, future forms, zero, first & second conditionals, modals, relative clauses, question tags, phrasal verbs, the passive'),
    GClass('B2', 'Upper-intermediate', 'فوق‌متوسط', 'used to / would / be used to, past perfect continuous, future continuous & perfect, third conditional, unless & in case, reported speech, deduction, contrast linkers'),
    GClass('C1', 'Advanced', 'پیشرفته', 'future perfect continuous, future in the past, inversion, mixed conditionals, wish, cleft sentences, subjunctive, ellipsis, formal style'),
    GClass('C2', 'Proficiency', 'تسلط', 'conditionals without if, tense for tact, will/would for habits, discourse markers, vague language, absolute phrases, I\'d rather / as if, focus adverbs, no matter / the more…, complex noun phrases'),
  ];
  static const pass = 60;
  /// Class final exam: 20 questions drawn from every topic's mini test; 80% earns the class certificate.
  static const examPass = 80;
  static const examSize = 20;
  /// A1–A2 are taught at Maple Grove Primary; B1–C2 at Riverside Adult College (fictional).
  static bool atCollege(String code) => const {'B1', 'B2', 'C1', 'C2'}.contains(code);
  static int courseLevel(String code) => classes.indexWhere((c) => c.code == code) + 1;
  /// The course has 5 levels (A1–C1); Class C2 opens only after Class C1 is passed.
  static bool hasCourseLevel(String code) => courseLevel(code) <= 5;
  static List<GTopic> parse(String raw) => [for (final t in (jsonDecode(raw) as Map)['topics'] as List) GTopic.fromJson(t)];
}

final grammarProvider = FutureProvider<List<GTopic>>((ref) async => Grammar.parse(await loadAssetText('assets/data/grammar.json')));

/// Extra lesson packs outside the A1–C2 ladder, always open, played by the same topic screen:
/// "Common mistakes of Persian speakers" (ids pm_, level PM) and IELTS Life Skills prep (ids ls_, level LS).
final mistakesProvider = FutureProvider<List<GTopic>>((ref) async => Grammar.parse(await loadAssetText('assets/data/mistakes.json')));
final lifeSkillsProvider = FutureProvider<List<GTopic>>((ref) async => Grammar.parse(await loadAssetText('assets/data/lifeskills.json')));
bool isMistakeTopic(String id) => id.startsWith('pm_');
bool isLifeSkillsTopic(String id) => id.startsWith('ls_');
bool isPackTopic(String id) => isMistakeTopic(id) || isLifeSkillsTopic(id);
bool isPackLevel(String level) => level == 'PM' || level == 'LS';
FutureProvider<List<GTopic>> topicSource(String id) => isLifeSkillsTopic(id) ? lifeSkillsProvider : isMistakeTopic(id) ? mistakesProvider : grammarProvider;
String packHome(String level) => level == 'LS' ? '/lifeskills' : '/mistakes';
String packLabel(String level) => level == 'LS' ? 'IELTS Life Skills' : 'Persian speakers';
