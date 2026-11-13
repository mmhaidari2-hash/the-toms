import 'dart:io';
import 'dart:math' as math;

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/map/map_home.dart';
import 'package:british_life/features/map/map_spots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _spotOrbs() => find.byWidgetPredicate((w) {
  final k = w.key;
  if (k is! ValueKey) return false;
  final v = '${k.value}';
  return v.startsWith('spot-') &&
      !v.startsWith('spot-focus') &&
      !v.startsWith('spot-level') &&
      !v.startsWith('spot-sheet') &&
      !v.startsWith('spot-open') &&
      !v.startsWith('spot-start') &&
      !v.startsWith('spot-lesson') &&
      !v.startsWith('spot-roleplay') &&
      !v.startsWith('spot-seasons') &&
      !v.startsWith('spot-label');
});

Future<void> _boot(
  WidgetTester t,
  Size logical, {
  bool reduceMotion = false,
}) async {
  t.view.physicalSize = logical * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  if (reduceMotion) {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      () => t.platformDispatcher.clearAccessibilityFeaturesTestValue(),
    );
  }
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(
          MemoryProgressStore()
            ..data = const UserProgress(
              onboarded: true,
              missionsDone: {'pref:lvseen': '1'},
            ).encode(),
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
  await t.pump(const Duration(milliseconds: 500));
  expect(
    find.byKey(const ValueKey('spot-home')),
    findsOneWidget,
    reason: 'map finished loading',
  );
}

Future<void> _pinch(
  WidgetTester t,
  Offset centre, {
  required double startSpan,
  required double endSpan,
}) async {
  final g1 = await t.startGesture(centre + Offset(-startSpan / 2, 0));
  final g2 = await t.startGesture(centre + Offset(startSpan / 2, 0));
  await t.pump(const Duration(milliseconds: 30));
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    final span = startSpan + (endSpan - startSpan) * i / steps;
    await g1.moveTo(centre + Offset(-span / 2, 0));
    await g2.moveTo(centre + Offset(span / 2, 0));
    await t.pump(const Duration(milliseconds: 20));
  }
  await g1.up();
  await g2.up();
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
}

InteractiveViewer _viewer(WidgetTester t) =>
    t.widget<InteractiveViewer>(find.byKey(const ValueKey('map-scroll')));

double _scale(WidgetTester t) =>
    _viewer(t).transformationController!.value.getMaxScaleOnAxis();

