import 'dart:io';
import 'dart:math';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/park/park_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Park games: words come from the learner's own lessons; every level has full rounds; gate, best scores, XP.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pools, rounds, odd sets, gate and best scores', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    final content = await pc.read(contentProvider.future);
    final c = content.course;
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());

    // A new learner reviews the words of the lesson they can open: Lesson 1 first.
    final a1 = ParkWords.of(ctrl, c, 'A1');
    final first = c.units.first.lessons.first.words.map((w) => w.word.toLowerCase()).toSet();
    expect(a1.fromOpen, greaterThan(0));
    expect(a1.words.take(a1.fromOpen).every((w) => first.contains(w.word.toLowerCase())), isTrue);
    expect(a1.words.length, greaterThanOrEqualTo(24));

    final r = Random(1);
    for (final code in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      final pw = ParkWords.of(ctrl, c, code);
      final lv = Park.courseLevel(code);
      final levelWords = c.units.where((u) => u.level == lv).expand((u) => u.words).map((w) => w.word).toSet();
      expect(pw.words.every((w) => levelWords.contains(w.word)), isTrue, reason: '$code words come from $code lessons');
      expect(ParkRounds.match(pw.words, r).length, Park.matchPairs, reason: code);
      final ls = ParkRounds.listen(pw.words, r);
      expect(ls.length, Park.listenRounds, reason: code);
      for (final (w, opts) in ls) {
        expect(opts.length, 4);
        expect(opts.where((o) => o == w.word).length, 1);
      }
      final sp = ParkRounds.spell(pw, r);
      expect(sp.length, Park.spellRounds, reason: code);
      expect(sp.every((w) => ParkWords.single(w.word)), isTrue);
      expect(ParkRounds.build(pw, r).length, Park.buildRounds, reason: code);
      final odd = ParkRounds.odd(code, r);
      expect(odd.length, Park.oddRounds, reason: code);
      for (final s in Park.odd[code]!) {
        expect(s.same.length, 3);
        expect(s.same, isNot(contains(s.odd)));
        expect(s.whyFa.trim(), isNotEmpty);
      }
    }
    // Spelling bee puts British spellings first when the learner has met them.
    final all = ParkWords.of(ctrl, c, 'A1', min: 5000);
    expect(ParkRounds.spell(all, r).every((w) => Park.us.containsKey(w.word.toLowerCase())), isTrue);

    ParkGate gate() => ParkGate(ctrl, content, topics);
    expect(gate().levelOpen('A1'), isTrue);
    for (final lv in ['A2', 'B1', 'B2', 'C1']) {
      expect(gate().levelOpen(lv), isFalse, reason: '$lv shut for a new learner');
    }
    expect(ParkGate(ctrl, content, topics, unlockAll: true).levelOpen('C1'), isTrue);

    var (a, best) = ctrl.saveParkGame('A1', 'match', 50);
    expect((a.xp, best), (2, true));
    (a, best) = ctrl.saveParkGame('A1', 'match', 95);
    expect((a.xp, best), (10, true));
    (a, best) = ctrl.saveParkGame('A1', 'match', 70);
    expect((a.xp, best), (6, false), reason: 'replays still earn XP');
    expect(ctrl.parkBest('A1', 'match'), 95);
    expect(ctrl.parkPlays, 3);
    for (final g in ['listen', 'spell', 'odd']) {
      ctrl.saveParkGame('A1', g, 80);
    }
    expect(gate().levelOpen('A2'), isFalse, reason: 'one A1 game not cleared yet');
    ctrl.saveParkGame('A1', 'build', 60);
    expect(gate().levelOpen('A2'), isTrue);
    pc.dispose();
  });
}
