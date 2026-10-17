class NewWord {
  final String word, fa;
  const NewWord(this.word, this.fa);
  factory NewWord.fromJson(Map<String, dynamic> j) => NewWord(j['word'], j['fa']);
}

class CultureNote {
  final String en, fa;
  const CultureNote(this.en, this.fa);
}

/// Connected-speech "X-Ray": formal text vs. how a Brit actually says it, plus IPA.
class XRay {
  final String formal, connected, ipa;
  const XRay(this.formal, this.connected, this.ipa);
  Map<String, String> toJson() => {'formal': formal, 'connected': connected, 'ipa': ipa};
}

/// Authored recast for a common learner error at this line (Implicit Recasting Engine).
class RecastRule {
  final List<String> match;
  final String echo, better, betterFa;
  const RecastRule(this.match, this.echo, this.better, this.betterFa);
  factory RecastRule.fromJson(Map<String, dynamic> j) => RecastRule(List<String>.from(j['match']), j['echo'], j['better'], j['betterFa'] ?? '');
}

class Branch {
  final List<String> keywords;
  final String suggestion, suggestionFa;
  final int trustDelta;
  final String? next;
  final bool success;
  const Branch({required this.keywords, required this.suggestion, required this.suggestionFa, required this.trustDelta, required this.next, this.success = true});
  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
    keywords: List<String>.from(j['keywords']),
    suggestion: j['suggestion'],
    suggestionFa: j['suggestionFa'],
    trustDelta: j['trustDelta'] ?? 0,
    next: j['next'],
    success: j['success'] ?? true,
  );
}

class DialogueNode {
  final String id, speaker, text;
  final Map<String, String> translations;
  final List<Branch> branches;
  final List<NewWord> newWords;
  final CultureNote? cultureNote;

  /// Pre-recorded audio per speed ('slow' | 'medium' | 'normal'); empty → offline TTS.
  final Map<String, String> audioBySpeed;

  /// Optional in-story Ghost Hint override; otherwise generated from the best branch.
  final String? ghostHint;

  /// Authored connected-speech form (null → rule-generated).
  final XRay? xray;

  /// Cooler, more formal reply used when the learner is blunt (politeness engine).
  final String? coolReply;

  /// Non-verbal surprise event the learner must react to (e.g. William spills jam).
  final CultureNote? event;
  final List<RecastRule> recasts;

  /// Character growth: the line as said in a later family chapter (index -> (en, fa)). Same replies.
  final Map<int, (String, String)> byChapter;
  const DialogueNode({this.byChapter = const {}, this.xray, this.coolReply, this.event, this.recasts = const [], required this.id, required this.speaker, required this.text, required this.translations, required this.branches, required this.newWords, this.cultureNote, this.audioBySpeed = const {}, this.ghostHint});
  bool get isEnd => branches.isEmpty;

  /// All keywords across branches (for UI / tests).
  List<String> get keywords => [for (final b in branches) ...b.keywords];

  /// Max trust that can be earned at this node.
  int get trustDelta => branches.fold(0, (m, b) => b.trustDelta > m ? b.trustDelta : m);

  factory DialogueNode.fromJson(Map<String, dynamic> j) {
    final cn = j['cultureNote'];
    return DialogueNode(
      id: j['id'],
      speaker: j['speaker'],
      text: j['text'],
      translations: Map<String, String>.from(j['translations'] ?? const {}),
      branches: [for (final b in j['branches'] ?? const []) Branch.fromJson(b)],
      newWords: [for (final w in j['newWords'] ?? const []) NewWord.fromJson(w)],
      cultureNote: cn == null ? null : CultureNote(cn['en'], cn['fa']),
      audioBySpeed: Map<String, String>.from(j['audioBySpeed'] ?? const {}),
      ghostHint: j['ghostHint'],
      xray: j['xray'] == null ? null : XRay(j['text'], j['xray']['connected'], j['xray']['ipa']),
      coolReply: j['coolReply'],
      event: j['event'] == null ? null : CultureNote(j['event']['en'], j['event']['fa']),
      recasts: [for (final r in j['recasts'] ?? const []) RecastRule.fromJson(r)],
      byChapter: {for (final e in ((j['byChapter'] ?? const <String, dynamic>{}) as Map<String, dynamic>).entries) int.parse(e.key): (e.value['text'] as String, (e.value['fa'] ?? '') as String)},
    );
  }

  /// This node as spoken in family chapter [ch]: the latest variant at or before it (else the original).
  DialogueNode atChapter(int ch) {
    final keys = byChapter.keys.where((k) => k <= ch).toList()..sort();
    if (keys.isEmpty) return this;
    final (t, fa) = byChapter[keys.last]!;
    return DialogueNode(
      id: id, speaker: speaker, text: t, translations: {...translations, 'fa': fa}, branches: branches, newWords: newWords,
      cultureNote: cultureNote, audioBySpeed: const {}, ghostHint: ghostHint, coolReply: coolReply, event: event, recasts: recasts, byChapter: byChapter,
    );
  }
}

class Scene {
  final String id, characterId, level, title, titleFa, setting, settingFa, start;
  final Map<String, DialogueNode> nodes;
  final String? requiresCharacter, requiresMilestone;

  /// Callback memory used by narrative SRS: “Remember yesterday when …?”
  final CultureNote? memory;

  /// Private family story: needs this much (soft) trust with [characterId].
  final int? requiresTrust;
  final int? episode;

  /// Role switching: this is a variant of [baseId] where the learner speaks as [playAs] and Mehdi is an NPC.
  final String? baseId, playAs;

  /// Career Packs with their own playable guest (e.g. Sara in Vida's Nursery) instead of Mehdi.
  final String? guest;

  /// Optional painting (place id) for scenes not hosted by a place hotspot or lesson.
  final String? placeHint;
  const Scene({this.baseId, this.playAs, this.guest, this.placeHint, this.memory, this.requiresTrust, this.episode, 
    required this.id,
    required this.characterId,
    this.level = 'A1',
    required this.title,
    required this.titleFa,
    required this.setting,
    required this.settingFa,
    required this.start,
    required this.nodes,
    this.requiresCharacter,
    this.requiresMilestone,
  });
  bool get isGated => requiresMilestone != null;
  factory Scene.fromJson(Map<String, dynamic> j) {
    final req = j['requires'];
    return Scene(
      id: j['id'],
      characterId: j['characterId'],
      level: j['level'] ?? 'A1',
      memory: j['memory'] == null ? null : CultureNote(j['memory']['en'], j['memory']['fa']),
      requiresTrust: j['requiresTrust'],
      episode: j['episode'],
      baseId: j['baseId'],
      playAs: j['playAs'],
      guest: j['guest'],
      placeHint: j['place'],
      title: j['title'],
      titleFa: j['titleFa'],
      setting: j['setting'],
      settingFa: j['settingFa'],
      start: j['start'],
      nodes: {for (final e in (j['nodes'] as Map<String, dynamic>).entries) e.key: DialogueNode.fromJson(e.value)},
      requiresCharacter: req?['characterId'],
      requiresMilestone: req?['milestone'],
    );
  }
}

/// TTS speed by CEFR level: slower for beginners, near-natural for advanced.
double speechRateFor(String level) => const {'A0': .36, 'A1': .40, 'A2': .44, 'B1': .48, 'B2': .52, 'C1': .55, 'C2': .58}[level] ?? .45;
