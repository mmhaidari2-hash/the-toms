import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/library/library_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walkable library: overflow at phone sizes, reduced motion, large text, aisle walk.
void main() {
  setUp(() => BL.useGoogleFonts = false);

  setUpAll(() async {
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = {'Roboto': 'Inter', 'Inter': 'Inter', 'Fraunces': 'Fraunces', 'Vazirmatn': 'Vazirmatn'}[fam]!;
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });

  test('painted library art is on disk for the facade, hall, wood shelf and every section', () {
    const files = [
      'facade', 'hall', 'shelf_wood',
      'aisle_fiction', 'aisle_children', 'aisle_poetry', 'aisle_history',
      'aisle_science', 'aisle_biography', 'aisle_uklife', 'aisle_reference',
    ];
    for (final name in files) {
      expect(File('assets/library/$name.webp').existsSync(), isTrue, reason: name);
    }
  });

  testWidgets('libraryMotion is zero when the OS asks for reduced motion', (t) async {
    late Duration d;
    late Duration normal;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) {
        d = libraryMotion(c);
        return const SizedBox.shrink();
      }),
    ));
    expect(d, Duration.zero);
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(),
      child: Builder(builder: (c) {
        normal = libraryMotion(c);
        return const SizedBox.shrink();
      }),
    ));
    expect(normal, const Duration(milliseconds: 420));
  });

  testWidgets('libraryShelfHeight grows with large text but stays bounded', (t) async {
    late double base;
    late double large;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1)),
      child: Builder(builder: (c) {
        base = libraryShelfHeight(c);
        return const SizedBox.shrink();
      }),
    ));
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Builder(builder: (c) {
        large = libraryShelfHeight(c);
        return const SizedBox.shrink();
      }),
    ));
    expect(base, 168);
    expect(large, 250);
    expect(large, greaterThan(base));
  });

  Future<void> openLibrary(WidgetTester t, Size size, {double textScale = 1, bool reduceMotion = false}) async {
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    t.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    if (reduceMotion) {
      t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true);
    }
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await _settle(t);
    router.go('/library');
    await _settle(t);
    expect(find.byKey(const ValueKey('library-list')), findsOneWidget);
    expect(t.takeException(), isNull);
  }

  for (final size in [const Size(375, 667), const Size(390, 844), const Size(844, 390)]) {
    testWidgets('no overflow walking the library at ${size.width}x${size.height}', (t) async {
      await openLibrary(t, size);
      expect(find.byKey(const ValueKey('front-desk')), findsOneWidget);
      expect(find.byKey(const ValueKey('aisle-map')), findsOneWidget);
      await _tapSign(t, 'science');
      await _settle(t);
      expect(t.takeException(), isNull, reason: 'after walking to science at $size');
      expect(find.byKey(const ValueKey('aisle-science')), findsWidgets);
      await t.scrollUntilVisible(find.byKey(const ValueKey('book-a1_animals')), 240, scrollable: _libraryScroll(t, size));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('book-a1_animals')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const ValueKey('booksheet-a1_animals')), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'pull-out at $size');
    });
  }

  testWidgets('reduced motion still opens the book without the 3D drawer animation', (t) async {
    await openLibrary(t, const Size(375, 667), reduceMotion: true);
    await _tapSign(t, 'children');
    await _settle(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('book-a1_bus')), 300, scrollable: find.descendant(of: find.byKey(const ValueKey('library-list')), matching: find.byType(Scrollable)).first);
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const ValueKey('book-a1_bus')));
    await t.pump(); // zero-duration transition should already show the sheet
    expect(find.byKey(const ValueKey('booksheet-a1_bus')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('large text does not overflow the library at 375x667', (t) async {
    await openLibrary(t, const Size(375, 667), textScale: 1.5);
    expect(find.byKey(const ValueKey('front-desk')), findsOneWidget);
    await _tapSign(t, 'reference');
    await _settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('facade and hall illustrations are on the walk-in path', (t) async {
    await openLibrary(t, const Size(390, 844));
    expect(find.byKey(const ValueKey('library-facade-art')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-hall-art')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('aisle signs expose EN+FA semantics labels', (t) async {
    await openLibrary(t, const Size(390, 844));
    await _tapSign(t, 'science', tap: false);
    final science = t.getSemantics(find.byKey(const ValueKey('sign-science')));
    expect(science.label, contains('Science'));
    expect(science.label, contains('علم'));
    expect(science.flagsCollection.isButton, isTrue);
  });
}

/// Bring an aisle sign on-screen (vertical then horizontal) and optionally tap it.
Future<void> _tapSign(WidgetTester t, String id, {bool tap = true}) async {
  final map = find.byKey(const ValueKey('aisle-map'), skipOffstage: false);
  await t.ensureVisible(map);
  await t.pump(const Duration(milliseconds: 300));
  final sign = find.byKey(ValueKey('sign-$id'), skipOffstage: false);
  final signsScroll = find.descendant(of: find.byKey(const ValueKey('aisle-map')), matching: find.byType(Scrollable)).first;
  await t.scrollUntilVisible(sign, 200, scrollable: signsScroll);
  await t.pump(const Duration(milliseconds: 200));
  if (tap) await t.tap(find.byKey(ValueKey('sign-$id')));
}

Finder _libraryScroll(WidgetTester t, Size size) {
  // Portrait keeps one outer CustomScrollView; short landscape may add an inner aisle list.
  if (size.height < 520) {
    final inner = find.byKey(const ValueKey('aisle-scroll-science'));
    if (inner.evaluate().isNotEmpty) {
      return find.descendant(of: inner, matching: find.byType(Scrollable)).first;
    }
  }
  return find.descendant(of: find.byKey(const ValueKey('library-list')), matching: find.byType(Scrollable)).first;
}

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
  for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(t.takeException(), isNull);
}
