import '../models/dialogue_node.dart';
import 'conversation_engine.dart';

/// What the character says back, folding the learner's sentence into natural British English,
/// plus a small green tip card. Never a red X.
class Recast {
  final String echo; // in-character recast, e.g. "Oh, you'd love a cuppa? Sure thing!"
  final String original, better, betterFa;
  const Recast(this.echo, this.original, this.better, this.betterFa);
  Map<String, String> toJson() => {'echo': echo, 'original': original, 'better': better, 'betterFa': betterFa};
}

class _Rule {
  final RegExp re;
  final String Function(Match m) echo;
  final String Function(Match m) better;
  final String fa;
  const _Rule(this.re, this.echo, this.better, this.fa);
}

/// Implicit Recasting Engine: authored per-line rules first, then a global table of common learner errors.
class RecastEngine {
  static String _obj(String s) => s.trim().replaceAll(RegExp(r'[.!?]+$'), '');
  static String _brit(String o) => {'tea': 'a cuppa', 'a tea': 'a cuppa', 'water': 'some water', 'bread': 'a loaf', 'coffee': 'a coffee'}[o.toLowerCase()] ?? o;

  static final _global = <_Rule>[
    _Rule(RegExp(r'^\s*(?:please\s+)?give me (.+)$', caseSensitive: false), (m) => "Oh, you'd love ${_brit(_obj(m[1]!))}? Sure thing!", (m) => "Could I grab ${_brit(_obj(m[1]!))}, please? / I'd love ${_brit(_obj(m[1]!))}, cheers.", 'به‌جای «Give me…» بگو «Could I grab…, please?»'),
    _Rule(RegExp(r'^\s*i want (?!to )(.+)$', caseSensitive: false), (m) => "Ah, you'd like ${_brit(_obj(m[1]!))}? No problem.", (m) => "I'd like ${_brit(_obj(m[1]!))}, please.", '«I want» رک است؛ بگو «I\'d like…, please»'),
    _Rule(RegExp(r'^\s*i want to (.+)$', caseSensitive: false), (m) => "Oh, you'd like to ${_obj(m[1]!)}? Course!", (m) => "I'd like to ${_obj(m[1]!)}, if that's alright.", 'بگو «I\'d like to…, if that\'s alright»'),
    _Rule(RegExp(r'\bi am agree\b', caseSensitive: false), (_) => 'You agree? Great minds!', (_) => 'I agree. / Fair enough.', '«agree» فعل است: «I agree»'),
    _Rule(RegExp(r'\bi have (\d+) years\b', caseSensitive: false), (m) => "Oh, you're ${m[1]}? Lovely.", (m) => "I'm ${m[1]}.", 'سن با «be»: «I\'m 30»'),
    _Rule(RegExp(r'\bopen the (light|tv|telly)\b', caseSensitive: false), (m) => 'Turn the ${m[1]} on? Right you are.', (m) => 'Could you turn the ${m[1]} on, please?', 'چراغ را «turn on» می‌کنیم نه «open»'),
    _Rule(RegExp(r'\bmake a (photo|picture)\b', caseSensitive: false), (m) => 'Take a ${m[1]}? Say cheese!', (m) => 'Could you take a ${m[1]}?', 'عکس را «take» می‌کنیم'),
    _Rule(RegExp(r'\bsay me\b', caseSensitive: false), (_) => 'Tell you? Course I will.', (_) => 'Could you tell me…?', '«tell me» نه «say me»'),
    _Rule(RegExp(r'\bhow much (?:is )?(?:the )?cost\b', caseSensitive: false), (_) => 'How much is it? Let me see…', (_) => 'How much is it, please?', 'بگو «How much is it?»'),
    _Rule(RegExp(r'\bwhere is (?:the )?toilet\b', caseSensitive: false), (_) => "The loo? Just down the hall, love.", (_) => "Sorry, where's the loo?", 'بریتانیایی‌ها «loo» می‌گویند'),
    _Rule(RegExp(r'\bi am fine,? thank you,? and you\b', caseSensitive: false), (_) => "Not bad, ta! You alright?", (_) => "Yeah, not bad, you?", 'جواب خودمانی: «Not bad, you?»'),
    _Rule(RegExp(r'^\s*(yes|yeah)\s*[.!]?\s*$', caseSensitive: false), (_) => 'Yes please? Lovely.', (_) => 'Yes, please. / Go on then!', 'وقتی چیزی تعارف می‌شود: «Yes, please»'),
    _Rule(RegExp(r'^\s*no\s*[.!]?\s*$', caseSensitive: false), (_) => 'No thanks? Fair enough.', (_) => 'No, thanks. / I\'m alright, thanks.', 'رد مؤدبانه: «No, thanks»'),
    _Rule(RegExp(r'\bfor me (tea|coffee)\b', caseSensitive: false), (m) => 'A ${m[1]} for you? Coming up!', (m) => "I'll have a ${m[1]}, please.", 'بگو «I\'ll have…, please»'),
  ];

  /// Returns a recast when the input contains a known learner pattern.
  static Recast? recast(DialogueNode node, String input) {
    final norm = ConversationEngine.normalise(input);
    for (final r in node.recasts) {
      if (r.match.any((m) => norm.contains(' ${ConversationEngine.normalise(m).trim()} '))) return Recast(r.echo, input, r.better, r.betterFa);
    }
    for (final r in _global) {
      final m = r.re.firstMatch(input.trim());
      if (m != null) return Recast(r.echo(m), input, r.better(m), r.fa);
    }
    return null;
  }

  /// In-story Ghost Hint: the character half-guesses what you meant (“You mean… the red bus?”).
  static String ghostHint(DialogueNode node) {
    if (node.ghostHint != null) return node.ghostHint!;
    final b = node.branches.firstWhere((b) => b.success, orElse: () => node.branches.first);
    final words = b.suggestion.replaceAll(RegExp(r'[.!?]+$'), '').split(' ');
    final short = words.length > 6 ? '${words.take(6).join(' ')}…' : words.join(' ');
    return 'You mean… “$short”?';
  }
}
