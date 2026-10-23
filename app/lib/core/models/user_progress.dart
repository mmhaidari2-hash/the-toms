import 'dart:convert';

class LeitnerCard {
  final String word, fa;
  final int box; // 1..5
  final DateTime due;
  /// Where it came from: an example sentence (and who says it, for its recorded British audio) and the screen.
  final String ex, exSp, src;
  const LeitnerCard(this.word, this.fa, this.box, this.due, {this.ex = '', this.exSp = '', this.src = ''});
  LeitnerCard moved(int box, DateTime due) => LeitnerCard(word, fa, box, due, ex: ex, exSp: exSp, src: src);
  Map<String, dynamic> toJson() => {'w': word, 'fa': fa, 'b': box, 'd': due.toIso8601String(), if (ex.isNotEmpty) 'x': ex, if (exSp.isNotEmpty) 'xs': exSp, if (src.isNotEmpty) 's': src};
  factory LeitnerCard.fromJson(Map<String, dynamic> j) =>
      LeitnerCard(j['w'], j['fa'] ?? '', j['b'], DateTime.parse(j['d']), ex: j['x'] ?? '', exSp: j['xs'] ?? '', src: j['s'] ?? '');
}

class DailyStats {
  final String date;
  final int conversations, wordsUsed;
  const DailyStats(this.date, this.conversations, this.wordsUsed);
}

class DiaryEntry {
  final DateTime at;
  final String sceneId, characterId;
  final int trust;
  final List<String> words;

  /// Transcript: each line is [speakerId or 'me', english, persian?].
  final List<List<String>> lines;
  const DiaryEntry(this.at, this.sceneId, this.characterId, this.trust, this.words, this.lines);
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 's': sceneId, 'c': characterId, 't': trust, 'w': words, 'l': lines};
  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(DateTime.parse(j['at']), j['s'], j['c'], j['t'], List<String>.from(j['w']), [for (final l in j['l']) List<String>.from(l)]);
}

/// Narrative SRS item: a learned or recast phrase, owned by the character who will bring it back.
class SrsItem {
  final String phrase, fa, characterId, kind, sceneId; // kind: 'learned' | 'recast'
  final DateTime due;
  const SrsItem(this.phrase, this.fa, this.characterId, this.kind, this.sceneId, this.due);
  Map<String, dynamic> toJson() => {'p': phrase, 'fa': fa, 'c': characterId, 'k': kind, 's': sceneId, 'd': due.toIso8601String()};
  factory SrsItem.fromJson(Map<String, dynamic> j) => SrsItem(j['p'], j['fa'] ?? '', j['c'], j['k'], j['s'] ?? '', DateTime.parse(j['d']));
}

/// A frozen snapshot of how a character spoke at a milestone (Sec 7.11 archive).
class ArchiveEntry {
  final DateTime at;
  final String characterId, milestoneId, sceneId;
  final List<List<String>> lines;
  const ArchiveEntry(this.at, this.characterId, this.milestoneId, this.sceneId, this.lines);
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'c': characterId, 'm': milestoneId, 's': sceneId, 'l': lines};
  factory ArchiveEntry.fromJson(Map<String, dynamic> j) => ArchiveEntry(DateTime.parse(j['at']), j['c'], j['m'], j['s'], [for (final l in j['l']) List<String>.from(l)]);
}

/// Accent Passport stamp, earned when a character reaches a milestone.
class Stamp {
  final String characterId, milestoneId, accent;
  final DateTime at;
  const Stamp(this.characterId, this.milestoneId, this.accent, this.at);
  Map<String, dynamic> toJson() => {'c': characterId, 'm': milestoneId, 'a': accent, 'at': at.toIso8601String()};
  factory Stamp.fromJson(Map<String, dynamic> j) => Stamp(j['c'], j['m'], j['a'], DateTime.parse(j['at']));
}

class WeeklyStats {
  final String week;
  final int chats, trust;
  const WeeklyStats(this.week, this.chats, this.trust);
}

class UserProgress {
  final Map<String, double> growthMap; // characterId -> 0..100
  final Map<String, String> milestoneMap; // characterId -> milestone id
  final Map<String, LeitnerCard> leitnerBox; // word -> card
  final Map<String, int> trustMap; // characterId -> raw trust
  final Map<String, int> successMap; // characterId -> successful branches
  final Map<String, int> accentPassport; // accent -> stamps
  final Set<String> unlockedScenes, completedScenes;
  final DailyStats daily;
  final int streak;
  final String? lastActive;
  final bool unlockAll;
  final List<String> rewards;
  final WeeklyStats weekly;
  final String lang;
  final int startTier;
  final bool onboarded;
  final List<DiaryEntry> diary;
  final Map<String, double> moodMap;
  final List<SrsItem> srsQueue;
  final Map<String, String> pendingMilestoneWords;
  final Map<String, String> missionsDone;
  final Map<String, String> mistakes;
  final List<Stamp> stamps;
  final List<ArchiveEntry> replayArchive;
  final String role;

  const UserProgress({
    this.growthMap = const {},
    this.milestoneMap = const {},
    this.leitnerBox = const {},
    this.trustMap = const {},
    this.successMap = const {},
    this.accentPassport = const {},
    this.unlockedScenes = const {},
    this.completedScenes = const {},
    this.daily = const DailyStats('', 0, 0),
    this.streak = 0,
    this.lastActive,
    this.unlockAll = false,
    this.moodMap = const {},
    this.diary = const [],
    this.onboarded = false,
    this.startTier = 0,
    this.lang = 'fa',
    this.weekly = const WeeklyStats('', 0, 0),
    this.rewards = const [],
    this.srsQueue = const [],
    this.pendingMilestoneWords = const {},
    this.missionsDone = const {},
    this.mistakes = const {},
    this.stamps = const [],
    this.replayArchive = const [],
    this.role = 'mehdi',
  });

