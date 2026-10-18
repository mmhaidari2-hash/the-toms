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

/// The conversation screen as a chat transcript: compact banner, stacked bubbles (others left with face + name,
/// the learner right), tools on the latest bubble or a tapped older one, and feedback inline.
void main() {
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

  testWidgets('Morning cuppa: bubbles stack, the reply sits on the right, earlier lines stay', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('The Toms').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    Future<void> wait([int n = 12]) async {
      for (var i = 0; i < n; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(t.takeException(), isNull);
    }

    router.go('/chat/tom_breakfast');
    await wait(20);
    expect(find.byKey(const ValueKey('chat-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-list')), findsOneWidget);
    final first = find.text("Morning! Kettle's just boiled — fancy a cuppa?");
    expect(first, findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('bubble-0')), matching: find.text('Tom')), findsOneWidget, reason: 'name on the bubble');
    expect(find.byKey(const ValueKey('bubble-tools')), findsOneWidget, reason: 'chips on the latest bubble');

    await t.enterText(find.byType(TextField), "Yes please, that'd be lovely.");
    await t.tap(find.byTooltip('Send'));
    await wait(25);
    expect(find.byKey(const ValueKey('bubble-me-1')), findsOneWidget);
    expect(first, findsOneWidget, reason: 'earlier lines stay visible');
    // The learner's bubble is on the right, Tom's on the left.
    final me = t.getRect(find.byKey(const ValueKey('bubble-me-1')));
    final tom = t.getRect(find.byKey(const ValueKey('bubble-0')));
    expect(me.right, greaterThan(tom.right - 1));
    expect(tom.left, lessThan(me.left));
    // A later line from Tom arrived below, and the tools moved to it.
    final later = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('bubble-') && !'${(w.key as ValueKey).value}'.startsWith('bubble-me') && (w.key as ValueKey).value != 'bubble-0' && (w.key as ValueKey).value != 'bubble-tools');
    expect(later, findsWidgets);
    expect(t.getRect(later.first).top, greaterThan(me.top));
    expect(find.descendant(of: find.byKey(const ValueKey('bubble-0')), matching: find.byKey(const ValueKey('bubble-tools'))), findsNothing);
    // Tap the first bubble: its tools open there.
    await t.tap(first);
    await wait(3);
    expect(find.descendant(of: find.byKey(const ValueKey('bubble-0')), matching: find.byKey(const ValueKey('bubble-tools'))), findsOneWidget);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
