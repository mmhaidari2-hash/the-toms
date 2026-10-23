import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/speech_result.dart';
import 'package:british_life/features/messages/thread_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Messages flow: home sheet → inbox locks → voice note, transcript, Persian → check → reply by typing / speaking → celebrate.
void main() {
  group('messages at 375x667', () {
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
    testWidgets('home → inbox → thread → reply → done', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
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

      Future<void> tapKey(String k) async {
        final f = find.byKey(ValueKey(k));
        await t.scrollUntilVisible(f, 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 500));
      }

      Text txt(String k) => t.widget<Text>(find.byKey(ValueKey(k)));

      // The home spot's sheet leads to Messages.
      router.go('/');
      await settle();
      await t.ensureVisible(find.byKey(const ValueKey('spot-home')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-home')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 800));
      await t.ensureVisible(find.byKey(const ValueKey('spot-open-messages')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('spot-open-messages')));
      await settle();
      expect(find.byKey(const ValueKey('inbox-list')), findsOneWidget);
      expect(txt('inbox-status-A1').data, '0/2');
      expect(find.byKey(const ValueKey('thread-unread-t_a1_milk')), findsOneWidget);
      await t.scrollUntilVisible(find.byKey(const ValueKey('inbox-status-A2')), 200);
      expect(txt('inbox-status-A2').data, 'Locked · قفل');
      await t.tap(find.byKey(const ValueKey('thread-t_a2_match')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('inbox-locked-snack')), findsOneWidget);
      ScaffoldMessenger.of(t.element(find.byKey(const ValueKey('inbox-locked-snack')))).removeCurrentSnackBar();
      await t.pump(const Duration(milliseconds: 500));

      // Deep link to a locked level.
      router.go('/messages/t_c1_choice');
      await settle();
      expect(find.byKey(const ValueKey('thread-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('thread-locked-why')), findsOneWidget);

      // A1: Leslie's voice note. Transcript hidden until asked; Persian on request.
      router.go('/messages/t_a1_milk');
      await settle();
      expect(find.byKey(const ValueKey('msg-voice-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('msg-transcript-0')), findsNothing, reason: 'listen first');
      expect(find.byKey(const ValueKey('msg-text-1')), findsOneWidget, reason: 'texts are always readable');
      await t.tap(find.byKey(const ValueKey('msg-play-0')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('msg-transcript')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('msg-transcript-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('msg-fa-0')), findsNothing);
      await t.tap(find.byKey(const ValueKey('msg-fa')));
      await settle();
      expect(find.byKey(const ValueKey('msg-fa-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('msg-fa-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('msg-gloss')), findsOneWidget);

      // Quick check: right first time. Then type a reply that's not close enough, then a good one.
      await tapKey('msg-opt-0');
      expect(find.byKey(const ValueKey('msg-reply')), findsOneWidget);
      await tapKey('msg-mode-type');
      await t.enterText(find.byKey(const ValueKey('msg-type')), 'I like trains');
      await tapKey('msg-send');
      expect(find.byKey(const ValueKey('msg-sent')), findsNothing);
      expect(find.byKey(const ValueKey('msg-score')), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('msg-type')), 'yes no problem');
      await tapKey('msg-send');
      expect(find.byKey(const ValueKey('msg-sent')), findsOneWidget);
      await tapKey('msg-finish');
      await settle();
      expect(find.byKey(const ValueKey('msg-celebrate')), findsOneWidget);

      // Second A1 thread: reply by speaking (mic replaced; no audio is ever kept).
      ThreadScreen.listenOverride = (target) async => SpeechResult(alternatives: [target.toLowerCase()]);
      addTearDown(() => ThreadScreen.listenOverride = null);
      router.go('/messages/t_a1_dino');
      await settle();
      await tapKey('msg-opt-0');
      await tapKey('msg-mode-say');
      expect(find.byKey(const ValueKey('msg-mic-note')), findsOneWidget);
      await tapKey('msg-mic');
      await settle();
      expect(find.byKey(const ValueKey('msg-sent')), findsOneWidget);
      await tapKey('msg-finish');
      await settle();
      expect(find.byKey(const ValueKey('msg-celebrate')), findsOneWidget);

      router.go('/messages');
      await settle();
      expect(txt('inbox-status-A1').data, '2/2');
      expect(find.byKey(const ValueKey('thread-done-t_a1_milk')), findsOneWidget);
      await t.scrollUntilVisible(find.byKey(const ValueKey('inbox-status-A2')), 200);
      expect(txt('inbox-status-A2').data, '0/2', reason: 'A1 done opens A2');
    });
  });
}
