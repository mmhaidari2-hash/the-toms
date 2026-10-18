import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/seasons/seasons_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seasonal events: content rules, the date maths, the featured (nearest) event, XP and the level gate.
void main() {
  final es = Seasons.parse(File('assets/data/seasons.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  SEvent ev(String id) => es.firstWhere((e) => e.id == id);
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('the requested celebrations are all there, translated and voiced', () {
    for (final id in ['bonfire', 'remembrance', 'christmas', 'boxing', 'pancake', 'mothers', 'easter', 'maybank', 'fete', 'halloween', 'diwali', 'eid', 'nowruz']) {
      expect(es.any((e) => e.id == id), isTrue, reason: id);
    }
    for (final e in es) {
      expect(e.noteFa, isNotEmpty);
      expect(e.qs.length, 3);
      expect(e.words.length, greaterThanOrEqualTo(4));
      for (final l in e.lines) {
        expect(l.fa, isNotEmpty);
        expect(audio.contains(Voice.key(l.sp, l.en)), isTrue, reason: 'voiced: ${l.en}');
        expect(l.ms, greaterThan(500));
      }
      for (final w in e.words) {
        expect(audio.contains(Voice.key('narrator', w.w)), isTrue, reason: 'word voiced: ${w.w}');
      }
    }
  });

  test('dates: Easter, Pancake Day, Mothering Sunday, bank holidays, Remembrance', () {
    expect(Seasons.easter(2026), d(2026, 4, 5));
    expect(Seasons.easter(2027), d(2027, 3, 28));
    expect(Seasons.easter(2030), d(2030, 4, 21));
    expect(ev('pancake').datesIn(2027), [d(2027, 2, 9)]);
    expect(ev('mothers').datesIn(2027), [d(2027, 3, 7)]);
    expect(ev('mothers').datesIn(2026), [d(2026, 3, 15)]);
    expect(ev('maybank').datesIn(2027), [d(2027, 5, 3), d(2027, 5, 31)]);
    expect(ev('remembrance').datesIn(2026), [d(2026, 11, 8)]);
    expect(ev('carnival').datesIn(2027), [d(2027, 8, 30)]);
    expect(ev('nowruz').datesIn(2027), [d(2027, 3, 21)]);
    expect(ev('maybank').next(d(2027, 5, 4)), d(2027, 5, 31), reason: 'after the early one, the spring one');
    expect(ev('christmas').next(d(2026, 12, 26)), d(2027, 12, 25));
    expect(ev('eid').next(d(2031, 1, 1)), isNull, reason: 'moon dates only from the table');
  });

  test('the event nearest today is featured', () {
    final f = Seasons.featured(es, d(2026, 10, 18))!;
    expect(f.$1.id, 'halloween');
    expect(Seasons.countdown(f.$2, d(2026, 10, 18)), 'In 13 days');
    expect(Seasons.featured(es, d(2026, 10, 31))!.$1.id, 'halloween');
    expect(Seasons.countdown(d(2026, 10, 31), d(2026, 10, 31)), 'Today!');
    expect(Seasons.featured(es, d(2026, 11, 1))!.$1.id, 'bonfire');
    expect(Seasons.featured(es, d(2026, 11, 9))!.$1.id, 'christmas');
    expect(Seasons.upcoming(es, d(2026, 10, 18)).first.$1.id, 'halloween');
  });

  test('XP, best score and the level gate (A2 locked for a new learner)', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    var gate = SeasonGate(ctrl, c, topics, es);
    expect(gate.levelOpen('A1'), isTrue);
    expect(gate.levelOpen('A2'), isFalse);
    expect(ctrl.saveSeason('halloween', 33).xp, 3);
    expect(ctrl.seasonDone('halloween'), isFalse);
    expect(ctrl.saveSeason('halloween', 67).xp, 10);
    expect(ctrl.saveSeason('halloween', 100).xp, 15);
    ctrl.saveSeason('halloween', 67);
    expect(ctrl.seasonScore('halloween'), 100, reason: 'best kept');
    ctrl.saveSeason('christmas', 100);
    ctrl.saveSeason('pancake', 67);
    gate = SeasonGate(ctrl, c, topics, es);
    expect(gate.levelOpen('A2'), isTrue, reason: 'all A1 celebrations done');
    expect(gate.levelOpen('B1'), isFalse);
  });
}
