import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pans the town-map [InteractiveViewer] so [spotId] is on screen, then taps it.
/// `ensureVisible` does not move this viewer, so a raw tap often misses.
Future<void> tapMapSpot(WidgetTester t, String spotId) async {
  final f = find.byKey(ValueKey('spot-$spotId'));
  expect(f, findsOneWidget, reason: 'spot $spotId not on the map');
  final box = t.getRect(find.byKey(const ValueKey('map-scroll')));
  final r = t.getRect(f);
  var dx = 0.0, dy = 0.0;
  if (r.left < box.left + 24) dx = box.left + 24 - r.left;
  if (r.right > box.right - 24) dx = box.right - 24 - r.right;
  if (r.top < box.top + 24) dy = box.top + 24 - r.top;
  if (r.bottom > box.bottom - 24) dy = box.bottom - 24 - r.bottom;
  if (dx != 0 || dy != 0) {
    final tc = t
        .widget<InteractiveViewer>(find.byKey(const ValueKey('map-scroll')))
        .transformationController!;
    tc.value = Matrix4.translationValues(dx, dy, 0) * tc.value;
  }
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 800));
}
