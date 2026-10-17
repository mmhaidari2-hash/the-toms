import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/emotion_engine.dart';
import '../engine/growth_engine.dart';
import '../engine/weekly.dart';
import '../engine/leitner.dart';
import '../engine/mission.dart';
import '../engine/motivation.dart';
export '../engine/motivation.dart';
import '../engine/narrative_srs.dart';
import '../engine/diary_coach.dart';
import '../models/character.dart';
import '../models/dialogue_node.dart';
import '../models/milestone.dart';
import '../models/place.dart';
import '../models/user_progress.dart';
import 'progress_store.dart';
import 'repository.dart';
import 'premium.dart';
export 'premium.dart';

final progressStoreProvider = Provider<ProgressStore>((_) => MemoryProgressStore());
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final contentProvider = FutureProvider<ContentBundle>((ref) => ContentRepository().load());

class TurnOutcome {
  final int trustDelta;
  final double growthBefore, growthAfter;
  final Milestone? reachedMilestone;
  final List<String> unlockedScenes;
  final List<String> promotedWords;
  const TurnOutcome(this.trustDelta, this.growthBefore, this.growthAfter, this.reachedMilestone, this.unlockedScenes, this.promotedWords);
}

String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

class ProgressController extends Notifier<UserProgress> {
  @override
  UserProgress build() {
    final raw = ref.read(progressStoreProvider).read();
    if (raw == null) return const UserProgress();
    try {
      return UserProgress.decode(raw);
    } catch (_) {
      return const UserProgress(); // corrupted save → fresh start rather than crash
    }
  }

  DateTime get _now => ref.read(clockProvider)();
  void _save() => ref.read(progressStoreProvider).write(state.encode());

  int masteredFor(String characterId, ContentBundle c) {
    final words = <String>{
      for (final s in c.scenes.values.where((s) => s.characterId == characterId))
        for (final n in s.nodes.values) ...n.newWords.map((w) => w.word),
    };
    return state.leitnerBox.values.where((w) => w.box == 5 && words.contains(w.word)).length;
  }

  bool isUnlocked(Scene s) => state.unlockAll || !s.isGated || state.unlockedScenes.contains(s.id);

  static const tierGate = 2; // dialogues to finish in a level before the next opens

  int completedInTier(int i, ContentBundle c) => i < 0 || i >= c.tiers.length ? 0 : c.tiers[i].sceneIds.where(state.completedScenes.contains).length;

  bool tierUnlocked(int i, ContentBundle c) => state.unlockAll || i <= state.startTier || completedInTier(i - 1, c) >= tierGate;

  /// Highest unlocked level index — the learner's current level.
  int currentTier(ContentBundle c) {
    var i = 0;
    while (i + 1 < c.tiers.length && tierUnlocked(i + 1, c)) {
      i++;
    }
    return i;
  }

  bool canPlay(Scene s, ContentBundle c) {
    final host = c.places.where((p) => p.sceneIds.contains(s.id)).firstOrNull;
    if (host?.season != null && !placeOpen(host!.id, c)) return false;
    final role = c.roleOfScene(s.id);
    if (role != null && role != state.role && !state.unlockAll) return false;
    if (s.requiresTrust != null && !state.unlockAll && GrowthEngine.softTrust(state.trustMap[s.characterId] ?? 0) < s.requiresTrust!) return false;
    return isUnlocked(s) && tierUnlocked(c.tierIndexOfScene(s.id), c);
  }

  bool placeOpen(String placeId, ContentBundle c) {
    final p = c.place(placeId);
    if (p == null) return false;
    final gated = p.requiresMilestone != null && !state.unlockAll && p.sceneIds.any((id) => !state.unlockedScenes.contains(id));
    final seasonal = p.season == null || state.unlockAll || _now.month == p.season || state.completedScenes.length >= Place.earlyAccessChats;
    return !gated && seasonal && tierUnlocked(c.tierIndexOfPlace(placeId), c);
  }

  void finishOnboarding({required int startTier, required String lang}) {
    state = state.copyWith(onboarded: true, startTier: startTier, lang: lang);
    _save();
  }

  void setStartTier(int tier) {
    state = state.copyWith(startTier: tier);
    _save();
  }

  void setLang(String lang) {
    state = state.copyWith(lang: lang);
    _save();
  }

