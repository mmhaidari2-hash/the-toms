import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/messages/messages_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Family messages: content rules, voice clips, spoken versions of replies, the gate and XP.
void main() {
  final ts = Messages.parse(File('assets/data/messages.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();

  test('2+ threads per level, each with a voice note, texting talk, a check and a reply', () {
    for (final lv in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(ts.where((t) => t.level == lv).length, greaterThanOrEqualTo(2), reason: lv);
    }
    expect(ts.map((t) => t.id).toSet().length, ts.length);
    final gl = ts.expand((t) => t.gloss.map((g) => g.term.toLowerCase())).toSet();
    for (final w in ['x', 'ta', 'cheers', 'lol']) {
      expect(gl, contains(w), reason: 'teaches "$w"');
    }
    for (final t in ts) {
      expect(File(t.avatar).existsSync(), isTrue, reason: t.avatar);
      expect(t.msgs.any((m) => m.isVoice), isTrue, reason: t.id);
      expect(t.gloss, isNotEmpty, reason: t.id);
      expect(t.qOptions.length, 3);
      expect(t.replies.length, 3);
      expect(t.replyFa.trim(), isNotEmpty);
      for (final m in t.msgs) {
        expect(m.fa.trim(), isNotEmpty, reason: m.en);
        if (m.isVoice) {
          expect(audio.contains(Voice.key(m.sp, m.en)), isTrue, reason: '${m.sp} clip for "${m.en}"');
          expect(m.ms, greaterThan(500));
        }
      }
      // What the learner says aloud: no emoji, kisses or "lol", times in words.
      expect(t.say, isNot(matches(RegExp(r'(\bx\b|\blol\b|\d\.\d)', caseSensitive: false))), reason: t.say);
      expect(t.say.runes.every((r) => r < 0x2000), isTrue, reason: t.say);
    }
    // Nana Maggie's voicemail is the long ramble.
    final nana = ts.firstWhere((t) => t.id == 't_b1_jumper').msgs.where((m) => m.isVoice);
    expect(nana.fold<int>(0, (a, m) => a + m.ms), greaterThan(15000));
  });

  test('gate: same rule as the rest; best score kept; XP', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    ThreadGate gate() => ThreadGate(ctrl, content, topics, ts);
    expect(gate().levelOpen('A1'), isTrue);
    for (final lv in ['A2', 'B1', 'B2', 'C1']) {
      expect(gate().levelOpen(lv), isFalse, reason: '$lv shut for a new learner');
    }
    expect(ThreadGate(ctrl, content, topics, ts, unlockAll: true).levelOpen('C1'), isTrue);
    expect(Messages.score(qFirst: true, reply: 60), 100);
    expect(Messages.score(qFirst: false, reply: 30), 30);
    final a1 = gate().of('A1');
    expect(ctrl.saveThread(a1[0].id, 30).xp, 3);
    expect(ctrl.threadDone(a1[0].id), isFalse);
    expect(ctrl.saveThread(a1[0].id, 100).xp, 15);
    expect(ctrl.saveThread(a1[0].id, 60).xp, 10);
    expect(ctrl.threadScore(a1[0].id), 100, reason: 'best kept');
    expect(gate().levelOpen('A2'), isFalse);
    ctrl.saveThread(a1[1].id, 60);
    expect(gate().levelOpen('A2'), isTrue);
    expect(ctrl.threadsDone, 2);
    pc.dispose();
  });
}
