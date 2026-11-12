import '../models/dialogue_node.dart';

/// Result of the tolerant matching layer.
class LooseMatch {
  final Branch? branch;
  final double score;
  final bool specific;
  const LooseMatch(this.branch, this.score, {this.specific = false});
}

/// Tolerant understanding of free typed or spoken replies (owner t306 item 2), fully offline.
///
/// Runs only after the strict keyword matcher found nothing. It folds the reply and every keyword into one
/// canonical form (contractions, digits, US/UK spelling, a small British-English synonym table, plural / -ing /
/// -ed endings), allows speech-recognition slips (one edit or a swap for words of 5+ letters, two for 9+), and
/// also accepts a reply that uses at least two distinctive content words of a branch's own model reply.
/// Safety rails: negation must agree, a reply carrying unknown content words must hit a lesson word, and a
/// word shared with a sibling branch never counts as "distinctive".
abstract final class Understand {
  static const _contractions = {
    "i'm": 'i am',
    "you're": 'you are',
    "we're": 'we are',
    "they're": 'they are',
    "he's": 'he is',
    "she's": 'she is',
    "it's": 'it is',
    "that's": 'that is',
    "there's": 'there is',
    "what's": 'what is',
    "where's": 'where is',
    "how's": 'how is',
    "who's": 'who is',
    "let's": 'let us',
    "i've": 'i have',
    "you've": 'you have',
    "we've": 'we have',
    "they've": 'they have',
    "i'd": 'i would',
    "you'd": 'you would',
    "we'd": 'we would',
    "they'd": 'they would',
    "he'd": 'he would',
    "she'd": 'she would',
    "i'll": 'i will',
    "you'll": 'you will',
    "we'll": 'we will',
    "they'll": 'they will',
    "it'll": 'it will',
    "that'll": 'that will',
    "don't": 'do not',
    "doesn't": 'does not',
    "didn't": 'did not',
    "can't": 'cannot',
    "won't": 'will not',
    "isn't": 'is not',
    "aren't": 'are not',
    "wasn't": 'was not',
    "weren't": 'were not',
    "haven't": 'have not',
    "hasn't": 'has not',
    "hadn't": 'had not',
    "shouldn't": 'should not',
    "wouldn't": 'would not',
    "couldn't": 'could not',
    "mustn't": 'must not',
    "shan't": 'shall not',
    "needn't": 'need not',
    "y'all": 'you all',
    'gonna': 'going to',
    'wanna': 'want to',
    'gotta': 'got to',
    'dont': 'do not',
    'doesnt': 'does not',
    'didnt': 'did not',
    'cant': 'cannot',
    'wont': 'will not',
    'isnt': 'is not',
    'arent': 'are not',
    'wasnt': 'was not',
    'im': 'i am',
    'ive': 'i have',
    'youre': 'you are',
    'thats': 'that is',
  };

  static const _digits = {
    '0': 'zero',
    '1': 'one',
    '2': 'two',
    '3': 'three',
    '4': 'four',
    '5': 'five',
    '6': 'six',
    '7': 'seven',
    '8': 'eight',
    '9': 'nine',
    '10': 'ten',
    '11': 'eleven',
    '12': 'twelve',
    '15': 'fifteen',
    '20': 'twenty',
    '30': 'thirty',
    '50': 'fifty',
    '100': 'hundred',
  };

  /// US → UK spelling (whole words; -ize/-yze endings are handled by rule).
  static const _spelling = {
    'color': 'colour',
    'favorite': 'favourite',
    'favor': 'favour',
    'neighbor': 'neighbour',
    'neighbors': 'neighbours',
    'center': 'centre',
    'theater': 'theatre',
    'meter': 'metre',
    'liter': 'litre',
    'practice': 'practise',
    'practicing': 'practising',
    'practiced': 'practised',
    'license': 'licence',
    'program': 'programme',
    'traveling': 'travelling',
    'traveled': 'travelled',
    'canceled': 'cancelled',
    'canceling': 'cancelling',
    'enroll': 'enrol',
    'gray': 'grey',
    'mom': 'mum',
    'jewelry': 'jewellery',
    'pajamas': 'pyjamas',
    'tire': 'tyre',
    'tires': 'tyres',
    'aluminum': 'aluminium',
    'labor': 'labour',
    'honor': 'honour',
    'humor': 'humour',
    'behavior': 'behaviour',
    'catalog': 'catalogue',
    'diarrhea': 'diarrhoea',
    'pediatrician': 'paediatrician',
    'anemia': 'anaemia',
    'fiber': 'fibre',
    'defense': 'defence',
    'offense': 'offence',
  };

