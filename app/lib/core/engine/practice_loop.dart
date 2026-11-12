import 'pronunciation.dart';

/// One line's speaking practice loop (owner t306 item 4): listen → say → see which words the recognizer heard →
/// retry the coloured words → slow model → try again. It checks WORDS the phone's speech-to-text heard; it is not a
/// phoneme or accent score and must not be presented as one.
class PracticeLoop {
  final String target;
  final List<PronResult> attempts = [];
  PracticeLoop(this.target);

  /// Scores one recognition, choosing the alternative closest to the target (recognizers return several).
  PronResult add(List<String> alternatives) {
    final best = Pronunciation.bestOf([target], alternatives)?.$2 ?? Pronunciation.score(target, '');
    attempts.add(best);
    return best;
  }

  PronResult? get last => attempts.isEmpty ? null : attempts.last;
  int get bestScore => attempts.isEmpty ? 0 : attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);
  bool get passed => bestScore >= Pronunciation.passScore;

  /// Words to focus on next: not heard or only close in the latest try, in sentence order, no repeats.
  List<String> get focusWords {
    final l = last;
    if (l == null) return const [];
    final seen = <String>{};
    return [
      for (final w in l.words)
        if (w.mark != WordMark.good && seen.add(w.word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9£]'), ''))) w.word.replaceAll(RegExp(r'[^A-Za-z0-9£\x27’-]'), ''),
    ].where((w) => w.isNotEmpty).toList();
  }

  /// Short coaching line (EN, FA) after each try.
  (String, String) get tip {
    final l = last;
    if (l == null) return ('Hear the model, then say the line.', 'مدل را بشنو، بعد جمله را بگو.');
    final prev = attempts.length > 1 ? attempts[attempts.length - 2].score : null;
    if (l.score >= 90) return ('Every word came through clearly.', 'همهٔ واژه‌ها واضح شنیده شد.');
    if (l.score >= Pronunciation.passScore) {
      return prev != null && l.score > prev ? ('Better than last time — clear enough. Next line when you are ready.', 'بهتر از دفعهٔ قبل — به اندازهٔ کافی واضح. هر وقت آماده بودی جملهٔ بعد.') : ('Clear enough. Try once more for every word, or go on.', 'به اندازهٔ کافی واضح. یک بار دیگر برای همهٔ واژه‌ها، یا برو جلو.');
    }
    if (attempts.length >= 2 && prev != null && l.score <= prev) {
      return ('Try "Hear slowly", then say just the coloured words.', '«آهسته بشنو» را بزن، بعد فقط واژه‌های رنگی را بگو.');
    }
    return ('Say the coloured words a little more clearly, then the whole line.', 'واژه‌های رنگی را کمی واضح‌تر بگو، بعد کل جمله را.');
  }
}
