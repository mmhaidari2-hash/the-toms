import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/engine/conversation_engine.dart';
import 'package:british_life/core/engine/emotion_engine.dart';
import 'package:british_life/core/engine/weekly.dart';
import 'package:british_life/core/i18n/strings.dart';
import 'package:british_life/core/engine/growth_engine.dart';
import 'package:british_life/core/engine/leitner.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:british_life/core/models/milestone.dart';
import 'package:british_life/core/models/place.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/ai/dialogue_brain.dart';
import 'package:british_life/core/engine/connected_speech.dart';
import 'package:british_life/core/engine/diary_coach.dart';
import 'package:british_life/core/engine/level_profile.dart';
import 'package:british_life/core/engine/mission.dart';
import 'package:british_life/core/engine/politeness_engine.dart';
import 'package:british_life/core/engine/recast_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic j(String p) => jsonDecode(File(p).readAsStringSync());

ContentBundle load() {
  final chars = [for (final c in j('assets/data/characters.json')) Character.fromJson(c)];
  final scenes = {for (final id in j('assets/data/scenes_index.json')) id as String: Scene.fromJson(j('assets/data/scenes/$id.json'))};
  final ms = <String, List<Milestone>>{
    for (final id in j('assets/data/growth_index.json')) id as String: [for (final m in j('assets/data/${id}_growth.json')['milestones']) Milestone.fromJson(m)],
  };
  final tiers = [for (final t in j('assets/data/places.json')) Tier.fromJson(t)];
  final moments = [for (final m in j('assets/data/moments.json')) Moment(m['sceneId'], m['cover'])];
  final roles = [for (final r in j('assets/data/roles.json')) RoleDef(r['id'], List<String>.from(r['scenes']))];
  return ContentBundle(chars, scenes, ms, tiers, moments, roles);
}

