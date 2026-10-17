import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/map/map_home.dart' show mapRegions, regionOpen;
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

  test('Career Packs: premium-flagged, every lesson playable (no payments yet), map region open', () {
    expect(course.packs, isNotEmpty);
    final c = ctrlWith();
    for (final pk in course.packs) {
      expect(pk.premium, isTrue, reason: pk.id);
      expect(pk.unlocked, isTrue, reason: '${pk.id}: packs stay unlocked until payments exist');
      for (final l in pk.lessons) {
        expect(c.lessonOpen(course, l), isTrue, reason: l.id);
      }
      final r = mapRegions.firstWhere((r) => r.pack == pk.id);
      expect(regionOpen(c, course, r), isTrue);
    }
    // Pack lessons never hijack the main Continue button.
    expect(c.nextLesson(course)!.id, all.first.id);
  });

  test('demo mode (unlock all) opens every lesson and region', () {
    final c = ctrlWith();
    c.setUnlockAll(true);
    expect(all.every((l) => c.lessonOpen(course, l)), isTrue);
    expect(mapRegions.every((r) => regionOpen(c, course, r)), isTrue);
  });
}
