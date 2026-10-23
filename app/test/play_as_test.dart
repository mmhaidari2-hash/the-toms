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

/// "Play as": a labelled role switch that carries on from the current line (never restarts).
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

  testWidgets('Play as: switch to Sian mid-call and back, the call carries on from the current line', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
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

    router.go('/chat/l2_u8_1');
    await wait(20);
    final n1 = find.text('Good morning, Northgate Bank, Sian speaking. How can I help?');
    expect(n1, findsOneWidget);
    expect(find.byKey(const ValueKey('play-as')), findsOneWidget);
    expect(find.text('Play as'), findsOneWidget);
    expect(find.text('در نقش'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('play-as')), matching: find.text('Siân')), findsOneWidget);

    // Swap mid-call: the reply the learner owed is spoken for them, then Sian's next line is theirs.
    await t.tap(find.byKey(const ValueKey('playas-them')));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Hi. Could I speak to someone about my account?'), findsNothing, reason: 'no stale reply chips while the other side is talking');
    await wait(25);
    // The painting is a bigger hero now, so the opening may be scrolled up: scroll to it, then back down.
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, 3000));
    await wait(3);
    expect(n1, findsOneWidget, reason: 'no restart');
    expect(find.text("Hello. I'm calling about my new bank card."), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, -3000));
    await wait(3);
    expect(find.byKey(const ValueKey('my-line')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('my-line')), matching: find.text('Of course. Can I take your full name and date of birth, please?')), findsOneWidget);

    // Say the line (tap it): it goes in as the learner's bubble, the caller answers, the next line is ready.
    await t.tap(find.byKey(const ValueKey('my-line')));
    await wait(25);
    expect(find.descendant(of: find.byKey(const ValueKey('chat-list')), matching: find.text('Of course. Can I take your full name and date of birth, please?')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-line')), findsOneWidget, reason: 'the next line is the learner\'s, no stall');
    final mine = (t.widget<Text>(find.descendant(of: find.byKey(const ValueKey('my-line')), matching: find.byType(Text)).at(1))).data!;

    // Back to the usual part: Sian says that same line, and the reply options return.
    await t.tap(find.byKey(const ValueKey('playas-me')));
    await wait(25);
    expect(find.byKey(const ValueKey('my-line')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('chat-list')), matching: find.text(mine)), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, 3000));
    await wait(3);
    expect(n1, findsOneWidget, reason: 'still no restart: the first line is still the only opening');
    await t.enterText(find.byType(TextField), 'Thanks, that is great.');
    await t.tap(find.byTooltip('Send'));
    await wait(25);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