  UserProgress copyWith({
    Map<String, double>? growthMap,
    Map<String, String>? milestoneMap,
    Map<String, LeitnerCard>? leitnerBox,
    Map<String, int>? trustMap,
    Map<String, int>? successMap,
    Map<String, int>? accentPassport,
    Set<String>? unlockedScenes,
    Set<String>? completedScenes,
    DailyStats? daily,
    int? streak,
    String? lastActive,
    bool? unlockAll,
    Map<String, double>? moodMap,
    List<DiaryEntry>? diary,
    bool? onboarded,
    int? startTier,
    String? lang,
    WeeklyStats? weekly,
    List<String>? rewards,
    List<SrsItem>? srsQueue,
    Map<String, String>? pendingMilestoneWords,
    Map<String, String>? missionsDone,
    Map<String, String>? mistakes,
    List<Stamp>? stamps,
    List<ArchiveEntry>? replayArchive,
    String? role,
  }) => UserProgress(
    growthMap: growthMap ?? this.growthMap,
    milestoneMap: milestoneMap ?? this.milestoneMap,
    leitnerBox: leitnerBox ?? this.leitnerBox,
    trustMap: trustMap ?? this.trustMap,
    successMap: successMap ?? this.successMap,
    accentPassport: accentPassport ?? this.accentPassport,
    unlockedScenes: unlockedScenes ?? this.unlockedScenes,
    completedScenes: completedScenes ?? this.completedScenes,
    daily: daily ?? this.daily,
    streak: streak ?? this.streak,
    lastActive: lastActive ?? this.lastActive,
    unlockAll: unlockAll ?? this.unlockAll,
    moodMap: moodMap ?? this.moodMap,
    diary: diary ?? this.diary,
    onboarded: onboarded ?? this.onboarded,
    startTier: startTier ?? this.startTier,
    lang: lang ?? this.lang,
    weekly: weekly ?? this.weekly,
    rewards: rewards ?? this.rewards,
    srsQueue: srsQueue ?? this.srsQueue,
    pendingMilestoneWords: pendingMilestoneWords ?? this.pendingMilestoneWords,
    missionsDone: missionsDone ?? this.missionsDone,
    mistakes: mistakes ?? this.mistakes,
    stamps: stamps ?? this.stamps,
    replayArchive: replayArchive ?? this.replayArchive,
    role: role ?? this.role,
  );

  String encode() => jsonEncode({
    'growth': growthMap,
    'milestone': milestoneMap,
    'leitner': {for (final e in leitnerBox.entries) e.key: e.value.toJson()},
    'trust': trustMap,
    'success': successMap,
    'passport': accentPassport,
    'unlocked': unlockedScenes.toList(),
    'completed': completedScenes.toList(),
    'daily': [daily.date, daily.conversations, daily.wordsUsed],
    'streak': streak,
    'last': lastActive,
    'all': unlockAll,
    'mood': moodMap,
    'diary': [for (final d in diary) d.toJson()],
    'onb': onboarded,
    'st': startTier,
    'lang': lang,
    'wk': [weekly.week, weekly.chats, weekly.trust],
    'rw': rewards,
    'srs': [for (final a in srsQueue) a.toJson()],
    'pmw': pendingMilestoneWords,
    'mis': missionsDone,
    'mist': mistakes,
    'stamps': [for (final a in stamps) a.toJson()],
    'arch': [for (final a in replayArchive) a.toJson()],
    'role': role,
  });

  factory UserProgress.decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final d = j['daily'] as List;
    return UserProgress(
      growthMap: (j['growth'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      milestoneMap: Map<String, String>.from(j['milestone']),
      leitnerBox: (j['leitner'] as Map).map((k, v) => MapEntry(k as String, LeitnerCard.fromJson(Map<String, dynamic>.from(v)))),
      trustMap: Map<String, int>.from(j['trust']),
      successMap: Map<String, int>.from(j['success']),
      accentPassport: Map<String, int>.from(j['passport']),
      unlockedScenes: Set<String>.from(j['unlocked']),
      completedScenes: Set<String>.from(j['completed']),
      daily: DailyStats(d[0], d[1], d[2]),
      streak: j['streak'] ?? 0,
      lastActive: j['last'],
      unlockAll: j['all'] ?? false,
      moodMap: ((j['mood'] ?? {}) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      diary: [for (final d in (j['diary'] ?? const [])) DiaryEntry.fromJson(Map<String, dynamic>.from(d))],
      onboarded: j['onb'] ?? false,
      startTier: j['st'] ?? 0,
      lang: j['lang'] ?? 'fa',
      weekly: j['wk'] == null ? const WeeklyStats('', 0, 0) : WeeklyStats(j['wk'][0], j['wk'][1], j['wk'][2]),
      rewards: List<String>.from(j['rw'] ?? const []),
      srsQueue: [for (final a in (j['srs'] ?? const [])) SrsItem.fromJson(Map<String, dynamic>.from(a))],
      pendingMilestoneWords: Map<String, String>.from(j['pmw'] ?? const {}),
      missionsDone: Map<String, String>.from(j['mis'] ?? const {}),
      mistakes: Map<String, String>.from(j['mist'] ?? const {}),
      stamps: [for (final a in (j['stamps'] ?? const [])) Stamp.fromJson(Map<String, dynamic>.from(a))],
      replayArchive: [for (final a in (j['arch'] ?? const [])) ArchiveEntry.fromJson(Map<String, dynamic>.from(a))],
      role: j['role'] ?? 'mehdi',
    );
  }
}
