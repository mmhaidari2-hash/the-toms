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
  Place? hostOf(String sceneId) => places.where((p) => p.sceneIds.contains(sceneId)).firstOrNull ?? (course.placeOfScene(sceneId) == null ? null : place(course.placeOfScene(sceneId)!));
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
    final ids = List<String>.from(await _json('assets/data/scenes_index.json'));
    final scenes = <String, Scene>{};
    // Parallel: ~150 small files (incl. role variants) must not load one-by-one on iPhone.
    final loaded = await Future.wait([for (final id in ids) _json('assets/data/scenes/$id.json')]);
    for (final (i, id) in ids.indexed) {
      scenes[id] = Scene.fromJson(loaded[i]);
    }
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
