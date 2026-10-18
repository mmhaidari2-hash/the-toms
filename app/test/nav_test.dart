import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every screen must have a visible Back button that leads (eventually) to the map, even when it was
/// opened directly (refresh / deep link, so there is nothing to pop), and the Map button must jump home.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  // Real metrics (the default test font is a wide box font that fakes overflows).
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
  testWidgets('every route can get back to the map', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true).encode())], child: const BritishLifeApp()));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(seconds: 2));
    String loc() => router.routerDelegate.currentConfiguration.uri.path;
    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
        await t.pump(const Duration(milliseconds: 300));
        if (i >= 2 && (loc() == '/' || find.byKey(const ValueKey('nav-back')).evaluate().isNotEmpty)) break;
      }
      await t.pump(const Duration(milliseconds: 600));
    }

    final course = jsonDecode(File('assets/data/course.json').readAsStringSync());
    final units = [...course['units'], for (final pk in course['packs']) ...pk['units']];
    final firstByLevel = <dynamic, String>{};
    for (final u in units) {
      firstByLevel.putIfAbsent(u['pack'] ?? u['level'], () => u['lessons'][0]['id']);
    }
    final places = [for (final tier in jsonDecode(File('assets/data/places.json').readAsStringSync())) for (final p in tier['places']) p['id']];
    final routes = [
      '/family', '/placement', '/howto', '/diary', '/course', '/course?level=3',
      for (final pk in course['packs']) '/pack/${pk['id']}',
      for (final id in firstByLevel.values) ...['/lesson/$id', '/practice/$id', '/chat/$id'],
      '/practice/${units.first['id']}',
      ...places.take(4).map((p) => '/place/$p'),
      '/chat/ep1_morning_table',
      '/cinema', '/cinema/c_a1_breakfast',
    ];
    for (final r in routes) {
      // 1) Opened directly: nothing to pop, Back must still lead to the map within a few taps.
      router.go(r);
      await settle();
      expect(find.byKey(const ValueKey('nav-back')), findsWidgets, reason: 'no Back button on $r');
      for (var i = 0; i < 4 && loc() != '/'; i++) {
        final b = find.byKey(const ValueKey('nav-back'));
        expect(b, findsWidgets, reason: 'dead end at ${loc()} (from $r)');
        await t.tap(b.first, warnIfMissed: false);
        await settle();
      }
      expect(loc(), '/', reason: 'Back from $r did not reach the map');
      // 2) Pushed from the map: Back pops exactly one screen.
      router.push(r);
      await settle();
      await t.tap(find.byKey(const ValueKey('nav-back')).first, warnIfMissed: false);
      await settle();
      expect(loc(), '/', reason: 'Back after push($r) did not pop to the map');
      // 3) The Map button jumps home from anywhere it is shown.
      router.go(r);
      await settle();
      final home = find.byKey(const ValueKey('nav-home'));
      if (home.evaluate().isNotEmpty) {
        await t.tap(home.first, warnIfMissed: false);
        await settle();
        expect(loc(), '/', reason: 'Map button on $r');
      }
      expect(t.takeException(), isNull, reason: r);
    }
  });
}
