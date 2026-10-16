import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';

import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/engine/conversation_engine.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:british_life/core/models/milestone.dart';
import 'package:british_life/core/models/place.dart';
import 'package:british_life/core/engine/connected_speech.dart';
import 'package:british_life/core/engine/recast_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:british_life/features/place/place_screen.dart' show hitTest;

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


/// Every line the app can speak, keyed exactly as Voice looks it up.
List<List<String>> spoken(ContentBundle c) {
  final out = <List<String>>[];
  final have = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
  String k(String a, String b) => md5.convert(utf8.encode('$a|$b')).toString().substring(0, 16);
  void add(String sp, String? t) {
    if (t == null || t.trim().isEmpty) return;
    // Mirrors Voice._find: Mehdi as NPC reuses the guest ('me') recordings, with or without the {you} placeholder.
    for (final s2 in {sp, if (sp == 'mehdi') 'me'}) {
      for (final t2 in {t, t.replaceAll('Mehdi', '{you}')}) {
        if (have.contains(k(s2, t2))) {
          out.add([s2, t2]);
          return;
        }
      }
    }
    out.add([sp, t]);
  }
  for (final s in c.scenes.values) {
    for (final n in s.nodes.values) {
      add(n.speaker, n.text);
      add(n.speaker, n.coolReply);
      add(n.speaker, ConnectedSpeech.of(n).connected);
      if (n.branches.isNotEmpty) {
        add(n.speaker, RecastEngine.ghostHint(n));
        add(n.speaker, 'No worries — have a peek at these 👇');
      }
      for (final r in n.recasts) {
        add(n.speaker, r.echo);
      }
      for (final i in ['give me tea', 'give me water', 'give me bread', 'give me coffee', 'i want tea']) {
        add(n.speaker, RecastEngine.recast(n, i)?.echo);
      }
      for (final b in n.branches) {
        if (s.playAs == null) add('me', b.suggestion);
      }
      for (final w in n.newWords) {
        add('narrator', w.word);
      }
    }
  }
  for (final t in c.tiers) {
    for (final p in t.places) {
      for (final h in p.hotspots) {
        if (h.characterId.isNotEmpty) add(h.characterId, h.ambientEn);
        if (h.prop != null) {
          add('narrator', h.prop!.phrase);
          add('narrator', h.prop!.word);
          for (final m in h.prop!.mini) {
            add(m[0], m[1]);
          }
        }
      }
    }
  }
  return out;
}

void main() {
  final c = load();

  test('dump spoken lines for tool/render_voices.py', () {
    File('build/voice_lines.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(spoken(c)));
  });

  test('every spoken line has a natural-voice mp3', () {
    final idx = (j('assets/audio/index.json') as List).cast<String>().toSet();
    final missing = [for (final l in spoken(c)) if (!idx.contains(md5.convert(utf8.encode('${l[0]}|${l[1]}')).toString().substring(0, 16))) l];
    expect(missing, isEmpty, reason: missing.take(10).join('\n'));
  });

  test('every conversation: all nodes reachable, always reaches an end, suggested replies pick their branch', () {
    for (final s in c.scenes.values) {
      final seen = <String>{};
      final todo = [s.start];
      while (todo.isNotEmpty) {
        final id = todo.removeLast();
        if (!seen.add(id)) continue;
        final n = s.nodes[id];
        expect(n, isNotNull, reason: '${s.id}: missing node $id');
        for (final b in n!.branches) {
          if (b.next != null) todo.add(b.next!);
          final m = ConversationEngine.match(n, b.suggestion);
          expect(m.branch?.next, b.next, reason: '${s.id}/$id suggestion "${b.suggestion}" picks the wrong branch');
        }
      }
      expect(seen.length, s.nodes.length, reason: '${s.id}: unreachable ${s.nodes.keys.toSet().difference(seen)}');
      // every node can reach an end
      bool ends(String id, Set<String> path) {
        final n = s.nodes[id]!;
        if (n.isEnd) return true;
        if (!path.add(id)) return false;
        return n.branches.any((b) => b.next == null || ends(b.next!, {...path}));
      }

      for (final id in s.nodes.keys) {
        expect(ends(id, {}), isTrue, reason: '${s.id}/$id never ends');
      }
    }
  });

  test('every person in every painting is tappable at their centre', () {
    for (final t in c.tiers) {
      for (final p in t.places) {
        for (final h in p.hotspots.where((h) => !h.isProp && h.rect != null)) {
          final pts = h.shape ?? [[h.rect![0] + h.rect![2] / 2, h.rect![1] + h.rect![3] / 2]];
          final cx = pts.map((e) => e[0]).reduce((a, b) => a + b) / pts.length, cy = pts.map((e) => e[1]).reduce((a, b) => a + b) / pts.length;
          final hit = hitTest(p.hotspots, cx, cy);
          if (hit?.isProp ?? false) continue;
          expect(hit?.characterId, h.characterId, reason: '${p.id}/${h.characterId} centre hits ${hit?.characterId ?? 'nothing'}');
        }
      }
    }
  });
}
