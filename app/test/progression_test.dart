import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/map/map_home.dart' show mapRegions, regionOpen;
import 'package:british_life/features/map/map_spots.dart' show MapSpot, spotFocus;
import 'package:british_life/features/onboarding/placement_screen.dart' show placementNext, placementLevel, placementPassMark;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Progression audit: level order, placement, map locks, pack locks and the Continue button.
void main() {
  final course = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()));
  final all = course.lessons.toList();

  ProgressController ctrlWith({int tier = 0, Iterable<Lesson> done = const [], Map<String, String> extra = const {}, Iterable<String> scenesOnly = const []}) {
    final p = UserProgress(
      onboarded: true,
      startTier: tier,
      completedScenes: {for (final l in done) ...l.sceneIds, ...scenesOnly},
      missionsDone: {for (final l in done) 'course:${l.id}': '100', ...extra},
    );
    final store = MemoryProgressStore()..data = p.encode();
    return ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]).read(progressProvider.notifier);
  }

  test('units run in level order 1→5 and every lesson belongs to exactly one unit', () {
    final lv = course.units.map((u) => u.level).toList();
    for (var i = 1; i < lv.length; i++) {
      expect(lv[i], greaterThanOrEqualTo(lv[i - 1]), reason: '${course.units[i].id} is out of level order');
    }
    expect(all.map((l) => l.id).toSet().length, all.length);
  });

  test('fresh learner: only the first lesson is open, Continue points at it, only Home is open on the map', () {
    final c = ctrlWith();
    expect(c.nextLesson(course)!.id, all.first.id);
    expect(c.lessonOpen(course, all[0]), isTrue);
    expect(c.lessonOpen(course, all[1]), isFalse);
    expect(c.unitOpen(course, 1), isFalse);
    for (final r in mapRegions.where((r) => r.level != null && r.pack == null)) {
      expect(regionOpen(c, course, r), r.level == 1, reason: r.id);
    }
  });

  test('walking the course in order: Continue is always the next lesson, it is open, and the one after is locked', () {
    for (var k = 0; k < 40; k++) {
      final c = ctrlWith(done: all.take(k));
      final next = c.nextLesson(course)!;
      expect(next.id, all[k].id, reason: 'after $k lessons');
      expect(c.lessonOpen(course, next), isTrue, reason: '${next.id} locked');
      expect(c.lessonOpen(course, all[k + 1]), isFalse, reason: '${all[k + 1].id} open too early');
    }
  });

  test('a unit the learner already played in stays open (no progress is ever re-locked)', () {
    final u5 = course.units[5];
    final c = ctrlWith(scenesOnly: u5.lessons.first.sceneIds);
    expect(c.unitOpen(course, 5), isTrue);
    expect(c.unitOpen(course, 6), isFalse);
  });

  test('a lesson only counts as done with its story finished AND practice ≥ 60%', () {
    final first = all.first;
    var c = ctrlWith(scenesOnly: first.sceneIds, extra: {'course:${first.id}': '50'});
    expect(c.nextLesson(course)!.id, first.id);
    expect(c.lessonOpen(course, all[1]), isFalse);
    c = ctrlWith(scenesOnly: first.sceneIds, extra: {'course:${first.id}': '60'});
    expect(c.nextLesson(course)!.id, all[1].id);
    c = ctrlWith(extra: {'course:${first.id}': '100'});
    expect(c.nextLesson(course)!.id, first.id, reason: 'practice without the story is not enough');
  });

  test('passing a unit test (≥70%) opens the next unit even if some lessons were skipped', () {
    final u0 = course.units[0];
    expect(ctrlWith(extra: {'course:${u0.id}': '69'}).unitOpen(course, 1), isFalse);
    final c = ctrlWith(extra: {'course:${u0.id}': '70'});
    expect(c.unitOpen(course, 1), isTrue);
    expect(c.lessonOpen(course, course.units[1].lessons.first), isTrue);
    expect(c.lessonOpen(course, course.units[1].lessons[1]), isFalse);
  });

  test('placement result L (tier L-1): Continue opens Level L, Levels ≤ L are open, Level L+1 stays locked', () {
    for (var level = 1; level <= 5; level++) {
      final c = ctrlWith(tier: level - 1);
      expect(c.startLevel, level);
      final next = c.nextLesson(course)!;
      expect(course.unitOf(next.id)!.level, level, reason: 'placement $level');
      expect(next.id, ProgressController.firstLessonOfLevel(course, level)!.id);
      expect(c.lessonOpen(course, next), isTrue);
      for (var i = 0; i < course.units.length; i++) {
        final u = course.units[i];
        final firstOfLevel = i == 0 || course.units[i - 1].level < u.level;
        if (u.level < level || (u.level == level && firstOfLevel)) expect(c.unitOpen(course, i), isTrue, reason: '${u.id} should be open at placement $level');
        if (u.level == level && !firstOfLevel) expect(c.unitOpen(course, i), isFalse, reason: '${u.id}: later units of the starting level open in order');
        if (u.level == level + 1 && firstOfLevel) expect(c.unitOpen(course, i), isFalse, reason: '${u.id} open too early');
      }
      for (final r in mapRegions.where((r) => r.pack == null)) {
        expect(regionOpen(c, course, r), r.level! <= level, reason: 'map ${r.id} at placement $level');
      }
    }
  });

  test('Continue falls back to skipped lower-level lessons, and is null when everything is done', () {
    final l2 = all.where((l) => course.unitOf(l.id)!.level >= 2).toList();
    final c = ctrlWith(tier: 1, done: l2);
    expect(c.nextLesson(course)!.id, all.first.id);
    expect(ctrlWith(done: all).nextLesson(course), isNull);
  });

  test('progress survives a save/reload round trip', () {
    final c = ctrlWith(tier: 2, done: all.take(5));
    final p = UserProgress.decode(c.state.encode());
    expect(p.startTier, 2);
    expect(p.completedScenes, containsAll(all.take(5).expand((l) => l.sceneIds)));
    expect(p.missionsDone['course:${all.first.id}'], '100');
  });

  test('Career Packs: premium-flagged, free during the beta, map region open', () {
    expect(course.packs, isNotEmpty);
    expect(PremiumConfig.betaFree, isTrue, reason: 'no real payments yet: the beta must stay free');
    final c = ctrlWith();
    // Free, level-gated packs (Hartley & Wren Homes) are covered in homes_test.dart.
    for (final pk in course.packs.where((p) => !p.gated)) {
      expect(pk.premium, isTrue, reason: pk.id);
      expect(pk.unlocked, isTrue, reason: '${pk.id}: the pack region stays visible (free preview)');
      for (final l in pk.lessons) {
        expect(c.lessonOpen(course, l), isTrue, reason: l.id);
      }
      final r = mapRegions.firstWhere((r) => r.pack == pk.id);
      expect(regionOpen(c, course, r), isTrue);
    }
    // Pack lessons never hijack the main Continue button.
    expect(c.nextLesson(course)!.id, all.first.id);
  });

  test('Career Packs after the beta: only the first lesson is a free preview; Premium, a one-off buy or demo mode open the rest', () {
    PremiumConfig.betaFree = false;
    addTearDown(() => PremiumConfig.betaFree = true);
    for (final pk in course.packs.where((p) => p.premium)) {
      final ls = pk.lessons.toList();
      final free = ctrlWith();
      expect(free.lessonOpen(course, ls.first), isTrue, reason: '${pk.id}: first lesson is the free preview');
      expect(ls.skip(1).where((l) => free.lessonOpen(course, l)), isEmpty, reason: '${pk.id}: the rest is locked');
      expect(free.packOwned(pk), isFalse);
      final bought = ctrlWith(extra: {'pack:${pk.id}': 'owned'});
      expect(ls.every((l) => bought.lessonOpen(course, l)), isTrue);
      final prem = ctrlWith(extra: {'pref:premium': 'on'});
      expect(ls.every((l) => prem.lessonOpen(course, l)), isTrue);
      final demo = ctrlWith()..setUnlockAll(true);
      expect(ls.every((l) => demo.lessonOpen(course, l)), isTrue);
      expect(regionOpen(free, course, mapRegions.firstWhere((r) => r.pack == pk.id)), isTrue, reason: 'region stays open for the preview');
    }
    // The main course is never behind the paywall.
    final c = ctrlWith(done: all.take(8));
    expect(c.lessonOpen(course, all[8]), isTrue);
  });

  test('certificates: a level is complete only when all its units are finished', () {
    final l1 = course.units.where((u) => u.level == 1).expand((u) => u.lessons).toList();
    expect(ctrlWith().levelComplete(course, 1), isFalse);
    final half = ctrlWith(done: l1.take(l1.length ~/ 2));
    expect(half.levelComplete(course, 1), isFalse);
    expect(half.levelProgress(course, 1), closeTo(.5, .02));
    final full = ctrlWith(done: l1);
    expect(full.levelComplete(course, 1), isTrue);
    expect(full.levelComplete(course, 2), isFalse);
    // Passing every unit test also earns it.
    final tests = ctrlWith(extra: {for (final u in course.units.where((u) => u.level == 1)) 'course:${u.id}': '80'});
    expect(tests.levelComplete(course, 1), isTrue);
    for (var lv = 1; lv <= 5; lv++) {
      expect(ctrlWith().levelUnits(course, lv), isNotEmpty, reason: 'level $lv has units');
    }
  });

  test('demo mode (unlock all) opens every lesson and region', () {
    final c = ctrlWith();
    c.setUnlockAll(true);
    expect(all.every((l) => c.lessonOpen(course, l)), isTrue);
    expect(mapRegions.every((r) => regionOpen(c, course, r)), isTrue);
  });

  group('the chosen level changes the content', () {
    final spots = [for (final j in jsonDecode(File('assets/data/spots.json').readAsStringSync())) MapSpot.fromJson(j)];
    test('map highlights, open districts, Continue and My path all follow the level', () {
      final focusSets = <int, Set<String>>{};
      for (var level = 1; level <= 5; level++) {
        final c = ctrlWith(tier: level - 1);
        expect(c.currentLevel(course), level);
        expect(course.unitOf(c.nextLesson(course)!.id)!.level, level, reason: 'Continue / recommendation at $level');
        final focus = {for (final s in spots) if (spotFocus(c, course, s)) s.id};
        expect(focus, isNotEmpty, reason: 'no highlighted places at level $level');
        focusSets[level] = focus;
        for (final r in mapRegions.where((r) => r.pack == null)) {
          expect(regionOpen(c, course, r), r.level! <= level, reason: '${r.id} at $level');
        }
      }
      for (var a = 1; a < 5; a++) {
        expect(focusSets[a], isNot(equals(focusSets[a + 1])), reason: 'levels $a and ${a + 1} highlight the same places');
      }
    });

    test('passing a level test moves the learner up: next district opens, Continue + My path switch, celebration due once', () {
      for (var level = 1; level < 5; level++) {
        final last = course.units.lastWhere((u) => u.level == level);
        final before = ctrlWith(tier: level - 1, extra: {'pref:lvseen': '$level'});
        expect(before.pendingLevelUp(course), isNull);
        final c = ctrlWith(tier: level - 1, extra: {'course:${last.id}': '80', 'pref:lvseen': '$level'});
        expect(c.levelPassed(course, level), isTrue);
        expect(c.currentLevel(course), level + 1, reason: 'level test $level passed');
        expect(c.nextLesson(course)!.id, ProgressController.firstLessonOfLevel(course, level + 1)!.id);
        expect(c.lessonOpen(course, c.nextLesson(course)!), isTrue);
        expect(regionOpen(c, course, mapRegions.firstWhere((r) => r.level == level + 1)), isTrue);
        if (level + 2 <= 5) expect(regionOpen(c, course, mapRegions.firstWhere((r) => r.level == level + 2)), isFalse);
        expect(c.pendingLevelUp(course), level + 1);
        c.markLevelSeen(level + 1);
        expect(c.pendingLevelUp(course), isNull, reason: 'celebrate only once');
      }
      // A failed level test (<70%) does not move you up.
      final last1 = course.units.lastWhere((u) => u.level == 1);
      expect(ctrlWith(extra: {'course:${last1.id}': '60'}).currentLevel(course), 1);
    });

    test('changing the level in placement resets the celebration marker (no false level-up)', () {
      final c = ctrlWith(extra: {'pref:lvseen': '1'});
      c.setStartTier(3);
      expect(c.currentLevel(course), 4);
      expect(c.pendingLevelUp(course), isNull);
    });

    test('adaptive placement: starts at A2, climbs on a pass, drops to A1 on an A2 fail', () {
      expect(placementNext({}), 2);
      expect(placementNext({2: false}), 1);
      expect(placementNext({2: false, 1: true}), isNull);
      expect(placementLevel({2: false, 1: true}), 1);
      expect(placementLevel({2: false, 1: false}), 1);
      expect(placementNext({2: true}), 3);
      expect(placementNext({2: true, 3: true, 4: false}), isNull);
      expect(placementLevel({2: true, 3: true, 4: false}), 3);
      expect(placementNext({2: true, 3: true, 4: true, 5: true}), isNull);
      expect(placementLevel({2: true, 3: true, 4: true, 5: true}), 5);
      expect(placementPassMark(5), 4);
    });
  });
}
