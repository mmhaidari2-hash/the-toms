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
import 'package:british_life/features/map/map_home.dart' show mapRegions, mapImage;
import 'package:british_life/features/onboarding/placement_screen.dart' show placementResult;

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
  final art = {for (final e in (j('assets/data/scene_art.json') as Map<String, dynamic>).entries) e.key: SceneArt.fromJson(e.value)};
  return ContentBundle(chars, scenes, ms, tiers, moments, roles, Course.fromJson(j('assets/data/course.json')), const Timeline([]), art);
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
    for (final n in [for (final n0 in s.nodes.values) ...[n0, for (final k in n0.byChapter.keys) n0.atChapter(k)]]) {
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
        if (s.playAs == null) add(s.guest ?? 'me', b.suggestion);
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

  test('every story opens on a picture that matches its setting (tool/match_scene_art.py)', () {
    // A painting of the setting always; a people-free location card only where no painting of that place exists.
    final lessonIds = {for (final u in c.course.allUnits) for (final l in u.lessons) ...l.sceneIds};
    final nursery = {for (final l in c.course.pack('nursery')?.lessons ?? const <Lesson>[]) ...l.sceneIds};
    final bad = <String>[];
    for (final s in c.scenes.values) {
      final a = c.artOf(s.id);
      if (a == null) {
        bad.add('${s.id}: no entry in scene_art.json (run tool/match_scene_art.py)');
        continue;
      }
      final base = c.scenes[s.baseId ?? s.id]!;
      final speakers = {base.characterId, for (final n in base.nodes.values) n.speaker};
      if (!File(a.spot).existsSync()) bad.add('${s.id}: missing icon ${a.spot}');
      if (a.bg != null && !File(a.bg!).existsSync()) bad.add('${s.id}: missing backdrop ${a.bg}');
      final cv = c.coverOf(s.id);
      if (a.img == null) {
        if (cv.image != null) bad.add('${s.id}: neutral card expected, got ${cv.image}');
        continue;
      }
      if (!File(a.img!).existsSync()) bad.add('${s.id}: missing painting ${a.img}');
      // 2026-10-23: the best painting of the setting is always used, even if it shows someone not in the scene.
      if (speakers.isEmpty) bad.add('${s.id}: no speakers');
      if (nursery.contains(base.id)) bad.add('${s.id}: nursery scene on a painting of ${a.place}');
      if (cv.image != a.img) bad.add('${s.id}: cover ${cv.image} != art ${a.img}');
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
    expect(lessonIds.every(c.scenes.containsKey), isTrue);
    expect(c.artOf('nur_6_4')!.img, isNull, reason: 'the bite-marks talk is in the nursery: no St Mary\'s gate');
  });

  test('placement test: every level has listening items with audio + a choice item; answers are among choices', () {
    final pj = j('assets/data/placement.json');
    final idx = (j('assets/audio/index.json') as List).cast<String>().toSet();
    for (var lv = 1; lv <= 5; lv++) {
      final its = [for (final i in pj['items']) if (i['level'] == lv) i];
      expect(its.where((i) => i['type'] == 'listen').length, greaterThanOrEqualTo(2), reason: 'level $lv');
      expect(its.where((i) => i['type'] == 'choice'), isNotEmpty, reason: 'level $lv');
      for (final i in its) {
        expect(List<String>.from(i['choices']), contains(i['answer']));
        expect(List<String>.from(i['choices']).toSet().length, i['choices'].length);
        if (i['type'] == 'listen') {
          expect(idx.contains(md5.convert(utf8.encode('${i['speaker']}|${i['text']}')).toString().substring(0, 16)), isTrue, reason: i['text']);
          expect((i['choicesFa'] as List).length, i['choices'].length);
        }
      }
    }
    final sp = pj['speak'];
    expect(idx.contains(md5.convert(utf8.encode('${sp['speaker']}|${sp['text']}')).toString().substring(0, 16)), isTrue);
    expect(placementResult([true, true, false, null, null]), 2);
    expect(placementResult([false]), 1);
    expect(placementResult([true, true, true, true, true]), 5);
  });

  test('map: one region per course level (1-5) + each Career Pack, tap areas inside the map', () {
    expect({for (final r in mapRegions) if (r.level != null) r.level}, {1, 2, 3, 4, 5});
    for (final pk in c.course.packs) {
      expect(mapRegions.where((r) => r.pack == pk.id), isNotEmpty, reason: pk.id);
    }
    expect(File(mapImage).existsSync(), isTrue);
    for (final r in mapRegions) {
      for (final rc in r.rects) {
        expect(rc[0] >= 0 && rc[1] >= 0 && rc[0] + rc[2] <= 1.001 && rc[1] + rc[3] <= 1.001, isTrue, reason: r.id);
      }
    }
  });

  test('career packs: every lesson wired, every line + reply + word + note has Persian, every line has audio', () {
    expect(c.course.packs, isNotEmpty);
    final idx = (j('assets/audio/index.json') as List).cast<String>().toSet();
    final bad = <String>[];
    for (final pk in c.course.packs) {
      expect(pk.lessons.length, greaterThanOrEqualTo(20), reason: pk.id);
      expect(c.characters.any((x) => x.id == pk.lead), isTrue);
      for (final l in pk.lessons) {
        for (final sid in l.sceneIds) {
          final sc = c.scenes[sid];
          if (sc == null) { bad.add('$sid missing'); continue; }
          for (final n in sc.nodes.values) {
            if (n.text.isNotEmpty && (n.translations['fa'] ?? '').trim().isEmpty) bad.add('$sid/${n.id} line fa');
            for (final b in n.branches) { if (b.suggestionFa.trim().isEmpty) bad.add('$sid/${n.id} reply fa'); }
            for (final w in n.newWords) { if (w.fa.trim().isEmpty) bad.add('$sid/${n.id} word ${w.word}'); }
            if (n.cultureNote != null && n.cultureNote!.fa.trim().isEmpty) bad.add('$sid/${n.id} note fa');
          }
        }
      }
    }
    for (final l in spoken(c)) {
      if (!idx.contains(md5.convert(utf8.encode('${l[0]}|${l[1]}')).toString().substring(0, 16)) && ['vida', 'jo', 'oscar', 'dan', 'harris'].contains(l[0])) bad.add('no audio: $l');
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  test('every spoken line has a natural-voice mp3', () {
    final idx = (j('assets/audio/index.json') as List).cast<String>().toSet();
    final missing = [for (final l in spoken(c)) if (!idx.contains(md5.convert(utf8.encode('${l[0]}|${l[1]}')).toString().substring(0, 16))) l];
    expect(missing, isEmpty, reason: missing.take(10).join('\n'));
  });

  test('audio sync: every spoken line is ONE clip in ONE voice, its speaker\'s current voice', () {
    // Voices as configured in tool/render_voices.py; the manifest records which voice rendered each clip.
    final cfg = File('tool/render_voices.py').readAsStringSync();
    final v = {for (final m in RegExp(r"'([a-z]+)':\('(en-[A-Za-z-]+)','([+-]\d+Hz)','([+-]\d+%)'\)").allMatches(cfg)) m[1]!: '${m[2]}|${m[3]}|${m[4]}'};
    final man = (jsonDecode(File('tool/audit/voice_manifest.json').readAsStringSync()) as Map<String, dynamic>);
    final have = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
    String k(String a, String b) => md5.convert(utf8.encode('$a|$b')).toString().substring(0, 16);
    final bad = <String>[];
    var n = 0;
    for (final l in spoken(c)) {
      final key = k(l[0], l[1]);
      if (!have.contains(key)) continue; // missing clips: 'every spoken line has a natural-voice mp3'
      n++;
      if (!v.containsKey(l[0])) bad.add('${l[0]} has no voice of its own: "${l[1]}"');
      final m = man[key] as List?;
      if (m == null || m[0] != l[0] || m[1] != v[l[0]]) bad.add('${l[0]} "${l[1]}" was rendered as $m, now ${v[l[0]]}');
    }
    // Every manifest entry belongs to exactly one speaker+voice, and every clip on disk has one.
    expect(have.difference(man.keys.toSet()).take(5), isEmpty, reason: 'clips without a recorded voice');
    expect(n, greaterThan(30000));
    expect(bad, isEmpty, reason: '${bad.length} drifted:\n${bad.take(15).join('\n')}');
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
