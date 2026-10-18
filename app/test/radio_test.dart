import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/radio/radio_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hackney Hum (radio): content rules + the level gate (same rule as the Library, Cinema and Grammar School).
void main() {
  final segs = RadioStation.parse(File('assets/data/radio.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  final cast = {for (final c in jsonDecode(File('assets/data/characters.json').readAsStringSync()) as List) c['id']: c['name']};
  const presenters = {'bex': 'Bex', 'malcolm': 'Malcolm', 'grace': 'Grace', 'owen': 'Owen'};

  test('2+ programmes per level, every kind on air; every line voiced, timed and translated', () {
    for (final lv in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(segs.where((s) => s.level == lv).length, greaterThanOrEqualTo(2), reason: lv);
    }
    expect({for (final s in segs) s.kind}, {'news', 'weather', 'travel', 'phonein', 'advert'});
    expect(segs.map((s) => s.id).toSet().length, segs.length);
    for (final s in segs) {
      expect(RadioStation.kinds.containsKey(s.kind), isTrue);
      expect(RegExp(r'^\d\d:\d\d$').hasMatch(s.slot), isTrue, reason: s.id);
      expect(s.lines.length, greaterThanOrEqualTo(5), reason: s.id);
      expect(s.quiz.length, greaterThanOrEqualTo(3), reason: s.id);
      for (final q in s.quiz) {
        expect(q.options.toSet().length, 3, reason: q.q);
      }
      for (final l in s.lines) {
        expect(presenters[l.sp] ?? cast[l.sp], l.spName, reason: '${s.id}: ${l.sp} is a presenter or a canon character');
        expect(l.fa.trim(), isNotEmpty, reason: l.en);
        expect(audio.contains(Voice.key(l.sp, l.en)), isTrue, reason: '${l.sp} clip for "${l.en}"');
        expect(l.ms, greaterThan(500), reason: 'clip length for "${l.en}" (run tool/make_radio.py after rendering)');
      }
    }
  });

  test('level-appropriate lines, British usage, no transport-operator branding', () {
    final us = RegExp(r"\b(color|favorite|mom|apartment|cookie|candy|pants|vacation|soccer|theater|center|gotten|sidewalk|truck|elevator|trash|realize|movie|subway)\b", caseSensitive: false);
    final brand = RegExp(r'\bTfL\b|Transport for London|\bTube\b|Overground|Oyster|Elizabeth line', caseSensitive: false);
    for (final s in segs) {
      final maxOne = switch (s.level) { 'A1' => 9, 'A2' => 13, 'B1' => 20, _ => 28 };
      for (final l in s.lines) {
        expect(l.en.split(RegExp(r'\s+')).length, lessThanOrEqualTo(maxOne), reason: '${s.id}: "${l.en}"');
        expect(us.hasMatch(l.en), isFalse, reason: 'American usage in "${l.en}"');
        expect(brand.hasMatch(l.en), isFalse, reason: 'branding in "${l.en}"');
      }
    }
  });

  test('levels open with the Grammar School / course rule; best score and XP kept', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    RadioGate gate() => RadioGate(ctrl, content, topics, segs);
    expect(gate().levelOpen('A1'), isTrue);
    for (final lv in ['A2', 'B1', 'B2', 'C1']) {
      expect(gate().levelOpen(lv), isFalse, reason: '$lv shut for a new learner');
    }
    expect(RadioGate(ctrl, content, topics, segs, unlockAll: true).levelOpen('C1'), isTrue);
    final a1 = gate().of('A1');
    expect(ctrl.saveRadioQuiz(a1[0].id, 33).xp, 3);
    expect(ctrl.segmentDone(a1[0].id), isFalse);
    expect(ctrl.saveRadioQuiz(a1[0].id, 67).xp, 10);
    expect(ctrl.saveRadioQuiz(a1[0].id, 0).xp, 3);
    expect(ctrl.radioScore(a1[0].id), 67);
    expect(gate().levelOpen('A2'), isFalse, reason: 'one A1 programme left');
    expect(ctrl.saveRadioQuiz(a1[1].id, 100).xp, 15);
    expect(gate().levelOpen('A2'), isTrue, reason: 'all A1 programmes understood');
    expect(gate().levelOpen('B1'), isFalse);
    expect(ctrl.segmentsDone, 2);
    pc.dispose();
  });
}
