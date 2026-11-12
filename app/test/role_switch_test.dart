import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/engine/role_switch.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic _j(String p) => jsonDecode(File(p).readAsStringSync());

ContentBundle _bundle() {
  final chars = [for (final c in _j('assets/data/characters.json')) Character.fromJson(c)];
  final scenes = <String, Scene>{for (final e in (_j('assets/data/scenes_bundle.json') as Map<String, dynamic>).entries) e.key: Scene.fromJson(e.value)};
  final roles = [for (final r in _j('assets/data/roles.json')) RoleDef(r['id'], List<String>.from(r['scenes']))];
  return ContentBundle(chars, scenes, const {}, const [], const [], roles);
}

/// Full role switching (owner t310, MASTERBOOK_GAPS item 2): every scene × every family member and every speaker
/// either yields a playable dialogue or is hidden with an EN+FA reason.
void main() {
  final c = _bundle();
  final family = [for (final ch in c.characters) if (ch.family) ch.id];

  test('sweep: every scene × role is playable to the end, or hidden with a reason', () {
    var pairs = 0, playable = 0, hidden = 0, scenesWithSwap = 0, lines = 0;
    final byRole = <String, int>{};
    final hiddenWhy = <String, int>{};
    for (final s in c.scenes.values) {
      final opts = RoleSwitch.optionsOf(s, c);
      expect(opts.first.usual, isTrue, reason: s.id);
      expect(opts.first.id, RoleSwitch.usualOf(s));
      final ids = opts.map((o) => o.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicate parts in ${s.id}');
      // Every family member is either offered or hidden with a reason.
      for (final f in family) {
        if (f != RoleSwitch.usualOf(s)) expect(ids, contains(f), reason: '${s.id} must account for $f');
      }
      var any = false;
      for (final o in opts.skip(1)) {
        pairs++;
        if (!o.playable) {
          hidden++;
          expect(o.reason, isNotNull, reason: '${s.id}/${o.id}');
          expect(o.reason!.$1.trim(), isNotEmpty);
          expect(RegExp(r'[\u0600-\u06FF]').hasMatch(o.reason!.$2), isTrue, reason: 'Persian reason ${s.id}/${o.id}');
          final k = o.absent ? 'absent' : o.reason!.$1.contains('loop') ? 'loop' : 'other path';
          hiddenWhy[k] = (hiddenWhy[k] ?? 0) + 1;
          continue;
        }
        any = true;
        playable++;
        byRole[o.id] = (byRole[o.id] ?? 0) + 1;
        // Simulate the scene exactly as the screen plays it in this role.
        final w = RoleSwitch.walk(s, o.id);
        expect(w.loops, isFalse, reason: '${s.id}/${o.id}');
        expect(w.mine, o.lines);
        expect(w.mine, greaterThan(0));
        expect(w.nodes.last.isEnd || RoleSwitch.partnerBranch(w.nodes.last)?.next == null || !s.nodes.containsKey(RoleSwitch.partnerBranch(w.nodes.last)!.next), isTrue,
            reason: '${s.id}/${o.id} must reach an ending');
        for (final n in w.nodes) {
          if (n.speaker == o.id) {
            lines++;
            // The learner saying the line itself is always accepted (the offline judge).
            expect(RoleSwitch.judge(n.text, n.text).$1, isTrue, reason: '${s.id}/${n.id}: ${n.text}');
          } else if (!n.isEnd) {
            // Everyone else's line gets an answer from the usual part, so the story never stalls.
            expect(RoleSwitch.partnerBranch(n), isNotNull, reason: '${s.id}/${n.id}');
          }
        }
        if (o.variant != null) expect(c.scenes[o.variant!]!.playAs, o.id);
      }
      if (any) scenesWithSwap++;
    }
    // ignore: avoid_print
    print('ROLE SWEEP scenes=${c.scenes.length} withSwap=$scenesWithSwap pairs=$pairs playable=$playable hidden=$hidden '
        'roleLines=$lines byRole=$byRole hiddenWhy=$hiddenWhy');
    expect(scenesWithSwap, greaterThan(1000));
  });

  test('a family member who is not in a scene is hidden with the reason; one who speaks is offered', () {
    final s = c.scenes['tom_breakfast']!;
    final opts = RoleSwitch.optionsOf(s, c);
    expect(opts.firstWhere((o) => o.id == 'tom').playable, isTrue);
    final ryan = opts.firstWhere((o) => o.id == 'ryan');
    expect(ryan.playable, isFalse);
    expect(ryan.absent, isTrue);
    expect(ryan.reason!.$1, 'Ryan is not in this scene');
    final h = RoleSwitch.hiddenSummary(opts, c)!;
    expect(h.$1, startsWith('Not in this story: '));
    expect(h.$2, startsWith('در این داستان نیستند: '));
  });

  test('multi-speaker scenes offer every speaker, not only the lead', () {
    final multi = c.scenes.values.where((s) => s.baseId == null && {for (final n in s.nodes.values) n.speaker}.length >= 3).toList();
    expect(multi, isNotEmpty);
    var extra = 0;
    for (final s in multi) {
      extra += RoleSwitch.playable(s, c).where((o) => o.id != s.characterId).length;
    }
    expect(extra, greaterThan(0));
  });

  test('the three role-locked stories and the authored variants are untouched', () {
    for (final r in c.roles) {
      for (final id in r.scenes) {
        expect(c.roleOfScene(id), r.id);
      }
    }
    final s = c.scenes['tom_breakfast']!;
    expect(RoleSwitch.optionsOf(s, c).firstWhere((o) => o.id == 'tom').variant, 'tom_breakfast__as_tom');
  });

  test('judge: tolerant but not anything goes', () {
    const line = 'Of course. Can I take your full name and date of birth, please?';
    expect(RoleSwitch.judge(line, line).$1, isTrue);
    expect(RoleSwitch.judge(line, 'of course can i take your full name and date of birth please').$1, isTrue);
    expect(RoleSwitch.judge(line, 'Can I take your full name and your date of birth').$1, isTrue);
    expect(RoleSwitch.judge(line, 'I like football and pizza').$1, isFalse);
    expect(RoleSwitch.judge(line, '').$1, isFalse);
  });

  test('per-role progress: best score, runs and trust as that character', () {
    final store = <String, String>{};
    final s = c.scenes['tom_breakfast']!;
    String pref(String k) => store[k] ?? '';
    void set(String k, String v) => store[k] = v;
    RoleSwitch.record(s, 'tom', 3, 4, pref, set);
    RoleSwitch.record(s, 'tom', 1, 4, pref, set);
    expect(RoleSwitch.readProgress(store[RoleSwitch.progressKey(s, 'tom')]!), (75, 2));
    expect(store[RoleSwitch.trustKey('tom')], '4');
    RoleSwitch.record(s, 'leslie', 0, 0, pref, set);
    expect(store.containsKey(RoleSwitch.progressKey(s, 'leslie')), isFalse);
    // A variant counts towards its base scene.
    final v = c.scenes['tom_breakfast__as_tom']!;
    expect(RoleSwitch.progressKey(v, 'tom'), RoleSwitch.progressKey(s, 'tom'));
  });
}
