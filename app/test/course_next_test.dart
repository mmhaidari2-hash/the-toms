import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/motivation/motivation_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Passing a lesson leads straight on to the next one (across unit boundaries), already unlocked and saved.
void main() {
  final course = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()));
  ProgressController ctrl(MemoryProgressStore store) =>
      ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]).read(progressProvider.notifier);

  test('pass lesson N -> N+1 is next and unlocked, including the unit boundary', () {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final c = ctrl(store);
    final ls = course.lessons.take(course.units[0].lessons.length + 2).toList();
    for (var i = 0; i + 1 < ls.length; i++) {
      final next = ProgressController.nextAfter(course, ls[i].id)!;
      expect(next.id, ls[i + 1].id);
      expect(c.lessonOpen(course, next), isFalse, reason: '${next.id} locked before ${ls[i].id} is passed');
      // Story not watched: passing the practice still counts the lesson as done.
      c.savePractice(ls[i].id, 80, storyScenes: ls[i].sceneIds);
      expect(c.lessonDone(ls[i]), isTrue);
      expect(c.lessonOpen(course, next), isTrue, reason: '${next.id} opens as soon as ${ls[i].id} is passed');
      // ...and it is saved before the app navigates.
      final saved = UserProgress.decode(store.data!);
      expect(saved.missionsDone['course:${ls[i].id}'], '80');
      expect(ls[i].sceneIds.every(saved.completedScenes.contains), isTrue);
    }
    // Last lesson of unit 1 -> first lesson of unit 2.
    final lastU1 = course.units[0].lessons.last;
    expect(ProgressController.nextAfter(course, lastU1.id)!.id, course.units[1].lessons.first.id);
    // A unit test leads to the next unit's first lesson.
    expect(ProgressController.nextAfter(course, course.units[0].id)!.id, course.units[1].lessons.first.id);
    expect(ProgressController.nextAfter(course, course.lessons.last.id), isNull);
  });

  test('a failed practice does not unlock the next lesson', () {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final c = ctrl(store);
    final l = course.units[0].lessons.first;
    c.savePractice(l.id, 40, storyScenes: l.sceneIds);
    expect(c.lessonOpen(course, ProgressController.nextAfter(course, l.id)!), isFalse);
  });

  Future<void> pumpC(WidgetTester t, {required VoidCallback onNext, VoidCallback? onContinue}) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Celebration(award: const XpAward(xp: 15), pass: true, checkpoint: false, right: 9, total: 10, onContinue: onContinue ?? () {}, onNext: onNext))));
  }

  testWidgets('Next lesson button + auto-advance after 3 s', (t) async {
    var n = 0;
    await pumpC(t, onNext: () => n++);
    expect(find.text('Next lesson  →'), findsOneWidget);
    expect(find.text('Opening in 3…'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(n, 0);
    await t.pump(const Duration(seconds: 1));
    expect(n, 1, reason: 'auto-advances once');
    await t.pump(const Duration(seconds: 4));
    expect(n, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('Stay here cancels the auto-advance; the button still works', (t) async {
    var n = 0;
    await pumpC(t, onNext: () => n++);
    await t.tap(find.byKey(const ValueKey('celebrate-stay')));
    await t.pump(const Duration(seconds: 5));
    expect(n, 0);
    expect(find.byKey(const ValueKey('celebrate-countdown')), findsNothing);
    await t.tap(find.byKey(const ValueKey('celebrate-next')));
    expect(n, 1);
  });
}
