import '../../core/platform/asset_text.dart';
import 'dart:convert';

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
  /// Catalogue shelf: one of [Library.categories] ids.
  final String category;
  /// Original author (classics) or '' for the app's own family stories.
  final String author;
  /// Where the text comes from and why it is public domain in the UK (classics only).
  final String source;
  /// 'recorded' = every line has a pre-rendered British clip; 'device' = no clips, read aloud by the
  /// phone's/browser's own text-to-speech voice when the learner asks (clearly labelled).
  final String audio;
  /// True for an unabridged original text (not a graded adaptation).
  final bool original;
  /// Content words worth learning (gloss keys); the app subtracts the learner's own words.
  final List<String> vocab;
  const Book({required this.id, required this.level, required this.title, required this.titleFa, required this.cover, required this.blurb, required this.blurbFa, required this.chapters, required this.gloss, required this.words, this.category = 'fiction', this.author = '', this.source = '', this.audio = 'recorded', this.original = false, this.vocab = const []});
  String get coverAsset => 'assets/places/$cover.webp';
  bool get deviceVoice => audio == 'device';
  int get sentenceCount => chapters.fold(0, (a, c) => a + c.sentences.length);
  /// Reading time at a comfortable learner pace for the level (words per minute).
  int get minutes => (words / Library.wpm(level)).ceil().clamp(1, 9999);
  int get levelIndex => Library.levels.indexWhere((l) => l.code == level);

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'],
        level: j['level'],
        title: j['title'],
        titleFa: j['titleFa'],
        cover: j['cover'],
        blurb: j['blurb'],
        blurbFa: j['blurbFa'],
        words: j['words'] ?? 0,
        category: j['cat'] ?? 'fiction',
        author: j['author'] ?? '',
        source: j['src'] ?? '',
        audio: j['audio'] ?? 'recorded',
        original: j['orig'] == true,
        vocab: List<String>.from(j['vocab'] ?? const []),
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

class LibraryCategory {
  final String id, name, nameFa;
  const LibraryCategory(this.id, this.name, this.nameFa);
}

class Library {
  /// Library sections, laid out like a British public library (Dewey-style order), one aisle each.
  static const categories = [
    LibraryCategory('fiction', 'Fiction', 'داستان'),
    LibraryCategory('children', "Children's & Easy Reads", 'کودکان و خواندنی‌های آسان'),
    LibraryCategory('poetry', 'Poetry', 'شعر'),
    LibraryCategory('history', 'History', 'تاریخ'),
    LibraryCategory('science', 'Science', 'علم'),
    LibraryCategory('biography', 'Biography', 'زندگی‌نامه'),
    LibraryCategory('uklife', 'Travel & UK Life', 'سفر و زندگی در بریتانیا'),
    LibraryCategory('reference', 'Reference', 'مرجع'),
  ];
  /// Dewey-style shelf mark shown on the aisle sign (decoration, not a real catalogue number).
  static const dewey = {'fiction': 'F', 'children': 'J', 'poetry': '821', 'history': '941', 'science': '500', 'biography': '920', 'uklife': '914.1', 'reference': '030'};
  static LibraryCategory category(String id) => categories.firstWhere((c) => c.id == id, orElse: () => categories[0]);
  /// Comfortable reading pace per level, used for the "~N min" on each card.
  static int wpm(String level) => switch (level) { 'A1' => 50, 'A2' => 70, 'B1' => 90, 'B2' => 110, _ => 130 };
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

final libraryProvider = FutureProvider<List<Book>>((ref) async => Library.parse(await loadAssetText('assets/data/library.json')));

/// One dictionary sense: part of speech, a simple English definition, an example.
class DictSense {
  final String pos, def, example;
  const DictSense(this.pos, this.def, this.example);
}

/// Offline dictionary for the reader's word card (assets/data/library_dict.json, built by tool/make_library.py
/// from Open English WordNet 2025, CC BY 4.0). Persian meanings come from each book's own glossary.
class LibraryDict {
  final Map<String, List<DictSense>> entries;
  const LibraryDict(this.entries);
  static const attribution = 'Definitions: Open English WordNet (CC BY 4.0)';
  static LibraryDict parse(String raw) {
    final e = (jsonDecode(raw) as Map)['entries'] as Map;
    return LibraryDict({
      for (final MapEntry(:key, :value) in e.entries)
        key as String: [for (final s in value as List) DictSense(s[0], s[1], s[2])],
    });
  }

  List<DictSense> of(String key) => entries[key] ?? const [];
}

final libraryDictProvider = FutureProvider<LibraryDict>((ref) async {
  try {
    return LibraryDict.parse(await loadAssetText('assets/data/library_dict.json'));
  } catch (_) {
    return const LibraryDict({});
  }
});