void main() {
  final c = load();

  test('content integrity: six characters, every branch target exists', () {
    expect(c.characters.where((e) => e.family).map((e) => e.id), ['tom', 'leslie', 'william', 'nicola', 'ryan', 'weda']);
    for (final s in c.scenes.values) {
      expect(s.nodes.containsKey(s.start), isTrue);
      for (final n in s.nodes.values) {
        expect(n.translations['fa'], isNotEmpty);
        for (final b in n.branches) {
          if (b.next != null) expect(s.nodes.containsKey(b.next), isTrue, reason: '${s.id}/${n.id}->${b.next}');
          // Every suggestion must be matched by its own branch.
          expect(ConversationEngine.match(n, b.suggestion).branch, same(b), reason: '${s.id}/${n.id}: ${b.suggestion}');
        }
      }
    }
  });

  test('keyword matching is case/punctuation insensitive and rejects nonsense', () {
    final n = c.scenes['tom_breakfast']!.nodes['t1']!;
    expect(ConversationEngine.match(n, 'YES, please!!').branch!.next, 't2');
    expect(ConversationEngine.match(n, 'asdf qwerty').matched, isFalse);
    expect(ConversationEngine.match(n, 'yesterday').matched, isFalse); // whole words only
  });

  test('soft trust saturates', () {
    expect(GrowthEngine.softTrust(0), 0);
    expect(GrowthEngine.softTrust(50), closeTo(63.2, .1));
    expect(GrowthEngine.softTrust(10000), lessThanOrEqualTo(100));
  });

  test('growth blends branches, mastered words and trust', () {
    expect(GrowthEngine.growth(successfulBranches: 0, masteredWords: 0, trust: 0), 0);
    expect(GrowthEngine.growth(successfulBranches: 8, masteredWords: 10, trust: 100000), closeTo(100, .01));
    expect(GrowthEngine.growth(successfulBranches: 4, masteredWords: 0, trust: 0), closeTo(22.5, .01));
  });

  test('leitner promotes, caps at 5 and resets on miss', () {
    final now = DateTime(2026, 10, 16);
    var card = Leitner.add('cuppa', 'چای', now);
    for (var i = 0; i < 7; i++) {
      card = Leitner.review(card, true, now);
    }
    expect(card.box, 5);
    expect(card.due, now.add(const Duration(days: 14)));
    expect(Leitner.review(card, false, now).box, 1);
  });

  test('playing nicola_park unlocks the birthday scene', () {
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore())]);
    final ctrl = ct.read(progressProvider.notifier);
    final park = c.scenes['nicola_park']!;
    final bday = c.scenes['nicola_birthday']!;
    expect(ctrl.isUnlocked(bday), isFalse);
    var node = park.nodes[park.start]!;
    final unlocked = <String>[];
    while (!node.isEnd) {
      ctrl.seeWords(node.newWords);
      final b = node.branches.first;
      unlocked.addAll(ctrl.applyTurn(park, b, const [], c).unlockedScenes);
      node = park.nodes[b.next]!;
    }
    expect(unlocked, contains('nicola_birthday'));
    expect(ctrl.isUnlocked(bday), isTrue);
    expect(['M1','M2','M3','M4'], contains(ct.read(progressProvider).milestoneMap['nicola']));
    // persistence round-trip
    final p = UserProgress.decode(ct.read(progressProvider).encode());
    expect(p.unlockedScenes, contains('nicola_birthday'));
    expect(p.leitnerBox.length, greaterThan(5));
  });

  test('places: hotspots valid, every dialogue reachable from a scene', () {
    final ids = c.characters.map((e) => e.id).toSet();
    final reachable = <String>{};
    for (final pl in c.places) {
      if (pl.image != null) expect(File(pl.image!).existsSync(), isTrue, reason: pl.image);
      for (final h in pl.hotspots) {
        if (h.isProp) {
          expect(h.prop!.phrase, isNotEmpty);
          reachable.add('');
        } else {
          expect(ids, contains(h.characterId));
        }
        if (h.sceneId != null) {
          expect(c.scenes.containsKey(h.sceneId), isTrue, reason: h.sceneId);
          reachable.add(h.sceneId!);
        } else if (!h.isProp) {
          expect(h.ambientEn, isNotNull);
        }
        final r = h.rect;
        if (r != null) expect(r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= 1.001 && r[1] + r[3] <= 1.001, isTrue, reason: '${pl.id}/${h.characterId}');
      }
    }
    reachable.addAll(c.moments.map((m) => m.sceneId));
    for (final u in j('assets/data/course.json')['units']) {
      for (final l in u['lessons']) {
        reachable.addAll(List<String>.from(l['sceneIds']));
      }
    }
    reachable.addAll(c.roles.expand((r) => r.scenes));
    // Role-switch variants are reached through their base scene.
    reachable.addAll([for (final s in c.scenes.values) if (s.baseId != null && reachable.contains(s.baseId)) s.id]);
    expect(reachable, containsAll(c.scenes.keys));
    for (final m in c.moments) {
      if (m.cover != null) expect(File(m.cover!).existsSync(), isTrue, reason: m.cover);
    }
  });

  test('levels unlock in order', () {
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore())]);
    final ctrl = ct.read(progressProvider.notifier);
    expect(ctrl.tierUnlocked(0, c), isTrue);
    expect(ctrl.tierUnlocked(1, c), isFalse);
    expect(ctrl.canPlay(c.scenes['priya_till']!, c), isFalse);
    ctrl.completeScene(c.scenes['tom_breakfast']!, 'London');
    ctrl.completeScene(c.scenes['william_breakfast']!, 'London');
    expect(ctrl.tierUnlocked(1, c), isTrue);
    expect(ctrl.currentTier(c), 1);
    expect(ctrl.canPlay(c.scenes['priya_till']!, c), isTrue);
  });

  test('mood rises with good turns, drops on misses; diary + weekly recorded', () {
    var m = 0.0;
    for (var i = 0; i < 4; i++) {
      m = EmotionEngine.update(m, understood: true, trustDelta: 8);
    }
    expect(EmotionEngine.label(m).en, 'Cheerful');
    m = EmotionEngine.update(m, understood: false);
    m = EmotionEngine.update(m, understood: false);
    expect(m, lessThan(.45));
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore())]);
    final ctrl = ct.read(progressProvider.notifier);
    final s = c.scenes['tom_breakfast']!;
    ctrl.applyTurn(s, s.nodes['t1']!.branches.first, const [], c);
    ctrl.completeScene(
      s,
      'London',
      transcript: const [
        ['tom', 'Morning!', 'صبح بخیر'],
        ['me', 'Yes please', ''],
      ],
      words: const ['cuppa'],
      trustGained: 6,
    );
    final p = UserProgress.decode(ct.read(progressProvider).encode());
    expect(p.diary.single.lines.length, 2);
    expect(p.weekly.chats, 1);
    expect(p.weekly.trust, greaterThan(0));
    expect(p.moodMap['tom'], greaterThan(0));
  });

  test('ISO week key', () {
    expect(WeeklyChallenge.weekKey(DateTime(2026, 10, 16)), '2026-W42');
    expect(WeeklyChallenge.weekKey(DateTime(2027, 1, 1)), '2026-W53');
  });

  test('onboarding start tier opens levels up to it', () {
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore())]);
    final ctrl = ct.read(progressProvider.notifier);
    ctrl.finishOnboarding(startTier: 3, lang: 'pl');
    expect(ctrl.tierUnlocked(3, c), isTrue);
    expect(ctrl.tierUnlocked(4, c), isFalse);
    expect(tr('pl', 'diary'), 'Pamiętnik');
    expect(tr('pl', 'replay_sub'), isNot(tr('en', 'replay_sub')));
  });

  test('recasting: "Give me tea." → Tom recasts, green tip, story continues, no red X', () {
    final n = c.scenes['ep1_morning_table']!.nodes['k1']!;
    final r = const OfflineBrain().respondSync(BrainRequest(sceneId: 'ep1_morning_table', characterId: 'tom', node: n, userText: 'Give me tea.', level: 'A1'));
    expect(r.npcReply, isNotNull);
    expect(r.recastTip!.better, contains('cuppa'));
    expect(r.branch, isNotNull); // moves on
    // global rule table also works on lines without authored recasts
    expect(RecastEngine.recast(c.scenes['tom_breakfast']!.nodes['t1']!, 'I want coffee')!.better, contains("I'd like"));
    expect(RecastEngine.ghostHint(n), startsWith('You mean…'));
  });

  test('politeness: warm words add trust, blunt imperatives earn none and cool the reply', () {
    final n = c.scenes['ep1_morning_table']!.nodes['k1']!;
    BrainReply say(String t) => const OfflineBrain().respondSync(BrainRequest(sceneId: 's', characterId: 'tom', node: n, userText: t, level: 'A1'));
    final warm = say("I'd love a cuppa, cheers"), plain = say('tea'), blunt = say('Tea. Hurry up.');
    expect(PolitenessEngine.score('Could I have one, please?').register, Register.warm);
    expect(warm.trustDelta, greaterThan(plain.trustDelta));
    expect(blunt.trustDelta, 0);
    expect(blunt.npcReply, n.coolReply);
  });

  test('connected speech x-ray: authored and rule-generated', () {
    expect(ConnectedSpeech.connected('Do you want to have a cup of tea?'), "D'you wanna cuppa?");
    expect(ConnectedSpeech.connected('I am going to get a bottle of water'), contains('gonna'));
    for (final s in c.scenes.values) {
      for (final n in s.nodes.values) {
        final x = ConnectedSpeech.of(n);
        expect(x.connected, isNotEmpty);
        expect(x.ipa, startsWith('/'));
      }
    }
    // every episode line has an authored X-Ray on its key lines
    for (final id in ['ep1_morning_table', 'ep2_muddy_hallway', 'ep3_high_street', 'ep4_evening_tea']) {
      expect(c.scenes[id]!.nodes.values.where((n) => n.xray != null).length, greaterThanOrEqualTo(2), reason: id);
    }
  });

  test('narrative SRS: recast phrase comes back tomorrow from the assigned character', () {
    var now = DateTime(2026, 10, 16, 9);
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()), clockProvider.overrideWithValue(() => now)]);
    final ctrl = ct.read(progressProvider.notifier);
    final s = c.scenes['ep1_morning_table']!;
    ctrl.completeScene(s, 'London', slips: 1, recasts: const [('Could I grab a cuppa, please?', '', 'tom')]);
    expect(ctrl.srsDue('tom'), isNull); // not today
    now = DateTime(2026, 10, 17, 8);
    final due = ctrl.srsDue('tom')!;
    expect(due.phrase, contains('cuppa'));
    expect(s.memory!.en, contains('piping hot'));
    ctrl.resolveSrs(due);
    expect(ctrl.srsDue('tom'), isNull);
  });

  test('daily mission tracks a clean run; growth thresholds, roles and private stories gate', () {
    final now = DateTime(2026, 10, 16);
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()), clockProvider.overrideWithValue(() => now)]);
    final ctrl = ct.read(progressProvider.notifier);
    final m = Missions.today(now);
    ctrl.completeScene(c.scenes[m.sceneIds.first]!, 'London', slips: m.clean ? 1 : 0);
    expect(Missions.done(ct.read(progressProvider), now), !m.clean);
    ctrl.completeScene(c.scenes[m.sceneIds.first]!, 'London');
    expect(Missions.done(ct.read(progressProvider), now), isTrue);
    expect(c.milestonesFor('nicola').map((x) => x.id), ['M0', 'M1', 'M2', 'M3', 'M4', 'M5']);
    expect(c.milestonesFor('william').length, 4);
    // role scenes
    expect(ctrl.canPlay(c.scenes['role_ryan_mum']!, c), isFalse);
    ctrl.setRole('ryan');
    expect(ctrl.canPlay(c.scenes['role_ryan_mum']!, c), isTrue);
    // private story needs high trust
    expect(ctrl.canPlay(c.scenes['private_tom_dad']!, c), isFalse);
    final s = c.scenes['tom_breakfast']!;
    for (var i = 0; i < 12; i++) {
      ctrl.applyTurn(s, s.nodes['t1']!.branches.first, const [], c, trustDelta: 10);
    }
    ctrl.finishOnboarding(startTier: 5, lang: 'fa');
    expect(ctrl.canPlay(c.scenes['private_tom_dad']!, c), isTrue);
    expect(GrowthEngine.streakBoost(30), closeTo(1.14, 1e-9));
  });

  test('milestone → passport stamp + replay archive', () {
    final ct = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore())]);
    final ctrl = ct.read(progressProvider.notifier);
    final park = c.scenes['nicola_park']!;
    var node = park.nodes[park.start]!;
    while (!node.isEnd) {
      final b = node.branches.first;
      ctrl.applyTurn(park, b, const [], c);
      node = park.nodes[b.next]!;
    }
    final p = UserProgress.decode(ct.read(progressProvider).encode());
    expect(p.stamps.map((s) => s.milestoneId), contains('M1'));
    expect(p.replayArchive.first.milestoneId, 'M0');
  });

  test('diary writing gets a reaction and gentle tips', () {
    final fb = DiaryCoach.review('today i had a cuppa with tom on the bus', ['cuppa'], c.characters.where((x) => x.family).toList(), const {});
    expect(fb.reactorId, 'tom');
    expect(fb.vocabUsed, ['cuppa']);
    expect(fb.tips, isNotEmpty);
  });

  test('linguistic matrix + level budgets', () {
    for (final s in c.scenes.values) {
      final lp = LevelProfile.of(s.level);
      for (final n in s.nodes.values) {
        expect(n.text.length, lessThanOrEqualTo(lp.maxChars), reason: '${s.id}/${n.id} (${n.text.length})');
        if (n.speaker == 'william') expect(n.text.split(' ').length, lessThanOrEqualTo(6), reason: '${s.id}/${n.id}');
        if (n.speaker == 'nicola') expect(n.text.split(' ').length, lessThanOrEqualTo(VoiceProfile.matrix['nicola']!.maxWords + 4), reason: '${s.id}/${n.id}');
      }
    }
    final ep1 = c.scenes['ep1_morning_table']!;
    final ryan = ep1.nodes.values.firstWhere((n) => n.speaker == 'ryan').text.toLowerCase();
    expect(['mate', 'knackered', 'alright'].every(ryan.contains), isTrue);
    expect(ep1.nodes.values.any((n) => n.event != null && n.speaker == 'william'), isTrue);
  });

  test('every helper language has every UI string', () {
    for (final l in helperLanguages) {
      for (final k in ['mission', 'diary', 'replay_sub', 'chapter1', 'passport', 'shadowHelp', 'privateStory']) {
        expect(tr(l.code, k), isNotEmpty, reason: '${l.code}/$k');
        if (l.code != 'en' && k != 'no_translation') expect(tr(l.code, k) != tr('en', k) || k == 'normal', isTrue, reason: '${l.code}/$k');
      }
    }
    expect(langOf('ur').rtl && langOf('ar').rtl, isTrue);
  });

  test('chapter-dependent lines: latest variant at or before the chapter, replies unchanged', () {
    final n = c.scenes['ep1_morning_table']!.nodes['k4']!;
    expect(n.atChapter(0).text, n.text);
    expect(n.atChapter(1).text, contains('six'));
    expect(n.atChapter(2).text, contains('six'));
    expect(n.atChapter(4).text, contains('raspberry'));
    expect(n.atChapter(4).branches, n.branches);
  });
}
