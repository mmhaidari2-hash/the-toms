import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/course/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The living town map: every building/object must open a sheet listing real lessons set there.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  setUpAll(() async {
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = fam == 'Roboto' ? 'Inter' : fam;
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });

  test('spots index: every spot has lessons, all ids exist, every lesson has a home on the map', () {
    final spots = jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List;
    final course = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()));
    final ids = {for (final u in course.allUnits) for (final l in u.lessons) l.id};
    final seen = <String>{};
    expect(spots.length, greaterThanOrEqualTo(20));
    for (final s in spots) {
      expect((s['lessons'] as List), isNotEmpty, reason: 'spot ${s['id']} is empty');
      for (final id in s['lessons']) {
        expect(ids, contains(id), reason: '${s['id']} -> $id');
        seen.add(id);
      }
      expect((s['x'] as num) >= 0 && (s['x'] as num) <= 1 && (s['y'] as num) >= 0 && (s['y'] as num) <= 1, isTrue, reason: s['id']);
      expect((s['titleFa'] as String).isNotEmpty, isTrue);
    }
    expect(ids.difference(seen), isEmpty, reason: 'lessons with no place on the map');
    for (final need in ['bus', 'gp', 'hospital', 'pharmacy', 'museum', 'cinema', 'shops', 'supermarket', 'shoppingcentre', 'nursery', 'school', 'bank', 'postoffice', 'cafe', 'library', 'park', 'station', 'home']) {
      expect(spots.any((s) => s['id'] == need), isTrue, reason: 'missing spot $need');
    }
  });

  testWidgets('tapping every spot on the map opens a non-empty lesson list', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true).encode())], child: const BritishLifeApp()));
    router.go('/');
    for (var i = 0; i < 40 && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    final spots = jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List;
    for (final s in spots) {
      final f = find.byKey(ValueKey('spot-${s['id']}'));
      expect(f, findsOneWidget, reason: 'spot ${s['id']} not on the map');
      await t.ensureVisible(f);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(f, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(ValueKey('spotsheet-${s['id']}')), findsOneWidget, reason: 'tap on ${s['id']} did not open its sheet');
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('spot-lesson-')), findsWidgets, reason: '${s['id']} sheet is empty');
      expect(find.byKey(const ValueKey('spot-start')), findsOneWidget);
      expect(t.takeException(), isNull, reason: s['id']);
      Navigator.of(t.element(find.byKey(const ValueKey('spot-start')))).pop();
      await t.pump(const Duration(milliseconds: 600));
    }
    // Start opens a lesson.
    await t.ensureVisible(find.byKey(const ValueKey('spot-home')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('spot-home')), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('spotsheet-home')), findsOneWidget);
    final btn = t.widget<ButtonStyleButton>(find.byKey(const ValueKey('spot-start')));
    expect(btn.onPressed, isNotNull, reason: 'Start disabled');
    await t.tap(find.byKey(const ValueKey('spot-start')));
    for (var i = 0; i < 10 && find.byType(LessonScreen).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 300));
    }
    debugPrint('DBG ${router.routerDelegate.currentConfiguration.matches.map((m) => m.matchedLocation).toList()} sheet=${find.byKey(const ValueKey('spotsheet-home')).evaluate().length} ex=${t.takeException()}');
    expect(find.byType(LessonScreen), findsOneWidget, reason: 'Start did not open a lesson');
  });
}
