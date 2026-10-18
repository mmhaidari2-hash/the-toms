import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Driving theory test prep (assets/data/theory.json, built by tool/make_theory.py). ORIGINAL questions only, written
/// from Highway Code rules and GOV.UK pages (never DVSA's or a commercial bank). Not the official test or DVSA material.
class ThyExpl {
  final String en, fa;
  final int ms;
  const ThyExpl(this.en, this.fa, this.ms);
}

class ThyCard {
  final String front, back, fa;
  const ThyCard(this.front, this.back, this.fa);
}

class ThyQ {
  final String id, q, fa, why, whyFa;
  final List<String> options; // options[0] is right
  final bool tf;
  const ThyQ(this.id, this.q, this.fa, this.options, this.tf, this.why, this.whyFa);
  String get right => options[0];
}

class ThyChapter {
  final String id, title, titleFa;
  final List<String> src;
  final List<ThyExpl> expl;
  final List<ThyCard> cards;
  final List<ThyQ> qs;
  const ThyChapter(this.id, this.title, this.titleFa, this.src, this.expl, this.cards, this.qs);
  factory ThyChapter.fromJson(Map j) => ThyChapter(
    j['id'],
    j['title'],
    j['titleFa'],
    List<String>.from(j['src']),
    [for (final e in j['expl']) ThyExpl(e['en'], e['fa'], (e['ms'] as num).toInt())],
    [for (final c in j['cards']) ThyCard(c['front'], c['back'], c['fa'])],
    [for (final q in j['qs']) ThyQ(q['id'], q['q'], q['fa'], List<String>.from(q['options']), q['tf'] == true, q['why'], q['whyFa'])],
  );
}

class Thy {
  /// Real format (GOV.UK, cars): 50 multiple-choice questions in 57 minutes, pass mark 43 of 50 (86%).
  static const mockQuestions = 50, mockMinutes = 57, passPct = 86, passMark = 43, chapterQuiz = 10;
  static const disclaimer =
      'Not affiliated with or endorsed by DVSA. This is not the official theory test or official revision material. '
      'The questions are our own, written from The Highway Code and GOV.UK pages (Open Government Licence). Study The Highway Code itself too. Book the real test only on GOV.UK.';
  static const disclaimerFa =
      'وابسته به DVSA نیست و مورد تأیید آن نیست. این آزمون رسمی تئوری یا مطالب رسمی آن نیست. سؤال‌ها را خودمان از روی «هایوی کد» و صفحه‌های GOV.UK نوشته‌ایم. خودِ هایوی کد را هم بخوان. آزمون واقعی را فقط در سایت GOV.UK رزرو کن.';
  static const levelNote = 'Best with B1+ English. Persian help is optional: the real test is in English or Welsh (with a British Sign Language option).';
  static const levelNoteFa = 'برای انگلیسی سطح B1 به بالا مناسب‌تر است. کمک فارسی اختیاری است؛ آزمون واقعی به انگلیسی یا ولزی است (با گزینهٔ زبان اشاره).';

  static List<ThyChapter> parse(String raw) => [for (final c in (jsonDecode(raw) as Map)['chapters'] as List) ThyChapter.fromJson(c)];

  /// Shown order of a question's options (TRUE/FALSE stay in that order).
  static List<int> order(ThyQ q, Random r) => q.tf ? (q.options[0] == 'TRUE' ? [0, 1] : [1, 0]) : (List.generate(q.options.length, (i) => i)..shuffle(r));

  /// A chapter quiz: [chapterQuiz] questions from one chapter.
  static List<ThyQ> chapterSet(ThyChapter c, Random r) => (c.qs.toList()..shuffle(r)).take(chapterQuiz).toList();

  /// A mock test: 50 questions spread evenly over the chapters, then shuffled.
  static List<ThyQ> mockSet(List<ThyChapter> cs, Random r) {
    final per = (mockQuestions / cs.length).ceil();
    final pick = [for (final c in cs) ...(c.qs.toList()..shuffle(r)).take(per)]..shuffle(r);
    return pick.take(mockQuestions).toList();
  }

  static int pct(int right, int total) => total == 0 ? 0 : (100 * right / total).round();
  /// The real test: 43 of 50. Shorter quizzes use the same ratio (9 of 10).
  static bool passed(int right, int total) => total > 0 && right * mockQuestions >= passMark * total;
}

final thyProvider = FutureProvider<List<ThyChapter>>((ref) async => Thy.parse(await rootBundle.loadString('assets/data/theory.json')));
