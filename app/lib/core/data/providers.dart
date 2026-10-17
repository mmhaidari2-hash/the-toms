import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/emotion_engine.dart';
import '../engine/growth_engine.dart';
import '../engine/weekly.dart';
import '../engine/leitner.dart';
import '../engine/mission.dart';
import '../engine/narrative_srs.dart';
import '../engine/diary_coach.dart';
import '../models/character.dart';
import '../models/dialogue_node.dart';
import '../models/milestone.dart';
import '../models/place.dart';
import '../models/user_progress.dart';
import 'progress_store.dart';
import 'repository.dart';

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
  void savePractice(String id, int pct) {
    final old = practiceScore(id) ?? -1;
    if (pct <= old) return;
    state = state.copyWith(missionsDone: {...state.missionsDone, 'course:$id': '$pct'});
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
    if (ui < 0) return c.packOf(u)?.unlocked ?? true; // Career Pack lessons: free order, unlocked for now
    return unitOpen(c, ui) && (state.unlockAll || li == 0 || lessonDone(u.lessons[li - 1]));
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
    final yesterday = _day(now.subtract(const Duration(days: 1)));
    final daily = state.daily.date == today ? state.daily : DailyStats(today, 0, 0);
    final streak = state.lastActive == today
        ? state.streak
        : state.lastActive == yesterday
        ? state.streak + 1
        : 1;
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
      streak: streak,
      lastActive: today,
      missionsDone: Missions.satisfies(Missions.today(now), scene.id, slips) ? {...state.missionsDone, Missions.dayKey(now): Missions.today(now).id} : null,
      srsQueue: NarrativeSrs.enqueue(state.srsQueue, scene, now, learned: learned, recasts: recasts),
      // Words mastered before a milestone are "spent" once that character's next dialogue is played.
      pendingMilestoneWords: {...state.pendingMilestoneWords}..removeWhere((_, v) => v == scene.characterId && scene.isGated),
    );
    _save();
  }

  Future<void> reset() async {
    await ref.read(progressStoreProvider).clear();
    state = const UserProgress();
  }
}

final progressProvider = NotifierProvider<ProgressController, UserProgress>(ProgressController.new);
