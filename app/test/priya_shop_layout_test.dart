import 'dart:io';
import 'dart:ui' as ui;

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Priya's A1 shop, route /chat/l1_u43_1 ("Excuse me, can you help me?").
/// Turning the phone after the chat has grown must keep the lesson on screen,
/// and the missing-audio notice must not cover the line or the reply controls.
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

  test('sideways painting height used to throw once the chat left the opening', () {
    // The phone column is at most 520 wide. After two lines the painting used
    // width * .5, clamped between 128 and height * .24. On a 390-tall landscape
    // phone the upper bound is below 128, and num.clamp throws ArgumentError.
    const height = 390.0;
    const column = 520.0;
    expect(() => (column * .5).clamp(128.0, height * .24), throwsArgumentError);
    expect(() => (column * .8).clamp(128.0, height * .42), returnsNormally);
    expect((390.0 * .5).clamp(128.0, 844.0 * .24), 195);
  });

  testWidgets('shop lesson stays usable portrait, landscape, and under the audio notice', (t) async {
    BL.useGoogleFonts = false;
    addTearDown(t.view.reset);
    final shotDir = Directory('/tmp/priya-shop-shots')..createSync(recursive: true);

    Future<void> size(Size logical) async {
      t.view.physicalSize = logical;
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = FakeViewPadding.zero;
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    // One photograph per process. A second toImageSync in the same test run
    // takes down the tester, so the proof shots are requested with --dart-define=SHOT=.
    const onlyShot = String.fromEnvironment('SHOT');
    Future<void> shoot(String name) async {
      if (onlyShot != name) return;
      await t.pump();
      final view = t.view.physicalSize / t.view.devicePixelRatio;
      RenderRepaintBoundary? best;
      for (final object in t.allRenderObjects) {
        if (object is! RenderRepaintBoundary || object.debugNeedsPaint || object.size.isEmpty) continue;
        if (object.size.width < 300 || object.size.height < 200) continue;
        if (object.size.width > view.width + 2 || object.size.height > view.height + 2) continue;
        if (best == null || object.size.width * object.size.height > best.size.width * best.size.height) best = object;
      }
      expect(best, isNotNull, reason: 'phone-sized frame for $name');
      final image = best!.toImageSync(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${shotDir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Future<void> wait([int n = 8]) async {
      for (var i = 0; i < n; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 80)));
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(t.takeException(), isNull);
    }

    Future<void> reveal(Finder target) async {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      final scroll = find.byType(Scrollable);
      expect(scroll, findsWidgets);
      await t.scrollUntilVisible(target, 48, scrollable: scroll.last);
      await t.pump();
    }

    void clearOfNotice(Finder target, String name) {
      expect(target, findsOneWidget);
      final notice = t.getRect(find.byKey(const ValueKey('voice-feedback')));
      final box = t.getRect(target);
      expect(box.height, greaterThan(8), reason: name);
      expect(notice.overlaps(box), isFalse, reason: '$name must stay clear of the audio notice');
    }

    await size(const Size(390, 844));
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 80));
    }

    router.go('/chat/l1_u43_1');
    await wait(16);
    expect(find.text('Excuse me, can you help me?'), findsWidgets);
    expect(find.text('Hi there! You look a bit lost. Can I help you with anything?'), findsOneWidget);
    expect(find.byKey(const ValueKey('playas-me')), findsOneWidget);
    await shoot('after-portrait-opening');

    await t.enterText(find.byType(TextField), 'yes please can i have candy');
    await t.tap(find.byTooltip('Send'));
    await wait(18);
    expect(find.text('yes please can i have candy', skipOffstage: false), findsOneWidget);
    expect(find.text('Of course! What are you looking for?', skipOffstage: false), findsNothing);
    expect(find.textContaining('You mean', skipOffstage: false), findsWidgets);
    await reveal(find.text('yes please can i have candy'));
    await shoot('after-portrait-typed');

    await t.enterText(find.byType(TextField), 'Excuse me, can you help me?');
    await t.tap(find.byTooltip('Send'));
    await wait(18);
    expect(find.text('Of course! What are you looking for?', skipOffstage: false), findsOneWidget);
    expect(find.text('yes please can i have candy', skipOffstage: false), findsOneWidget);

    await size(const Size(844, 390));
    await wait(4);
    expect(find.byKey(const ValueKey('chat-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-as')), findsOneWidget);
    expect(find.text('Of course! What are you looking for?', skipOffstage: false), findsOneWidget);
    expect(find.text('yes please can i have candy', skipOffstage: false), findsOneWidget);
    await reveal(find.text('Of course! What are you looking for?'));
    expect(find.byTooltip('Send'), findsOneWidget);
    await shoot('after-landscape-typed');

    await size(const Size(390, 844));
    await wait(3);
    expect(find.text('Of course! What are you looking for?', skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('playas-me')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('playas-them')));
    await wait(18);
    expect(find.text('Do you sell saffron?', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('YOUR LINE AS PRIYA'), findsOneWidget);
    await reveal(find.byKey(const ValueKey('my-line')));

    Voice.debugSetAudio(keys: {});
    await Voice.say('priya', 'a line with no recording');
    await t.pump();
    await t.pump();
    expect(find.textContaining('No recording for this line yet'), findsOneWidget);
    expect(find.textContaining('صدای این جمله هنوز آماده نیست'), findsOneWidget);
    await reveal(find.byKey(const ValueKey('my-line')));
    await reveal(find.byTooltip('Send'));
    clearOfNotice(find.byKey(const ValueKey('my-line')), 'your line');
    clearOfNotice(find.byKey(const ValueKey('play-as')), 'role switch');
    clearOfNotice(find.byTooltip('Send'), 'send');
    clearOfNotice(find.byTooltip('Speak with the keyboard mic'), 'microphone');
    await shoot('after-portrait-notice');

    await size(const Size(844, 390));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    await reveal(find.byKey(const ValueKey('my-line')));
    await reveal(find.byTooltip('Send'));
    clearOfNotice(find.byKey(const ValueKey('my-line')), 'your line');
    clearOfNotice(find.byKey(const ValueKey('play-as')), 'role switch');
    clearOfNotice(find.byTooltip('Send'), 'send');
    expect(find.text('Do you sell saffron?', skipOffstage: false), findsOneWidget);
    await shoot('after-landscape-notice');

    t.view.viewInsets = const FakeViewPadding(bottom: 150);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    await reveal(find.byKey(const ValueKey('my-line')));
    await reveal(find.byTooltip('Send'));
    clearOfNotice(find.byKey(const ValueKey('my-line')), 'your line');
    clearOfNotice(find.byTooltip('Send'), 'send');
    expect(find.text('Do you sell saffron?', skipOffstage: false), findsOneWidget);
    await shoot('after-landscape-keyboard');
  });
}
