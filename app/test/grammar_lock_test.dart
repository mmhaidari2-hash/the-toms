import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grammar School strict lock: the topic page itself enforces the lock (deep links included).
void main() {
  group('strict lock at 375x667', () {
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
    testWidgets('strict lock: a deep link to a locked topic shows the lock, never the lesson', (t) async {
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

      // Next topic in an open class: locked, with a button to the topic that opens it.
      router.go('/grammar/a1_have');
      await settle();
      expect(find.byKey(const ValueKey('topic-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-screen-a1_have')), findsNothing);
      expect(find.byKey(const ValueKey('start-practice'), skipOffstage: false), findsNothing);
      expect(find.textContaining('Pass "The verb "be"'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topic-locked-next')));
      await settle();
      expect(find.byKey(const ValueKey('topic-screen-a1_be')), findsOneWidget);

      // A topic in a locked class: no shortcut, back to the school.
      router.go('/grammar/c1_cleft');
      await settle();
      expect(find.byKey(const ValueKey('topic-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-locked-next')), findsNothing);
      expect(find.textContaining('Class C1 opens when you pass Class B2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topic-locked-school')));
      await settle();
      expect(find.byKey(const ValueKey('class-A1')), findsOneWidget);

      // Passing the first topic opens the second one for deep links too.
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('class-A1')))).read(progressProvider.notifier);
      ctrl.saveGrammar('a1_be', 80);
      router.go('/grammar/a1_have');
      await settle();
      expect(find.byKey(const ValueKey('topic-locked')), findsNothing);
      expect(find.byKey(const ValueKey('topic-screen-a1_have')), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
    });
  });
}
