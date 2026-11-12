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

/// Full role switching (owner t310): pick any speaker of a scene, before it starts (lesson card, ?as=) or mid-scene.
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

  Future<(MemoryProgressStore, Future<void> Function([int]))> boot(WidgetTester t) async {
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

    return (store, wait);
  }

  Finder inChat(String s) => find.descendant(of: find.byKey(const ValueKey('chat-list')), matching: find.text(s));
  /// Scrolls the chat from the top down until [s] is built (the list builds lazily).
  Future<bool> seen(WidgetTester t, String s) async {
    final list = find.byKey(const ValueKey('chat-list'));
    await t.drag(list, const Offset(0, 3000));
    await t.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 40; i++) {
      if (inChat(s).evaluate().isNotEmpty) return true;
      await t.drag(list, const Offset(0, -120));
      await t.pump(const Duration(milliseconds: 200));
    }
    return inChat(s).evaluate().isNotEmpty;
  }

  Finder myLine(String s) => find.descendant(of: find.byKey(const ValueKey('my-line')), matching: find.text(s));

  testWidgets('lesson card lists every speaker; ?as=george plays George, the others speak, progress is saved', (t) async {
    final (store, wait) = await boot(t);
    router.go('/lesson/l4_u5_4');
    await wait(15);
    await t.scrollUntilVisible(find.byKey(const ValueKey('role-hidden')), 200, scrollable: find.byType(Scrollable).first);
    // Clear the floating start bar at the bottom.
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await wait(2);
    expect(find.byKey(const ValueKey('role-pick-learner')), findsOneWidget);
    expect(find.byKey(const ValueKey('role-pick-leslie')), findsOneWidget);
    expect(find.byKey(const ValueKey('role-pick-george')), findsOneWidget);
    final hidden = t.widget<Text>(find.byKey(const ValueKey('role-hidden'))).data!;
    expect(hidden, contains('Not in this story:'));
    expect(hidden, contains('Ryan'));
    expect(hidden, isNot(contains('George')));
    await t.tap(find.byKey(const ValueKey('role-pick-george')));
    await wait(30);

    // Leslie (an NPC now) opens, the usual guest answers her, then George's line is the learner's.
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, 3000));
    await wait(2);
    expect(find.textContaining('You are Grandad George: say Grandad George’s 3 lines'), findsOneWidget);
    expect(find.textContaining('Listen first: 1 line comes before yours.'), findsOneWidget);
    expect(await seen(t, 'George has been a bit low since his friend Stan passed away. Would you sit with him for a while? He likes talking to you.'), isTrue);
    expect(await seen(t, "Of course. George, I'm so sorry about Stan."), isTrue, reason: 'the usual guest answers Leslie');
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, -3000));
    await wait(2);
    expect(myLine('Sixty years. Best mate.'), findsOneWidget);
    expect(find.text('YOUR LINE AS GRANDAD GEORGE'), findsOneWidget);

    // Say it (tap), then George's next line comes after the guest's answer.
    await t.tap(find.byKey(const ValueKey('my-line')));
    await wait(25);
    expect(myLine('We played football. Every Saturday.'), findsOneWidget);
    // A reply that is not the line: the story still moves on (it counts as a slip for this role).
    await t.enterText(find.byType(TextField), 'I like pizza');
    await t.tap(find.byTooltip('Send'));
    await wait(35);
    // Leslie's long line is hers (NPC), the guest answers, then the last line is George's again.
    expect(myLine('Yes. Brothers. Thank you, son.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('my-line')));
    await wait(30);
    expect(store.data, contains('pref:role:l4_u5_4:george'));
    expect(store.data, contains('67|1'), reason: '2 of 3 lines said well, one run');
    expect(store.data, contains('pref:roleTrust:george'));
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('mid-scene picker: every speaker, switch between two characters and back without a restart', (t) async {
    final (_, wait) = await boot(t);
    router.go('/chat/l4_u5_4');
    await wait(20);
    expect(find.byKey(const ValueKey('play-as')), findsOneWidget);
    expect(find.byKey(const ValueKey('playas-me')), findsOneWidget);
    expect(find.byKey(const ValueKey('playas-them')), findsOneWidget, reason: 'the lead (Leslie)');
    expect(find.byKey(const ValueKey('playas-george')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('playas-george')));
    await wait(25);
    expect(myLine('Sixty years. Best mate.'), findsOneWidget);
    // Now Leslie: George says his own line, the guest answers, George again, then Leslie's line is the learner's.
    await t.tap(find.byKey(const ValueKey('playas-them')));
    await wait(40);
    expect(myLine("Stan was the goalkeeper. George always said he was rubbish, but he never missed a match. They'd argue about it every week, and then go for a pint."), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, 3000));
    await wait(2);
    expect(inChat('George has been a bit low since his friend Stan passed away. Would you sit with him for a while? He likes talking to you.'), findsOneWidget, reason: 'no restart');
    // George's two lines were said by George himself (an NPC now).
    expect(await seen(t, 'Sixty years. Best mate.'), isTrue);
    expect(await seen(t, 'We played football. Every Saturday.'), isTrue);
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, -3000));
    await wait(2);
    // Back to the usual part: Leslie says her line and the reply options return.
    await t.tap(find.byKey(const ValueKey('playas-me')));
    await wait(25);
    expect(find.byKey(const ValueKey('my-line')), findsNothing);
    expect(await seen(t, "Stan was the goalkeeper. George always said he was rubbish, but he never missed a match. They'd argue about it every week, and then go for a pint."), isTrue,
        reason: 'Leslie says the line the learner was about to say');
    await t.drag(find.byKey(const ValueKey('chat-list')), const Offset(0, -3000));
    await wait(2);
    await t.enterText(find.byType(TextField), 'It sounds like there was a lot of love behind the teasing.');
    await t.tap(find.byTooltip('Send'));
    await wait(30);
    expect(await seen(t, 'Yes. Brothers. Thank you, son.'), isTrue, reason: 'the usual reply moves the story on');
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
