import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/engine/role_switch.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/device_tts.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner t338: "when you answer someone only their reply is read; YOUR line is never read" (real Android phone,
/// Hartley & Wren Homes, playing Olivia). The learner's own line must play its recorded clip (or, with no
/// recording, the device's British voice) when tapped and after it is said.
dynamic _j(String p) => jsonDecode(File(p).readAsStringSync());

class _Tts implements DeviceTtsBackend {
  bool has;
  final said = <String>[];
  _Tts({this.has = true});
  @override
  Future<bool> available() async => has;
  @override
  Future<bool> speak(String text, double rate) async {
    said.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}
}

ContentBundle _bundle() {
  final chars = [for (final c in _j('assets/data/characters.json')) Character.fromJson(c)];
  final scenes = <String, Scene>{for (final e in (_j('assets/data/scenes_bundle.json') as Map<String, dynamic>).entries) e.key: Scene.fromJson(e.value)};
  final roles = [for (final r in _j('assets/data/roles.json')) RoleDef(r['id'], List<String>.from(r['scenes']))];
  return ContentBundle(chars, scenes, const {}, const [], const [], roles);
}

String _pack(Scene s) {
  final id = s.baseId ?? s.id;
  final m = RegExp(r'^l(\d)_').firstMatch(id);
  if (m != null) return 'course L${m[1]}';
  return id.split('_').first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final index = (_j('assets/audio/index.json') as List).cast<String>().toSet();
  const olivia = "Of course. I've got Thursday at half past five or Saturday at ten. Which is better for you?";
  tearDown(() {
    Voice.debugSetAudio(keys: {});
    DeviceTts.debugBackend = null;
  });

  test('the Olivia line (est_1_1 n3, played as Olivia) resolves its recorded clip', () async {
    final played = <String>[];
    Voice.debugSetAudio(keys: index, player: (a, _) async {
      played.add(a);
      return true;
    });
    final s = _bundle().scenes['est_1_1']!;
    expect(s.nodes['n3']!.speaker, 'agent');
    expect(s.nodes['n3']!.text, olivia);
    expect(Voice.has('agent', olivia), isTrue);
    expect(await Voice.say('agent', olivia, shown: olivia, deviceFallback: true), isTrue);
    expect(played, ['assets/audio/${Voice.key('agent', olivia)}.mp3']);
    expect(File('assets/audio/${Voice.key('agent', olivia)}.mp3').existsSync(), isTrue);
    expect(Voice.failure.value, isNull);
    // The wrong pairing the picture tap used to send (Olivia's voice, the previous reply's words) is unrecorded:
    // that was the "No recording for this line yet" notice on the phone.
    expect(Voice.has('agent', 'Yes, please. Can I see it this week?'), isFalse);
  });

  test('a learner line with no recording falls back to the device British voice, no notice', () async {
    final tts = _Tts();
    DeviceTts.debugBackend = tts;
    Voice.debugSetAudio(keys: {}, player: (_, _) async => true);
    expect(await Voice.say('agent', 'An unrecorded line.', shown: 'An unrecorded line.', deviceFallback: true), isTrue);
    expect(tts.said, ['An unrecorded line.']);
    expect(Voice.failure.value, isNull);
    // Playback of an existing clip fails (offline, no cache): the device voice reads it instead.
    tts.said.clear();
    Voice.debugSetAudio(keys: {Voice.key('agent', olivia)}, player: (_, _) async => false);
    expect(await Voice.say('agent', olivia, deviceFallback: true), isTrue);
    expect(tts.said, [olivia]);
    // NPC lines keep "silent beats robotic": no device voice without the opt-in.
    tts.said.clear();
    Voice.debugSetAudio(keys: {}, player: (_, _) async => true);
    expect(await Voice.say('agent', 'An unrecorded line.'), isFalse);
    expect(tts.said, isEmpty);
    expect(Voice.failure.value?.kind, VoiceFailureKind.missing);
  });

  test('no recording and no device voice: the notice stays', () async {
    DeviceTts.debugBackend = _Tts(has: false);
    Voice.debugSetAudio(keys: {}, player: (_, _) async => true);
    expect(await Voice.say('agent', 'An unrecorded line.', deviceFallback: true), isFalse);
    expect(Voice.failure.value?.kind, VoiceFailureKind.missing);
  });

  test('sweep: every scene × playable role — learner lines with a recorded clip vs device-voice fallback', () {
    Voice.debugSetAudio(keys: index, player: (_, _) async => true);
    final c = _bundle();
    final byPack = <String, List<int>>{}; // [usualLines, usualRec, swapLines, swapRec, swapPartner, swapPartnerRec]
    final missing = <String>[];
    var pairs = 0;
    for (final s in c.scenes.values) {
      final p = byPack.putIfAbsent(_pack(s), () => List.filled(6, 0));
      for (final o in RoleSwitch.optionsOf(s, c)) {
        if (!o.playable) continue;
        pairs++;
        if (o.usual) {
          final voice = RoleSwitch.usualOf(s);
          final lines = {for (final n in s.nodes.values) for (final b in n.branches) b.suggestion};
          for (final l in lines) {
            p[0]++;
            if (Voice.has(voice, l)) {
              p[1]++;
            } else {
              missing.add('${s.id}\t(usual:$voice)\t$l');
            }
          }
          continue;
        }
        final w = RoleSwitch.walk(s, o.id);
        final lines = <String>{};
        final partner = <String>{};
        for (final n in w.nodes) {
          if (n.speaker == o.id) {
            lines.add(n.text);
            for (final v in n.byChapter.values) {
              lines.add(v.$1);
            }
          }
          if (n.speaker != o.id) continue;
        }
        for (final n in w.nodes) {
          if (n.speaker != o.id && n.branches.isNotEmpty) partner.add(RoleSwitch.partnerBranch(n)!.suggestion);
        }
        for (final l in lines) {
          p[2]++;
          if (Voice.has(o.id, l)) {
            p[3]++;
          } else {
            missing.add('${s.id}\t(as:${o.id})\t$l');
          }
        }
        for (final l in partner) {
          p[4]++;
          if (Voice.has(RoleSwitch.usualOf(s), l)) p[5]++;
        }
      }
    }
    final keys = byPack.keys.toList()..sort();
    final t = List.filled(6, 0);
    final rows = <String>['pack\tusual lines\trecorded\tTTS\tswapped lines\trecorded\tTTS\tpartner replies\trecorded\tTTS'];
    for (final k in keys) {
      final v = byPack[k]!;
      for (var i = 0; i < 6; i++) {
        t[i] += v[i];
      }
      rows.add('$k\t${v[0]}\t${v[1]}\t${v[0] - v[1]}\t${v[2]}\t${v[3]}\t${v[2] - v[3]}\t${v[4]}\t${v[5]}\t${v[4] - v[5]}');
    }
    rows.add('TOTAL\t${t[0]}\t${t[1]}\t${t[0] - t[1]}\t${t[2]}\t${t[3]}\t${t[2] - t[3]}\t${t[4]}\t${t[5]}\t${t[4] - t[5]}');
    Directory('build').createSync(recursive: true);
    File('build/learner_line_audio.tsv').writeAsStringSync('${rows.join('\n')}\n');
    File('build/learner_line_audio_missing.tsv').writeAsStringSync('${missing.join('\n')}\n');
    // ignore: avoid_print
    print('scenes ${c.scenes.length}, playable scene×role pairs $pairs\n${rows.join('\n')}');
    expect(c.scenes.length, greaterThan(1000));
    // The homes pack (Hartley & Wren) is fully recorded in every role.
    expect(byPack['est']![2], byPack['est']![3]);
  });

  group('conversation at 375x667', () {
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

    Future<(List<String>, Future<void> Function([int]))> boot(WidgetTester t, String route) async {
      BL.useGoogleFonts = false;
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final played = <String>[];
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Voice.debugSetAudio(keys: index, player: (a, _) async {
        played.add(a.split('/').last.replaceAll('.mp3', ''));
        return true;
      }, allowLoad: false);
      Future<void> wait([int n = 12]) async {
        for (var i = 0; i < n; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
          await t.pump(const Duration(milliseconds: 300));
        }
        expect(t.takeException(), isNull);
      }

      router.go(route);
      await wait(20);
      return (played, wait);
    }

    Finder myLine(String s) => find.descendant(of: find.byKey(const ValueKey('my-line')), matching: find.text(s));

    testWidgets('playing Olivia: Hear it plays her clip; after saying it her clip is read, then the reply', (t) async {
      final (played, wait) = await boot(t, '/chat/est_1_1?as=agent');
      for (var i = 0; i < 6 && myLine(olivia).evaluate().isEmpty; i++) {
        if (find.byKey(const ValueKey('my-line')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('my-line')));
        }
        await wait(15);
      }
      expect(myLine(olivia), findsOneWidget);
      played.clear();
      await t.tap(find.byTooltip('Hear it'));
      await wait(3);
      expect(played, [Voice.key('agent', olivia)], reason: 'the speaker icon plays the recorded line');
      expect(Voice.failure.value, isNull);
      played.clear();
      await t.tap(find.byKey(const ValueKey('my-line')));
      await wait(20);
      expect(played.first, Voice.key('agent', olivia), reason: 'the learner\'s line is read after it is said');
      expect(played, contains(Voice.key('me', 'Saturday at ten is perfect.')), reason: 'then the usual part answers');
      expect(Voice.failure.value, isNull);
      router.go('/');
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('usual part: the reply is read in the learner voice before Olivia answers', (t) async {
      final (played, wait) = await boot(t, '/chat/est_1_1');
      expect(played, contains(Voice.key('agent', 'Good morning, Hartley and Wren Homes, Olivia speaking. How can I help?')));
      played.clear();
      await t.enterText(find.byType(TextField), "Hello. I'm calling about the one-bed flat on Mare Street.");
      await t.tap(find.byTooltip('Send'));
      await wait(25);
      final mine = Voice.key('me', "Hello. I'm calling about the one-bed flat on Mare Street.");
      expect(played, contains(mine));
      final theirs = Voice.key('agent', "Yes, it's still available. It's twelve hundred pounds a month. Would you like to come and see it?");
      expect(played, contains(theirs));
      expect(played.indexOf(mine), lessThan(played.indexOf(theirs)), reason: 'your line first, then the answer');
      router.go('/');
      await t.pump(const Duration(seconds: 1));
    });
  });
}
