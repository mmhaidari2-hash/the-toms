import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/guide/user_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _fa = RegExp(r'[\u0600-\u06FF]');

Future<void> _boot(WidgetTester t) async {
  final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
  await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
  for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => BL.useGoogleFonts = false);
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

  test('course entry explains role switching (t310)', () {
    final e = [for (final g in UserGuide.groups) ...g.$3].firstWhere((e) => e.route == '/course');
    expect(e.how, contains('Swap roles'));
    expect(e.how, contains('Play as'));
    expect(e.howFa, contains('نقش هر شخصیت'));
  });

  test('library entry matches the t310 library (hall, narrator, dictionary card, Leitner, any book opens)', () {
    final lib = [for (final g in UserGuide.groups) ...g.$3].firstWhere((e) => e.route == '/library');
    for (final w in ['front desk', 'sections', 'level-coloured shelves', 'Any book can be opened', 'narrator', 'dictionary card', 'Add to Leitner', 'new words', 'search']) {
      expect('${lib.what} ${lib.how}'.contains(w), isTrue, reason: w);
    }
    for (final w in ['راوی', 'دیکشنری', 'لایتنر', 'میز امانت']) {
      expect('${lib.whatFa} ${lib.howFa}'.contains(w), isTrue, reason: w);
    }
  });

  test('every guide entry is EN+FA, points at a real route, and paid wording matches the guard', () {
    final routes = RegExp(r"GoRoute\(path: '([^']+)'").allMatches(File('lib/app/router.dart').readAsStringSync()).map((m) => m.group(1)!).toSet();
    final all = [for (final g in UserGuide.groups) ...g.$3];
    expect(all.length, greaterThanOrEqualTo(25));
    for (final e in all) {
      final path = e.route.split('?').first;
      final known = routes.contains(path) || routes.any((r) => RegExp('^${r.replaceAll(RegExp(r':[a-z]+'), '[^/]+')}\$').hasMatch(path));
      expect(known, isTrue, reason: '${e.route} is not a route');
      for (final s in [e.title, e.what, e.how]) {
        expect(s.trim(), isNotEmpty);
      }
      for (final s in [e.titleFa, e.whatFa, e.howFa]) {
        expect(_fa.hasMatch(s), isTrue, reason: '${e.route} needs Persian');
      }
      if (e.access == GuideAccess.mixed) expect(e.accessNote, isNotNull, reason: e.route);
    }
    // Premium-only parts in a paid build: certificates; partly free: course, Life in the UK, theory.
    GuideAccess of(String r) => all.firstWhere((e) => e.route == r).access;
    expect(of('/certificate/1'), GuideAccess.premium);
    for (final r in ['/course', '/lifeuk', '/theory']) {
      expect(of(r), GuideAccess.mixed);
    }
    for (final r in ['/arrival', '/forms', '/visa', '/settlement', '/coach', '/leitner', '/check']) {
      expect(of(r), GuideAccess.free, reason: r);
    }
    // Every menu route has a guide entry.
    final menu = RegExp(r"',\s*'(/[a-z/0-9]+)',?\s*\)").allMatches(File('lib/features/map/map_home.dart').readAsStringSync()).map((m) => m.group(1)!).toSet()
      ..removeAll({'/guide', '/howto', '/premium', '/family', '/driving', '/placement'});
    final guided = all.map((e) => e.route).toSet();
    for (final r in menu) {
      if (r.startsWith('/pack/') || r.startsWith('/lesson') || r.startsWith('/course?')) continue;
      expect(guided.contains(r) || r == '/practice/mistakes', isTrue, reason: 'menu route $r has no guide entry');
    }
  });

  test('beta note is honest about the current build', () {
    expect(PremiumConfig.betaFree, isTrue);
    expect(UserGuide.betaNote.$1, contains('everything in the app is free'));
    expect(_fa.hasMatch(UserGuide.betaNote.$2), isTrue);
  });

  testWidgets('menu → User guide: beta note, sections expand, Open goes there; menu has Progress check; tour shows the tip', (t) async {
    t.view.physicalSize = const Size(360, 780) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await _boot(t);
    await t.tap(find.byKey(const ValueKey('menu')));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('menu-/guide'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-/check'), skipOffstage: false), findsOneWidget);
    final g = find.byKey(const ValueKey('menu-/guide'), skipOffstage: false);
    await t.ensureVisible(g);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(g);
    for (var i = 0; i < 20 && find.byKey(const ValueKey('user-guide')).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('user-guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-beta-note')), findsOneWidget);
    expect(t.takeException(), isNull);
    final tile = find.byKey(const ValueKey('guide-/course'));
    await t.scrollUntilVisible(tile, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('user-guide')), matching: find.byType(Scrollable)).first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(tile);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Units 1–10, the first unit of every level'), findsOneWidget);
    expect(find.textContaining('Free during the beta'), findsOneWidget);
    final open = find.byKey(const ValueKey('guide-open-/course'));
    await t.ensureVisible(open);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(open);
    await t.pump(const Duration(milliseconds: 800));
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/course');
    expect(t.takeException(), isNull);
    router.go('/howto');
    for (var i = 0; i < 30 && find.byKey(const ValueKey('howto-guide-tip')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('howto-guide-tip')), findsOneWidget);
    expect(find.textContaining('User guide & help'), findsOneWidget);
    expect(t.takeException(), isNull);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
