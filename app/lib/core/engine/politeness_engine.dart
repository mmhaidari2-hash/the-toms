import 'conversation_engine.dart';

enum Register { warm, neutral, blunt }

class PolitenessResult {
  final Register register;
  final int bonus; // extra trust for warmth (0..4)
  final List<String> markers;
  const PolitenessResult(this.register, this.bonus, this.markers);
}

/// Pragmatic politeness score (offline, rule-based).
/// Warm markers raise trust; blunt imperatives earn none and cool the reply.
class PolitenessEngine {
  static const warm = [
    'please', 'cheers', 'lovely', 'mind if i', 'would you mind', 'sorry to bother you', 'could i', 'could you', 'would you',
    'thank you', 'thanks', 'ta', 'brilliant', 'if that s ok', 'if you don t mind', 'i d love', 'i d like', 'may i', 'go on then',
  ];
  static const blunt = ['give me', 'gimme', 'bring me', 'i want', 'tell me', 'hurry up', 'do it', 'you must', 'shut up', 'move'];

  static PolitenessResult score(String input) {
    final n = ConversationEngine.normalise(input.replaceAll("'", ' '));
    final found = [for (final w in warm) if (n.contains(' $w ')) w];
    final rude = [for (final w in blunt) if (n.trim().startsWith(w) || n.contains(' $w ')) w];
    if (rude.isNotEmpty && found.isEmpty) return PolitenessResult(Register.blunt, 0, rude);
    if (found.isNotEmpty) return PolitenessResult(Register.warm, found.length.clamp(1, 2) * 2, found);
    return const PolitenessResult(Register.neutral, 0, []);
  }
}
