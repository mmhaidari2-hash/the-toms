// Renders Play-store phone screenshots from the live widgets.
// Skipped in the normal suite. From app/: STORE_SHOTS=1 flutter test test/store_screenshots_test.dart
//
// Loads Inter, Fraunces, Vazirmatn and the MaterialIcons font so headless
// toolbars are not tofu squares. Writes PNGs under docs/launch/store/raw/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/feedback/feedback_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _logical = Size(375, 667);
const _dpr = 1080 / 375; // 2.88 → 1080 × 1920.96

bool get _enabled => Platform.environment['STORE_SHOTS'] == '1';

Directory get _outDir {
  final fromEnv = Platform.environment['STORE_SHOTS_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return Directory(fromEnv);
  return Directory('../docs/launch/store/raw');
}

Future<void> _loadFonts() async {
  for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
    final file = {
      'Roboto': 'Inter',
      'Inter': 'Inter',
      'Fraunces': 'Fraunces',
      'Vazirmatn': 'Vazirmatn',
    }[fam]!;
    final loader = FontLoader(fam);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final path = 'assets/google_fonts/$file-$w.ttf';
      if (!File(path).existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  final iconCandidates = <String>[
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/box/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  final iconPath = iconCandidates.firstWhere(
    (p) => p.isNotEmpty && File(p).existsSync(),
    orElse: () => '',
  );
  if (iconPath.isEmpty) {
    fail(
      'MaterialIcons font not found; refusing to write store shots with tofu icons',
    );
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(File(iconPath).readAsBytesSync())),
    );
  await icons.load();
}

Future<void> _settle(WidgetTester t, {int pumps = 8, int ms = 250}) async {
  await t.runAsync(() => Future.delayed(Duration(milliseconds: ms)));
  for (var i = 0; i < pumps; i++) {
    await t.pump(Duration(milliseconds: ms));
  }
}

Future<void> _boot(WidgetTester t) async {
  t.view.physicalSize = Size(_logical.width * _dpr, _logical.height * _dpr);
  t.view.devicePixelRatio = _dpr;
  addTearDown(t.view.reset);
  BL.useGoogleFonts = false;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(
          MemoryProgressStore()
            ..data = const UserProgress(
              onboarded: true,
              unlockAll: true,
              lang: 'fa',
              missionsDone: {'pref:chapter': '99', 'pref:lvseen': '1'},
            ).encode(),
        ),
      ],
      child: const BritishLifeApp(),
    ),
  );
  router.go('/');
  for (var i = 0; i < 50 && find.text('New Life UK').evaluate().isEmpty; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 200));
  }
  await _settle(t, pumps: 6, ms: 300);
  expect(
    find.text('New Life UK'),
    findsWidgets,
    reason: 'app finished booting',
  );
}

Future<void> _go(WidgetTester t, String route) async {
  router.go(route);
  await _settle(t, pumps: 10, ms: 300);
}

Future<void> _dismissAudio(WidgetTester t) async {
  final close = find.byKey(const ValueKey('voice-dismiss'));
  if (close.evaluate().isNotEmpty) {
    await t.tap(close);
    await _settle(t, pumps: 3, ms: 200);
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int tries = 20}) async {
  for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
    await _settle(t, pumps: 2, ms: 300);
  }
}

Future<File> _shot(WidgetTester t, String name) async {
  final dir = _outDir..createSync(recursive: true);
  final dest = File('${dir.path}/$name.png');
  final ro = screenBoundaryKey.currentContext?.findRenderObject();
  expect(
    ro,
    isA<RenderRepaintBoundary>(),
    reason: 'missing screen boundary for $name',
  );
  final img = await t.runAsync(
    () => (ro! as RenderRepaintBoundary).toImage(pixelRatio: _dpr),
  );
  expect(img, isNotNull, reason: 'toImage failed for $name');
  final bd = await t.runAsync(
    () => img!.toByteData(format: ui.ImageByteFormat.png),
  );
  expect(bd, isNotNull, reason: 'png encode failed for $name');
  dest.writeAsBytesSync(bd!.buffer.asUint8List());
  debugPrint(
    'STORE_SHOT ${dest.path} ${dest.lengthSync()} ${img!.width}x${img.height}',
  );
  return dest;
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  test('store screenshots skipped (set STORE_SHOTS=1 to render)', () {
    if (_enabled) return;
    // Keeps the file cheap in the full suite.
  });

  testWidgets(
    'render Play store raw screenshots',
    (t) async {
      await _boot(t);
      final exceptions = <String>[];

      Future<void> capture(String name, Future<void> Function() prep) async {
        await prep();
        final ex = t.takeException();
        if (ex != null) {
          exceptions.add('$name: $ex');
          debugPrint('STORE_SHOT_EXCEPTION $name $ex');
        }
        await _dismissAudio(t);
        await _shot(t, name);
      }

      await capture('01_map', () async {
        await _go(t, '/');
        await _settle(t, pumps: 8, ms: 400);
      });

      await capture('02_conversation', () async {
        await _go(t, '/chat/l1_u43_1');
        await _settle(t, pumps: 12, ms: 300);
      });

      await capture('03_nursery', () async {
        await _go(t, '/pack/nursery');
        await _settle(t, pumps: 8, ms: 300);
      });

      await capture('04_library', () async {
        await _go(t, '/library');
        await _waitFor(t, find.byKey(const ValueKey('library-facade-art')));
        await _settle(t, pumps: 4, ms: 400);
      });

      await capture('05_library_hall', () async {
        await _go(t, '/library');
        await _waitFor(t, find.byKey(const ValueKey('library-enter')));
        await t.tap(find.byKey(const ValueKey('library-enter')));
        await _waitFor(t, find.byKey(const ValueKey('library-hall-art')));
        await _settle(t, pumps: 6, ms: 400);
      });

      await capture('06_lifeuk', () async {
        await _go(t, '/lifeuk');
        await _settle(t, pumps: 8, ms: 300);
      });

      await capture('07_school', () async {
        await _go(t, '/school');
        await _settle(t, pumps: 8, ms: 300);
      });

      await capture('08_visa', () async {
        await _go(t, '/visa');
        await _settle(t, pumps: 8, ms: 300);
      });

      expect(
        exceptions,
        isEmpty,
        reason: 'unexpected exceptions while rendering store shots',
      );
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