bool _rectsOverlap(Rect a, Rect b, {double slack = 1}) {
  final ar = a.deflate(slack);
  final br = b.deflate(slack);
  return ar.overlaps(br);
}

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

  test('TownMapLayout covers a landscape safe rectangle width-first, no side gutter', () {
    const view = Size(844, 390);
    final top = TownMapLayout.topSafe(0, landscape: true);
    final bottom = TownMapLayout.bottomSafe(landscape: true);
    final safeH = view.height - 64 /* nav */ - top - bottom;
    final covered = TownMapLayout.cover(view.width, safeH);
    expect(covered.width, closeTo(view.width, .001));
    expect(covered.width / covered.height, closeTo(mapAspect, .001));
    expect(covered.height, greaterThan(safeH));
  });

  test('TownMapLayout covers a portrait safe rectangle height-first', () {
    const view = Size(375, 667);
    final top = TownMapLayout.topSafe(0, landscape: false);
    final bottom = TownMapLayout.bottomSafe(landscape: false);
    final safeH = view.height - 64 - top - bottom;
    final covered = TownMapLayout.cover(view.width, safeH);
    expect(covered.height, closeTo(safeH, .001));
    expect(covered.width, greaterThan(view.width));
  });

  test(
    'close pins nudge labels so a name never sits under a neighbour orb',
    () {
      const w = 400.0, h = 400.0;
      final laid = layoutMapLabelsForPins(
        [
          ('a', const Offset(0.50, 0.50), 0),
          ('b', const Offset(0.56, 0.50), 1),
        ],
        w,
        h,
      );
      expect(laid['a']!.show, isTrue);
      expect(laid['b']!.show, isTrue);
      final ra = SpotMapLabel.rectFor(0.50 * w, 0.50 * h, laid['a']!.offset);
      final rb = SpotMapLabel.rectFor(0.56 * w, 0.50 * h, laid['b']!.offset);
      final orbA = Rect.fromCircle(
        center: const Offset(0.50 * w, 0.50 * h),
        radius: 24,
      );
      final orbB = Rect.fromCircle(
        center: const Offset(0.56 * w, 0.50 * h),
        radius: 24,
      );
      expect(
        ra.deflate(1).overlaps(orbB),
        isFalse,
        reason: 'a $ra under orb b $orbB, offset ${laid['a']!.offset}',
      );
      expect(
        rb.deflate(1).overlaps(orbA),
        isFalse,
        reason: 'b $rb under orb a $orbA, offset ${laid['b']!.offset}',
      );
      expect(
        ra.deflate(1).overlaps(rb),
        isFalse,
        reason: 'labels overlap $ra $rb',
      );
    },
  );

  for (final size in const [Size(375, 667), Size(390, 844), Size(844, 390)]) {
    testWidgets(
      'title fits, no overflow, spots clear the top bar at ${size.width.toInt()}x${size.height.toInt()}',
      (t) async {
        final overflows = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          if ('$d'.contains('overflowed')) overflows.add(d.exceptionAsString());
          old?.call(d);
        };
        addTearDown(() => FlutterError.onError = old);
        await _boot(t, size);
        expect(t.takeException(), isNull);
        expect(overflows, isEmpty, reason: overflows.join('\n'));

        expect(find.byKey(const ValueKey('app-title')), findsOneWidget);
        expect(find.text('New Life UK'), findsOneWidget);
        final title = t.getRect(find.byKey(const ValueKey('app-title')));
        final stats = t.getRect(find.byKey(const ValueKey('stats-chip')));
        final menu = t.getRect(find.byKey(const ValueKey('menu')));
        expect(
          title.overlaps(stats.deflate(1)),
          isFalse,
          reason: 'title $title overlaps stats $stats',
        );
        expect(
          title.overlaps(menu.deflate(1)),
          isFalse,
          reason: 'title $title overlaps menu $menu',
        );
        expect(title.right, lessThanOrEqualTo(stats.left + 1.5));

        final topBar = t.getRect(find.byKey(const ValueKey('map-top-bar')));
        final screen = Offset.zero & size;
        for (final e in _spotOrbs().evaluate()) {
          final r = t.getRect(find.byKey(e.widget.key!));
          if (!r.overlaps(screen)) continue;
          expect(
            _rectsOverlap(r, topBar),
            isFalse,
            reason: '${e.widget.key} $r overlaps top bar $topBar',
          );
        }

        // Title and Continue lesson name scale down instead of ellipsising.
        final titlePara = t.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('app-title')),
            matching: find.byType(RichText),
          ),
        );
        expect(titlePara.didExceedMaxLines, isFalse);
        final continueTexts = find.descendant(
          of: find.byKey(const ValueKey('continue')),
          matching: find.byType(Text),
        );
        expect(continueTexts, findsWidgets);
        for (final e in continueTexts.evaluate()) {
          final ro = e.renderObject;
          if (ro is RenderParagraph) {
            expect(
              ro.didExceedMaxLines,
              isFalse,
              reason: '${(e.widget as Text).data}',
            );
          }
        }

        // Level chips: Neighbourhood is fully readable (scroll the strip if needed).
        if (size.width > size.height &&
            find.byKey(const ValueKey('level-strip')).evaluate().isEmpty) {
          await t.tap(find.byKey(const ValueKey('level-strip-toggle')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 80));
        }
        final pin = find.byKey(const ValueKey('pin-neighbourhood'));
        expect(pin, findsOneWidget);
        await t.ensureVisible(pin);
        await t.pump();
        expect(find.text('Neighbourhood'), findsWidgets);
        final hood = t.renderObject<RenderParagraph>(
          find
              .descendant(
                of: find.byKey(const ValueKey('pin-neighbourhood')),
                matching: find.byType(RichText),
              )
              .first,
        );
        expect(hood.didExceedMaxLines, isFalse);

        // Visible labels are never under a different spot's orb.
        final orbs = <String, Rect>{};
        for (final e in _spotOrbs().evaluate()) {
          orbs['${(e.widget.key as ValueKey).value}'] = t.getRect(
            find.byKey(e.widget.key!),
          );
        }
        final labelFind = find.byWidgetPredicate((w) {
          final k = w.key;
          return k is ValueKey && '${k.value}'.startsWith('spot-label-');
        });
        for (final e in labelFind.evaluate()) {
          final id = '${(e.widget.key as ValueKey).value}';
          final r = t.getRect(find.byKey(e.widget.key!));
          if (!r.overlaps(screen)) continue;
          final own = 'spot-${id.substring('spot-label-'.length)}';
          for (final o in orbs.entries) {
            if (o.key == own) continue;
            expect(
              _rectsOverlap(r, o.value),
              isFalse,
              reason: '$id $r buried under ${o.key} ${o.value}',
            );
          }
        }
      },
    );
  }

  testWidgets(
    'pinch-to-zoom grows spot icons and labels; double-tap zooms then returns',
    (t) async {
      const size = Size(375, 667);
      await _boot(t, size);
      final viewer = _viewer(t);
      expect(viewer.minScale, TownMapLayout.minScale);
      expect(viewer.maxScale, TownMapLayout.maxScale);
      expect(_scale(t), closeTo(1, .05));

      final spot = find.byKey(const ValueKey('spot-home'));
      // If home is off-screen, pan isn't required: use a visible orb.
      Finder target = spot;
      if (t.getRect(spot).overlaps(Offset.zero & size) == false ||
          t.getRect(spot).width == 0) {
        target = _spotOrbs().hitTestable().first;
      }
      final before = t.getRect(target);
      expect(before.width, greaterThan(10));

      final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
      final continueTop = t.getRect(find.byKey(const ValueKey('continue'))).top;
      final topBar = t.getRect(find.byKey(const ValueKey('map-top-bar')));
      final pinchAt = Offset(
        map.center.dx,
        ((topBar.bottom + continueTop) / 2).clamp(
          topBar.bottom + 24,
          continueTop - 24,
        ),
      );

      await _pinch(t, pinchAt, startSpan: 80, endSpan: 200);
      expect(
        _scale(t),
        greaterThan(1.25),
        reason: 'pinch should zoom in, scale=${_scale(t)}',
      );
      final after = t.getRect(target);
      expect(
        after.width,
        greaterThan(before.width * 1.15),
        reason: 'spot grew: $before -> $after',
      );

      // Double-tap on empty-ish map area toggles back toward 1 when already zoomed.
      await t.tap(find.byKey(const ValueKey('map-scroll')));
      await t.pump(const Duration(milliseconds: 50));
      // The first tap of a double-tap may hit a region; still send a double-tap at the pinch point via gesture.
      await t.tapAt(pinchAt);
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(pinchAt);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(
        _scale(t),
        closeTo(TownMapLayout.minScale, .15),
        reason: 'double-tap returns toward 1, scale=${_scale(t)}',
      );
    },
  );

  testWidgets(
    'reduced motion: double-tap jumps to zoom without a long animation',
    (t) async {
      const size = Size(390, 844);
      await _boot(t, size, reduceMotion: true);
      final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
      final continueTop = t.getRect(find.byKey(const ValueKey('continue'))).top;
      final topBar = t.getRect(find.byKey(const ValueKey('map-top-bar')));
      final at = Offset(
        map.center.dx,
        ((topBar.bottom + continueTop) / 2).clamp(
          topBar.bottom + 24,
          continueTop - 24,
        ),
      );
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 40));
      await t.tapAt(at);
      await t.pump(); // one frame; no 220ms animation
      expect(
        _scale(t),
        closeTo(TownMapLayout.doubleTapScale, .2),
        reason: 'jumped to 2× immediately, scale=${_scale(t)}',
      );
      await t.pump(const Duration(milliseconds: 400));
    },
  );

  for (final size in const [Size(844, 390), Size(915, 412)]) {
    testWidgets(
      'landscape ${size.width.toInt()}x${size.height.toInt()}: compact chrome, map ≥60%, no chrome overlap',
      (t) async {
        final overflows = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          if ('$d'.contains('overflowed')) overflows.add(d.exceptionAsString());
          old?.call(d);
        };
        addTearDown(() => FlutterError.onError = old);
        await _boot(t, size);
        expect(t.takeException(), isNull);
        expect(overflows, isEmpty, reason: overflows.join('\n'));

        expect(
          find.byKey(const ValueKey('level-strip')),
          findsNothing,
          reason: 'level chips start collapsed in landscape',
        );
        expect(
          find.byKey(const ValueKey('level-strip-toggle')),
          findsOneWidget,
        );
        expect(find.text('New Life UK'), findsOneWidget);
        expect(find.byKey(const ValueKey('continue')), findsOneWidget);

        final screen = Offset.zero & size;
        final topBar = t.getRect(find.byKey(const ValueKey('map-top-bar')));
        final cont = t.getRect(find.byKey(const ValueKey('continue')));
        expect(
          _rectsOverlap(topBar, cont),
          isFalse,
          reason: 'top bar $topBar overlaps continue $cont',
        );
        expect(
          cont.width,
          lessThan(size.width * .7),
          reason: 'continue is a compact pill, width=${cont.width}',
        );
        expect(
          cont.left,
          greaterThan(size.width * .25),
          reason: 'continue sits on the side, not full-bleed',
        );

        // Visible map: body minus top chrome (continue is a side pill, so it doesn't reserve the full width).
        final map = t.getRect(find.byKey(const ValueKey('map-viewport')));
        expect(
          map.width,
          closeTo(size.width, 1),
          reason: 'map viewer fills the width (no side gutter)',
        );
        final visibleTop = topBar.bottom;
        final visibleH = math.max(0.0, map.bottom - visibleTop);
        final visibleArea = visibleH * map.width;
        expect(
          visibleArea / (size.width * size.height),
          greaterThanOrEqualTo(0.60),
          reason:
              'visible map ${visibleArea.toStringAsFixed(0)} / screen ${size.width * size.height}',
        );

        for (final e in _spotOrbs().evaluate()) {
          final r = t.getRect(find.byKey(e.widget.key!));
          if (!r.overlaps(screen)) continue;
          expect(
            _rectsOverlap(r, topBar),
            isFalse,
            reason: '${e.widget.key} $r overlaps top bar $topBar',
          );
        }

        // Opening the strip must not overflow or overlap the top bar / continue.
        await t.tap(find.byKey(const ValueKey('level-strip-toggle')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('level-strip')), findsOneWidget);
        final strip = t.getRect(find.byKey(const ValueKey('level-strip')));
        expect(
          _rectsOverlap(topBar, strip, slack: 0.5),
          isFalse,
          reason: 'strip $strip overlaps top bar $topBar',
        );
        expect(
          _rectsOverlap(strip, cont),
          isFalse,
          reason: 'strip $strip overlaps continue $cont',
        );
        expect(t.takeException(), isNull);
        expect(overflows, isEmpty);
      },
    );
  }

  testWidgets('spot stays tappable after zoom', (t) async {
    const size = Size(375, 667);
    await _boot(t, size);
    final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
    final continueTop = t.getRect(find.byKey(const ValueKey('continue'))).top;
    final topBar = t.getRect(find.byKey(const ValueKey('map-top-bar')));
    final pinchAt = Offset(
      map.center.dx,
      ((topBar.bottom + continueTop) / 2).clamp(
        topBar.bottom + 24,
        continueTop - 24,
      ),
    );
    await _pinch(t, pinchAt, startSpan: 70, endSpan: 160);
    expect(_scale(t), greaterThan(1.15));

    final targets = _spotOrbs().hitTestable();
    expect(targets, findsWidgets);
    await t.tap(targets.first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byType(BottomSheet).evaluate().isNotEmpty ||
          find
              .byWidgetPredicate((w) {
                final k = w.key;
                return k is ValueKey && '${k.value}'.startsWith('spot-sheet');
              })
              .evaluate()
              .isNotEmpty,
      isTrue,
      reason: 'tapping a zoomed spot still opens it',
    );
  });
}
