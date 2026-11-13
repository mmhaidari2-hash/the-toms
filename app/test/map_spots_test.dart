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
import 'package:british_life/features/map/map_spots.dart';
import 'package:british_life/core/data/repository.dart';
import 'package:british_life/core/models/character.dart';
import 'package:british_life/features/shared/sheets.dart';
import 'package:flutter/rendering.dart';
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
        l.addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/google_fonts/$file-$w.ttf').readAsBytesSync(),
            ),
          ),
        );
      }
      await l.load();
    }
  });

  test('spots index: every spot has lessons, all ids exist, every lesson has a home on the map', () {
    final spots =
        jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List;
    final course = Course.fromJson(
      jsonDecode(File('assets/data/course.json').readAsStringSync()),
    );
    final ids = {
      for (final u in course.allUnits)
        for (final l in u.lessons) l.id,
    };
    final seen = <String>{};
    expect(spots.length, greaterThanOrEqualTo(20));
    for (final s in spots) {
      // Visa/settlement have their own sections; they are not course buildings.
      if (!{'visa', 'settlement'}.contains(s['id'])) {
        expect(
          (s['lessons'] as List),
          isNotEmpty,
          reason: 'spot ${s['id']} is empty',
        );
      } else {
        expect(featureSpots, contains(s['id']));
      }
      for (final id in s['lessons']) {
        expect(ids, contains(id), reason: '${s['id']} -> $id');
        seen.add(id);
      }
      expect(
        (s['x'] as num) >= 0 &&
            (s['x'] as num) <= 1 &&
            (s['y'] as num) >= 0 &&
            (s['y'] as num) <= 1,
        isTrue,
        reason: s['id'],
      );
      expect((s['titleFa'] as String).isNotEmpty, isTrue);
    }
    expect(
      ids.difference(seen),
      isEmpty,
      reason: 'lessons with no place on the map',
    );
    for (final need in [
      'bus',
      'gp',
      'hospital',
      'pharmacy',
      'museum',
      'cinema',
      'shops',
      'supermarket',
      'shoppingcentre',
      'nursery',
      'school',
      'bank',
      'postoffice',
      'cafe',
      'library',
      'park',
      'station',
      'home',
    ]) {
      expect(
        spots.any((s) => s['id'] == need),
        isTrue,
        reason: 'missing spot $need',
      );
    }
  });

  testWidgets('tapping every spot on the map opens a non-empty lesson list', (
    t,
  ) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(
            MemoryProgressStore()
              ..data = const UserProgress(onboarded: true).encode(),
          ),
        ],
        child: const BritishLifeApp(),
      ),
    );
    router.go('/');
    for (
      var i = 0;
      i < 40 && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    final spots =
        jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List;
    void reveal(Finder f) {
      final box = t.getRect(find.byKey(const ValueKey('map-scroll')));
      final r = t.getRect(f);
      var dx = 0.0, dy = 0.0;
      if (r.left < box.left + 24) dx = box.left + 24 - r.left;
      if (r.right > box.right - 24) dx = box.right - 24 - r.right;
      if (r.top < box.top + 24) dy = box.top + 24 - r.top;
      if (r.bottom > box.bottom - 24) dy = box.bottom - 24 - r.bottom;
      if (dx == 0 && dy == 0) return;
      final tc = t
          .widget<InteractiveViewer>(find.byKey(const ValueKey('map-scroll')))
          .transformationController!;
      tc.value = Matrix4.translationValues(dx, dy, 0) * tc.value;
    }

    for (final s in spots) {
      final f = find.byKey(ValueKey('spot-${s['id']}'));
      expect(f, findsOneWidget, reason: 'spot ${s['id']} not on the map');
      reveal(f);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(f, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byKey(ValueKey('spotsheet-${s['id']}')),
        findsOneWidget,
        reason: 'tap on ${s['id']} did not open its sheet',
      );
      if ({'visa', 'settlement'}.contains(s['id'])) {
        expect(
          find.byKey(ValueKey('spot-open-${s['id']}')),
          findsOneWidget,
          reason: '${s['id']} must provide its section action',
        );
      } else {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key as ValueKey).value}'.startsWith('spot-lesson-'),
          ),
          findsWidgets,
          reason: '${s['id']} sheet is empty',
        );
      }
      expect(find.byKey(const ValueKey('spot-start')), findsOneWidget);
      expect(t.takeException(), isNull, reason: s['id']);
      Navigator.of(t.element(find.byKey(const ValueKey('spot-start')))).pop();
      await t.pump(const Duration(milliseconds: 600));
    }
    // Start opens a lesson.
    reveal(find.byKey(const ValueKey('spot-home')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('spot-home')), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('spotsheet-home')), findsOneWidget);
    final btn = t.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('spot-start')),
    );
    expect(btn.onPressed, isNotNull, reason: 'Start disabled');
    await t.tap(find.byKey(const ValueKey('spot-start')));
    for (
      var i = 0;
      i < 10 && find.byType(LessonScreen).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 300));
    }
    debugPrint(
      'DBG ${router.routerDelegate.currentConfiguration.matches.map((m) => m.matchedLocation).toList()} sheet=${find.byKey(const ValueKey('spotsheet-home')).evaluate().length} ex=${t.takeException()}',
    );
    expect(
      find.byType(LessonScreen),
      findsOneWidget,
      reason: 'Start did not open a lesson',
    );
  });

  test(
    'every map spot has its own painted icon (no platform emoji on the map)',
    () {
      final spots =
          jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List;
      for (final s in spots) {
        expect(
          File('assets/spots/${s['id']}.webp').existsSync(),
          isTrue,
          reason: '${s['id']} has no painted icon',
        );
      }
    },
  );

  test('British English lint passes on every authored line (tool/check_british.py)', () {
    final r = Process.runSync('python3', ['tool/check_british.py']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  testWidgets(
    'nursery sheet Start CTA is not truncated and list clears a 48dp nav inset',
    (t) async {
      const size = Size(360, 780);
      const inset = 48.0;
      const scale = 1.6;
      t.view.physicalSize = size * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);

      final spots =
          jsonDecode(File('assets/data/spots.json').readAsStringSync()) as List;
      final nursery = MapSpot.fromJson(
        Map<String, dynamic>.from(
          spots.firstWhere((s) => s['id'] == 'nursery') as Map,
        ),
      );
      final chars = [
        for (final c in jsonDecode(
          File('assets/data/characters.json').readAsStringSync(),
        ) as List)
          Character.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
      final course = Course.fromJson(
        jsonDecode(File('assets/data/course.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final bundle = ContentBundle(
        chars,
        const {},
        const {},
        const [],
        const [],
        const [],
        course,
      );

      await t.pumpWidget(
        ProviderScope(
          overrides: [
            progressStoreProvider.overrideWithValue(
              MemoryProgressStore()
                ..data = const UserProgress(
                  onboarded: true,
                  unlockAll: true,
                ).encode(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                textScaler: const TextScaler.linear(scale),
                padding: const EdgeInsets.only(bottom: inset),
                viewPadding: const EdgeInsets.only(bottom: inset),
                viewInsets: EdgeInsets.zero,
              ),
              child: child!,
            ),
            // SafeArea consumes padding so a bug that reads the opener's padding.bottom would pad 0.
            home: SafeArea(
              child: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    key: const ValueKey('open-nursery'),
                    onPressed: () =>
                        showSpotSheet(context, ref, nursery, bundle),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('open-nursery')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('spotsheet-nursery')), findsOneWidget);
      expect(find.byType(SpotStartCta), findsOneWidget);
      expect(find.textContaining('Start:'), findsOneWidget);
      expect(find.textContaining('The nursery interview'), findsWidgets);

      final list = t.widget<ListView>(
        find.byKey(const ValueKey('safe-sheet-list')),
      );
      expect(list.padding, isA<EdgeInsets>());
      final pad = list.padding! as EdgeInsets;
      expect(
        pad.bottom,
        greaterThanOrEqualTo(inset),
        reason:
            'sheet list padding ${pad.bottom} < system inset $inset; must use viewPadding of the sheet, not a parent SafeArea',
      );

      bool exceeded(Finder f) {
        for (final e in f.evaluate()) {
          final ro = e.renderObject;
          if (ro is RenderParagraph && ro.didExceedMaxLines) return true;
        }
        return false;
      }

      expect(
        exceeded(find.textContaining('The nursery interview')),
        isFalse,
        reason: 'Start: The nursery interview was truncated',
      );
    },
  );
}
