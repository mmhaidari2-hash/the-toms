import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/engine/progress_check.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/progress_check/progress_check_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ids = (jsonDecode(File('assets/data/scenes_index.json').readAsStringSync()) as List).cast<String>();
  final scenes = [for (final id in ids) Scene.fromJson(jsonDecode(File('assets/data/scenes/$id.json').readAsStringSync()))];
  final byId = {for (final s in scenes) s.id: s};

  test('every level gets a full set of questions; the answer is a real reply of that line; distractors are not', () {
    for (final seed in [1, 2, 3, 42, 99]) {
      final b = ProgressCheck.build(scenes, seed: seed);
      for (var lv = 1; lv <= 5; lv++) {
        final items = b[lv]!;
        expect(items.length, ProgressCheck.perLevel, reason: 'level $lv');
        for (final it in items) {
          expect(it.choices.toSet().length, 3);
          expect(it.choices, contains(it.answer));
          final nodes = [for (final s in scenes) ...s.nodes.values.where((n) => n.text == it.prompt)];
          expect(nodes.any((n) => n.branches.any((x) => x.success && x.suggestion == it.answer)), isTrue);
          for (final d in it.choices.where((c) => c != it.answer)) {
            expect(nodes.any((n) => n.branches.any((x) => x.suggestion == d)), isFalse, reason: 'distractor "$d" is a reply to "${it.prompt}"');
          }
        }
      }
    }
    expect(byId, isNotEmpty);
  });

  test('a repeat check draws different questions', () {
    final a = ProgressCheck.build(scenes, seed: 1), b = ProgressCheck.build(scenes, seed: 2);
    for (var lv = 1; lv <= 5; lv++) {
      final pa = a[lv]!.map((e) => e.prompt).toSet(), pb = b[lv]!.map((e) => e.prompt).toSet();
      expect(pa.intersection(pb).length, lessThan(ProgressCheck.perLevel), reason: 'level $lv');
    }
  });

  test('history round-trips, is capped, tolerates junk; compare lines are EN+FA', () {
    String? raw;
    for (var i = 0; i < 35; i++) {
      raw = ProgressCheck.addResult(raw, CheckResult('2026-11-${(i % 28 + 1).toString().padLeft(2, '0')}', i % 5 + 1, 3, 5));
    }
    final h = ProgressCheck.history(raw);
    expect(h.length, ProgressCheck.maxHistory);
    expect(ProgressCheck.history('not json'), isEmpty);
    String cefr(int l) => ProgressController.cefrOf(l);
    final up = ProgressCheck.compare(const [CheckResult('2026-10-01', 2, 4, 5), CheckResult('2026-11-12', 3, 8, 10)], cefr);
    expect(up.$1, contains('Up from A2 to B1'));
    expect(up.$2, contains('آفرین'));
    expect(ProgressCheck.compare(const [CheckResult('2026-11-12', 1, 1, 5)], cefr).$1, contains('First check'));
  });

  testWidgets('progress check: answers everything right → C1 estimate, saved to history, labelled unofficial, course level unchanged', (t) async {
    ProgressCheckScreen.seed = 7;
    addTearDown(() => ProgressCheckScreen.seed = null);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, startTier: 1).encode();
    t.view.physicalSize = const Size(400, 1600) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/check');
    for (var i = 0; i < 40 && find.byKey(const ValueKey('check-start')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('check-disclaimer')), findsOneWidget);
    expect(find.textContaining('not a CEFR certificate'), findsOneWidget);
    // Wait until both data files are loaded and the button enables.
    for (var i = 0; i < 40 && t.widget<FilledButton>(find.byKey(const ValueKey('check-start'))).onPressed == null; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.byKey(const ValueKey('check-start')));
    await t.pump();
    final ctx = t.element(find.byType(ProgressCheckScreen));
    final container = ProviderScope.containerOf(ctx);
    expect(find.byType(NavLoading), findsNothing);
    var answered = 0;
    while (find.byKey(const ValueKey('check-prompt')).evaluate().isNotEmpty && answered < 40) {
      final prompt = t.widget<Text>(find.byKey(const ValueKey('check-prompt'))).data!;
      // The right answer: a success reply of this line (scene items) — or the placement answer.
      final buttons = find.byWidgetPredicate((w) => w is OutlinedButton && (w.key as ValueKey?)?.value.toString().startsWith('check-choice-') == true);
      String? right;
      for (final e in buttons.evaluate()) {
        final label = ((e.widget as OutlinedButton).child as Text).data!;
        final ok = scenes.any((s) => s.nodes.values.any((n) => n.text == prompt && n.branches.any((b) => b.success && b.suggestion == label)));
        if (ok) right = label;
      }
      right ??= _placementAnswer(prompt);
      await t.tap(find.widgetWithText(OutlinedButton, right!).first);
      await t.pump(const Duration(milliseconds: 700));
      answered++;
    }
    expect(answered, 20); // A2, B1, B2, C1 blocks of 5
    expect(find.byKey(const ValueKey('check-result-5')), findsOneWidget);
    expect(find.textContaining('Estimated level (unofficial)'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-chart')), findsOneWidget);
    final p = container.read(progressProvider);
    expect(p.startTier, 1, reason: 'the check never changes the course level');
    final h = ProgressCheck.history(container.read(progressProvider.notifier).pref('checkHistory'));
    expect(h.single.level, 5);
    expect(h.single.right, 20);
  });
}

String? _placementAnswer(String prompt) {
  final j = jsonDecode(File('assets/data/placement.json').readAsStringSync());
  for (final i in j['items']) {
    if (i['text'] == prompt) return i['answer'] as String;
  }
  return null;
}
