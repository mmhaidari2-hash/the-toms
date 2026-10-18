import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/cinema/cinema_data.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cinema & dubbing: content rules + the level gate (same rule as the Library and Grammar School).
void main() {
  final scenes = Cinema.parse(File('assets/data/cinema.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  final cast = {for (final c in jsonDecode(File('assets/data/characters.json').readAsStringSync()) as List) c['id']: c['name']};

  test('2+ original scenes per level; every line voiced by its character, timed and translated', () {
    for (final lv in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(scenes.where((s) => s.level == lv).length, greaterThanOrEqualTo(2), reason: lv);
    }
    expect(scenes.map((s) => s.id).toSet().length, scenes.length);
    for (final s in scenes) {
      expect(File(s.stillAsset).existsSync(), isTrue, reason: '${s.id} still');
      expect(s.lines.length, greaterThanOrEqualTo(6), reason: s.id);
      expect(s.cast.length, greaterThanOrEqualTo(2), reason: s.id);
      expect(s.lines.where((l) => l.sp == s.dub).length, greaterThanOrEqualTo(2), reason: '${s.id}: dub role needs 2+ lines');
      expect(s.quiz.length, greaterThanOrEqualTo(3), reason: s.id);
      for (final q in s.quiz) {
        expect(q.options.toSet().length, 3, reason: q.q);
      }
      for (final l in s.lines) {
        expect(cast[l.sp], l.spName, reason: '${s.id}: ${l.sp} is a canon character');
        expect(l.fa.trim(), isNotEmpty, reason: l.en);
        expect(audio.contains(Voice.key(l.sp, l.en)), isTrue, reason: '${l.sp} clip for "${l.en}"');
        expect(l.ms, greaterThan(500), reason: 'clip length for "${l.en}" (run tool/make_cinema.py after rendering)');
      }
    }
  });

  test('level-appropriate line length and British usage', () {
    final us = RegExp(r"\b(color|favorite|mom|apartment|cookie|candy|pants|vacation|soccer|theater|center|gotten|sidewalk|truck|elevator|trash|realize|movie)\b", caseSensitive: false);
    for (final s in scenes) {
      final lens = s.lines.map((l) => l.en.split(RegExp(r'\s+')).length).toList();
      final maxOne = switch (s.level) { 'A1' => 8, 'A2' => 12, 'B1' => 20, _ => 26 };
      expect(lens.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(maxOne), reason: '${s.id} longest line');
      for (final l in s.lines) {
        expect(us.hasMatch(l.en), isFalse, reason: 'American usage in "${l.en}"');
      }
    }
  });

  test('levels open with the Grammar School / course rule; scores and XP are kept', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    CinemaGate gate() => CinemaGate(ctrl, content, topics, scenes);
    expect(gate().levelOpen('A1'), isTrue);
    for (final lv in ['A2', 'B1', 'B2', 'C1']) {
      expect(gate().levelOpen(lv), isFalse, reason: '$lv shut for a new learner');
    }
    expect(CinemaGate(ctrl, content, topics, scenes, unlockAll: true).levelOpen('C1'), isTrue);
    // Questions: best score kept, 2 of 3 passes.
    final a1 = gate().of('A1');
    expect(ctrl.saveSceneQuiz(a1[0].id, 33).xp, 3);
    expect(ctrl.sceneDone(a1[0].id), isFalse);
    expect(ctrl.saveSceneQuiz(a1[0].id, 67).xp, 10);
    expect(ctrl.saveSceneQuiz(a1[0].id, 0).xp, 3);
    expect(ctrl.cineScore(a1[0].id), 67);
    expect(gate().levelOpen('A2'), isFalse, reason: 'one A1 scene left');
    ctrl.saveSceneQuiz(a1[1].id, 100);
    expect(gate().levelOpen('A2'), isTrue, reason: 'all A1 scenes watched');
    expect(ctrl.scenesDone, 2);
    // Dub: best kept, XP by score.
    expect(ctrl.saveDub(a1[0].id, 95).xp, 15);
    expect(ctrl.saveDub(a1[0].id, 50).xp, 3);
    expect(ctrl.dubScore(a1[0].id), 95);
    // Grammar Class A2 passed → B1; a started C1 scene keeps C1 open.
    for (final t in topics.where((t) => t.level == 'A1' || t.level == 'A2')) {
      ctrl.saveGrammar(t.id, 80);
    }
    expect(gate().levelOpen('B1'), isTrue);
    expect(gate().levelOpen('B2'), isFalse);
    ctrl.saveDub(gate().of('C1').first.id, 40);
    expect(gate().levelOpen('C1'), isTrue);
    expect(CinemaGate.why('B2').$1, contains('Grammar Class B1'));
  });
}
