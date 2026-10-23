import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/engine/leitner.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/leitner/glossary.dart';
import 'package:british_life/features/leitner/leitner_add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('glossary: every entry has Persian; lookups forgive case, punctuation and simple endings', () {
    final m = (jsonDecode(File('assets/data/glossary.json').readAsStringSync()) as Map).map((k, v) => MapEntry(k as String, (v as List).cast<String>()));
    expect(m.length, greaterThan(3000));
    expect(m.values.every((v) => v.length == 4 && v[1].isNotEmpty), isTrue);
    Glossary.seed(m);
    expect(Glossary.lookup('Cuppa!')?.fa, isNotEmpty);
    expect(Glossary.lookup('cuppas')?.word.toLowerCase(), 'cuppa');
    expect(Glossary.clean('  “lovely,” '), 'lovely');
  });

  test('cards keep their example and source through reviews and saves', () {
    final now = DateTime(2026, 10, 23, 9);
    var c = Leitner.add('cuppa', 'چای', now, ex: 'Fancy a cuppa?', exSp: 'tom', src: '/chat/tom_breakfast');
    c = Leitner.review(c, true, now);
    expect(c.box, 2);
    expect(c.due, now.add(const Duration(days: 1)));
    final back = LeitnerCard.fromJson(jsonDecode(jsonEncode(c.toJson())));
    expect((back.ex, back.exSp, back.src, back.box), ('Fancy a cuppa?', 'tom', '/chat/tom_breakfast', 2));
    expect(Leitner.review(back, false, now).box, 1);
    expect(LeitnerCard.fromJson({'w': 'old', 'fa': 'x', 'b': 3, 'd': now.toIso8601String()}).ex, '', reason: 'old saves still load');
  });

  testWidgets('add from any screen, then review it in the Leitner box', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
    final scope = ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp());
    await t.pumpWidget(scope);
    Future<void> wait([int n = 10]) async {
      for (var i = 0; i < n; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    await wait(30);
    expect(find.byType(SelectionArea), findsOneWidget, reason: 'every text in the app is selectable');
    router.go('/leitner');
    await wait();
    expect(find.textContaining('Your Leitner box is empty'), findsOneWidget);

    final ctx = router.routerDelegate.navigatorKey.currentContext!;
    showLeitnerSheet(ctx, 'cuppa', ex: "Fancy a cuppa?", exSp: 'tom');
    await wait(15);
    expect(find.byKey(const ValueKey('leitner-word')), findsOneWidget);
    expect((t.widget<TextField>(find.byKey(const ValueKey('leitner-fa'))).controller!.text), isNotEmpty, reason: 'Persian from the glossary');
    expect(find.text('“Fancy a cuppa?”'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('leitner-add')));
    await wait();
    final c = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
    expect(c.read(progressProvider).leitnerBox['cuppa']?.box, 1);
    expect(c.read(progressProvider).leitnerBox['cuppa']?.src, '/leitner');

    expect(find.byKey(const ValueKey('leitner-card')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('leitner-show')));
    await wait(3);
    expect(find.byKey(const ValueKey('leitner-back')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('leitner-yes')));
    await wait(3);
    expect(c.read(progressProvider).leitnerBox['cuppa']?.box, 2);
    expect(find.byKey(const ValueKey('leitner-done')), findsOneWidget);
    expect(store.data, contains('"x":"Fancy a cuppa?"'), reason: 'saved offline (Hive store)');
  });
}
