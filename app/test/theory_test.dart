import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/theory/theory_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driving theory prep: content rules, the not-official note, mock structure, pass mark and XP.
void main() {
  final cs = Thy.parse(File('assets/data/theory.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();

  test('5 Highway Code chapters, 70 original questions, all translated, sourced and voiced', () {
    expect(cs.map((c) => c.id), ['attitude', 'speed', 'signs', 'roads', 'law']);
    expect(cs.fold<int>(0, (a, c) => a + c.qs.length), 70);
    final seen = <String>{};
    for (final c in cs) {
      expect(c.src.every((s) => s.startsWith('https://')), isTrue, reason: c.id);
      expect(c.cards.length, greaterThanOrEqualTo(8));
      for (final e in c.expl) {
        expect(e.fa.trim(), isNotEmpty);
        expect(audio.contains(Voice.key('instructor', e.en)), isTrue, reason: 'voiced: ${e.en}');
        expect(e.ms, greaterThan(3000));
      }
      for (final q in c.qs) {
        expect(seen.add(q.id), isTrue);
        expect(q.fa.trim(), isNotEmpty, reason: q.q);
        expect(q.whyFa.trim(), isNotEmpty, reason: q.q);
        expect(q.tf ? q.options.length == 2 : q.options.toSet().length == 4, isTrue, reason: q.q);
      }
    }
    expect(Thy.disclaimer, contains('Not affiliated with or endorsed by DVSA'));
    expect(Thy.disclaimer, contains('not the official'));
  });

  test('mock: 50 questions spread over every chapter; pass mark 43 of 50; options keep TRUE/FALSE order', () {
    final m = Thy.mockSet(cs, Random(3));
    expect(m.length, 50);
    expect(m.map((q) => q.id).toSet().length, 50);
    for (final c in cs) {
      expect(m.where((q) => q.id.startsWith('${c.id}_')).length, 10);
    }
    expect(Thy.passed(43, 50), isTrue);
    expect(Thy.passed(42, 50), isFalse);
    expect(Thy.passed(9, 10), isTrue);
    expect(Thy.passed(8, 10), isFalse);
    expect(Thy.mockMinutes, 57);
    expect(Thy.levelNote, contains('B1+'));
    final tf = cs.expand((c) => c.qs).firstWhere((q) => q.tf && q.right == 'FALSE');
    expect([for (final o in Thy.order(tf, Random(1))) tf.options[o]], ['TRUE', 'FALSE']);
    expect(Thy.chapterSet(cs.first, Random(2)).length, Thy.chapterQuiz);
  });

  test('scores and XP', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    expect(ctrl.saveThyQuiz('law', 60).xp, 5);
    expect(ctrl.saveThyQuiz('law', 90).xp, 15);
    ctrl.saveThyQuiz('law', 70);
    expect(ctrl.thyQuizBest('law'), 90);
    expect(ctrl.saveThyMock(86).xp, 30);
    expect(ctrl.saveThyMock(50).xp, 5);
    expect((ctrl.thyMockBest, ctrl.thyMocks), (86, 2));
    ctrl.saveThyCards('law', 4);
    ctrl.saveThyCards('law', 2);
    expect(ctrl.thyCardsKnown('law'), 4);
    pc.dispose();
  });
}