  /// Sec 3.2: play as the guest Mehdi, or step into Ryan / Tom / Leslie.
  void setRole(String role) {
    state = state.copyWith(role: role);
    _save();
  }

  /// Sec 7.7: the learner writes a diary entry; a family member reacts.
  DiaryFeedback writeDiary(String text, List<Character> family) {
    final now = _now;
    final fb = DiaryCoach.review(text, state.leitnerBox.keys.toList(), family, state.trustMap, seed: now.day);
    final box = {...state.leitnerBox};
    for (final w in fb.vocabUsed) {
      final card = box[w];
      if (card != null) box[w] = Leitner.review(card, true, now);
    }
    final entry = DiaryEntry(now, 'written', fb.reactorId, 2, fb.vocabUsed, [
      ['me', text, ''],
      [fb.reactorId, fb.reaction, fb.reactionFa],
    ]);
    state = state.copyWith(diary: [entry, ...state.diary].take(60).toList(), leitnerBox: box, trustMap: {...state.trustMap, fb.reactorId: (state.trustMap[fb.reactorId] ?? 0) + 2});
    _save();
    return fb;
  }

  /// Narrative SRS item this character should open with today, if any.
  SrsItem? srsDue(String characterId) => NarrativeSrs.dueFor(state.srsQueue, characterId, _now);

  void resolveSrs(SrsItem x) {
    state = state.copyWith(srsQueue: NarrativeSrs.resolve(state.srsQueue, x));
    _save();
  }

  // ---- Course (Level 1…): practice scores live in missionsDone under 'course:<id>' (no schema change).
  int? practiceScore(String id) => int.tryParse(state.missionsDone['course:$id'] ?? '');
  /// Saves the best score and awards XP for every finished practice (replays count too).
  XpAward savePractice(String id, int pct) {
    final old = practiceScore(id) ?? -1;
    if (pct > old) {
      state = state.copyWith(missionsDone: {...state.missionsDone, 'course:$id': '$pct'});
      _save();
    }
    return awardXp(Motivation.practiceXp(pct));
  }

