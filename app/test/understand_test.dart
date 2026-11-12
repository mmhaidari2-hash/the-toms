import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/engine/conversation_engine.dart';
import 'package:british_life/core/engine/understand.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/legacy_conversation_engine.dart';

/// Owner t306 item 2: smarter offline matching of free typed / spoken replies, with a regression guard over
/// every node of every scene: anything the old matcher accepted still reaches exactly the same branch.
void main() {
  final ids = (jsonDecode(File('assets/data/scenes_index.json').readAsStringSync()) as List).cast<String>();
  final scenes = {for (final id in ids) id: Scene.fromJson(jsonDecode(File('assets/data/scenes/$id.json').readAsStringSync()))};

  String typo(String s) {
    // Swap two letters inside the longest word (a typical typing / recognition slip).
    final ws = s.split(' ');
    var k = 0;
    for (var i = 0; i < ws.length; i++) {
      if (ws[i].length > ws[k].length) k = i;
    }
    final w = ws[k];
    if (w.length < 6) return s;
    ws[k] = '${w.substring(0, 2)}${w[3]}${w[2]}${w.substring(4)}';
    return ws.join(' ');
  }

  List<String> probes(DialogueNode n) => [
    for (final b in n.branches) ...[
      b.suggestion,
      b.suggestion.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ''),
      typo(b.suggestion),
      ...b.keywords,
      b.keywords.join(' '),
      'um ${b.keywords.first} please',
    ],
  ];

  test('regression: every reply the old matcher accepted reaches the same branch (match and route, all scenes)', () {
    var checked = 0, gained = 0;
    final broken = <String>[];
    for (final s in scenes.values) {
      for (final n in s.nodes.values) {
        if (n.branches.isEmpty) continue;
        for (final p in probes(n)) {
          final old = LegacyConversationEngine.match(n, p).branch;
          final now = ConversationEngine.match(n, p).branch;
          final oldR = LegacyConversationEngine.route(s.nodes, n, p).branch;
          final nowR = ConversationEngine.route(s.nodes, n, p).branch;
          checked++;
          if (old != null && !identical(old, now)) broken.add('${s.id}/${n.id} match "$p"');
          if (oldR != null && !identical(oldR, nowR)) broken.add('${s.id}/${n.id} route "$p"');
          if (old == null && now != null) gained++;
        }
      }
    }
    expect(broken, isEmpty, reason: broken.take(20).join('\n'));
    expect(checked, greaterThan(20000));
    // ignore: avoid_print
    print('understand: $checked probes, $gained newly understood (typos etc.)');
  });

  test('typing / recognition slips in model replies: the tolerant layer never picks a different branch', () {
    final missed = <String>[];
    var tried = 0, understood = 0;
    final notUnderstood = <String>[];
    for (final s in scenes.values) {
      for (final n in s.nodes.values) {
        for (final b in n.branches) {
          final t = typo(b.suggestion);
          if (t == b.suggestion) continue;
          if (LegacyConversationEngine.match(n, t).branch != null) continue; // decided by the unchanged strict matcher
          final got = ConversationEngine.match(n, t).branch;
          tried++;
          if (identical(got, b)) {
            understood++;
          } else if (got == null && notUnderstood.length < 25) {
            notUnderstood.add('${s.id}/${n.id}: "$t"');
          }
          if (got != null && !identical(got, b) && n.branches.where((x) => x.suggestion == b.suggestion).length == 1) missed.add('${s.id}/${n.id}: "$t"');
        }
      }
    }
    expect(missed, isEmpty, reason: 'a slip never reaches a different branch:\n${missed.take(20).join('\n')}');
    expect(understood / tried, greaterThan(.7), reason: '$understood of $tried slips understood\n${notUnderstood.join('\n')}');
    // ignore: avoid_print
    print('slips: $understood of $tried understood by the tolerant layer');
  });

  test('safety: clearly off-topic replies are not accepted anywhere', () {
    const offTopic = ['My cat is asleep on the sofa', 'I watched football on Sunday', 'The weather in Tehran is hot', 'banana keyboard mountain', 'Can you repeat that'];
    final accepted = <String>[];
    for (final s in scenes.values) {
      for (final n in s.nodes.values) {
        if (n.branches.isEmpty) continue;
        for (final p in offTopic) {
          final old = LegacyConversationEngine.match(n, p).branch;
          final now = ConversationEngine.match(n, p).branch;
          if (old == null && now != null) accepted.add('${s.id}/${n.id}: "$p" → ${now.suggestion}');
        }
      }
    }
    expect(accepted.length, lessThanOrEqualTo(3), reason: accepted.take(30).join('\n'));
  });

  group('understands natural variants', () {
    DialogueNode node(String id, String nodeId) => scenes[id]!.nodes[nodeId]!;

    test('nur_7_3 n4: paraphrases of "Keep practising \'Can I have a turn?\' at home" reach that branch', () {
      final n = node('nur_7_3', 'n4');
      final target = n.branches.firstWhere((b) => b.suggestion.contains('turn'));
      expect(LegacyConversationEngine.match(n, 'We could practise asking for a turn at home').branch, isNull, reason: 'the gap that QA found');
      for (final p in ['We could practise asking for a turn at home', 'Practice taking turns at home', 'keep practicing can I have a turn at home']) {
        expect(ConversationEngine.match(n, p).branch, same(target), reason: p);
      }
    });

    test('contractions, digits, US spelling, synonyms and word endings fold together', () {
      expect(Understand.tokens("I'd like it"), ['i', 'would', 'like', 'it']);
      expect(Understand.tokens("don't"), ['do', 'not']);
      expect(Understand.tokens('8 blocks'), ['eight', 'blocks']);
      expect(Understand.near('blocks', 'block'), isTrue);
      expect(Understand.canon('color'), Understand.canon('colour'));
      expect(Understand.canon('apartment'), Understand.canon('flat'));
      expect(Understand.canon('elevator'), Understand.canon('lift'));
      expect(Understand.near('counted', 'count'), isTrue);
      expect(Understand.near('meeting', 'meteing'), isTrue);
      expect(Understand.near(Understand.canon('practicing'), 'practise'), isTrue);
      expect(Understand.canon('organize'), 'organise');
    });

    test('speech-recognition slips: swaps and single edits on long words, never on short ones', () {
      expect(Understand.near('saffron', 'safron'), isTrue);
      expect(Understand.near('prescription', 'perscription'), isTrue);
      expect(Understand.near('appointment', 'apointmant'), isTrue);
      expect(Understand.near('bag', 'bog'), isFalse);
      expect(Understand.near('card', 'cart'), isFalse);
    });

    test('negation must agree: "no" never takes a yes-branch through the tolerant layer', () {
      final n = DialogueNode.fromJson({
        'id': 'x',
        'speaker': 'npc',
        'text': 'Would you like a receipt?',
        'branches': [
          {
            'keywords': ['receipt please'],
            'suggestion': 'Yes, a printed receipt please.',
            'suggestionFa': '',
            'next': 'a',
          },
          {
            'keywords': ['no thanks'],
            'suggestion': "No thanks, I don't need a receipt.",
            'suggestionFa': '',
            'next': 'b',
          },
        ],
      });
      expect(ConversationEngine.match(n, 'I do not want a printed one').branch?.next, isNot('a'));
      expect(ConversationEngine.match(n, 'yes a recipt please').branch?.next, 'a');
    });
  });
}
