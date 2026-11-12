import '../models/dialogue_node.dart';
import 'understand.dart';

class MatchResult {
  final Branch? branch;
  final double score;
  final List<String> matchedWords; // newWords the learner actually used
  /// A lesson word was used, not only please / can / yes.
  final bool specific;
  const MatchResult(this.branch, this.score, this.matchedWords, {this.specific = false});
  bool get matched => branch != null;
}

/// Offline, deterministic keyword matcher — no network, no LLM.
class ConversationEngine {
  static String normalise(String s) => ' ${s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  static const _weak = {
    'a', 'an', 'the', 'i', 'me', 'my', 'you', 'your', 'we', 'us', 'it', 'to', 'for', 'of', 'and', 'or', 'with', 'in', 'on', 'at',
    'can', 'could', 'would', 'please', 'yes', 'yeah', 'ok', 'okay', 'thanks', 'thank', 'just', 'really', 'very', 'some',
    'do', 'does', 'did', 'is', 'are', 'am', 'be', 'have', 'has', 'had', 'that', 'this', 'want', 'like', 'im', 'id', 'ill', 'its',
    'hi', 'hello', 'hey', 'excuse', 'sorry', 'oh', 'ah', 'um', 'well', 'so', 'but', 'if', 'up', 'out', 'there', 'here',
    'what', 'when', 'how', 'who', 'which', 'from', 'about', 'into', 'over', 'then', 'than', 'too', 'also', 'bit', 'one',
    'ta', 'cheers', 'lovely', 'love', 'nice', 'great', 'good', 'alright', 'right', 'mate', 'morning',
  };

  static const _neg = {
    'no', 'not', 'never', 'dont', 'doesnt', 'didnt', 'wont', 'cant', 'cannot', 'isnt', 'arent', 'wasnt', 'werent', 'nothing', 'neither', 'nor',
  };

  static String _fold(String t) => t.replaceAll("'", '');

  static bool _weakWord(String t) => t.length <= 2 || _weak.contains(_fold(t));

  static bool _isNeg(String t) => _neg.contains(_fold(t));

  static List<String> _parts(String kw) => normalise(kw).trim().split(' ').where((p) => p.isNotEmpty).toList();

  static List<String> _tokens(String norm) => norm.trim().split(' ').where((t) => t.isNotEmpty).toList();

  /// One edit is enough for a long word (saffron / safron, please / pleas). Short words stay exact.
  static bool _near(String a, String b) {
    if (a == b) return true;
    if (a.length < 5 || b.length < 5) return false;
    if ((a.length - b.length).abs() > 1) return false;
    if (a.length == b.length) {
      var diff = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) diff++;
        if (diff > 1) return false;
      }
      return diff == 1;
    }
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    var i = 0, j = 0, skipped = false;
    while (i < longer.length && j < shorter.length) {
      if (longer[i] == shorter[j]) {
        i++;
        j++;
      } else if (skipped) {
        return false;
      } else {
        skipped = true;
        i++;
      }
    }
    return true;
  }

  static bool _phrase(List<String> tokens, List<String> parts) {
    if (parts.isEmpty) return false;
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < parts.length; j++) {
        if (tokens[i + j] != parts[j] && !_near(tokens[i + j], parts[j])) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  static bool _specificHits(List<String> hits) => hits.any((k) => _parts(k).any((p) => !_weakWord(p)));

  static List<String> _leftover(List<String> tokens, DialogueNode node) {
    final known = <String>[
      for (final b in node.branches)
        for (final k in b.keywords) ..._parts(k),
    ];
    return [
      for (final t in tokens)
        if (!_weakWord(t) && !known.any((k) => k == t || _near(t, k))) t,
    ];
  }

  /// Matches a free reply. The original strict matcher runs first, unchanged, so every reply that matched before
  /// still reaches the same branch; only when it finds nothing does the tolerant layer ([Understand]) try
  /// contractions, spelling variants, synonyms, word endings, speech-recognition slips and the reply's own wording.
  static MatchResult match(DialogueNode node, String input, {List<String> vocab = const []}) {
    final strict = matchStrict(node, input, vocab: vocab);
    if (strict.branch != null) return strict;
    final loose = Understand.match(node, input);
    return loose.branch == null ? strict : MatchResult(loose.branch, loose.score, strict.matchedWords, specific: loose.specific);
  }

  /// The pre-t306 matcher (kept exactly; regression baseline).
  static MatchResult matchStrict(DialogueNode node, String input, {List<String> vocab = const []}) {
    final norm = normalise(input);
    final tokens = _tokens(norm);
    final used = <String>[
      for (final w in vocab)
        if (_phrase(tokens, _parts(w.replaceAll(RegExp(r'[?!]'), '')))) w,
    ];
    // An authored reply must follow its own branch, even when another branch
    // happens to contain more of its common keywords (yes / could / please).
    final exact = node.branches.where((b) => normalise(b.suggestion) == norm).firstOrNull;
    if (norm.trim().isNotEmpty && exact != null) {
      final hits = [for (final k in exact.keywords) if (_phrase(tokens, _parts(k))) k];
      return MatchResult(exact, 1, used, specific: _specificHits(hits));
    }
    final leftover = _leftover(tokens, node);
    final negated = tokens.any(_isNeg);
    Branch? best;
    var bestScore = 0.0;
    var bestSpecific = false;
    for (final b in node.branches) {
      final hits = [for (final k in b.keywords) if (_phrase(tokens, _parts(k))) k];
      if (hits.isEmpty) continue;
      if (negated && !hits.any((k) => _parts(k).any(_isNeg))) continue;
      final specific = _specificHits(hits);
      // "can" / "please" must not accept a different item (candy) that the lesson never names.
      if (!specific && leftover.isNotEmpty) continue;
      var score = 0.0;
      for (final k in hits) {
        score += k.contains(' ') ? 2 : 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = b;
        bestSpecific = specific;
      }
    }
    return MatchResult(best, bestScore, used, specific: bestSpecific);
  }

  /// Follows a reply that already answers the next question, one step only.
  /// "Do you sell saffron?" at the help line continues with the aisle answer.
  /// A polite "yes please" still stops on the question it has not answered.
  static MatchResult route(Map<String, DialogueNode> nodes, DialogueNode current, String input, {List<String> vocab = const []}) {
    final strict = _route(nodes, current, input, vocab: vocab, m: matchStrict);
    if (strict.branch != null) return strict;
    return _route(nodes, current, input, vocab: vocab, m: match);
  }

  static MatchResult _route(Map<String, DialogueNode> nodes, DialogueNode current, String input,
      {List<String> vocab = const [], required MatchResult Function(DialogueNode, String, {List<String> vocab}) m}) {
    final here = m(current, input, vocab: vocab);
    if (here.branch != null) return _skipAnswered(nodes, here, input, vocab: vocab, m: m);
    final seen = <String>{current.id};
    for (final b in current.branches) {
      final next = b.next == null ? null : nodes[b.next];
      if (next == null || !seen.add(next.id)) continue;
      final hit = m(next, input, vocab: vocab);
      if (hit.branch != null && hit.specific) return _skipAnswered(nodes, hit, input, vocab: vocab, m: m);
    }
    return here;
  }

  static MatchResult _skipAnswered(Map<String, DialogueNode> nodes, MatchResult hit, String input,
      {List<String> vocab = const [], required MatchResult Function(DialogueNode, String, {List<String> vocab}) m}) {
    if (!hit.specific || hit.branch?.next == null) return hit;
    final next = nodes[hit.branch!.next!];
    if (next == null) return hit;
    final further = m(next, input, vocab: vocab);
    if (further.branch == null || !further.specific) return hit;
    return further;
  }
}
