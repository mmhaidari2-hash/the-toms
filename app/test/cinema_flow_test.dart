import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/speech_result.dart';
import 'package:british_life/features/cinema/scene_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cinema & dubbing flow: locked levels, watch with subtitles, dub a role (scored), questions.
void main() {
  group('cinema at 375x667', () {
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
    testWidgets('foyer locks → watch → dub (scored, in time) → questions → watched', (t) async {
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

      Future<void> run(Finder busy, {int maxSec = 90}) async {
        for (var i = 0; i < maxSec * 2 && busy.evaluate().isNotEmpty; i++) {
          await t.pump(const Duration(milliseconds: 500));
        }
        expect(busy, findsNothing, reason: 'still playing');
        expect(t.takeException(), isNull);
      }

      router.go('/cinema');
      await settle();
      expect(find.byKey(const ValueKey('cine-level-A1')), findsOneWidget);
      expect(find.byKey(const ValueKey('cine-status-A2')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('cine-status-A2'))).data, 'Locked · قفل');
      await t.tap(find.byKey(const ValueKey('scene-c_a2_shop')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('cine-locked-snack')), findsOneWidget);
      await t.pump(const Duration(seconds: 5));

      // Deep link to a locked level: never plays.
      router.go('/cinema/c_b1_keys');
      await settle();
      expect(find.byKey(const ValueKey('scene-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('cine-screen')), findsNothing);

      // Watch an A1 scene with subtitles.
      router.go('/');
      await settle();
      router.push('/cinema');
      await settle();
      await t.tap(find.byKey(const ValueKey('scene-c_a1_breakfast')));
      await settle();
      expect(find.byKey(const ValueKey('cine-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('line-spk-0')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cine-fa')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('line-fa-0')), findsOneWidget, reason: 'Persian subtitles');
      await t.tap(find.byKey(const ValueKey('cine-watch')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('cine-subtitle')), findsOneWidget);
      expect(find.byKey(const ValueKey('cine-stop')), findsOneWidget);
      await run(find.byKey(const ValueKey('cine-stop')));

      // Dub Nicola: the "microphone" hears each target line exactly.
      final heard = <String>[];
      SceneScreen.listenOverride = (target, onPartial) async {
        heard.add(target);
        onPartial(target);
        await Future.delayed(const Duration(milliseconds: 600));
        return SpeechResult(alternatives: [target], confidence: .9);
      };
      addTearDown(() => SceneScreen.listenOverride = null);
      expect(find.byKey(const ValueKey('role-nicola')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('role-nicola')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('cine-dub')));
      await t.pump(const Duration(milliseconds: 300));
      var sawYourLine = false;
      for (var i = 0; i < 180 && find.byKey(const ValueKey('cine-stop')).evaluate().isNotEmpty; i++) {
        await t.pump(const Duration(milliseconds: 500));
        sawYourLine |= find.byKey(const ValueKey('your-line')).evaluate().isNotEmpty;
      }
      await t.pump(const Duration(milliseconds: 700));
      expect(sawYourLine, isTrue, reason: 'cue for the learner\'s line');
      expect(heard, ["Morning, Mum. I'm hungry!", 'Toast, please. With jam!', "Dad, you've got jam on your nose!"]);
      expect(find.byKey(const ValueKey('dub-results')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('dub-score'))).data, '100%');
      expect(find.text('3 of 3 lines in time  ·  +15 XP'), findsOneWidget);
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('cine-screen')))).read(progressProvider.notifier);
      expect(ctrl.dubScore('c_a1_breakfast'), 100);

      // A mumbled line scores lower and shows which words were missed; the best score is kept.
      SceneScreen.listenOverride = (target, onPartial) async => const SpeechResult(alternatives: ['toast'], confidence: .4);
      await t.tap(find.byKey(const ValueKey('dub-again')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('cine-stop')), findsOneWidget);
      for (var i = 0; i < 180 && find.byKey(const ValueKey('cine-stop')).evaluate().isNotEmpty; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      await t.pump(const Duration(milliseconds: 700));
      final low = int.parse(t.widget<Text>(find.byKey(const ValueKey('dub-score'))).data!.replaceAll('%', ''));
      expect(low, lessThan(50));
      expect(find.byKey(const ValueKey('dub-marks')), findsWidgets);
      expect(ctrl.dubScore('c_a1_breakfast'), 100);

      // Questions (the correct option is index 0 before shuffling).
      await t.tap(find.byKey(const ValueKey('cine-quiz')));
      await t.pump(const Duration(milliseconds: 400));
      while (find.byKey(const ValueKey('cine-q')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const ValueKey('cine-opt-0')));
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const ValueKey('cine-celebrate')), findsOneWidget);
      expect(find.text('Scene understood!'), findsOneWidget);
      expect(ctrl.sceneDone('c_a1_breakfast'), isTrue);
      await t.tap(find.text('Continue').first);
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('cine-screen')), findsOneWidget);
      router.go('/cinema');
      await settle();
      expect(find.byKey(const ValueKey('scene-done-c_a1_breakfast')), findsOneWidget);
      expect(find.byKey(const ValueKey('scene-dub-c_a1_breakfast')), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
    });
  });
}
