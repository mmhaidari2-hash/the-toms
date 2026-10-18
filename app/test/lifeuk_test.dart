import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/lifeuk/lifeuk_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Life in the UK prep: content rules, the not-official note, mock structure, pass mark and XP.
void main() {
  final cs = Luk.parse(File('assets/data/lifeuk.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();

  test('4 handbook topics, 80+ original questions, all translated, sourced and voiced', () {
    expect(cs.map((c) => c.id), ['values', 'history', 'society', 'law']);
    expect(cs.fold<int>(0, (a, c) => a + c.qs.length), greaterThanOrEqualTo(80));
    final seen = <String>{};
    for (final c in cs) {
      expect(c.src.every((s) => s.startsWith('https://')), isTrue, reason: c.id);
      expect(c.cards.length, greaterThanOrEqualTo(8));
      for (final e in c.expl) {
        expect(e.fa.trim(), isNotEmpty);
        expect(audio.contains(Voice.key('tutor', e.en)), isTrue, reason: 'voiced: ${e.en}');
        expect(e.ms, greaterThan(3000));
      }
      for (final q in c.qs) {
        expect(seen.add(q.id), isTrue);
        expect(q.fa.trim(), isNotEmpty, reason: q.q);
        expect(q.whyFa.trim(), isNotEmpty, reason: q.q);
        expect(q.tf ? q.options.length == 2 : q.options.toSet().length == 4, isTrue, reason: q.q);
      }
    }
    expect(Luk.disclaimer, contains('Not affiliated with the Home Office'));
    expect(Luk.disclaimer, contains('not the official'));
  });

  test('mock: 24 questions spread over every chapter; 75% pass mark; options keep TRUE/FALSE order', () {
    final m = Luk.mockSet(cs, Random(3));
    expect(m.length, 24);
    expect(m.map((q) => q.id).toSet().length, 24);
    for (final c in cs) {
      expect(m.where((q) => q.id.startsWith('${c.id}_')).length, 6);
    }
    expect(Luk.passed(18, 24), isTrue);
    expect(Luk.passed(17, 24), isFalse);
    final tf = cs.expand((c) => c.qs).firstWhere((q) => q.tf && q.right == 'FALSE');
    expect([for (final o in Luk.order(tf, Random(1))) tf.options[o]], ['TRUE', 'FALSE']);
    expect(Luk.chapterSet(cs.first, Random(2)).length, Luk.chapterQuiz);
  });

  test('scores and XP', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    expect(ctrl.saveLukQuiz('law', 60).xp, 5);
    expect(ctrl.saveLukQuiz('law', 80).xp, 15);
    ctrl.saveLukQuiz('law', 70);
    expect(ctrl.lukQuizBest('law'), 80);
    expect(ctrl.saveLukMock(79).xp, 30);
    expect(ctrl.saveLukMock(50).xp, 5);
    expect((ctrl.lukMockBest, ctrl.lukMocks), (79, 2));
    ctrl.saveLukCards('law', 4);
    ctrl.saveLukCards('law', 2);
    expect(ctrl.lukCardsKnown('law'), 4);
    pc.dispose();
  });
}
