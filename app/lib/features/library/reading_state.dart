import 'package:flutter/material.dart';

import '../../core/data/providers.dart';
import 'library_data.dart';

/// Reading position, per-book progress and reader settings, kept in the learner's local progress (prefs).
/// Keys: `libPos:<book>` = "chapter:sentence" (exact place to resume), `libMax:<book>` = furthest sentence
/// reached (book-wide index), `libLast` = last book opened, `libOpened:<book>` = 1 once a book was opened.
extension ReadingState on ProgressController {
  (int, int)? readPos(String book) {
    final v = pref('libPos:$book');
    final p = v.split(':');
    if (p.length != 2) return null;
    final c = int.tryParse(p[0]), s = int.tryParse(p[1]);
    return c == null || s == null ? null : (c, s);
  }

  /// Saves the exact place (no write when unchanged, so scrolling does not churn storage).
  void saveReadPos(Book b, int ch, int s) {
    ch = ch.clamp(0, b.chapters.length - 1);
    s = s.clamp(0, b.chapters[ch].sentences.length - 1);
    if (pref('libPos:${b.id}') != '$ch:$s') setPref('libPos:${b.id}', '$ch:$s');
    final g = globalIndex(b, ch, s) + 1;
    if (g > readMax(b.id)) setPref('libMax:${b.id}', '$g');
    if (pref('libLast') != b.id) setPref('libLast', b.id);
  }

  int readMax(String book) => int.tryParse(pref('libMax:$book')) ?? 0;
  String? get lastBook => pref('libLast').isEmpty ? null : pref('libLast');

  /// 0–100: finished books are 100; otherwise the furthest sentence reached.
  int readPercent(Book b) {
    if (bookDone(b.id)) return 100;
    final n = b.sentenceCount;
    if (n == 0) return 0;
    return (readMax(b.id) * 100 / n).floor().clamp(0, 99);
  }

  bool bookStarted(Book b) => readMax(b.id) > 0 || readScore(b.id, 0) != null || bookDone(b.id);

  // ---- Reader settings
  double get readerFont => (double.tryParse(pref('libFont', '19')) ?? 19).clamp(14, 30).toDouble();
  double get readerLine => (double.tryParse(pref('libLine', '1.5')) ?? 1.5).clamp(1.2, 2.2).toDouble();
  ReaderTheme get readerTheme => ReaderTheme.of(pref('libTheme', 'light'));
}

int globalIndex(Book b, int ch, int s) {
  var n = 0;
  for (var i = 0; i < ch && i < b.chapters.length; i++) {
    n += b.chapters[i].sentences.length;
  }
  return n + s;
}

/// Page colours for comfortable reading.
class ReaderTheme {
  final String id, name, nameFa;
  final Color page, text, muted, bar, highlight;
  const ReaderTheme(this.id, this.name, this.nameFa, this.page, this.text, this.muted, this.bar, this.highlight);
  static const light = ReaderTheme('light', 'Light', 'روشن', Color(0xFFFCF8F1), Color(0xFF14203A), Color(0xFF6B7385), Color(0xFFFFFFFF), Color(0x52E9B949));
  static const sepia = ReaderTheme('sepia', 'Sepia', 'کاغذی', Color(0xFFF4ECD8), Color(0xFF4A3727), Color(0xFF8A7560), Color(0xFFEDE2C8), Color(0x5CD9A441));
  static const dark = ReaderTheme('dark', 'Dark', 'تیره', Color(0xFF15171C), Color(0xFFE8E2D4), Color(0xFF9AA0AC), Color(0xFF22252C), Color(0x55B08A2E));
  static const all = [light, sepia, dark];
  static ReaderTheme of(String id) => all.firstWhere((t) => t.id == id, orElse: () => light);
  bool get isDark => id == 'dark';
}
