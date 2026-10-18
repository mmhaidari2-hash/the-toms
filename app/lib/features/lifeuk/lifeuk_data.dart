import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Life in the UK test prep (assets/data/lifeuk.json, built by tool/make_lifeuk.py). ORIGINAL questions only,
/// on the official handbook's topics, each fact checked against public sources. Not the official test.
class LukExpl {
  final String en, fa;
  final int ms;
  const LukExpl(this.en, this.fa, this.ms);
}

class LukCard {
  final String front, back, fa;
  const LukCard(this.front, this.back, this.fa);
}

class LukQ {
  final String id, q, fa, why, whyFa;
  final List<String> options; // options[0] is right
  final bool tf;
  const LukQ(this.id, this.q, this.fa, this.options, this.tf, this.why, this.whyFa);
  String get right => options[0];
}

class LukChapter {
  final String id, title, titleFa;
  final List<String> src;
  final List<LukExpl> expl;
  final List<LukCard> cards;
  final List<LukQ> qs;
  const LukChapter(this.id, this.title, this.titleFa, this.src, this.expl, this.cards, this.qs);
  factory LukChapter.fromJson(Map j) => LukChapter(
    j['id'],
    j['title'],
    j['titleFa'],
    List<String>.from(j['src']),
    [for (final e in j['expl']) LukExpl(e['en'], e['fa'], (e['ms'] as num).toInt())],
    [for (final c in j['cards']) LukCard(c['front'], c['back'], c['fa'])],
    [for (final q in j['qs']) LukQ(q['id'], q['q'], q['fa'], List<String>.from(q['options']), q['tf'] == true, q['why'], q['whyFa'])],
  );
}

class Luk {
  static const mockQuestions = 24, mockMinutes = 45, passPct = 75, chapterQuiz = 10;
  static const disclaimer =
      'Not affiliated with the Home Office. This is not the official Life in the UK test or official practice material. '
      'The questions are our own, written on the topics of the official handbook, “Life in the United Kingdom: A Guide for New Residents”. Study the handbook too: the real test only uses it. Book the real test only on GOV.UK.';
  static const disclaimerFa =
      'وابسته به وزارت کشور بریتانیا نیست. این آزمون رسمی یا مطالب تمرینی رسمی نیست. سؤال‌ها را خودمان بر پایهٔ موضوع‌های کتاب رسمی نوشته‌ایم. کتاب رسمی را هم بخوان؛ آزمون واقعی فقط از آن سؤال می‌دهد. آزمون واقعی را فقط در سایت GOV.UK رزرو کن.';
  static const levelNote = 'Best with B1+ English. The real test is in English only, so Persian help is optional here.';
  static const levelNoteFa = 'برای انگلیسی سطح B1 به بالا مناسب‌تر است. آزمون واقعی فقط انگلیسی است، پس کمک فارسی اینجا اختیاری است.';

  static List<LukChapter> parse(String raw) => [for (final c in (jsonDecode(raw) as Map)['chapters'] as List) LukChapter.fromJson(c)];

  /// Shown order of a question's options (TRUE/FALSE stay in that order).
  static List<int> order(LukQ q, Random r) => q.tf ? (q.options[0] == 'TRUE' ? [0, 1] : [1, 0]) : (List.generate(q.options.length, (i) => i)..shuffle(r));

  /// A chapter quiz: [chapterQuiz] questions from one chapter.
  static List<LukQ> chapterSet(LukChapter c, Random r) => (c.qs.toList()..shuffle(r)).take(chapterQuiz).toList();

  /// A mock test: 24 questions spread evenly over the chapters, then shuffled.
  static List<LukQ> mockSet(List<LukChapter> cs, Random r) {
    final per = (mockQuestions / cs.length).ceil();
    final pick = [for (final c in cs) ...(c.qs.toList()..shuffle(r)).take(per)]..shuffle(r);
    return pick.take(mockQuestions).toList();
  }

  static int pct(int right, int total) => total == 0 ? 0 : (100 * right / total).round();
  static bool passed(int right, int total) => pct(right, total) >= passPct;
}

final lukProvider = FutureProvider<List<LukChapter>>((ref) async => Luk.parse(await rootBundle.loadString('assets/data/lifeuk.json')));
