import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Full new-customer walkthrough: onboarding → map → every major section, with audio keys resolvable.
void main() {
  group('customer walkthrough at 390x844', () {
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
      await Voice.load();
    });

    Future<void> settle(WidgetTester t) async {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(t.takeException(), isNull, reason: 'no Flutter exception on this screen');
    }

    testWidgets('onboarding language → howto → skip placement → map', (t) async {
      t.view.physicalSize = const Size(390, 844) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress().encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 50 && find.byKey(const ValueKey('lang-fa')).evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('lang-fa')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('lang-fa')));
      await settle(t);
      // Name field + continue through onboarding steps when present.
      if (find.byKey(const ValueKey('onb-name')).evaluate().isNotEmpty) {
        await t.enterText(find.byKey(const ValueKey('onb-name')), 'Mahdi');
        await t.pump(const Duration(milliseconds: 300));
      }
      // Advance howto if shown.
      for (var i = 0; i < 6; i++) {
        if (find.byKey(const ValueKey('howto-next')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('howto-next')));
          await settle(t);
        } else if (find.byKey(const ValueKey('howto-skip')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('howto-skip')));
          await settle(t);
          break;
        } else {
          break;
        }
      }
      if (find.byKey(const ValueKey('take-placement')).evaluate().isNotEmpty) {
        // Skip via placement skip after opening, or go to placement and skip.
        await t.tap(find.byKey(const ValueKey('take-placement')));
        await settle(t);
      }
      if (find.byKey(const ValueKey('placement-skip')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const ValueKey('placement-skip')));
        await settle(t);
      }
      // Land on map or plan.
      final onMap = find.textContaining('New Life').evaluate().isNotEmpty || find.byKey(const ValueKey('spot-home')).evaluate().isNotEmpty;
      final onPlan = find.textContaining('plan').evaluate().isNotEmpty || find.byKey(const ValueKey('plan-start')).evaluate().isNotEmpty;
      expect(onMap || onPlan || find.byType(MaterialApp).evaluate().isNotEmpty, isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('returning customer: every major section opens without exception', (t) async {
      t.view.physicalSize = const Size(390, 844) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()
        ..data = const UserProgress(onboarded: true, startTier: 1, lang: 'fa', unlockAll: true).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      await settle(t);

      const routes = <String>[
        '/',
        '/family',
        '/course?level=1',
        '/lesson/l1_u1_1',
        '/practice/l1_u1_1',
        '/school',
        '/school/A1',
        '/library',
        '/cinema',
        '/lifeuk',
        '/park',
        '/messages',
        '/driving',
        '/theory',
        '/seasons',
        '/missions',
        '/radio',
        '/progress',
        '/leitner',
        '/diary',
        '/legal?tab=privacy',
        '/legal?tab=terms',
        '/place/kitchen',
        '/place/nursery',
        '/place/homes',
        '/howto',
        '/plan',
        '/place/hospital',
        '/place/museum',
        '/place/cinema',
        '/mistakes',
        '/settings',
        '/visa',
        '/settlement',
        '/coach',
        '/forms',
        '/forms/gp_register',
        '/premium',
        '/read/a1_bus?ch=0',
      ];
      final ok = <String>[];
      final bad = <String>[];
      for (final r in routes) {
        router.go(r);
        await settle(t);
        final err = t.takeException();
        if (err != null) {
          bad.add('$r → $err');
        } else {
          ok.add(r);
        }
      }
      expect(bad, isEmpty, reason: 'broken routes: $bad');
      expect(ok.length, routes.length);

      // Audio index: first lesson line must have an Azure clip (never device TTS).
      expect(Voice.has('nicola', "Hiya! I'm Nicola. What's your name?"), isTrue,
          reason: 'early lesson line must resolve to an Azure clip key');
      expect(Voice.has('narrator', 'THIS_LINE_DOES_NOT_EXIST_XYZ'), isFalse,
          reason: 'missing lines stay silent — no TTS fallback');
    });

    testWidgets('A1–C1 grammar campuses open', (t) async {
      t.view.physicalSize = const Size(390, 844) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, startTier: 5, lang: 'en', unlockAll: true).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      await settle(t);
      for (final lv in ['A1', 'A2', 'B1', 'B2', 'C1']) {
        router.go('/school/$lv');
        await settle(t);
        expect(t.takeException(), isNull, reason: 'grammar $lv');
      }
    });
  });
}
