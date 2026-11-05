import 'dart:async';

import 'package:british_life/app/theme.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/map/map_home.dart';
import 'package:british_life/features/shared/voice_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const text = 'A full sentence.';
  final key = Voice.key('narrator', text);
  tearDown(() => Voice.debugSetAudio(keys: {}));

  test('missing recording is a failure, never silent success', () async {
    Voice.debugSetAudio(keys: {}, player: (_, _) async => true);
    expect(await Voice.say('narrator', text), isFalse);
    expect(Voice.failure.value?.kind, VoiceFailureKind.missing);
    expect(await Voice.retry(), isFalse);
  });

  test(
    'playback failure and exception propagate without robotic fallback',
    () async {
      Voice.debugSetAudio(keys: {key}, player: (_, _) async => false);
      expect(await Voice.say('narrator', text), isFalse);
      expect(Voice.failure.value?.kind, VoiceFailureKind.playback);
      Voice.debugSetAudio(
        keys: {key},
        player: (_, _) async => throw StateError('blocked'),
      );
      expect(await Voice.say('narrator', text), isFalse);
      expect(Voice.failure.value?.kind, VoiceFailureKind.playback);
    },
  );

  test(
    'retry replays the failed line and clears feedback on success',
    () async {
      var calls = 0;
      Voice.debugSetAudio(keys: {key}, player: (_, _) async => ++calls > 1);
      expect(await Voice.say('narrator', text), isFalse);
      expect(await Voice.retry(), isTrue);
      expect(calls, 2);
      expect(Voice.failure.value, isNull);
    },
  );

  test(
    'superseded playback cannot succeed or overwrite current feedback',
    () async {
      final pending = Completer<bool>();
      Voice.debugSetAudio(keys: {key}, player: (_, _) => pending.future);
      final first = Voice.say('narrator', text);
      expect(await Voice.say('narrator', 'A missing line.'), isFalse);
      pending.complete(true);
      expect(await first, isFalse);
      expect(Voice.failure.value?.text, 'A missing line.');
    },
  );

  test('stop cancels a sequence without displaying a playback error', () async {
    final pending = Completer<bool>();
    Voice.debugSetAudio(keys: {key}, player: (_, _) => pending.future);
    final first = Voice.say('narrator', text);
    Voice.stop();
    pending.complete(false);
    expect(await first, isFalse);
    expect(Voice.failure.value, isNull);
  });

  test('invalid playback speeds are bounded safely', () async {
    final observed = <double>[];
    Voice.debugSetAudio(
      keys: {key},
      player: (_, rate) async {
        observed.add(rate);
        return true;
      },
    );
    for (final rate in [double.nan, double.infinity, -2.0, 50.0]) {
      expect(await Voice.say('narrator', text, rate: rate), isTrue);
    }
    expect(observed, [1, 1, .5, 2]);
  });

  test('menu matches English and Arabic keyboard forms of Persian', () {
    expect(menuSearchMatches('Library', 'کتابخانه', 'LIBrary'), isTrue);
    expect(menuSearchMatches('Library', 'کتابخانه', 'كتابخانه'), isTrue);
    expect(
      menuSearchMatches('Course path', 'مسیر درس‌ها', 'مسير درس ها'),
      isTrue,
    );
    expect(menuSearchMatches('Grammar', 'دستور زبان', 'not-present'), isFalse);
  });

  testWidgets('playback feedback retry succeeds and removes the notice', (
    t,
  ) async {
    BL.useGoogleFonts = false;
    var calls = 0;
    Voice.debugSetAudio(keys: {key}, player: (_, _) async => ++calls > 1);
    await t.pumpWidget(
      const MaterialApp(home: VoiceFeedback(child: Scaffold())),
    );
    await Voice.say('narrator', text);
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('voice-retry')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('voice-retry')));
    await t.pump();
    await t.pump();
    expect(calls, 2);
    expect(find.byKey(const ValueKey('voice-feedback')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'audio failure feedback is visible and dismissible at mobile width',
    (t) async {
      BL.useGoogleFonts = false;
      t.view.physicalSize = const Size(375, 667);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Voice.debugSetAudio(keys: {});
      await t.pumpWidget(
        const MaterialApp(home: VoiceFeedback(child: Scaffold())),
      );
      await Voice.say('narrator', text);
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('voice-feedback')), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-retry')), findsNothing);
      await t.tap(find.byKey(const ValueKey('voice-dismiss')));
      await t.pump();
      expect(find.byKey(const ValueKey('voice-feedback')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
