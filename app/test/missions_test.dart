import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/missions/missions_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real-life missions: content rules, safety, the level gate and XP/badges.
void main() {
  final ms = Missions.parse(File('assets/data/missions.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  final spots = {for (final s in jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List) s['id']};

  test('2+ missions per level; phrases voiced and translated; a map place, a tip and a British icon each', () {
    for (final lv in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(ms.where((m) => m.level == lv).length, greaterThanOrEqualTo(2), reason: lv);
    }
    expect(ms.map((m) => m.id).toSet().length, ms.length);
    expect(spots, contains('missions'));
    for (final m in ms) {
      expect(spots, contains(m.spot), reason: m.id);
      expect(File(m.icon).existsSync(), isTrue, reason: m.icon);
      expect(m.say.length, greaterThanOrEqualTo(3), reason: m.id);
      expect(m.hear, isNotEmpty, reason: m.id);
      expect(m.tip.$2.trim(), isNotEmpty);
      for (final p in [...m.say, ...m.hear]) {
        expect(p.fa.trim(), isNotEmpty, reason: p.en);
        expect(audio.contains(Voice.key(p.sp, p.en)), isTrue, reason: '${p.sp} clip for "${p.en}"');
        expect(p.ms, greaterThan(300), reason: p.en);
      }
      for (final p in m.say) {
        expect(p.sp, 'me');
        final maxOne = switch (m.level) { 'A1' => 9, 'A2' => 13, 'B1' => 20, _ => 28 };
        expect(p.en.split(' ').length, lessThanOrEqualTo(maxOne), reason: '${m.id}: "${p.en}"');
      }
    }
  });

  test('safety: ground rules cover strangers, personal details, recording and under-18s', () {
    final all = Missions.safety.map((s) => s.$1).join(' ').toLowerCase();
    for (final w in ['stranger', 'address', 'recording', 'microphone', 'under 18', 'already know']) {
      expect(all, contains(w));
    }
    for (final s in Missions.safety) {
      expect(s.$2.trim(), isNotEmpty);
    }
    // Directions are asked of staff, never "a stranger in the street".
    final dir = ms.firstWhere((m) => m.id == 'm_a2_directions');
    expect(dir.goal.toLowerCase(), contains('staff'));
    expect(dir.safe, isNotNull);
    expect(ms.firstWhere((m) => m.id == 'm_b1_pharmacy').safe!.$1, contains('999'));
  });

  test('gate: same rule as the rest; check-in XP, best rating kept, badges', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    MissionGate gate() => MissionGate(ctrl, content, topics, ms);
    expect(gate().levelOpen('A1'), isTrue);
    for (final lv in ['A2', 'B1', 'B2', 'C1']) {
      expect(gate().levelOpen(lv), isFalse, reason: '$lv shut for a new learner');
    }
    expect(MissionGate(ctrl, content, topics, ms, unlockAll: true).levelOpen('C1'), isTrue);
    final a1 = gate().of('A1');
    ctrl.startMission(a1[0].id);
    expect(ctrl.missionPending(a1[0].id), isTrue);
    expect(ctrl.checkInMission(a1[0].id, 0, 0).xp, 3, reason: "didn't happen: a small XP for trying");
    expect(ctrl.missionPending(a1[0].id), isFalse);
    expect(ctrl.missionDone(a1[0].id), isFalse);
    final a = ctrl.checkInMission(a1[0].id, 2, 3);
    expect(a.xp, 20);
    expect(a.newBadges.map((b) => b.id), contains('mission1'));
    expect(ctrl.checkInMission(a1[0].id, 1, 1).xp, 15);
    expect(ctrl.missionRating(a1[0].id), 2, reason: 'best rating kept');
    expect(gate().levelOpen('A2'), isFalse, reason: 'one A1 mission left');
    ctrl.checkInMission(a1[1].id, 1, 2);
    expect(gate().levelOpen('A2'), isTrue);
    expect(ctrl.missionsCompleted, 2);
    expect(ctrl.badgesEarned, isNot(contains('mission5')));
    pc.dispose();
  });
}
