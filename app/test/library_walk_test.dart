import 'dart:io';
import 'dart:ui' as ui;

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/feedback/feedback_screen.dart';
import 'package:british_life/features/library/library_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walkable library: overflow at phone sizes, reduced motion, large text, aisle walk.
void main() {
  setUp(() => BL.useGoogleFonts = false);

  setUpAll(() async {
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = {
        'Roboto': 'Inter',
        'Inter': 'Inter',
        'Fraunces': 'Fraunces',
        'Vazirmatn': 'Vazirmatn',
      }[fam]!;
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

  test('painted library art is on disk for the facade, hall, wood shelf and every section', () {
    const files = [
      'facade',
      'hall',
      'shelf_wood',
      'aisle_fiction',
      'aisle_children',
      'aisle_poetry',
      'aisle_history',
      'aisle_science',
      'aisle_biography',
      'aisle_uklife',
      'aisle_reference',
    ];
    for (final name in files) {
      expect(
        File('assets/library/$name.webp').existsSync(),
        isTrue,
        reason: name,
      );
    }
  });

  testWidgets('libraryMotion is zero when the OS asks for reduced motion', (
    t,
  ) async {
    late Duration d;
    late Duration normal;
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (c) {
            d = libraryMotion(c);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(d, Duration.zero);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (c) {
            normal = libraryMotion(c);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(normal, const Duration(milliseconds: 420));
  });

  testWidgets('libraryShelfHeight grows with large text but stays bounded', (
    t,
  ) async {
    late double base;
    late double large;
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1)),
        child: Builder(
          builder: (c) {
            base = libraryShelfHeight(c);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Builder(
          builder: (c) {
            large = libraryShelfHeight(c);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(base, 168);
    expect(large, 250);
    expect(large, greaterThan(base));
  });

  Future<void> openLibrary(
    WidgetTester t,
    Size size, {
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    t.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    if (reduceMotion) {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
    }
    final store = MemoryProgressStore()
      ..data = const UserProgress(
        onboarded: true,
        missionsDone: {'pref:chapter': '99'},
      ).encode();
    await t.pumpWidget(
      ProviderScope(
        overrides: [progressStoreProvider.overrideWithValue(store)],
        child: const BritishLifeApp(),
      ),
    );
    for (
      var i = 0;
      i < 40 && find.text('New Life UK').evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await _settle(t);
    router.go('/library');
    await _settle(t);
    expect(find.byKey(const ValueKey('library-list')), findsOneWidget);
    expect(t.takeException(), isNull);
  }

  Future<void> writePreview(WidgetTester t, String path) async {
    try {
      final ro = screenBoundaryKey.currentContext?.findRenderObject();
      if (ro is RenderRepaintBoundary) {
        final img = await t.runAsync(() => ro.toImage(pixelRatio: 1.5));
        if (img != null) {
          final bd = await t.runAsync(
            () => img.toByteData(format: ui.ImageByteFormat.png),
          );
          if (bd != null) File(path).writeAsBytesSync(bd.buffer.asUint8List());
        }
      }
    } catch (_) {}
  }

  for (final size in [
    const Size(375, 667),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'no overflow walking the library at ${size.width}x${size.height}',
      (t) async {
        await openLibrary(t, size);
        expect(find.byKey(const ValueKey('library-street')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('library-facade-art')),
          findsOneWidget,
        );
        await t.tap(find.byKey(const ValueKey('library-enter')));
        await _settle(t);
        expect(find.byKey(const ValueKey('library-hall')), findsOneWidget);
        expect(find.byKey(const ValueKey('library-hall-art')), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'after walking in at $size');
        await t.tap(find.byKey(const ValueKey('walk-forward')));
        await _settle(t);
        expect(find.byKey(const ValueKey('aisle-fiction')), findsWidgets);
        await t.tap(find.byKey(const ValueKey('walk-right')));
        await _settle(t);
        expect(find.byKey(const ValueKey('aisle-children')), findsWidgets);
        await t.tap(find.byKey(const ValueKey('aisle-shelves')));
        await _settle(t);
        expect(find.byKey(const ValueKey('shelf-panel')), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'shelves at $size');
      },
    );
  }

  testWidgets(
    'arrows and swipe walk hall to aisle and open a book on a phone',
    (t) async {
      await openLibrary(t, const Size(390, 844));
      expect(find.byKey(const ValueKey('walk-forward')), findsOneWidget);
      expect(find.byKey(const ValueKey('walk-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('walk-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('walk-right')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('walk-forward')));
      await _settle(t);
      expect(find.byKey(const ValueKey('library-hall')), findsOneWidget);
      expect(find.byKey(const ValueKey('front-desk')), findsOneWidget);
      await writePreview(t, '/workspace/library_interior_preview.png');

      await t.tap(find.byKey(const ValueKey('walk-forward')));
      await _settle(t);
      expect(find.byKey(const ValueKey('aisle-fiction')), findsWidgets);
      expect(find.byKey(const ValueKey('library-aisle-art')), findsOneWidget);
      await writePreview(t, '/workspace/library_aisle_preview.png');

      await t.tap(find.byKey(const ValueKey('walk-right')));
      await _settle(t);
      expect(find.byKey(const ValueKey('aisle-children')), findsWidgets);

      await t.tap(find.byKey(const ValueKey('walk-left')));
      await _settle(t);
      expect(find.byKey(const ValueKey('aisle-fiction')), findsWidgets);

      await t.tap(find.byKey(const ValueKey('aisle-shelves')));
      await _settle(t);
      expect(find.byKey(const ValueKey('shelf-panel')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('aisle-enter')));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(
        find.byKey(const ValueKey('booksheet-a1_lostkey')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion still opens the book without the 3D drawer animation',
    (t) async {
      await openLibrary(t, const Size(375, 667), reduceMotion: true);
      await t.tap(find.byKey(const ValueKey('walk-forward')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('walk-forward')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('walk-right'))); // children
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('aisle-shelves')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('book-a1_bus')));
      await t.pump();
      expect(find.byKey(const ValueKey('booksheet-a1_bus')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('large text does not overflow the library at 375x667', (t) async {
    await openLibrary(t, const Size(375, 667), textScale: 1.5);
    await t.tap(find.byKey(const ValueKey('library-enter')));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('walk-forward')));
    await _settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('facade and hall illustrations are on the walk-in path', (
    t,
  ) async {
    await openLibrary(t, const Size(390, 844));
    expect(find.byKey(const ValueKey('library-facade-art')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('library-enter')));
    await _settle(t);
    expect(find.byKey(const ValueKey('library-hall-art')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
  for (
    var i = 0;
    i < 40 &&
        find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty;
    i++
  ) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(t.takeException(), isNull);
}
