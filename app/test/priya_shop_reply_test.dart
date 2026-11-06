import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/ai/dialogue_brain.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/engine/conversation_engine.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:british_life/core/models/milestone.dart';
import 'package:british_life/core/models/place.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic j(String p) => jsonDecode(File(p).readAsStringSync());

ContentBundle load() {
  final chars = [for (final c in j('assets/data/characters.json')) Character.fromJson(c)];
  final scenes = {for (final id in j('assets/data/scenes_index.json')) id as String: Scene.fromJson(j('assets/data/scenes/$id.json'))};
  final ms = <String, List<Milestone>>{
    for (final id in j('assets/data/growth_index.json')) id as String: [for (final m in j('assets/data/${id}_growth.json')['milestones']) Milestone.fromJson(m)],
  };
  final tiers = [for (final t in j('assets/data/places.json')) Tier.fromJson(t)];
  final moments = [for (final m in j('assets/data/moments.json')) Moment(m['sceneId'], m['cover'])];
  final roles = [for (final r in j('assets/data/roles.json')) RoleDef(r['id'], List<String>.from(r['scenes']))];
  return ContentBundle(chars, scenes, ms, tiers, moments, roles);
}

void main() {
  final c = load();
  final shop = c.scenes['l1_u43_1']!;
  final n1 = shop.nodes['n1']!;
  final breakfast = c.scenes['tom_breakfast']!.nodes['t1']!;

  BrainReply say(String text) => const OfflineBrain().respondSync(BrainRequest(
        sceneId: shop.id,
        characterId: 'priya',
        node: n1,
        userText: text,
        level: 'A1',
        nodes: shop.nodes,
      ));

  test('a named item the lesson does not sell is not treated as the help line', () {
    // "can" and "please" used to score this sentence onto the first branch.
    for (final text in [
      'yes please can i have candy',
      'yes pleas can i have candy',
      'Yes, please — can I have candy?',
      'candy',
    ]) {
      expect(ConversationEngine.match(n1, text).branch, isNull, reason: text);
      final reply = say(text);
      expect(reply.branch, isNull, reason: text);
      expect(reply.trustDelta, 0, reason: text);
    }
  });

  test('help, a lesson item, spelling, and punctuation still continue', () {
    expect(say('Excuse me, can you help me?').branch!.next, 'n2');
    expect(say('yes please').branch!.next, 'n2');
    expect(say('Yes, please!').branch!.next, 'n2');
    expect(say('can you help').branch!.next, 'n2');

    for (final text in [
      'saffron',
      'safron',
      'yes please can i have saffron',
      'Do you sell saffron?',
      "I'm looking for saffron.",
      'Where are the spices?',
    ]) {
      expect(say(text).branch!.next, 'n3', reason: text);
    }
  });

  test('negatives and unrelated sentences do not advance the shop', () {
    for (final text in ["I don't want saffron", 'no thanks', 'not candy', "what's the weather", 'yesterday banana']) {
      expect(say(text).branch, isNull, reason: text);
    }
    expect(ConversationEngine.match(breakfast, 'YES, please!!').branch!.next, 't2');
    expect(ConversationEngine.match(breakfast, 'asdf qwerty').matched, isFalse);
  });

  test('an unsupported request does not add a successful branch', () {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final box = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    addTearDown(box.dispose);
    final progress = box.read(progressProvider.notifier);
    final before = box.read(progressProvider).successMap['priya'] ?? 0;
    final candy = say('yes please can i have candy');
    progress.applyTurn(shop, candy.branch, candy.usedWords, c, speaker: 'priya', trustDelta: candy.trustDelta);
    expect(box.read(progressProvider).successMap['priya'] ?? 0, before);

    final item = say('Do you sell saffron?');
    progress.applyTurn(shop, item.branch, item.usedWords, c, speaker: 'priya', trustDelta: item.trustDelta);
    expect(box.read(progressProvider).successMap['priya'], before + 1);
  });
}