  // ---- Motivation: XP, daily goal, streak + freezes, weekly league, badges (all in missionsDone).
  String _m(String k) => state.missionsDone[k] ?? '';
  int _mi(String k, int d) => int.tryParse(_m(k)) ?? d;
  Map<String, int> get xpLog => Motivation.parseLog(state.missionsDone['xp:log']);
  int get xpTotal => _mi('xp:total', 0);
  int get xpToday => xpLog[Motivation.day(_now)] ?? 0;
  int get xpWeek => Motivation.weekXp(xpLog, _now);
  int get dailyGoal => _mi('pref:goal', Motivation.defaultGoal);
  bool get goalChosen => state.missionsDone.containsKey('pref:goal');
  int get freezes => _mi('freeze', 1);
  int get leagueTier => _mi('league:tier', 0);
  Set<String> get badgesEarned => {for (final k in state.missionsDone.keys) if (k.startsWith('badge:')) k.substring(6)};
  int get goalDays => xpLog.values.where((v) => v >= dailyGoal).length + _mi('goal:old', 0);
  /// The streak as it stands today: it only counts if you practised today or yesterday (or a freeze can cover one missed day).
  int get currentStreak {
    final la = state.lastActive;
    if (la == null) return 0;
    final now = _now;
    if (la == _day(now) || la == _day(now.subtract(const Duration(days: 1)))) return state.streak;
    if (la == _day(now.subtract(const Duration(days: 2))) && freezes > 0) return state.streak;
    return 0;
  }
  void setDailyGoal(int xp) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:goal': '$xp'});
    _save();
  }
  List<(String, int, bool)> leagueBoard() => Motivation.board(WeeklyChallenge.weekKey(_now), leagueTier, xpWeek, _now);
  List<(String, int, bool)> leagueBoardOf(String week, int tier, int xp) => Motivation.board(week, tier, xp, _now);

  /// Adds XP for today, moves the streak on (using a freeze for one missed day), settles last week's
  /// league and unlocks any new badges.
  XpAward awardXp(int xp) {
    final now = _now;
    final today = _day(now), yesterday = _day(now.subtract(const Duration(days: 1))), twoAgo = _day(now.subtract(const Duration(days: 2)));
    final m = {...state.missionsDone};
    var fr = freezes;
    var streak = state.streak;
    var freezeUsed = false;
    final la = state.lastActive;
    if (la != today) {
      if (la == yesterday) {
        streak += 1;
      } else if (la == twoAgo && fr > 0 && streak > 0) {
        fr -= 1;
        streak += 1;
        freezeUsed = true;
      } else {
        streak = 1;
      }
      if (streak > 0 && streak % 7 == 0) fr = (fr + 1).clamp(0, Motivation.maxFreezes); // a freeze for every full week
    }
    // League: settle the previous week the first time we earn XP in a new week.
    final wk = WeeklyChallenge.weekKey(now);
    final lastWk = m['league:week'];
    if (lastWk != null && lastWk != wk) {
      final lastWeekXp = xpLog.entries.where((e) => WeeklyChallenge.weekKey(DateTime.parse(e.key)) == lastWk).fold(0, (a, e) => a + e.value);
      final rows = Motivation.board(lastWk, leagueTier, lastWeekXp, now, ended: true);
      m['league:tier'] = '${Motivation.nextTier(leagueTier, Motivation.rank(rows))}';
    }
    m['league:week'] = wk;
    final log = xpLog;
    final dkey = Motivation.day(now);
    final before = log[dkey] ?? 0;
    log[dkey] = before + xp;
    // Days that fall out of the 21-day log still count towards the "goal 7 times" badge.
    final kept = Motivation.parseLog(Motivation.encodeLog(log));
    final dropped = log.entries.where((e) => !kept.containsKey(e.key) && e.value >= dailyGoal).length;
    if (dropped > 0) m['goal:old'] = '${_mi('goal:old', 0) + dropped}';
    m['xp:log'] = Motivation.encodeLog(log);
    final total = xpTotal + xp;
    m['xp:total'] = '$total';
    m['freeze'] = '$fr';
    state = state.copyWith(missionsDone: m, streak: streak, lastActive: today);
    final had = badgesEarned;
    final fresh = Motivation.badges.where((b) => !had.contains(b.id) && _badgeEarned(b.id)).toList();
    if (fresh.isNotEmpty) {
      state = state.copyWith(missionsDone: {...state.missionsDone, for (final b in fresh) 'badge:${b.id}': today});
    }
    _save();
    return XpAward(xp: xp, total: total, today: before + xp, goal: dailyGoal, streak: streak, week: xpWeek, streakUp: la != today, goalJustHit: before < dailyGoal && before + xp >= dailyGoal, freezeUsed: freezeUsed, newBadges: fresh);
  }

  bool _badgeEarned(String id) {
    final scores = {for (final e in state.missionsDone.entries) if (e.key.startsWith('course:')) e.key.substring(7): int.tryParse(e.value) ?? 0};
    final lessons = scores.entries.where((e) => RegExp(r'_\d+$').hasMatch(e.key) && e.value >= 60).length;
    final units = scores.entries.where((e) => !RegExp(r'_\d+$').hasMatch(e.key) && e.value >= 70).length;
    return switch (id) {
      'first' => scores.isNotEmpty,
      'streak3' => state.streak >= 3,
      'streak7' => state.streak >= 7,
      'streak30' => state.streak >= 30,
      'xp100' => xpTotal >= 100,
      'xp500' => xpTotal >= 500,
      'xp1000' => xpTotal >= 1000,
      'lessons10' => lessons >= 10,
      'lessons50' => lessons >= 50,
      'unit' => units >= 1,
      'perfect' => scores.values.any((v) => v >= 100),
      'goal7' => goalDays >= 7,
      'words50' => state.leitnerBox.length >= 50,
      'league' => leagueTier >= 1,
      'book1' => booksDone >= 1,
      'book5' => booksDone >= 5,
      _ => false,
    };
  }

  // ---- Library (graded readers): best quiz % per chapter in 'read:<book>:<ch>', finished books in 'read:done:<book>'.
  int? readScore(String book, int ch) => int.tryParse(state.missionsDone['read:$book:$ch'] ?? '');
  bool bookDone(String book) => state.missionsDone.containsKey('read:done:$book');
  int get booksDone => state.missionsDone.keys.where((k) => k.startsWith('read:done:')).length;
  /// First chapter whose quiz is not passed yet (or 0 when the book is finished).
  int nextChapter(String book, int chapters) {
    for (var i = 0; i < chapters; i++) {
      if ((readScore(book, i) ?? -1) < 50) return i;
    }
    return 0;
  }

  XpAward saveChapter(String book, int ch, int pct, int chapters) {
    final m = {...state.missionsDone};
    if (pct > (readScore(book, ch) ?? -1)) m['read:$book:$ch'] = '$pct';
    final all = List.generate(chapters, (i) => i == ch ? pct : (readScore(book, i) ?? -1)).every((v) => v >= 50);
    if (all) m.putIfAbsent('read:done:$book', () => Motivation.day(DateTime.now()));
    state = state.copyWith(missionsDone: m);
    _save();
    return awardXp(pct >= 50 ? (pct >= 100 ? 15 : 10) : 3);
  }

  String pref(String k, [String def = '']) => state.missionsDone['pref:$k'] ?? def;
  void setPref(String k, String v) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:$k': v});
    _save();
  }

  // ---- Speaking: answer chats by voice (speech recognition + per-word pronunciation scoring).
  bool get speakMode => state.missionsDone['pref:speakMode'] == 'on';
  void setSpeakMode(bool on) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:speakMode': on ? 'on' : 'off'});
    _save();
  }

  // ---- Daily reminder preferences (the reminder itself: PWA notification where allowed, or a calendar .ics).
  String get reminderTime => _m('pref:remind').isEmpty ? '19:00' : _m('pref:remind');
  bool get reminderOn => _m('pref:remindOn') == 'on';
  void setReminder(String hhmm, bool on) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:remind': hhmm, 'pref:remindOn': on ? 'on' : 'off'});
    _save();
  }
  /// True once per day, after the reminder time, if today's goal isn't met yet (for an in-app / notification nudge).
  bool reminderDue() {
    if (!reminderOn) return false;
    final now = _now;
    final p = reminderTime.split(':');
    final at = DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
    return now.isAfter(at) && xpToday < dailyGoal && _m('remind:last') != Motivation.day(now);
  }
  void markReminded() {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'remind:last': Motivation.day(_now)});
    _save();
  }

  bool lessonDone(Lesson l) => l.sceneIds.every(state.completedScenes.contains) && (practiceScore(l.id) ?? 0) >= 60;
  bool unitPassed(Unit u) => (practiceScore(u.id) ?? 0) >= 70;
  /// Units open in order. Levels below the starting level are fully open; at the starting level only its
  /// first unit opens straight away, the rest follow as the previous unit is finished or its test passed.
  /// A unit the learner has already played in never locks again.
  bool unitOpen(Course c, int i) {
    if (state.unlockAll || i == 0) return true;
    final u = c.units[i];
    if (u.level < startLevel) return true;
    if (u.level == startLevel && c.units[i - 1].level < startLevel) return true; // first unit of the starting level
    return unitPassed(c.units[i - 1]) || c.units[i - 1].lessons.every(lessonDone) || u.lessons.any((l) => state.completedScenes.any(l.sceneIds.contains));
  }

  /// Course level (1–5) matching the level picked at onboarding (A0–A1 … C1–C2).
  int get startLevel => levelForTier(state.startTier);
  static int levelForTier(int tier) => const [1, 2, 3, 4, 5, 5][tier.clamp(0, 5)];
  /// First lesson of a course level — each level opens on its own lesson.
  static Lesson? firstLessonOfLevel(Course c, int level) => c.units.where((u) => u.level == level).expand((u) => u.lessons).firstOrNull;
  /// The learner's next lesson: the first unfinished one at or above their starting level.
  Lesson? nextLesson(Course c) =>
      c.lessons.where((l) => c.unitOf(l.id)!.level >= startLevel && !lessonDone(l)).firstOrNull ?? c.lessons.where((l) => !lessonDone(l)).firstOrNull;
  bool lessonOpen(Course c, Lesson l) {
    final u = c.unitOf(l.id)!;
    final ui = c.units.indexOf(u), li = u.lessons.indexOf(l);
    if (ui < 0) { // Career Pack lessons: free order; the first lesson is a free preview, the rest need the pack
      final pk = c.packOf(u);
      return pk == null || packOwned(pk) || pk.lessons.first.id == l.id;
    }
    return unitOpen(c, ui) && (state.unlockAll || li == 0 || lessonDone(u.lessons[li - 1]));
  }

  // ---- Premium (display-only until real payments exist; see PremiumConfig).
  bool get hasPremium => PremiumConfig.betaFree || state.unlockAll || state.missionsDone['pref:premium'] == 'on';
  bool packOwned(Pack p) => !p.premium || hasPremium || state.missionsDone['pack:${p.id}'] == 'owned';

  // ---- Certificates: a level is complete when every one of its units is finished (all lessons done or test passed).
  List<Unit> levelUnits(Course c, int level) => c.units.where((u) => u.level == level).toList();
  bool levelComplete(Course c, int level) {
    final us = levelUnits(c, level);
    return us.isNotEmpty && us.every((u) => unitPassed(u) || u.lessons.every(lessonDone));
  }
  double levelProgress(Course c, int level) {
    final ls = levelUnits(c, level).expand((u) => u.lessons).toList();
    return ls.isEmpty ? 0 : ls.where(lessonDone).length / ls.length;
  }
  String get certName => state.missionsDone['pref:name'] ?? '';
  void setCertName(String v) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:name': v.trim()});
    _save();
  }

  // ---- Character growth over time: the family calendar advances with your progress.
  int growthPoints(ContentBundle c) =>
      state.completedScenes.where((id) => !id.contains('__as_')).length + 3 * c.course.units.where(unitPassed).length;
  int chapterIndex(ContentBundle c) => c.timeline.indexFor(growthPoints(c));
  int get seenChapter => int.tryParse(state.missionsDone['pref:chapter'] ?? '') ?? 0;
  void markChapterSeen(int i) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:chapter': '$i'});
    _save();
  }

  // Role switching: by default you return to being the guest after a role story; this keeps the role.
  bool get keepRole => state.missionsDone['pref:keepRole'] == 'on';
  void setKeepRole(bool on) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:keepRole': on ? 'on' : 'off'});
    _save();
  }

  // Ambient motion preference (optional; default on). Stored in missionsDone under 'pref:motion'.
  bool get motionOn => state.missionsDone['pref:motion'] != 'off';
  void setMotion(bool on) {
    state = state.copyWith(missionsDone: {...state.missionsDone, 'pref:motion': on ? 'on' : 'off'});
    _save();
  }

  void setUnlockAll(bool v) {
    state = state.copyWith(unlockAll: v);
    _save();
  }

  /// Words shown on a character line enter Leitner box 1.
  void seeWords(List<NewWord> words) {
    final box = {...state.leitnerBox};
    var changed = false;
    for (final w in words) {
      if (!box.containsKey(w.word)) {
        box[w.word] = Leitner.add(w.word, w.fa, _now);
        changed = true;
      }
    }
    if (changed) {
      state = state.copyWith(leitnerBox: box);
      _save();
    }
  }

  TurnOutcome applyTurn(Scene scene, Branch? branch, List<String> usedWords, ContentBundle c, {String? speaker, int? trustDelta}) {
    // Trust goes to whoever is speaking (episodes have several family members at the table).
    final sp = speaker == null ? null : c.characterOrNull(speaker);
    final id = sp != null && (sp.family || c.milestones.containsKey(sp.id)) ? sp.id : scene.characterId;
    final before = state.growthMap[id] ?? 0;
    final now = _now;
    // Leitner: a vocabulary word used naturally counts as a correct review.
    final box = {...state.leitnerBox};
    final promoted = <String>[];
    for (final w in usedWords) {
      final card = box[w];
      if (card != null && Leitner.isDue(card, now)) {
        box[w] = Leitner.review(card, true, now);
        promoted.add(w);
      }
    }
    final oldMood = state.moodMap[id] ?? 0;
    final delta = EmotionEngine.trustWithMood(trustDelta ?? branch?.trustDelta ?? 0, oldMood);
    final mood = EmotionEngine.update(oldMood, understood: branch != null, trustDelta: branch?.trustDelta ?? 0);
    final wk = WeeklyChallenge.weekKey(now);
    final weekly = state.weekly.week == wk ? state.weekly : WeeklyStats(wk, 0, 0);
    final trust = {...state.trustMap, id: (state.trustMap[id] ?? 0) + delta};
    final success = {...state.successMap};
    if (branch != null && branch.success) success[id] = (success[id] ?? 0) + 1;
    final today = _day(now);
    final daily = state.daily.date == today ? state.daily : DailyStats(today, 0, 0);
    state = state.copyWith(
      moodMap: {...state.moodMap, id: mood},
      weekly: WeeklyStats(wk, weekly.chats, weekly.trust + delta),
      leitnerBox: box,
      trustMap: trust,
      successMap: success,
      daily: DailyStats(today, daily.conversations, daily.wordsUsed + usedWords.length),
    );
    final after = GrowthEngine.growth(successfulBranches: success[id] ?? 0, masteredWords: masteredFor(id, c), trust: trust[id]!, streak: state.streak);
    final ms = c.milestonesFor(id);
    final oldM = GrowthEngine.milestoneFor(before, ms);
    final newM = GrowthEngine.milestoneFor(after, ms);
    final unlocked = <String>[];
    final scenesUnlocked = {...state.unlockedScenes};
    for (final m in ms.where((m) => m.threshold <= after)) {
      for (final u in m.unlocks) {
        if (scenesUnlocked.add(u)) unlocked.add(u);
      }
    }
    final reached = newM.id != oldM.id && newM.threshold > oldM.threshold;
    final ch = c.characterOrNull(id);
    state = state.copyWith(
      growthMap: {...state.growthMap, id: after},
      milestoneMap: {...state.milestoneMap, id: newM.id},
      unlockedScenes: scenesUnlocked,
      // Accent Passport stamp per milestone + archive of how this character spoke at the milestone they just left.
      stamps: reached ? [...state.stamps, Stamp(id, newM.id, ch?.accent ?? 'British', now)] : null,
      replayArchive: reached
          ? [
              ...state.replayArchive,
              ArchiveEntry(now, id, oldM.id, scene.id, [
                for (final n in scene.nodes.values.where((n) => n.speaker == id)) [n.speaker, n.text, n.translations['fa'] ?? ''],
              ]),
            ]
          : null,
      // Box-5 words feed the next milestone dialogue.
      pendingMilestoneWords: reached ? {...state.pendingMilestoneWords, for (final w in state.leitnerBox.values.where((w) => w.box == 5)) w.word: id} : null,
    );
    _save();
    return TurnOutcome(delta, before, after, reached ? newM : null, unlocked, promoted);
  }

  void completeScene(Scene scene, String accent, {List<List<String>> transcript = const [], List<String> words = const [], int trustGained = 0, int slips = 0, List<(String, String, String)> recasts = const [], List<NewWord> learned = const []}) {
    final now = _now;
    final today = _day(now);
    final daily = state.daily.date == today ? state.daily : DailyStats(today, 0, 0);
    final storyFirstTime = !state.completedScenes.contains(scene.id);
    final wk = WeeklyChallenge.weekKey(now);
    final w0 = state.weekly.week == wk ? state.weekly : WeeklyStats(wk, 0, 0);
    final weekly = WeeklyStats(wk, w0.chats + 1, w0.trust);
    final rewards = [...state.rewards];
    if (weekly.chats >= WeeklyChallenge.chatsTarget && weekly.trust >= WeeklyChallenge.trustTarget && !rewards.contains(wk)) rewards.add(wk);
    state = state.copyWith(
      weekly: weekly,
      rewards: rewards,
      diary: transcript.isEmpty ? state.diary : [DiaryEntry(now, scene.id, scene.characterId, trustGained, words, transcript), ...state.diary].take(60).toList(),
      completedScenes: {...state.completedScenes, scene.id, if (scene.baseId != null) scene.baseId!},
      daily: DailyStats(today, daily.conversations + 1, daily.wordsUsed),
      accentPassport: {...state.accentPassport, accent: (state.accentPassport[accent] ?? 0) + 1},
      missionsDone: Missions.satisfies(Missions.today(now), scene.id, slips) ? {...state.missionsDone, Missions.dayKey(now): Missions.today(now).id} : null,
      srsQueue: NarrativeSrs.enqueue(state.srsQueue, scene, now, learned: learned, recasts: recasts),
      // Words mastered before a milestone are "spent" once that character's next dialogue is played.
      pendingMilestoneWords: {...state.pendingMilestoneWords}..removeWhere((_, v) => v == scene.characterId && scene.isGated),
    );
    // The streak was already moved on above, so the award only adds XP (and badges) here.
    awardXp(storyFirstTime ? Motivation.storyXp : Motivation.storyXp ~/ 2);
  }

  Future<void> reset() async {
    await ref.read(progressStoreProvider).clear();
    state = const UserProgress();
  }
}

final progressProvider = NotifierProvider<ProgressController, UserProgress>(ProgressController.new);
