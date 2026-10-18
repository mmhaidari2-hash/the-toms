import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Library shelf lock: locked shelves can't be opened, and the reader enforces it on deep links too.
void main() {
  group('library lock at 375x667', () {
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
    testWidgets('locked shelf + locked deep link; unlocked B1 book shows voiced speaker labels', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('The Toms').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> settle() async {
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

      // A deep link to a B1 book on a fresh learner: locked message, no text.
      router.go('/read/b1_flood');
      await settle();
      expect(find.byKey(const ValueKey('book-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('reader-text')), findsNothing);
      expect(find.textContaining('The B1 shelf opens at Level 3'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('book-locked-library')));
      await settle();
      expect(find.byKey(const ValueKey('shelf-A1')), findsOneWidget);
      expect(find.text('Locked · قفل'), findsWidgets);

      // Tapping a locked cover explains why instead of opening it.
      final list = find.byType(Scrollable).first;
      await t.scrollUntilVisible(find.byKey(const ValueKey('book-b1_flood')), 300, scrollable: list);
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull, reason: 'CP1 after scroll');
      await t.tap(find.byKey(const ValueKey('book-b1_flood')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('shelf-locked-snack')), findsOneWidget);
      expect(find.byKey(const ValueKey('booksheet-b1_flood')), findsNothing);
      await t.pump(const Duration(seconds: 5));
      expect(t.takeException(), isNull, reason: 'CP2 after snack');

      // Pass Grammar Classes A1 + A2 → B1 opens; the reader names each speaker.
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('book-b1_flood')))).read(progressProvider.notifier);
      for (final id in ctrl.state.missionsDone.keys.toList()) {
        if (id.startsWith('gram:')) fail('fresh learner has grammar scores');
      }
      final topics = await t.runAsync(() async => Grammar.parse(File('assets/data/grammar.json').readAsStringSync()));
      for (final g in topics!.where((g) => g.level == 'A1' || g.level == 'A2')) {
        ctrl.saveGrammar(g.id, 80);
      }
      router.go('/read/b1_flood');
      await settle();
      expect(find.byKey(const ValueKey('book-locked')), findsNothing);
      expect(find.byKey(const ValueKey('reader-text')), findsOneWidget);
      expect(find.byKey(const ValueKey('spk-3')), findsOneWidget);
      expect(find.text('LESLIE'), findsOneWidget);
      expect(find.byKey(const ValueKey('spk-0')), findsNothing, reason: 'narration has no label');
      await t.pump(const Duration(seconds: 3));
    });
  });
}
