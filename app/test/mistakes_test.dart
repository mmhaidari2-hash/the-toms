import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Common mistakes of Persian speakers": content rules and the screens open without a class lock.
void main() {
  final topics = Grammar.parse(File('assets/data/mistakes.json').readAsStringSync());
  final ls = Grammar.parse(File('assets/data/lifeskills.json').readAsStringSync());
  final grammarIds = {for (final t in Grammar.parse(File('assets/data/grammar.json').readAsStringSync())) t.id};

  test('both packs are well formed, ids never clash with the grammar ladder', () {
    expect(topics.length, greaterThanOrEqualTo(10));
    expect(ls.length, greaterThanOrEqualTo(8));
    expect({for (final t in [...topics, ...ls]) t.id}.length, topics.length + ls.length);
    for (final t in ls) {
      expect(t.level, 'LS');
      expect(isLifeSkillsTopic(t.id), isTrue);
      expect(topicSource(t.id), same(lifeSkillsProvider));
    }
    final us = RegExp(r"\b(color|favorite|mom|apartment|cookie|candy|pants|vacation|soccer|gotten|center|realize|trash|movie)\b", caseSensitive: false);
    for (final t in [...topics, ...ls]) {
      expect(isPackLevel(t.level), isTrue);
      expect(isPackTopic(t.id), isTrue);
      expect(grammarIds, isNot(contains(t.id)));
      expect(t.practice.length, greaterThanOrEqualTo(12), reason: t.id);
      expect(t.test.length, greaterThanOrEqualTo(5), reason: t.id);
      expect(t.practice.map((e) => e.kind).toSet(), containsAll(['gap', 'choose', 'order', 'transform']), reason: t.id);
      for (final l in [...t.teach, ...t.examples]) {
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(l.fa), isTrue, reason: l.en);
        expect(us.hasMatch(l.en), isFalse, reason: l.en);
      }
      for (final it in [...t.practice, ...t.test]) {
        expect(us.hasMatch(it.prompt + it.answers.join(' ')), isFalse, reason: it.prompt);
        if (it.kind == 'gap' || it.kind == 'choose') expect(it.answers.toSet().length, 3, reason: it.prompt);
        if (it.kind == 'gap') expect(it.fill(it.answers.first), isNot(contains('___')), reason: it.prompt);
        if (it.kind == 'order') expect(it.answers.first.split(' ').length, greaterThanOrEqualTo(3), reason: it.prompt);
        if (it.kind == 'transform') expect(it.check(it.answers.first), isTrue, reason: it.prompt);
      }
    }
  });

  setUp(() => BL.useGoogleFonts = false);
  setUpAll(() async {
    for (final (fam, file) in [('Roboto', 'Inter'), ('Inter', 'Inter'), ('Fraunces', 'Fraunces'), ('Vazirmatn', 'Vazirmatn')]) {
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });

  testWidgets('school → mistakes list → a lesson opens straight away (no lock)', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
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

    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/school');
    await settle();
    expect(find.byKey(const ValueKey('school-mistakes')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('school-mistakes')));
    await settle();
    expect(find.byKey(const ValueKey('mistakes-list')), findsOneWidget);
    expect(find.textContaining('0 of ${topics.length} passed'), findsOneWidget);
    final last = find.byKey(ValueKey('pack-${topics.last.id}'));
    await t.scrollUntilVisible(last, 200, scrollable: find.byType(Scrollable).first);
    await t.tap(last);
    await settle();
    expect(find.byKey(const ValueKey('topic-locked')), findsNothing, reason: 'mistakes are never locked');
    expect(find.textContaining('Persian speakers · Lesson'), findsOneWidget);

    router.go('/lifeuk');
    await settle();
    await t.scrollUntilVisible(find.byKey(const ValueKey('luk-open-lifeskills')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const ValueKey('luk-open-lifeskills')));
    await settle();
    expect(find.byKey(const ValueKey('lifeskills-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('ls-2027')), findsOneWidget, reason: 'the B2-from-2027 warning is shown');
    final first = find.byKey(ValueKey('pack-${ls.first.id}'));
    await t.scrollUntilVisible(first, 200, scrollable: find.byType(Scrollable).first);
    await t.tap(first);
    await settle();
    expect(find.byKey(const ValueKey('topic-locked')), findsNothing);
    expect(find.textContaining('IELTS Life Skills · Lesson'), findsOneWidget);
  });
}
