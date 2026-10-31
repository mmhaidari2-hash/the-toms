import 'dart:io';
import 'dart:ui' as ui;

import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:british_life/core/models/milestone.dart';
import 'package:british_life/core/models/place.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/features/arrival/arrival_pack_data.dart';
import 'package:british_life/features/arrival/arrival_pack_screen.dart';
import 'package:british_life/features/course/course_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

dynamic j(String p) => jsonDecode(File(p).readAsStringSync());

ContentBundle loadBundle() {
  final chars = [for (final c in j('assets/data/characters.json')) Character.fromJson(c)];
  final scenes = {for (final id in j('assets/data/scenes_index.json')) id as String: Scene.fromJson(j('assets/data/scenes/$id.json'))};
  final ms = <String, List<Milestone>>{
    for (final id in j('assets/data/growth_index.json')) id as String: [for (final m in j('assets/data/${id}_growth.json')['milestones']) Milestone.fromJson(m)],
  };
  final tiers = [for (final t in j('assets/data/places.json')) Tier.fromJson(t)];
  final moments = [for (final m in j('assets/data/moments.json')) Moment(m['sceneId'], m['cover'])];
  final roles = [for (final r in j('assets/data/roles.json')) RoleDef(r['id'], List<String>.from(r['scenes']))];
  final art = {for (final e in (j('assets/data/scene_art.json') as Map<String, dynamic>).entries) e.key: SceneArt.fromJson(e.value)};
  return ContentBundle(chars, scenes, ms, tiers, moments, roles, Course.fromJson(j('assets/data/course.json')), const Timeline([]), art,
      [for (final p in j('assets/data/art_places.json')) Place.fromJson(p)]);
}

Future<void> _save(WidgetTester t, Key key, String path) async {
  final boundary = t.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bd!.buffer.asUint8List());
}

void main() {
  testWidgets('nursery + arrival screenshots', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final bundle = loadBundle();
    final pack = ArrivalPack.parse(File('assets/data/arrival_pack.json').readAsStringSync());
    final store = MemoryProgressStore()
      ..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
    Directory('/workspace/upgrade/shots').createSync(recursive: true);

    await t.pumpWidget(ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        contentProvider.overrideWith((ref) async => bundle),
      ],
      child: MaterialApp(
        theme: BL.theme(),
        home: RepaintBoundary(
          key: const ValueKey('shot-nursery'),
          child: const PackScreen(id: 'nursery'),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await _save(t, const ValueKey('shot-nursery'), '/workspace/upgrade/shots/nursery_pack.png');

    await t.pumpWidget(ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        arrivalPackProvider.overrideWith((ref) async => pack),
      ],
      child: MaterialApp(
        theme: BL.theme(),
        home: RepaintBoundary(
          key: const ValueKey('shot-arrival'),
          child: const ArrivalPackScreen(),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await _save(t, const ValueKey('shot-arrival'), '/workspace/upgrade/shots/arrival.png');

    expect(File('/workspace/upgrade/shots/nursery_pack.png').lengthSync(), greaterThan(15000));
    expect(File('/workspace/upgrade/shots/arrival.png').lengthSync(), greaterThan(15000));
  });
}
