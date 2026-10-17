import 'dart:math';

/// Per-word pronunciation scoring from a speech-recognition transcript (no audio leaves the device).
/// The recogniser hears words, so "pronunciation" here means: did each target word come through
/// clearly enough to be recognised? Words are aligned (edit distance over words), then each target
/// word is good (recognised, or a homophone/spelling variant), close (similar sounds) or missed.
enum WordMark { good, close, missed }

class WordScore {
  final String word; // as written in the target, punctuation kept for display
  final WordMark mark;
  final String? heard;
  const WordScore(this.word, this.mark, [this.heard]);
}

class PronResult {
  final String target, heard;
  final List<WordScore> words;
  const PronResult(this.target, this.heard, this.words);
  /// 0–100: good words count fully, close words half.
  int get score => words.isEmpty ? 0 : (100 * words.fold<double>(0, (a, w) => a + (w.mark == WordMark.good ? 1 : w.mark == WordMark.close ? .5 : 0)) / words.length).round();
  bool get passed => score >= Pronunciation.passScore;
  List<WordScore> get toPractise => words.where((w) => w.mark != WordMark.good).toList();
}

class Pronunciation {
  static const passScore = 70;

  static const _contractions = {
    "i'm": 'i am', "you're": 'you are', "we're": 'we are', "they're": 'they are', "it's": 'it is', "that's": 'that is',
    "there's": 'there is', "what's": 'what is', "he's": 'he is', "she's": 'she is', "i've": 'i have', "you've": 'you have',
    "we've": 'we have', "i'll": 'i will', "you'll": 'you will', "we'll": 'we will', "i'd": 'i would', "you'd": 'you would',
    "don't": 'do not', "doesn't": 'does not', "didn't": 'did not', "can't": 'cannot', "won't": 'will not', "isn't": 'is not',
    "aren't": 'are not', "wasn't": 'was not', "haven't": 'have not', "let's": 'let us', "shan't": 'shall not', "couldn't": 'could not',
    "shouldn't": 'should not', "wouldn't": 'would not', "o'clock": 'oclock',
  };
  static const _numbers = {
    '0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four', '5': 'five', '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine', '10': 'ten',
    '11': 'eleven', '12': 'twelve', '20': 'twenty', '30': 'thirty', '50': 'fifty', '100': 'hundred',
  };
  // British/American spellings and common recogniser variants count as the same word.
  static const _same = {
    'colour': 'color', 'favourite': 'favorite', 'mum': 'mom', 'theatre': 'theater', 'centre': 'center', 'realise': 'realize', 'organise': 'organize',
    'travelling': 'traveling', 'grey': 'gray', 'cheque': 'check', 'programme': 'program', 'neighbour': 'neighbor', 'okay': 'ok', 'alright': 'all right',
    'mummy': 'mommy', 'cannot': 'can not',
  };
  static const _homophones = [
    {'there', 'their', "they're"}, {'to', 'too', 'two'}, {'for', 'four'}, {'right', 'write'}, {'here', 'hear'}, {'see', 'sea'}, {'by', 'buy', 'bye'},
    {'no', 'know'}, {'new', 'knew'}, {'our', 'hour'}, {'one', 'won'}, {'wear', 'where'}, {'weather', 'whether'}, {'would', 'wood'}, {'peace', 'piece'},
    {'tea', 'tee'}, {'mare', 'mayor'}, {'leyton', 'leighton'}, {'ate', 'eight'}, {'meet', 'meat'}, {'flour', 'flower'}, {'sun', 'son'}, {'week', 'weak'},
  ];

  /// Lower-case word tokens with contractions expanded (keeps a link to the original display word).
  static List<(String, int)> _tokens(String s, {List<String>? display}) {
    final raw = s.replaceAll('’', "'").replaceAll(RegExp(r'[—–\-/]'), ' ').split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    final out = <(String, int)>[];
    for (var i = 0; i < raw.length; i++) {
      final w = raw[i].toLowerCase().replaceAll(RegExp(r"[^a-z0-9'£]"), '').replaceAll(RegExp(r"^'+|'+$"), '');
      if (w.isEmpty) continue;
      display?.add(raw[i]);
      final idx = (display?.length ?? i + 1) - 1;
      final exp = _contractions[w] ?? _numbers[w] ?? w;
      for (final p in exp.split(' ')) {
        out.add((_same[p] ?? p, idx));
      }
    }
    return out;
  }

