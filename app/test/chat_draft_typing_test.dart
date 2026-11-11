import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless widget coverage for the shop composer.
/// This is not a browser, a physical keyboard, or a device.
void main() {
  const shop = '/chat/l1_u43_1';
  const draft = 'ADULT-ONLY-DRAFT';

  late MemoryProgressStore store;

  setUp(() {
    BL.useGoogleFonts = false;
    store = MemoryProgressStore()
      ..data = const UserProgress(onboarded: true, unlockAll: true).encode();
  });

  Future<void> boot(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = FakeViewPadding.zero;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: const BritishLifeApp(),
    ));
    router.go(shop);
    await wait(t);
    expect(find.text('Hi there! You look a bit lost. Can I help you with anything?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('yes pleas is the near spelling of please and continues the shop', (t) async {
    await boot(t);
    await t.enterText(find.byType(TextField), 'yes pleas');
    await t.tap(find.byTooltip('Send'));
    await wait(t, 20);
    expect(find.text('yes pleas'), findsOneWidget);
    expect(find.text('Of course! What are you looking for?'), findsOneWidget);
    expect(find.textContaining('You mean'), findsNothing);
    expect(store.exportAllLocalData().values.join('\n').contains('yes pleas'), isFalse);
  });

  testWidgets('an unsent line is not sent when the keyboard inset changes, the route changes, or the role changes', (t) async {
    await boot(t);
    await t.enterText(find.byType(TextField), draft);
    expect(composer(t), draft);
    expect(sent(draft), findsNothing);

    t.view.viewInsets = const FakeViewPadding(bottom: 320);
    await t.pump();
    expect(composer(t), draft);
    expect(sent(draft), findsNothing);

    t.view.viewInsets = FakeViewPadding.zero;
    await t.pump();
    expect(composer(t), draft);

    await t.tap(find.byKey(const ValueKey('playas-them')));
    await wait(t, 16);
    expect(sent(draft), findsNothing, reason: 'swapping role must not send the unsent line');
    expect(composer(t), draft, reason: 'the swap leaves the unsent line in the composer');
    expect(stored(store).contains(draft), isFalse);

    router.push('/chat/nicola_park');
    await wait(t, 12);
    expect(composer(t), isEmpty, reason: 'the other character gets an empty composer');
    expect(sent(draft), findsNothing);
    expect(stored(store).contains(draft), isFalse);

    router.pop();
    await wait(t, 4);
    expect(composer(t), draft, reason: 'coming back keeps the unsent line on the same chat');
    expect(sent(draft), findsNothing);

    router.go('/');
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    router.go(shop);
    await wait(t);
    expect(sent(draft), findsNothing, reason: 'a new visit must not show the old line as sent');
    expect(composer(t), isEmpty, reason: 'leaving with go drops the chat state instead of saving a draft');
    expect(stored(store).contains(draft), isFalse);
  });

  testWidgets('an unsent line does not stay in the composer or the other profile after a profile switch', (t) async {
    final child = await store.addProfile(displayName: 'Sara', kind: ProfileKind.child);
    await boot(t);
    await t.enterText(find.byType(TextField), draft);

    router.push('/profiles');
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(ValueKey('profile-${child.id}')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(store.activeId, child.id);

    router.pop();
    await wait(t, 4);
    expect(composer(t), isEmpty, reason: 'the other profile must not see the unsent line');
    expect(sent(draft), findsNothing);
    expect(stored(store).contains(draft), isFalse);
    expect(store.read(), isNull, reason: 'switching must not create progress from an unsent line');

    await t.tap(find.byTooltip('Send'));
    await t.pump();
    expect(sent(draft), findsNothing, reason: 'send after the switch has nothing left to send');
    expect(store.read(), isNull);
    expect(stored(store).contains(draft), isFalse);
  });
}

Finder sent(String text) => find.descendant(
      of: find.byKey(const ValueKey('chat-list')),
      matching: find.text(text),
    );

String composer(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).controller?.text ?? '';

String stored(MemoryProgressStore store) => store.exportAllLocalData().values.join('\n');

Future<void> wait(WidgetTester t, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(t.takeException(), isNull);
}
