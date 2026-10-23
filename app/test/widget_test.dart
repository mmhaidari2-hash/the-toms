import 'package:british_life/app/app.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:british_life/app/router.dart';

void main() {
  setUp(() => BL.useGoogleFonts = false);
  testWidgets('home renders family and locked birthday story', (t) async {
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true).encode())], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) { await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250))); await t.pump(const Duration(milliseconds: 100)); }
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('New Life UK'), findsOneWidget);
    // Decluttered home: the map + one big Continue button; the old home lives behind the menu at /family.
    expect(find.byKey(const ValueKey('continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-home')), findsOneWidget);
    expect(find.text('Play'), findsNothing);
    await t.tap(find.byKey(const ValueKey('menu')));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('menu-/howto')), findsOneWidget);
    expect(t.takeException(), isNull);
    Navigator.of(t.element(find.byKey(const ValueKey('menu-/howto')))).pop();
    await t.pump(const Duration(milliseconds: 600));
    router.go('/family');
    for (var i = 0; i < 20 && find.text('Play').evaluate().isEmpty; i++) { await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200))); await t.pump(const Duration(milliseconds: 100)); }
    expect(find.text('Play'), findsOneWidget);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });

  // Real metrics (the default test font is a wide box font that fakes overflows).
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
  for (final size in [const Size(375, 667), const Size(390, 844), const Size(844, 390)]) {
    testWidgets('no overflow on key screens at ${size.width}x${size.height}', (t) async {
      t.view.physicalSize = size * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true).encode())], child: const BritishLifeApp()));
      router.go('/');
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 2));
      for (final r in ['/', '/family', '/placement', '/howto', '/diary', '/onboarding', '/course', '/progress', '/premium', '/premium?pack=nursery', for (var lv = 1; lv <= 5; lv++) '/certificate/$lv', for (final pk in jsonDecode(File('assets/data/course.json').readAsStringSync())['packs'] ?? []) ...['/pack/${pk['id']}', for (final u in pk['units']) ...['/practice/${u['id']}', for (final l in u['lessons']) ...['/lesson/${l['id']}', '/practice/${l['id']}']]], for (final u in jsonDecode(File('assets/data/course.json').readAsStringSync())['units']) ...['/practice/${u['id']}', for (final l in u['lessons']) ...['/lesson/${l['id']}', '/practice/${l['id']}']], for (final t in jsonDecode(File('assets/data/places.json').readAsStringSync())) for (final p in t['places']) '/place/${p['id']}', for (final id in jsonDecode(File('assets/data/scenes_index.json').readAsStringSync())) '/chat/$id']) {
        router.go(r);
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
        await t.pump(const Duration(seconds: 3));
        final ex = t.takeException();
        if (ex != null) debugPrint("OVERFLOW $r $size: ${(ex as FlutterError).diagnostics.map((d) => d.toString()).where((l) => l.contains("Column") || l.contains("Row") || l.contains("file:")).take(4).join(" | ")}");
        expect(ex, isNull, reason: "$r at $size");
      }
      router.go('/');
      await t.pump(const Duration(seconds: 1));
    });
  }
}
