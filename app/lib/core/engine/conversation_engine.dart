import '../models/dialogue_node.dart';

class MatchResult {
  final Branch? branch;
  final double score;
  final List<String> matchedWords; // newWords the learner actually used
  const MatchResult(this.branch, this.score, this.matchedWords);
  bool get matched => branch != null;
}

/// Offline, deterministic keyword matcher — no network, no LLM.
class ConversationEngine {
  static String normalise(String s) => ' ${s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  static bool _contains(String norm, String kw) => norm.contains(' ${normalise(kw).trim()} ');

  static MatchResult match(DialogueNode node, String input, {List<String> vocab = const []}) {
    final norm = normalise(input);
    Branch? best;
    var bestScore = 0.0;
    for (final b in node.branches) {
      var score = 0.0;
      for (final k in b.keywords) {
        if (_contains(norm, k)) score += k.contains(' ') ? 2 : 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = b;
      }
    }
    final used = <String>[
      for (final w in vocab)
        if (_contains(norm, w.replaceAll(RegExp(r"[?!]"), ''))) w,
    ];
    return MatchResult(best, bestScore, used);
  }
}
