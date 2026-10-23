import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/grammar/school_screen.dart';
import 'package:british_life/features/grammar/topic_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grammar School: content rules, answer checking, unlocking in order, and the full topic flow.
void main() {
  final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  final course = (jsonDecode(File('assets/data/course.json').readAsStringSync()) as Map)['units'] as List;
  final lessonIds = {for (final u in course) for (final l in u['lessons'] as List) l['id'] as String};

  test('Classes A1 to C1 are complete and well formed', () {
    expect(topics.where((t) => t.level == 'A1').length, greaterThanOrEqualTo(6));
    expect(topics.where((t) => t.level == 'A2').length, greaterThanOrEqualTo(5));
    expect(topics.where((t) => t.level == 'B1').length, greaterThanOrEqualTo(5));
    expect(topics.where((t) => t.level == 'B2').length, greaterThanOrEqualTo(5));
    expect(topics.where((t) => t.level == 'C1').length, greaterThanOrEqualTo(5));
    expect(topics.map((t) => t.id).toSet().length, topics.length, reason: 'unique ids');
    for (final t in topics) {
      for (final id in t.related) {
        final lv = int.parse(id.substring(1, id.indexOf('_')));
        expect(lv, lessThanOrEqualTo(Grammar.classes.indexWhere((c) => c.code == t.level) + 1), reason: '${t.id} links only to lessons at or below its level');
      }
    }
    final us = RegExp(r"\b(color|favorite|mom|apartment|cookie|candy|pants|vacation|soccer|gotten|center|realize|trash|movie)\b", caseSensitive: false);
    for (final t in topics) {
      expect(t.practice.map((e) => e.kind).toSet(), containsAll(['gap', 'choose', 'order', 'transform']), reason: '${t.id} uses every exercise type');
      expect(t.test.length, greaterThanOrEqualTo(5), reason: t.id);
      expect(t.related, isNotEmpty, reason: '${t.id} links to lessons');
      for (final id in t.related) {
        expect(lessonIds, contains(id));
      }
      for (final l in [...t.teach, ...t.examples]) {
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(l.fa), isTrue, reason: l.en);
        expect(audio.contains(Voice.key('ellis', l.en)), isTrue, reason: 'Mrs Ellis clip for "${l.en}"');
        expect(us.hasMatch(l.en), isFalse, reason: l.en);
      }
      for (final it in [...t.practice, ...t.test]) {
        expect(us.hasMatch(it.prompt + it.answers.join(' ')), isFalse, reason: it.prompt);
        if (it.kind == 'gap' || it.kind == 'choose') {
          expect(it.answers.length, 3, reason: it.prompt);
          expect(it.answers.toSet().length, 3, reason: it.prompt);
        }
        if (it.kind == 'gap') {
          expect(it.prompt, contains('___'));
          expect(it.fill(it.answers.first), isNot(contains('___')));
        }
        if (it.kind == 'order') {
          expect(it.answers.first.split(' ').length, greaterThanOrEqualTo(3), reason: it.prompt);
          expect(it.tiles(3).join(' '), isNot(it.answers.first), reason: 'tiles are shuffled');
        }
        if (it.kind == 'transform') expect(it.check(it.answers.first), isTrue);
      }
    }
  });

  test('answer checking is forgiving about case, punctuation and apostrophes', () {
    const tr = GItem('transform', 'Make it negative: "It is cold today."', ["It isn't cold today.", 'It is not cold today.']);
    expect(tr.check('it isn’t cold today'), isTrue);
    expect(tr.check('  It is NOT cold today!  '), isTrue);
    expect(tr.check('It not cold today.'), isFalse);
    const gap = GItem('gap', 'I ___ hungry, Mummy!', ["'m", "'s", "'re"]);
    expect(gap.fill("'m"), "I'm hungry, Mummy!");
    expect(gap.shownAnswer, "I'm hungry, Mummy!");
    expect(gap.check("'m"), isTrue);
    expect(gap.check("'s"), isFalse);
    const ord = GItem('order', 'Is Ryan at school today?', ['Is Ryan at school today?']);
    expect(ord.check('Is Ryan at school today?'), isTrue);
    expect(ord.check('Ryan is at school today?'), isFalse);
  });

  test('topics unlock in order; Class A2 opens after Class A1 (or when the course reaches Level 2)', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await pc.read(contentProvider.future);
    GrammarGate gate() => GrammarGate(ctrl, content, topics);
    final a1 = gate().of('A1'), a2 = gate().of('A2');
    expect(gate().classOpen('A1'), isTrue);
    expect(gate().classOpen('A2'), isFalse);
    expect(gate().classOpen('B1'), isFalse);
    expect(gate().classOpen('C1'), isFalse);
    expect(gate().topicOpen(a1[0]), isTrue);
    expect(gate().topicOpen(a1[1]), isFalse);
    expect(ctrl.saveGrammar(a1[0].id, 40).xp, 3);
    expect(gate().topicOpen(a1[1]), isFalse, reason: 'below the pass mark');
    expect(ctrl.saveGrammar(a1[0].id, 80).xp, 10);
    expect(gate().topicOpen(a1[1]), isTrue);
    for (final t in a1) {
      ctrl.saveGrammar(t.id, 100);
    }
    expect(gate().classDone('A1'), isTrue);
    expect(gate().classOpen('A2'), isTrue);
    expect(gate().topicOpen(a2[0]), isTrue);
    expect(gate().topicOpen(a2[1]), isFalse);
    expect(gate().classOpen('B1'), isFalse, reason: 'A2 not passed yet');
    for (final t in a2) {
      ctrl.saveGrammar(t.id, 60);
    }
    expect(gate().classOpen('B1'), isTrue);
    expect(gate().topicOpen(gate().of('B1').first), isTrue);
    expect(gate().classOpen('B2'), isFalse);
    for (final t in gate().of('B1')) {
      ctrl.saveGrammar(t.id, 90);
    }
    expect(gate().classOpen('B2'), isTrue);
    expect(gate().classOpen('C1'), isFalse);
    for (final t in gate().of('B2')) {
      ctrl.saveGrammar(t.id, 70);
    }
    expect(gate().classOpen('C1'), isTrue);
    expect(gate().topicOpen(gate().of('C1').first), isTrue);
    expect(gate().topicOpen(gate().of('C1')[1]), isFalse);
  });

  group('screens at 375x667', () {
    setUp(() => BL.useGoogleFonts = false);
    setUpAll(() async {
      for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
        final file = {'Roboto': 'Inter', 'Inter': 'Inter', 'Fraunces': 'Fraunces', 'Vazirmatn': 'Vazirmatn'}[fam]!;
        final l = FontLoader(fam);
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
          l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
        }
        await l.load();
      }
    });
    testWidgets('school → Class A1 → topic: lesson, practice (with feedback), mini test → passed, next topic opens', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> settle() async {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 400));
        }
        for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull);
      }

      router.go('/school');
      await settle();
      expect(find.byKey(const ValueKey('class-A1')), findsOneWidget);
      expect(find.text('Class A1 · مبتدی'), findsOneWidget);
      await t.scrollUntilVisible(find.byKey(const ValueKey('class-B2')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('0 of 5 topics passed'), findsWidgets, reason: 'B1/B2 have topics now');
      await t.scrollUntilVisible(find.byKey(const ValueKey('class-A1')), -200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const ValueKey('class-A1')));
      await settle();
      expect(find.byKey(const ValueKey('topic-a1_be')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topic-a1_be')));
      await settle();
      expect(find.byKey(const ValueKey('topic-learn')), findsOneWidget);
      final sc = find.descendant(of: find.byKey(const ValueKey('topic-learn')), matching: find.byType(Scrollable)).first;
      await t.scrollUntilVisible(find.byKey(const ValueKey('related-l1_u1_1')), 300, scrollable: sc);
      await t.scrollUntilVisible(find.byKey(const ValueKey('start-practice')), 300, scrollable: sc);
      await t.tap(find.byKey(const ValueKey('start-practice')));
      await t.pump(const Duration(milliseconds: 500));

      Future<void> solve({bool wrong = false}) async {
        final ev = t.widget<ExerciseView>(find.byType(ExerciseView));
        final it = ev.item;
        switch (it.kind) {
          case 'gap' || 'choose':
            await t.tap(find.byKey(ValueKey('opt-${wrong ? it.answers[1] : it.answers.first}')));
          case 'order':
            final tiles = it.tiles(ev.seed), used = <int>{};
            for (final w in it.answers.first.split(' ')) {
              final k = List.generate(tiles.length, (i) => i).firstWhere((i) => tiles[i] == w && !used.contains(i));
              used.add(k);
              await t.tap(find.byKey(ValueKey('tile-$k')));
              await t.pump();
            }
          default:
            await t.enterText(find.byKey(const ValueKey('ex-input')), it.answers.first);
        }
        await t.pump();
        await t.tap(find.byKey(const ValueKey('ex-action')));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byKey(ValueKey(wrong ? 'feedback-wrong' : 'feedback-right')), findsOneWidget, reason: it.prompt);
        if (wrong) expect(find.byKey(const ValueKey('feedback-answer')), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const ValueKey('ex-action')));
        await t.pump(const Duration(milliseconds: 500));
      }

      await solve(wrong: true); // feedback shows the right answer
      var n = 1;
      while (find.byType(ExerciseView).evaluate().isNotEmpty) {
        await solve();
        n++;
      }
      expect(n, 11, reason: '6 practice + 5 test');
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('grammar-celebrate')), findsOneWidget);
      expect(find.text('Topic passed!'), findsOneWidget);
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('grammar-celebrate')))).read(progressProvider.notifier);
      expect(ctrl.grammarScore('a1_be'), 100, reason: 'practice mistakes do not count; the mini test does');
      expect(ctrl.xpToday, greaterThanOrEqualTo(15));
      expect(find.text('Next topic  →'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('celebrate-next')));
      await settle();
      expect(find.byKey(const ValueKey('topic-screen-a1_have')), findsOneWidget, reason: 'goes on to the next topic');
      router.go('/school/A1');
      await settle();
      expect(find.byKey(const ValueKey('topic-a1_have')), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
    });

  });
}
