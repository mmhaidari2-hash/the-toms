import 'dart:io';
import 'dart:ui' as ui;

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/feedback/feedback_screen.dart';
import 'package:british_life/features/map/map_home.dart';
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

Future<void> _boot(WidgetTester t, Size logical) async {
  t.view.physicalSize = logical * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
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

/// Screen rectangle of the painted map image (map.webp).
Rect _mapImageRect(WidgetTester t) {
  final img = find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName.contains('places/map'),
  );
  expect(img, findsOneWidget, reason: 'painted town map is on screen');
  return t.getRect(img);
}

Future<void> _writePreview(WidgetTester t, String path) async {
  try {
    final ro = screenBoundaryKey.currentContext?.findRenderObject();
    if (ro is RenderRepaintBoundary) {
      final img = await t.runAsync(() => ro.toImage(pixelRatio: 1.5));
      if (img != null) {
        final bd = await t.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.png),
        );
        if (bd != null) {
          File(path).writeAsBytesSync(bd.buffer.asUint8List());
        }
      }
    }
  } catch (_) {}
}

void _expectDefaultFill(WidgetTester t, Size size) {
  expect(_scale(t), closeTo(TownMapZoom.minScale, .02));
  final painted = _mapImageRect(t);
  final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
  expect(
    painted.left,
    lessThanOrEqualTo(map.left + 1),
    reason: 'left gutter: ${painted.left}',
  );
  expect(
    painted.right,
    greaterThanOrEqualTo(map.right - 1),
    reason: 'right gutter: ${painted.right}',
  );
  expect(
    painted.top,
    lessThanOrEqualTo(map.top + 1),
    reason: 'top gap: ${painted.top}',
  );
  expect(
    painted.bottom,
    greaterThanOrEqualTo(map.bottom - 1),
    reason: 'bottom gap: ${painted.bottom}',
  );
  expect(find.byKey(const ValueKey('spot-library')), findsOneWidget);
  expect(find.text('Library'), findsWidgets);
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

  test('TownMapZoom clamp keeps scale 1 from panning into a side gutter', () {
    const view = Size(412, 915);
    final child = Size(view.height * mapAspect, view.height);
    final centred = TownMapZoom.clamped(
      1,
      Offset(view.width / 2 - 0.48 * child.width, 0),
      view,
      child,
    );
    expect(centred.getMaxScaleOnAxis(), closeTo(1, .001));
    final imageLeft = centred.getTranslation().x;
    final imageRight = imageLeft + child.width;
    expect(
      imageLeft,
      lessThanOrEqualTo(0.5),
      reason: 'no left gutter: left=$imageLeft',
    );
    expect(
      imageRight,
      greaterThanOrEqualTo(view.width - 0.5),
      reason: 'no right gutter: right=$imageRight',
    );
  });

  for (final size in const [Size(412, 915), Size(360, 780)]) {
    testWidgets(
      'default zoom fills the width, Library is labelled, at ${size.width.toInt()}x${size.height.toInt()}',
      (t) async {
        await _boot(t, size);

        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(_scale(t), closeTo(TownMapZoom.minScale, .02));

        final painted = _mapImageRect(t);
        expect(
          painted.left,
          lessThanOrEqualTo(1),
          reason: 'left dark gutter: map starts at ${painted.left}',
        );
        expect(
          painted.right,
          greaterThanOrEqualTo(size.width - 1),
          reason:
              'right dark gutter: map ends at ${painted.right} of ${size.width}',
        );

        expect(find.byKey(const ValueKey('spot-library')), findsOneWidget);
        // The orb still carries the short English name, as it did before t340.
        expect(find.text('Library'), findsWidgets);

        if (size == const Size(412, 915)) {
          try {
            final ro = screenBoundaryKey.currentContext?.findRenderObject();
            if (ro is RenderRepaintBoundary) {
              final img = await t.runAsync(() => ro.toImage(pixelRatio: 1.5));
              if (img != null) {
                final bd = await t.runAsync(
                  () => img.toByteData(format: ui.ImageByteFormat.png),
                );
                if (bd != null) {
                  File('/workspace/map_preview.png')
                      .writeAsBytesSync(bd.buffer.asUint8List());
                }
              }
            }
          } catch (_) {
            // Preview is best-effort; the layout asserts above still stand.
          }
        }
      },
    );
  }

  testWidgets('pinch and double-tap zoom the town map', (t) async {
    const size = Size(412, 915);
    await _boot(t, size);
    expect(_scale(t), closeTo(TownMapZoom.minScale, .02));

    final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
    await _pinch(t, map.center, startSpan: 70, endSpan: 160);
    expect(_scale(t), greaterThan(1.15));
    expect(_scale(t), lessThanOrEqualTo(TownMapZoom.maxScale + .01));

    final targets = _spotOrbs().hitTestable();
    expect(targets, findsWidgets);

    Future<void> doubleTap(Offset at) async {
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(at);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    final at = map.center;
    // From a mid zoom, double-tap goes to 2x; from 2x it returns to 1x.
    if (_scale(t) < (TownMapZoom.minScale + TownMapZoom.doubleTapScale) / 2) {
      await doubleTap(at);
    }
    expect(_scale(t), closeTo(TownMapZoom.doubleTapScale, .2));
    await doubleTap(at);
    expect(_scale(t), closeTo(TownMapZoom.minScale, .15));
  });

  testWidgets(
    'at 390x844 the map fills the screen and pinch-out cannot shrink it',
    (t) async {
      const size = Size(390, 844);
      await _boot(t, size);
      _expectDefaultFill(t, size);
      await _writePreview(t, '/workspace/map_default_preview.png');

      final before = _scale(t);
      final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
      await _pinch(t, map.center, startSpan: 180, endSpan: 50);
      expect(
        _scale(t),
        closeTo(TownMapZoom.minScale, .02),
        reason: 'pinch-out must not go below the full-screen default',
      );
      expect(_scale(t), closeTo(before, .02));
      _expectDefaultFill(t, size);
      await _writePreview(t, '/workspace/map_zoomout_attempt_preview.png');
    },
  );
}
