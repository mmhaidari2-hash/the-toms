import '../models/user_progress.dart';

/// Classic 5-box Leitner system. Box n is reviewed after [intervals][n-1] days.
class Leitner {
  static const intervals = [0, 1, 3, 7, 14];

  static LeitnerCard add(String word, String fa, DateTime now, {String ex = '', String exSp = '', String src = ''}) =>
      LeitnerCard(word, fa, 1, now, ex: ex, exSp: exSp, src: src);

  static bool isDue(LeitnerCard c, DateTime now) => !now.isBefore(c.due);

  /// Correct answer promotes one box (max 5); a wrong one sends it back to box 1.
  static LeitnerCard review(LeitnerCard c, bool correct, DateTime now) {
    final box = correct ? (c.box + 1).clamp(1, 5) : 1;
    return c.moved(box, now.add(Duration(days: intervals[box - 1])));
  }

  static List<LeitnerCard> due(Iterable<LeitnerCard> cards, DateTime now) => cards.where((c) => isDue(c, now)).toList()..sort((a, b) => a.box.compareTo(b.box));
}
