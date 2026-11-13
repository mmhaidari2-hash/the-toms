import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walk in from the street, go down the first aisle (plus [aisleIndex] steps
/// right), and open the shelves. Replaces the old `sign-*` aisle map.
Future<void> openLibraryShelves(
  WidgetTester t,
  Future<void> Function() settle, {
  int aisleIndex = 0,
}) async {
  await t.tap(find.byKey(const ValueKey('library-enter')));
  await settle();
  await t.tap(find.byKey(const ValueKey('walk-forward')));
  await settle();
  for (var i = 0; i < aisleIndex; i++) {
    await t.tap(find.byKey(const ValueKey('walk-right')));
    await settle();
  }
  await t.tap(find.byKey(const ValueKey('aisle-shelves')));
  await settle();
}
