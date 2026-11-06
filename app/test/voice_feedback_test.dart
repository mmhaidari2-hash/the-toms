import 'dart:async';
import 'dart:io';

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

  testWidgets('missing-audio notice stays visible and does not block the reply', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(375, 667);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var replyTaps = 0;
    var bodyTaps = 0;
    Voice.debugSetAudio(keys: {});
    await t.pumpWidget(MaterialApp(
      home: VoiceFeedback(
        child: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 88,
                    child: FilledButton(
                      key: const ValueKey('under-notice'),
                      onPressed: () => bodyTaps++,
                      child: const Text('Covered'),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton.filled(
                  key: const ValueKey('msg-send'),
                  onPressed: () => replyTaps++,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await Voice.say('narrator', text);
    await t.pump();
    await t.pump();
    final notice = t.getRect(find.byKey(const ValueKey('voice-feedback')));
    final covered = t.getRect(find.byKey(const ValueKey('under-notice')));
    final send = t.getRect(find.byKey(const ValueKey('msg-send')));
    expect(notice.intersect(covered).height, greaterThan(8));
    expect(notice.overlaps(send), isFalse);
    await t.tapAt(notice.intersect(covered).center);
    await t.tap(find.byKey(const ValueKey('msg-send')));
    await t.pump();
    expect(bodyTaps, 1, reason: 'the missing-audio note must not take the tap');
    expect(replyTaps, 1, reason: 'the reply send control must stay clear of the note');
    expect(find.byKey(const ValueKey('voice-feedback')), findsOneWidget);
    expect(find.textContaining('No recording for this line yet'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('voice-dismiss')));
    await t.pump();
    expect(find.byKey(const ValueKey('voice-feedback')), findsNothing);
    expect(t.takeException(), isNull);
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

  test('an unloaded audio list is not the same as a missing line', () async {
    Voice.debugSetAudio(keys: {}, ready: false, allowLoad: false);
    expect(await Voice.say('learner', 'Do you sell saffron?'), isFalse);
    expect(Voice.failure.value?.kind, VoiceFailureKind.notReady);
    expect(await Voice.say('me', 'yes please can i have candy', scripted: false), isFalse);
    expect(Voice.failure.value, isNull);
  });

  test('recorded saffron lines resolve; typed candy is not a recorded line', () async {
    const saffron = 'Do you sell saffron?';
    const aisle = "We do! Spices are in aisle six. But saffron is behind the till. It's very expensive!";
    expect(File('assets/audio/7f6d6c589b18837c.mp3').lengthSync(), greaterThan(1000));
    expect(File('assets/audio/8db96d4723b8e439.mp3').lengthSync(), greaterThan(1000));
    expect(File('assets/audio/b922edc0347e152d.mp3').existsSync(), isFalse);
    expect(File('assets/audio/f42e529f09e12a54.mp3').existsSync(), isFalse);

    await Voice.load();
    expect(Voice.has('learner', saffron), isTrue);
    expect(Voice.key('learner', saffron), '2baed0e7dbf8c870');
    expect(Voice.key('me', saffron), '7f6d6c589b18837c');
    expect(Voice.has('priya', aisle), isTrue);
    expect(Voice.has('me', 'yes please can i have candy'), isFalse);

    expect(await Voice.say('learner', saffron), isFalse);
    expect(Voice.failure.value?.kind, VoiceFailureKind.playback);

    final played = <String>[];
    Voice.debugSetAudio(player: (asset, _) async {
      played.add(asset);
      return false;
    });
    expect(await Voice.say('learner', saffron), isFalse);
    expect(Voice.failure.value?.kind, VoiceFailureKind.playback);
    expect(played, ['assets/audio/7f6d6c589b18837c.mp3']);

    expect(await Voice.say('priya', aisle), isFalse);
    expect(played.last, 'assets/audio/8db96d4723b8e439.mp3');
    expect(Voice.failure.value?.kind, VoiceFailureKind.playback);

    expect(await Voice.say('me', 'yes please can i have candy', scripted: false), isFalse);
    expect(Voice.failure.value, isNull);
    expect(played, ['assets/audio/7f6d6c589b18837c.mp3', 'assets/audio/8db96d4723b8e439.mp3']);
  });

  test('retry after the audio list loads plays the recorded line', () async {
    const saffron = 'Do you sell saffron?';
    Voice.debugSetAudio(keys: {}, ready: false, allowLoad: false);
    expect(await Voice.say('learner', saffron), isFalse);
    expect(Voice.failure.value?.kind, VoiceFailureKind.notReady);
    final played = <String>[];
    Voice.debugSetAudio(
      player: (asset, _) async {
        played.add(asset);
        return true;
      },
      clear: false,
      ready: false,
    );
    expect(await Voice.retry(), isTrue);
    expect(played, ['assets/audio/7f6d6c589b18837c.mp3']);
    expect(Voice.failure.value, isNull);
  });
}
