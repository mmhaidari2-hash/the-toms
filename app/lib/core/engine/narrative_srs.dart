import '../models/dialogue_node.dart';
import '../models/user_progress.dart';

/// Narrative SRS: phrases you learned or were recast on come back the next day,
/// opened by the character assigned to trigger them — inside the story, not as flashcards.
class NarrativeSrs {
  static const maxQueue = 40;

  static DateTime _tomorrow(DateTime now) => DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

  static List<SrsItem> enqueue(List<SrsItem> q, Scene s, DateTime now, {required List<NewWord> learned, required List<(String, String, String)> recasts}) {
    final out = [...q];
    bool has(String p) => out.any((x) => x.phrase.toLowerCase() == p.toLowerCase());
    for (final r in recasts) {
      if (!has(r.$1)) out.add(SrsItem(r.$1, r.$2, r.$3, 'recast', s.id, _tomorrow(now)));
    }
    for (final w in learned.take(2)) {
      if (!has(w.word)) out.add(SrsItem(w.word, w.fa, s.characterId, 'learned', s.id, _tomorrow(now)));
    }
    return out.length > maxQueue ? out.sublist(out.length - maxQueue) : out;
  }

  static SrsItem? dueFor(List<SrsItem> q, String characterId, DateTime now) {
    for (final x in q) {
      if (x.characterId == characterId && !x.due.isAfter(now)) return x;
    }
    return null;
  }

  /// The callback line the character opens with.
  static (String, String) callback(SrsItem x, Scene? origin) {
    final mem = origin?.memory;
    final when = mem == null ? 'we chatted yesterday' : mem.en;
    final whenFa = mem == null ? 'دیروز با هم گپ زدیم' : mem.fa;
    return x.kind == 'recast'
        ? ('Remember yesterday when $when? Go on — say it the British way: “${x.phrase}”', 'یادته دیروز وقتی $whenFa؟ یالا — به سبک بریتانیایی بگو: «${x.phrase}»')
        : ('Remember yesterday when $when? You learned “${x.phrase}” — use it on me today!', 'یادته دیروز وقتی $whenFa؟ «${x.phrase}» را یاد گرفتی — امروز با من به کارش ببر!');
  }

  static List<SrsItem> resolve(List<SrsItem> q, SrsItem x) => [for (final y in q) if (!identical(y, x) && y.phrase != x.phrase) y];
}
