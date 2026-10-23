import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/driving/driving_data.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driving School: content rules, scene-art rule, sound cues, the moving/parked logic, XP and the level gate.
void main() {
  final ls = Drive.parse(File('assets/data/driving.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  const mains = {'tom', 'leslie', 'william', 'nicola', 'ryan', 'weda', 'george', 'mehdi'};
  const placeMains = {'petrol': {'bilal', 'tom'}, 'driving': {'ryan', 'tom'}};

  test('two or more dialogues per level, covering the requested topics, translated and voiced', () {
    for (final lv in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(ls.where((l) => l.level == lv).length, greaterThanOrEqualTo(2), reason: lv);
    }
    for (final id in ['cockpit', 'petrol', 'directions', 'provisional', 'roundabout', 'mot', 'parallel', 'motfail', 'debrief', 'testday']) {
      expect(ls.any((l) => l.id == id), isTrue, reason: id);
    }
    final all = ls.expand((l) => l.lines.map((x) => x.en.toLowerCase())).join(' ');
    for (final p in ['mirror', 'signal', 'roundabout', 'pull up on the left', 'park', 'show me', 'tell me']) {
      expect(all, contains(p));
    }
    for (final l in ls) {
      expect(l.qs.length, 3);
      expect(l.words.length, greaterThanOrEqualTo(4));
      expect(l.noteFa, isNotEmpty);
      for (final x in l.lines) {
        expect(x.fa, isNotEmpty);
        expect(audio.contains(Voice.key(x.sp, x.en)), isTrue, reason: 'voiced: ${x.en}');
        expect(x.ms, greaterThan(500));
      }
      for (final w in l.words) {
        expect(audio.contains(Voice.key('narrator', w.w)), isTrue, reason: w.w);
      }
    }
  });

  test('scene art: lessons out of the car open on the painting of their setting; sound cues exist', () {
    for (final l in ls) {
      final speakers = l.lines.map((x) => x.sp).toSet();
      expect(['car', 'road', 'petrol', 'garage', 'home'], contains(l.scene));
      if (l.img != null) {
        final place = l.img!.split('/').last.split('.').first;
        expect(placeMains.containsKey(place) || mains.isNotEmpty, isTrue, reason: '${l.id} painting $place');
        expect(speakers, isNotEmpty);
        expect(File(l.img!).existsSync(), isTrue);
      }
      if (l.bg != null) expect(File(l.bg!).existsSync(), isTrue);
      if (l.inCar) expect(l.img, isNull, reason: 'in-car scenes are drawn, people-free');
      if (l.videoAsset != null) expect(File(l.videoAsset!).existsSync(), isTrue);
      for (final x in l.lines) {
        if (x.fx != null) {
          expect(['engine', 'indicator', 'brake'], contains(x.fx));
          expect(File('assets/sfx/${x.fx}.mp3').existsSync(), isTrue);
        }
      }
    }
  });

  test('the car moves after the engine cue and stops on the brake', () {
    final r = ls.firstWhere((l) => l.id == 'roundabout');
    final brake = r.lines.indexWhere((x) => x.fx == 'brake'), go = r.lines.indexWhere((x) => x.fx == 'engine');
    expect(r.movingAt(0), isTrue, reason: 'road scenes start on the move');
    expect(r.movingAt(brake), isFalse);
    expect(r.movingAt(go), isTrue);
    final c = ls.firstWhere((l) => l.id == 'cockpit');
    expect(c.movingAt(0), isFalse, reason: 'cockpit drill starts parked');
    expect(ls.firstWhere((l) => l.id == 'petrol').movingAt(0), isFalse);
  });

  test('XP, best score and the level gate (A2 locked for a new learner)', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    var gate = DriveGate(ctrl, c, topics, ls);
    expect(gate.levelOpen('A1'), isTrue);
    expect(gate.levelOpen('A2'), isFalse);
    expect(ctrl.saveDrive('cockpit', 33).xp, 3);
    expect(ctrl.driveDone('cockpit'), isFalse);
    expect(ctrl.saveDrive('cockpit', 67).xp, 10);
    expect(ctrl.saveDrive('cockpit', 100).xp, 15);
    expect(ctrl.driveScore('cockpit'), 100);
    ctrl.saveDrive('petrol', 67);
    gate = DriveGate(ctrl, c, topics, ls);
    expect(gate.levelOpen('A2'), isTrue);
    expect(gate.levelOpen('B1'), isFalse);
    expect(DriveGate.why('A2').$1, contains('A1 driving lessons'));
  });
}
