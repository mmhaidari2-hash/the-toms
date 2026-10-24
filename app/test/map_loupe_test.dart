import 'dart:io';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:british_life/features/map/map_loupe.dart';

/// The glass loupe: press-hold-slide over the map magnifies the spot under the finger with its name and level.
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

  testWidgets('hold and slide: loupe follows, names the spot with its level, release opens it', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true).encode())], child: const BritishLifeApp()));
    router.go('/');
    for (var i = 0; i < 40 && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(seconds: 1));
    // A visible spot.
    final spot = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('spot-') && !'${(w.key as ValueKey).value}'.startsWith('spot-focus')).hitTestable().first;
    final id = '${(t.widget(spot).key as ValueKey).value}'.substring(5);
    final r = t.getRect(spot);
    final orb = Offset(r.center.dx, r.top + 22);
    final g = await t.startGesture(orb + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(MapLoupe), findsOneWidget, reason: 'lens appears after a short hold');
    await g.moveTo(orb + const Offset(14, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g.moveTo(orb);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('loupe-label')), findsOneWidget, reason: 'spot $id named under the lens');
    final loupe = t.widget<MapLoupe>(find.byType(MapLoupe));
    expect(loupe.spot?.id, id);
    expect(loupe.level, isNotNull);
    expect(find.text(loupe.spot!.title), findsWidgets);
    // The lens sits exactly over the pin (same x as the orb centre, unless clamped at a screen edge).
    await t.pump(const Duration(milliseconds: 300));
    final lens = t.getRect(find.byKey(const ValueKey('loupe-lens')));
    final orbNow = t.getRect(find.byKey(ValueKey('spot-$id')));
    expect(orbNow.isEmpty, isFalse);
    // Run 26: centred in BOTH axes on the real orb centre, with no edge exemption (no lift, no clamping).
    expect((lens.center - orb).distance, lessThan(1.5), reason: 'lens centred on the pin: lens ${lens.center} vs orb $orb');
    expect(lens.width, closeTo(MapLoupe.size, .5));
    // Small jitter around the pin keeps the same pin (hysteresis), no jumping.
    for (final d in const [Offset(20, 8), Offset(-25, -10), Offset(30, 20), Offset(0, 0)]) {
      await g.moveTo(orb + d);
      await t.pump(const Duration(milliseconds: 60));
      expect(t.widget<MapLoupe>(find.byType(MapLoupe)).spot?.id, id, reason: 'jitter $d stays on $id');
    }
    await g.up();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(MapLoupe), findsNothing);
    expect(find.byKey(ValueKey('spot-sheet-$id')).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue, reason: 'letting go on a spot opens it');
    expect(t.takeException(), isNull);
  });

  testWidgets('mouse: lens only over a pin and centred on it; scrolling the map puts it away', (t) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true).encode())], child: const BritishLifeApp()));
    router.go('/');
    for (var i = 0; i < 40 && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(seconds: 1));
    final spots = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('spot-') && !'${(w.key as ValueKey).value}'.startsWith('spot-focus')).hitTestable();
    final r = t.getRect(spots.at(spots.evaluate().length ~/ 2));
    final orb = Offset(r.center.dx, r.top + 22);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 700));
    await t.pump();
    // Far from every pin: no lens.
    await mouse.moveTo(const Offset(640, 700));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(MapLoupe), findsNothing, reason: 'no lens over empty map');
    await mouse.moveTo(orb + const Offset(6, 4));
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(MapLoupe), findsOneWidget, reason: 'hovering a pin raises the lens');
    final lens = t.getRect(find.byKey(const ValueKey('loupe-lens')));
    expect((lens.center - orb).distance, lessThan(1.5), reason: 'lens centred on the hovered pin: lens ${lens.center} vs orb $orb');
    // Scroll the map with the wheel: the hover lens goes away rather than drifting off its pin.
    await mouse.moveTo(orb);
    await t.pump();
    final pos = find.byKey(const ValueKey('map-scroll'));
    await t.sendEventToBinding(PointerScrollEvent(position: orb, scrollDelta: const Offset(0, 120), kind: PointerDeviceKind.mouse));
    t.state<ScrollableState>(find.descendant(of: pos, matching: find.byType(Scrollable))).position.jumpTo(200);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(MapLoupe), findsNothing, reason: 'scrolling hides the hover lens');
    await mouse.removePointer();
    expect(t.takeException(), isNull);
  });

  testWidgets('every pin, even at a screen edge, gets the glass exactly over it', (t) async {
    t.view.physicalSize = const Size(375, 667) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true).encode())], child: const BritishLifeApp()));
    router.go('/');
    for (var i = 0; i < 40 && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(seconds: 1));
    final spots = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('spot-') && !'${(w.key as ValueKey).value}'.startsWith('spot-focus') && !'${(w.key as ValueKey).value}'.startsWith('spot-level') && !'${(w.key as ValueKey).value}'.startsWith('spot-sheet'));
    final orbs = <String, Offset>{};
    for (final e in spots.evaluate()) {
      final k = '${((e.widget.key) as ValueKey).value}';
      final r = t.getRect(find.byKey(ValueKey(k)));
      final o = Offset(r.center.dx, r.top + 22);
      if (o.dx > 4 && o.dx < 371 && o.dy > 230 && o.dy < 520) orbs[k] = o;
    }
    expect(orbs.length, greaterThan(3));
    expect(orbs.values.any((o) => o.dx < 66 || o.dx > 309), isTrue, reason: 'covers a pin near a screen edge');
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(187, 640));
    for (final e in orbs.entries) {
      await mouse.moveTo(e.value + const Offset(3, 2));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      final loupe = find.byType(MapLoupe);
      if (loupe.evaluate().isEmpty) continue; // covered by another pin's hit area
      final lens = t.getRect(find.byKey(const ValueKey('loupe-lens')));
      final id = t.widget<MapLoupe>(loupe).spot?.id;
      final o = orbs['spot-$id'] ?? e.value;
      expect((lens.center - o).distance, lessThan(1.5), reason: '${e.key}: lens ${lens.center} vs orb $o');
    }
    await mouse.removePointer();
    expect(t.takeException(), isNull);
  });
}