  static bool _homophone(String a, String b) => _homophones.any((s) => s.contains(a) && s.contains(b));

  static int _lev(String a, String b) {
    if (a == b) return 0;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = [i, ...List.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// A rough sound key: drops vowels after the first letter and merges letters that sound alike.
  static String soundKey(String w) {
    if (w.isEmpty) return w;
    var s = w.replaceAll('ph', 'f').replaceAll('ck', 'k').replaceAll('gh', '').replaceAll('wh', 'w').replaceAll('kn', 'n').replaceAll('wr', 'r').replaceAll(RegExp(r'(.)\1'), r'$1');
    s = s.replaceAll(RegExp('[cqk]'), 'k').replaceAll(RegExp('[sz]'), 's').replaceAll(RegExp('[dt]'), 't').replaceAll(RegExp('[bp]'), 'p').replaceAll(RegExp('[fv]'), 'f').replaceAll(RegExp('[gj]'), 'j');
    return s[0] + s.substring(1).replaceAll(RegExp('[aeiouyhw]'), '');
  }

  /// Similarity 0–1 between a target word and a heard word.
  static double similarity(String t, String h) {
    if (t == h || _homophone(t, h)) return 1;
    final edit = 1 - _lev(t, h) / max(t.length, h.length);
    if (soundKey(t) == soundKey(h) && soundKey(t).length > 1 && edit >= .5) return .9;
    return edit;
  }

  /// Scores one transcript against the target sentence.
  static PronResult score(String target, String heard) {
    final display = <String>[];
    final t = _tokens(target, display: display);
    final h = _tokens(heard).map((e) => e.$1).toList();
    // Word-level alignment (Needleman–Wunsch style), substitution cost from similarity.
    final n = t.length, m = h.length;
    final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      cost[i][0] = i.toDouble();
    }
    for (var j = 1; j <= m; j++) {
      cost[0][j] = j * .6;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        cost[i][j] = [cost[i - 1][j - 1] + (1 - similarity(t[i - 1].$1, h[j - 1])), cost[i - 1][j] + 1, cost[i][j - 1] + .6].reduce(min);
      }
    }
    final best = List<(double, String?)>.filled(n, (0, null));
    var i = n, j = m;
    while (i > 0) {
      if (j > 0 && (cost[i][j] - (cost[i - 1][j - 1] + (1 - similarity(t[i - 1].$1, h[j - 1])))).abs() < 1e-9) {
        best[i - 1] = (similarity(t[i - 1].$1, h[j - 1]), h[j - 1]);
        i--;
        j--;
      } else if (j > 0 && (cost[i][j] - (cost[i][j - 1] + .6)).abs() < 1e-9) {
        j--;
      } else {
        best[i - 1] = (0, null);
        i--;
      }
    }
    // Merge expanded tokens back onto display words: a word is as good as its weakest part.
    final perWord = List<(double, String?)>.filled(display.length, (1, null));
    final seen = <int>{};
    for (var k = 0; k < n; k++) {
      final idx = t[k].$2;
      final cur = perWord[idx];
      perWord[idx] = !seen.contains(idx) || best[k].$1 < cur.$1 ? best[k] : cur;
      seen.add(idx);
    }
    final words = [
      for (var k = 0; k < display.length; k++)
        WordScore(display[k], !seen.contains(k) || perWord[k].$1 >= .85 ? WordMark.good : perWord[k].$1 >= .5 ? WordMark.close : WordMark.missed, perWord[k].$2),
    ];
    return PronResult(target, heard, words);
  }

  /// Best match among several targets (e.g. the reply options) and several recogniser alternatives.
  static (int, PronResult)? bestOf(List<String> targets, List<String> heard) {
    (int, PronResult)? best;
    for (var ti = 0; ti < targets.length; ti++) {
      for (final h in heard.where((h) => h.trim().isNotEmpty)) {
        final r = score(targets[ti], h);
        if (best == null || r.score > best.$2.score) best = (ti, r);
      }
    }
    return best;
  }
}
