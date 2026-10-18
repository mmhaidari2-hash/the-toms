import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Graded readers (assets/data/library.json, built by tool/make_library.py).
class BookSentence {
  final String en, fa;
  /// [surface, glossKey] pairs; glossKey is '' for spaces/punctuation.
  final List<(String, String)> segs;
  /// Voice id for dialogue (B1+ books: each character reads their own lines); null = narrator.
  final String? sp, spName;
  const BookSentence(this.en, this.fa, this.segs, {this.sp, this.spName});
  String get voice => sp ?? 'narrator';
}

class BookQuiz {
  final String q;
  final List<String> options; // options[answer] is correct (shuffled for display)
  final int answer;
  const BookQuiz(this.q, this.options, this.answer);
}

class BookChapter {
  final String title, titleFa;
  final List<BookSentence> sentences;
  final List<BookQuiz> quiz;
  const BookChapter(this.title, this.titleFa, this.sentences, this.quiz);
}

class Book {
  final String id, level, title, titleFa, cover, blurb, blurbFa;
  final List<BookChapter> chapters;
  final Map<String, String> gloss;
  final int words;
  const Book({required this.id, required this.level, required this.title, required this.titleFa, required this.cover, required this.blurb, required this.blurbFa, required this.chapters, required this.gloss, required this.words});
  String get coverAsset => 'assets/places/$cover.webp';

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'],
        level: j['level'],
        title: j['title'],
        titleFa: j['titleFa'],
        cover: j['cover'],
        blurb: j['blurb'],
        blurbFa: j['blurbFa'],
        words: j['words'] ?? 0,
        gloss: Map<String, String>.from(j['gloss'] ?? const {}),
        chapters: [
          for (final c in j['chapters'] as List)
            BookChapter(
              c['title'],
              c['titleFa'],
              [for (final s in c['sentences'] as List) BookSentence(s['en'], s['fa'], [for (final g in s['segs'] as List) (g[0] as String, g[1] as String)], sp: s['sp'], spName: s['spn'])],
              [for (final q in c['quiz'] as List) BookQuiz(q['q'], List<String>.from(q['options']), q['answer'] ?? 0)],
            ),
        ],
      );
}

class LibraryLevel {
  final String code, name, nameFa;
  const LibraryLevel(this.code, this.name, this.nameFa);
}

class Library {
  static const levels = [
    LibraryLevel('A1', 'Beginner', 'مبتدی'),
    LibraryLevel('A2', 'Elementary', 'مقدماتی'),
    LibraryLevel('B1', 'Intermediate', 'متوسط'),
    LibraryLevel('B2', 'Upper-intermediate', 'فوق‌متوسط'),
    LibraryLevel('C1', 'Advanced', 'پیشرفته'),
  ];
  static List<Book> parse(String raw) => [for (final b in (jsonDecode(raw) as Map)['books'] as List) Book.fromJson(b)];
  /// Quiz pass mark for a chapter (percent).
  static const pass = 50;
  static int chapterXp(int pct) => pct >= pass ? (pct >= 100 ? 15 : 10) : 3;
}

final libraryProvider = FutureProvider<List<Book>>((ref) async => Library.parse(await rootBundle.loadString('assets/data/library.json')));
