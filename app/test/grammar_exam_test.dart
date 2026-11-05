import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/grammar/exam_screen.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Q43: one class = one level; each class has a final exam that samples every topic.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());

  test('every topic belongs to exactly one real class, and each class has topics', () {
    final codes = Grammar.classes.map((c) => c.code).toSet();
    expect(topics.every((t) => codes.contains(t.level)), isTrue);
    for (final c in codes) {
      expect(topics.where((t) => t.level == c), isNotEmpty, reason: c);
    }
    expect(topics.map((t) => t.id).toSet().length, topics.length, reason: 'ids are unique');
  });

  test('exam draws ${Grammar.examSize} questions and covers every topic of the class', () {
    for (final c in Grammar.classes) {
      final ts = topics.where((t) => t.level == c.code).toList();
      final items = examItems(ts, 1);
      expect(items.length, Grammar.examSize, reason: c.code);
      final covered = ts.where((t) => t.test.any(items.contains)).length;
      expect(covered, min(ts.length, Grammar.examSize), reason: '${c.code} covers each topic');
    }
  });

  testWidgets('exam opens after the class is passed and runs ${Grammar.examSize} questions', (t) async {
    t.view.physicalSize = const Size(375, 812) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final passed = {for (final x in topics.where((x) => x.level == 'A1')) 'gram:${x.id}': '100'};
    final store = MemoryProgressStore()..data = UserProgress(onboarded: true, missionsDone: passed).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    router.go('/school/a1/exam');
    for (var k = 0; k < 30 && find.byKey(const ValueKey('exam-start')).evaluate().isEmpty; k++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    final start = t.widget<FilledButton>(find.byKey(const ValueKey('exam-start')));
    expect(start.onPressed, isNotNull);
    await t.tap(find.byKey(const ValueKey('exam-start')));
    await t.pump();
    expect(find.textContaining('1/${Grammar.examSize}'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

int min(int a, int b) => a < b ? a : b;