  /// Small British-English synonym table (meaning-safe pairs only), folded to the lesson's British word.
  static const _synonyms = {
    'apartment': 'flat',
    'elevator': 'lift',
    'cellphone': 'mobile',
    'trash': 'rubbish',
    'garbage': 'rubbish',
    'vacation': 'holiday',
    'restroom': 'toilet',
    'washroom': 'toilet',
    'loo': 'toilet',
    'drugstore': 'chemist',
    'pharmacy': 'chemist',
    'sidewalk': 'pavement',
    'subway': 'underground',
    'tube': 'underground',
    'cookie': 'biscuit',
    'cookies': 'biscuits',
    'fries': 'chips',
    'candy': 'sweets',
    'zip': 'postcode',
    'zipcode': 'postcode',
    'mail': 'post',
    'mailbox': 'postbox',
    'parcel': 'package',
    'purchase': 'buy',
    'reserve': 'book',
    'reservation': 'booking',
    'assist': 'help',
    'assistance': 'help',
    'physician': 'doctor',
    'medic': 'doctor',
    'kid': 'child',
    'kids': 'children',
    'diaper': 'nappy',
    'diapers': 'nappies',
    'stroller': 'pushchair',
    'faucet': 'tap',
    'movie': 'film',
    'movies': 'films',
    'soccer': 'football',
    'gasoline': 'petrol',
    'truck': 'lorry',
    'roundtrip': 'return',
    'schedule': 'timetable',
    'check-up': 'checkup',
    'okay': 'ok',
    'alright': 'ok',
    'hiya': 'hello',
  };

  static final _wordRe = RegExp(r"[a-z0-9']+");

  static const _weak = {
    'a',
    'an',
    'the',
    'i',
    'me',
    'my',
    'you',
    'your',
    'we',
    'us',
    'it',
    'to',
    'for',
    'of',
    'and',
    'or',
    'with',
    'in',
    'on',
    'at',
    'can',
    'could',
    'would',
    'will',
    'shall',
    'should',
    'please',
    'yes',
    'yeah',
    'ok',
    'thanks',
    'thank',
    'just',
    'really',
    'very',
    'some',
    'do',
    'does',
    'did',
    'is',
    'are',
    'am',
    'was',
    'were',
    'be',
    'been',
    'have',
    'has',
    'had',
    'that',
    'this',
    'these',
    'those',
    'want',
    'like',
    'its',
    'hi',
    'hello',
    'hey',
    'excuse',
    'sorry',
    'oh',
    'ah',
    'um',
    'well',
    'so',
    'but',
    'if',
    'up',
    'out',
    'there',
    'here',
    'what',
    'when',
    'how',
    'who',
    'which',
    'from',
    'about',
    'into',
    'over',
    'then',
    'than',
    'too',
    'also',
    'bit',
    'one',
    'ta',
    'cheers',
    'lovely',
    'love',
    'nice',
    'great',
    'good',
    'right',
    'mate',
    'morning',
    'he',
    'she',
    'they',
    'them',
    'his',
    'her',
    'their',
    'our',
    'by',
    'as',
    'all',
    'any',
    'get',
    'got',
    'go',
    'going',
    'let',
    'make',
    'need',
    'know',
    'think',
    'thing',
    'things',
    'much',
    'many',
    'more',
    'most',
    'not',
    'no',
    'maybe',
    'sure',
    'still',
    'again',
    'now',
    'today',
    'time',
    'way',
    'say',
    'said',
    'tell',
    'ask',
    'take',
    'give',
    'keep',
    'come',
    'see',
    'look',
    'put',
    'use',
  };

