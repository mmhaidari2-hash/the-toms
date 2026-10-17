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


class ContentBundle {
  final List<Character> characters;
  final Map<String, Scene> scenes;
  final Map<String, List<Milestone>> milestones;
  final List<Tier> tiers;
  final List<Moment> moments;
  final List<RoleDef> roles;
  final Course course;
  final Timeline timeline;
  const ContentBundle(this.characters, this.scenes, this.milestones, [this.tiers = const [], this.moments = const [], this.roles = const [], this.course = const Course([]), this.timeline = const Timeline([])]);
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
    return ContentBundle(chars, scenes, ms, tiers, moments, roles, course, timeline);
  }
}
