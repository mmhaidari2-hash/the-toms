import '../engine/connected_speech.dart';
import '../engine/conversation_engine.dart';
import '../engine/politeness_engine.dart';
import '../engine/recast_engine.dart';
import '../models/dialogue_node.dart';

/// The contract a future FastAPI/LLM layer will satisfy:
///   POST /dialogue  → { npc_reply, recast_tip, connected_speech_xray, trust_delta }
/// Today [OfflineBrain] fulfils it on-device with rules. Swap in a RemoteBrain later
/// without touching the UI — the conversation screen only talks to [DialogueBrain].
class BrainRequest {
  final String sceneId, characterId, nodeId, userText, level;
  final DialogueNode node;
  final List<String> vocab;
  const BrainRequest({required this.sceneId, required this.characterId, required this.node, required this.userText, required this.level, this.vocab = const []}) : nodeId = '';
  Map<String, dynamic> toJson() => {'scene_id': sceneId, 'character_id': characterId, 'node_id': node.id, 'user_text': userText, 'level': level};
}

class BrainReply {
  final String? npcReply; // in-character reply (recast echo / cooler reply); null → follow the authored next line
  final Recast? recastTip;
  final XRay connectedSpeechXray;
  final int trustDelta;
  final Branch? branch;
  final Register register;
  final List<String> usedWords;
  const BrainReply({this.npcReply, this.recastTip, required this.connectedSpeechXray, required this.trustDelta, this.branch, this.register = Register.neutral, this.usedWords = const []});

  Map<String, dynamic> toJson() => {'npc_reply': npcReply, 'recast_tip': recastTip?.toJson(), 'connected_speech_xray': connectedSpeechXray.toJson(), 'trust_delta': trustDelta};
  factory BrainReply.fromJson(Map<String, dynamic> j, DialogueNode node) => BrainReply(
    npcReply: j['npc_reply'],
    recastTip: j['recast_tip'] == null ? null : Recast(j['recast_tip']['echo'] ?? '', j['recast_tip']['original'] ?? '', j['recast_tip']['better'] ?? '', j['recast_tip']['betterFa'] ?? ''),
    connectedSpeechXray: j['connected_speech_xray'] == null ? ConnectedSpeech.of(node) : XRay(node.text, j['connected_speech_xray']['connected'], j['connected_speech_xray']['ipa']),
    trustDelta: j['trust_delta'] ?? 0,
  );
}

abstract class DialogueBrain {
  Future<BrainReply> respond(BrainRequest r);
}

/// Deterministic, offline implementation (keyword branches + recasting + politeness).
class OfflineBrain implements DialogueBrain {
  const OfflineBrain();
  @override
  Future<BrainReply> respond(BrainRequest r) async => respondSync(r);

  BrainReply respondSync(BrainRequest r) {
    final m = ConversationEngine.match(r.node, r.userText, vocab: r.vocab);
    final recast = RecastEngine.recast(r.node, r.userText);
    final pol = PolitenessEngine.score(r.userText);
    final xray = ConnectedSpeech.of(r.node);
    // A recast with no keyword match still moves the story on along the best branch (meaning was clear enough).
    final branch = m.branch ?? (recast != null ? r.node.branches.firstWhere((b) => b.success, orElse: () => r.node.branches.first) : null);
    if (branch == null) return BrainReply(connectedSpeechXray: xray, trustDelta: 0, register: pol.register);
    var trust = branch.trustDelta + pol.bonus;
    String? reply = recast?.echo;
    if (pol.register == Register.blunt) {
      trust = 0;
      // Recasting wins (the learner hears the natural form); otherwise the character just goes cooler.
      reply = recast?.echo ?? r.node.coolReply ?? 'Right.';
    } else if (recast != null) {
      trust = (trust * .6).round();
    }
    return BrainReply(npcReply: reply, recastTip: recast, connectedSpeechXray: xray, trustDelta: trust, branch: branch, register: pol.register, usedWords: m.matchedWords);
  }
}