  static const _neg = {'no', 'not', 'never', 'cannot', 'nothing', 'neither', 'nor', 'none', 'nobody', 'nowhere'};

  /// Canonical tokens of a phrase.
  static List<String> tokens(String s) {
    final out = <String>[];
    for (final m in _wordRe.allMatches(s.toLowerCase().replaceAll('’', "'"))) {
      var w = m.group(0)!;
      final c = _contractions[w];
      if (c != null) {
        out.addAll(c.split(' '));
        continue;
      }
      w = w.replaceAll("'", '');
      if (w.isEmpty) continue;
      w = _digits[w] ?? w;
      out.add(canon(w));
    }
    return out;
  }

  /// Words without expanding contractions (apostrophes dropped), for comparing a reply with a model reply.
  static List<String> rawTokens(String s) => [
    for (final m in _wordRe.allMatches(s.toLowerCase().replaceAll('’', "'")))
      if (m.group(0)!.replaceAll("'", '').isNotEmpty) canon(_digits[m.group(0)!] ?? m.group(0)!.replaceAll("'", '')),
  ];

  /// One word folded to its canonical British form (spelling, synonyms). Endings are compared by [near].
  static String canon(String w) {
    w = _spelling[w] ?? w;
    if (w.length > 5 && w.endsWith('yze')) w = '${w.substring(0, w.length - 3)}yse';
    if (w.length > 5 && (w.endsWith('ize') || w.endsWith('izes') || w.endsWith('ized') || w.endsWith('izing'))) w = w.replaceFirstMapped(RegExp(r'iz(e|es|ed|ing)$'), (m) => 'is${m[1]}');
    return _synonyms[w] ?? w;
  }

  /// Light stem: plural, -ing, -ed (only when a 3+ letter base remains).
  static String stem(String w) {
    if (w.length >= 6 && w.endsWith('ing')) return _undouble(w.substring(0, w.length - 3));
    if (w.length >= 5 && w.endsWith('ied')) return '${w.substring(0, w.length - 3)}y';
    if (w.length >= 5 && w.endsWith('ed') && !w.endsWith('eed')) return _undouble(w.substring(0, w.length - 2));
    if (w.length >= 5 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.length >= 5 && (w.endsWith('ches') || w.endsWith('shes') || w.endsWith('sses') || w.endsWith('xes'))) return w.substring(0, w.length - 2);
    if (w.length >= 4 && w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) return w.substring(0, w.length - 1);
    if (w.length >= 7 && w.endsWith('e')) return w.substring(0, w.length - 1); // practise / practis(ing)
    return w;
  }

  static String _undouble(String w) {
    if (w.length >= 4 && w[w.length - 1] == w[w.length - 2] && !'aeiouls'.contains(w[w.length - 1])) return w.substring(0, w.length - 1);
    if (w.length >= 5 && w.endsWith('e')) return w.substring(0, w.length - 1);
    return w;
  }

  static bool weak(String t) => t.length <= 2 || _weak.contains(t);

  /// Equal, or a recognition / spelling slip: one edit or adjacent swap for 5+ letters, two edits for 9+.
  static bool near(String a, String b) {
    if (a == b) return true;
    if (a.length >= 3 && b.length >= 3 && stem(a) == stem(b)) return true;
    final n = a.length < b.length ? a.length : b.length;
    if (n < 5) return false;
    final max = n >= 9 ? 2 : 1;
    if ((a.length - b.length).abs() > max) return false;
    return _dist(a, b, max) <= max;
  }

