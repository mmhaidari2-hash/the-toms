import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/course/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "My mistakes": wrong answers are saved, come back as their own lesson, and leave once answered right.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  final word = (jsonDecode(File('assets/data/course.json').readAsStringSync())['units'][0]['lessons'][0]['words'][0]['word']) as String;

  test('record, repeat, order and clear', () {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final c = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]).read(progressProvider.notifier);
    final a = mistakeOf(const ListenPick('kettle', ['kettle', 'mug', 'tea']), 'L1')!;
    final b = mistakeOf(const BuildSentence(['I', 'like', 'tea'], ['tea', 'I', 'like'], 'من چای دوست دارم'), 'L1')!;
    expect(mistakeOf(const FillGap('A ', ' please', 'tea', ['tea', 'x', 'y'], ''), 'L1')!.$1, 'f:A _ please');
    c.recordMistake(a.$1, a.$2);
    c.recordMistake(b.$1, b.$2);
    c.recordMistake(b.$1, b.$2);
    expect(c.mistakeList.map((e) => e.$1).toList(), ['s:I like tea', 'w:kettle']); // repeated first
    expect(c.mistakeList.first.$2['n'], 2);
    c.clearMistake('s:I like tea');
    expect(c.mistakeList.map((e) => e.$1).toList(), ['w:kettle']);
    for (var i = 0; i < 70; i++) {
      c.recordMistake('w:x$i', {'t': 'w', 'w': 'x$i'});
    }
    expect(c.mistakeList.length, 60);
  });

  Future<ProviderContainer> boot(WidgetTester t, Map<String, String> mist) async {
    t.view.physicalSize = const Size(750, 1334);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = UserProgress(onboarded: true, mistakes: mist, missionsDone: const {'pref:lvseen': '1'}).encode())], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('continue')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 500));
    return ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
  }

  testWidgets('no mistakes: a friendly empty screen', (t) async {
    await boot(t, const {});
    router.go('/practice/mistakes');
    for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 200)); }
    expect(find.byKey(const ValueKey('mistakes-empty')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a saved mistake comes back and is cleared when answered right', (t) async {
    final c = await boot(t, {'w:${word.toLowerCase()}': jsonEncode({'t': 'w', 'w': word, 'n': 1, 'd': '2026-10-20'})});
    router.go('/practice/mistakes');
    for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 200)); }
    expect(find.text('1/1'), findsOneWidget);
    await t.tap(find.text(word).first);
    for (var i = 0; i < 4; i++) { await t.pump(const Duration(milliseconds: 200)); }
    expect(c.read(progressProvider).mistakes, isEmpty);
    expect(t.takeException(), isNull);
  });
}
