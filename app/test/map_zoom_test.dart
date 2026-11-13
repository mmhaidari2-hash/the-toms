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

({Size view, Size child, double fit}) _fitOf(WidgetTester t) {
  final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
  final view = map.size;
  final child = Size(view.height * mapAspect, view.height);
  return (view: view, child: child, fit: TownMapZoom.fitScale(view, child));
}

/// Screen rectangle of the interactive painted map (not the cover-fit backdrop).
Rect _mapImageRect(WidgetTester t) {
  final img = find.byKey(const ValueKey('map-art'));
  expect(img, findsOneWidget, reason: 'painted town map is on screen');
  return t.getRect(img);
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

  test(
    'TownMapZoom fit shows the whole town and clamp keeps side gutters away',
    () {
      const view = Size(412, 915);
      final child = Size(view.height * mapAspect, view.height);
      final fit = TownMapZoom.fitScale(view, child);
      expect(fit, lessThan(TownMapZoom.fillScale));
      expect(child.width * fit, closeTo(view.width, .01));
      expect(child.height * fit, lessThanOrEqualTo(view.height));
      final fitted = TownMapZoom.clamped(fit, Offset.zero, view, child);
      expect(fitted.getMaxScaleOnAxis(), closeTo(fit, .001));
      final imageLeft = fitted.getTranslation().x;
      final imageRight = imageLeft + child.width * fit;
      expect(
        imageLeft,
        closeTo(0, .5),
        reason: 'no left gutter at fit: left=$imageLeft',
      );
      expect(
        imageRight,
        closeTo(view.width, .5),
        reason: 'no right gutter at fit: right=$imageRight',
      );

      final fill = TownMapZoom.clamped(
        TownMapZoom.fillScale,
        Offset(view.width / 2 - 0.48 * child.width, 0),
        view,
        child,
      );
      expect(fill.getMaxScaleOnAxis(), closeTo(TownMapZoom.fillScale, .001));
      final fillLeft = fill.getTranslation().x;
      final fillRight = fillLeft + child.width;
      expect(
        fillLeft,
        lessThanOrEqualTo(0.5),
        reason: 'no left gutter at fill: left=$fillLeft',
      );
      expect(
        fillRight,
        greaterThanOrEqualTo(view.width - 0.5),
        reason: 'no right gutter at fill: right=$fillRight',
      );
    },
  );

  for (final size in const [Size(412, 915), Size(360, 780)]) {
    testWidgets(
      'on open the whole town fits, Library is labelled, at ${size.width.toInt()}x${size.height.toInt()}',
      (t) async {
        await _boot(t, size);

        expect(find.byType(InteractiveViewer), findsOneWidget);
        final fit = _fitOf(t);
        expect(
          _scale(t),
          closeTo(fit.fit, .02),
          reason: 'initial scale should be fit-to-screen',
        );

        final painted = _mapImageRect(t);
        final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
        expect(
          painted.left,
          lessThanOrEqualTo(map.left + 1),
          reason: 'left dark gutter: map starts at ${painted.left}',
        );
        expect(
          painted.right,
          greaterThanOrEqualTo(map.right - 1),
          reason:
              'right dark gutter: map ends at ${painted.right} of ${map.right}',
        );
        expect(
          painted.top,
          greaterThanOrEqualTo(map.top - 1),
          reason: 'top clipped: ${painted.top}',
        );
        expect(
          painted.bottom,
          lessThanOrEqualTo(map.bottom + 1),
          reason: 'bottom clipped: ${painted.bottom}',
        );
        expect(
          painted.width,
          closeTo(map.width, 2),
          reason: 'fitted map should fill the width',
        );

        expect(find.byKey(const ValueKey('spot-library')), findsOneWidget);
        // Feature place names stay readable at fit (street names appear on zoom).
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
                  File('/workspace/map_fit_preview.png')
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
    final fit = _fitOf(t);
    expect(_scale(t), closeTo(fit.fit, .02));

    final map = t.getRect(find.byKey(const ValueKey('map-scroll')));
    await _pinch(t, map.center, startSpan: 70, endSpan: 200);
    expect(_scale(t), greaterThan(fit.fit + 0.15));
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
    // From a mid / fit zoom, double-tap goes to 2x; from 2x it returns to fit.
    if (_scale(t) < (fit.fit + TownMapZoom.doubleTapScale) / 2) {
      await doubleTap(at);
    }
    expect(_scale(t), closeTo(TownMapZoom.doubleTapScale, .2));
    await doubleTap(at);
    expect(_scale(t), closeTo(fit.fit, .15));
  });
}