  /// Optimal string alignment distance with an early cut-off.
  static int _dist(String a, String b, int cut) {
    final m = a.length, n = b.length;
    var prev2 = List<int>.filled(n + 1, 0), prev = List<int>.generate(n + 1, (j) => j), cur = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      cur[0] = i;
      var rowMin = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] && prev2[j - 2] + 1 < v) v = prev2[j - 2] + 1;
        cur[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > cut) return cut + 1;
      final t = prev2;
      prev2 = prev;
      prev = cur;
      cur = t;
    }
    return prev[n];
  }

  static bool _phrase(List<String> tokens, List<String> parts) {
    if (parts.isEmpty) return false;
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < parts.length; j++) {
        if (!near(tokens[i + j], parts[j])) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  static bool _negated(List<String> t) => t.any(_neg.contains);

  /// Distinctive content words of each branch's model reply: not weak, 4+ letters, not used by a sibling branch.
  static List<Set<String>> _distinctive(DialogueNode node) {
    final words = [
      for (final b in node.branches)
        {
          for (final t in tokens(b.suggestion))
            if (!weak(t) && t.length >= 4 && !_neg.contains(t)) t,
        },
    ];
    final kw = [
      for (final b in node.branches) {for (final k in b.keywords) ...tokens(k)},
    ];
    return [
      for (var i = 0; i < words.length; i++)
        {
          for (final w in words[i])
            if (![
              for (var j = 0; j < words.length; j++)
                if (j != i) ...words[j],
              for (var j = 0; j < kw.length; j++)
                if (j != i) ...kw[j],
            ].any((o) => near(o, w)))
              w,
        },
    ];
  }

  static LooseMatch match(DialogueNode node, String input) {
    final t = tokens(input);
    if (t.isEmpty || node.branches.isEmpty) return const LooseMatch(null, 0);
    // The model reply itself, with slips (also inside contractions): always its own branch.
    final raw = rawTokens(input);
    for (final b in node.branches) {
      final st = tokens(b.suggestion), sr = rawTokens(b.suggestion);
      bool same(List<String> x, List<String> y) =>
          x.length == y.length && (x.length > 1 || (x.isNotEmpty && x.first.length >= 5)) && [for (var i = 0; i < x.length; i++) near(x[i], y[i])].every((v) => v);
      if (same(st, t) || same(sr, raw)) return LooseMatch(b, 1, specific: st.any((w) => !weak(w)));
    }
    final negated = _negated(t);
    final distinct = _distinctive(node);
    final known = <String>[
      for (final b in node.branches) ...[for (final k in b.keywords) ...tokens(k), ...tokens(b.suggestion)],
    ];
    final leftover = [
      for (final w in t)
        if (!weak(w) && !known.any((k) => near(k, w))) w,
    ];
    Branch? best;
    var bestScore = 0.0;
    var bestSpecific = false;
    for (var i = 0; i < node.branches.length; i++) {
      final b = node.branches[i];
      final hits = [
        for (final k in b.keywords)
          if (_phrase(t, tokens(k))) k,
      ];
      // Negation: a negated reply is only accepted through a keyword that itself carries the negation (as in the
      // strict matcher); a model reply that says "no" is never reached by a reply without one.
      if (negated && !hits.any((k) => _negated(tokens(k)))) continue;
      if (!negated && _negated(tokens(b.suggestion)) && hits.isEmpty) continue;
      final specificKw = hits.any((k) => tokens(k).any((p) => !weak(p)));
      final implicit = [
        for (final w in distinct[i])
          if (t.any((x) => near(x, w))) w,
      ];
      // More unknown content words than understood ones: the reply is about something else.
      final content = {for (final k in hits) ...tokens(k).where((p) => !weak(p)), ...implicit};
      if (leftover.length > content.length) continue;
      var score = 0.0;
      for (final k in hits) {
        score += tokens(k).length > 1 ? 2 : 1;
      }
      final implicitOk = implicit.length >= 2;
      if (implicitOk) score += implicit.length * .5;
      if (score == 0) continue;
      final specific = specificKw || implicitOk;
      if (!specific && leftover.isNotEmpty) continue;
      if (!specificKw && !implicitOk) continue;
      if (score > bestScore) {
        bestScore = score;
        best = b;
        bestSpecific = specific;
      } else if (score == bestScore && best != null) {
        best = null; // a tie between branches is not understanding
        bestSpecific = false;
      }
    }
    return LooseMatch(best, bestScore, specific: bestSpecific);
  }
}
