export '../models/timeline.dart';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/dialogue_node.dart';
import '../models/milestone.dart';
import '../models/place.dart';
import '../models/course.dart';
import '../models/timeline.dart';
export '../models/course.dart';

class Moment {
  final String sceneId;
  final String? cover;
  const Moment(this.sceneId, this.cover);
}

class RoleDef {
  final String id;
  final List<String> scenes;
  const RoleDef(this.id, this.scenes);
}


/// The picture a conversation opens on (tool/match_scene_art.py -> assets/data/scene_art.json): a painting that
/// shows the scene's setting and no main character who isn't in it, or else a neutral, people-free location card.
class SceneArt {
  final String? img, place, bg;
  final String spot, label, labelFa;
  const SceneArt({this.img, this.place, this.bg, required this.spot, required this.label, this.labelFa = ''});
  factory SceneArt.fromJson(Map<String, dynamic> j) =>
      SceneArt(img: j['img'], place: j['place'], bg: j['bg'], spot: j['spot'], label: j['label'] ?? '', labelFa: j['labelFa'] ?? '');
}

class ContentBundle {
  final List<Character> characters;
  final Map<String, Scene> scenes;
  final Map<String, List<Milestone>> milestones;
  final List<Tier> tiers;
  final List<Moment> moments;
  final List<RoleDef> roles;
  final Course course;
  final Timeline timeline;
  final Map<String, SceneArt> art;
  const ContentBundle(this.characters, this.scenes, this.milestones, [this.tiers = const [], this.moments = const [], this.roles = const [], this.course = const Course([]), this.timeline = const Timeline([]), this.art = const {}]);
  /// Art for a scene (role-switch variants use their base scene's).
  /// Picture for a lesson card or unit banner: its first scene's painting, else that setting's people-free blur.
  String? lessonPicture(Lesson l) {
    final a = l.sceneIds.isEmpty ? null : artOf(l.sceneIds.first);
    return a == null ? place(l.place)?.image : (a.img ?? a.bg);
  }
  SceneArt? artOf(String sceneId) => art[scenes[sceneId]?.baseId ?? sceneId.split('__').first];
  /// Role-switch variants of a scene: role id -> variant scene.
  Map<String, Scene> variantsOf(String sceneId) => {for (final s in scenes.values) if (s.baseId == sceneId && s.playAs != null) s.playAs!: s};
  Character? characterOrNull(String id) => characters.where((c) => c.id == id).firstOrNull;
  /// Scenes only playable in a given role (Sec 3.2 character switching).
  String? roleOfScene(String id) => roles.where((r) => r.scenes.contains(id)).firstOrNull?.id;
  /// The place whose painting hosts this scene. Role-switch variants use their base scene's place.
  Place? hostOf(String sceneId) {
    final id = scenes[sceneId]?.baseId ?? sceneId.split('__').first;
    return places.where((p) => p.sceneIds.contains(id)).firstOrNull ?? (course.placeOfScene(id) == null ? null : place(course.placeOfScene(id)!));
  }
  /// Fallback painting so a story never opens without a scene: explicit hint, then a painting featuring the lead.
  Place? paintingOf(String sceneId) {
    final s = scenes[sceneId]; final base = scenes[s?.baseId ?? sceneId.split('__').first] ?? s;
    final hint = base?.placeHint ?? s?.placeHint;
    final withImg = places.where((p) => p.image != null);
    return (hint == null ? null : place(hint)) ??
        withImg.where((p) => p.hotspots.any((h) => h.characterId == base?.characterId)).firstOrNull ??
        withImg.firstOrNull;
  }
  /// The painting a story opens on. `generic` is true only when nothing specific matched (last-resort painting).
  ({String? image, Place? host, bool generic}) coverOf(String sceneId) {
    final a = artOf(sceneId);
    if (a != null) return (image: a.img, host: a.place == null ? null : place(a.place!), generic: a.img == null);
    final baseId = scenes[sceneId]?.baseId ?? sceneId.split('__').first;
    final direct = hostOf(sceneId);
    if (direct?.image != null) return (image: direct!.image, host: direct, generic: false);
    final moment = moments.where((m) => m.sceneId == baseId).firstOrNull?.cover;
    if (moment != null) return (image: moment, host: direct, generic: false);
    final p = paintingOf(sceneId);
    final s = scenes[sceneId]; final base = scenes[baseId] ?? s;
    final specific = p != null && (p.id == (base?.placeHint ?? s?.placeHint) || p.hotspots.any((h) => h.characterId == base?.characterId));
    return (image: p?.image, host: p, generic: !specific);
  }
  Iterable<Place> get places => tiers.expand((t) => t.places);
  Place? place(String id) => places.where((p) => p.id == id).firstOrNull;
  int tierIndexOfScene(String sceneId) => tiers.indexWhere((t) => t.sceneIds.contains(sceneId));
  int tierIndexOfPlace(String placeId) => tiers.indexWhere((t) => t.places.any((p) => p.id == placeId));
  Character character(String id) => characters.firstWhere((c) => c.id == id);
  List<Milestone> milestonesFor(String id) => milestones[id] ?? defaultMilestones;
  static const defaultMilestones = [
    Milestone(id: 'M0', title: 'Getting acquainted', titleFa: 'آشنایی', description: '', descriptionFa: '', threshold: 0),
    Milestone(id: 'M1', title: 'Friendly', titleFa: 'دوستانه', description: '', descriptionFa: '', threshold: 25),
    Milestone(id: 'M2', title: 'Close', titleFa: 'صمیمی', description: '', descriptionFa: '', threshold: 60),
  ];
}

class ContentRepository {
  final AssetBundle bundle;
  ContentRepository([AssetBundle? b]) : bundle = b ?? rootBundle;

  Future<dynamic> _json(String p) async => jsonDecode(await bundle.loadString(p));

  Future<ContentBundle> load() async {
    final chars = [for (final c in await _json('assets/data/characters.json')) Character.fromJson(c)];
    // One bundle (tool/bundle_scenes.py): ~2000 scenes incl. role variants must not be ~2000 requests on iPhone.
    final bundle = await _json('assets/data/scenes_bundle.json') as Map<String, dynamic>;
    final scenes = <String, Scene>{for (final e in bundle.entries) e.key: Scene.fromJson(e.value)};
    final ms = <String, List<Milestone>>{};
    for (final id in List<String>.from(await _json('assets/data/growth_index.json'))) {
      final g = await _json('assets/data/${id}_growth.json');
      ms[g['characterId'] as String] = [for (final m in g['milestones']) Milestone.fromJson(m)];
    }
    final tiers = [for (final t in await _json('assets/data/places.json')) Tier.fromJson(t)];
    final moments = [for (final m in await _json('assets/data/moments.json')) Moment(m['sceneId'], m['cover'])];
    final roles = [for (final r in await _json('assets/data/roles.json')) RoleDef(r['id'], List<String>.from(r['scenes']))];
    final course = Course.fromJson(await _json('assets/data/course.json'));
    Timeline timeline = const Timeline([]);
    try {
      timeline = Timeline.fromJson(await _json('assets/data/timeline.json'));
    } catch (_) {}
    var art = const <String, SceneArt>{};
    try {
      art = {for (final e in (await _json('assets/data/scene_art.json') as Map<String, dynamic>).entries) e.key: SceneArt.fromJson(e.value)};
    } catch (_) {}
    return ContentBundle(chars, scenes, ms, tiers, moments, roles, course, timeline, art);
  }
}
