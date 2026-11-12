import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/native_reminders.dart';
import 'package:british_life/core/platform/remind.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner t306 item 3: opt-in local daily reminder on Android. No server, no FCM.
class FakeReminders implements ReminderBackend {
  bool allowed;
  bool grantOnRequest;
  int requests = 0;
  final log = <String>[];
  FakeReminders({this.allowed = false, this.grantOnRequest = true});
  @override
  Future<void> init() async => log.add('init');
  @override
  Future<bool> enabled() async => allowed;
  @override
  Future<bool> request() async {
    requests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async => log.add('daily $hour:${minute.toString().padLeft(2, '0')}');
  @override
  Future<void> cancel() async => log.add('cancel');
  @override
  Future<void> showNow() async => log.add('show');
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  tearDown(() => NativeReminders.debugUse(null));

  ProgressController ctrl() {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final c = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    return c.read(progressProvider.notifier);
  }

  test('off by default; turning it on asks for POST_NOTIFICATIONS, then schedules one daily local reminder', () async {
    final f = FakeReminders();
    await NativeReminders.debugUse(f);
    final c = ctrl();
    expect(c.reminderOn, isFalse);
    expect(notificationStatus(), 'default');
    expect(await requestNotifications(), 'granted');
    expect(f.requests, 1);
    c.setReminder('08:30', true);
    await settle();
    expect(f.log.last, 'daily 8:30');
    c.setReminder('08:30', false);
    await settle();
    expect(f.log.last, 'cancel');
  });

  test('blocked notifications: nothing is scheduled and the status says so', () async {
    final f = FakeReminders(grantOnRequest: false);
    await NativeReminders.debugUse(f);
    expect(await requestNotifications(), 'denied');
    final c = ctrl();
    c.setReminder('19:00', true);
    await settle();
    expect(f.log.where((l) => l.startsWith('daily')), isEmpty);
    expect(await showNotification('x', 'y'), isFalse);
  });

  test('child profiles start with the reminder off; switching profile reschedules for that profile', () async {
    final f = FakeReminders(allowed: true);
    await NativeReminders.debugUse(f);
    final c = ctrl();
    c.setReminder('18:00', true);
    await settle();
    expect(f.log.last, 'daily 18:00');
    final kid = await c.addProfile(displayName: 'Kid', kind: ProfileKind.child);
    await c.switchProfile(kid.id);
    await settle();
    expect(c.kidMode, isTrue);
    expect(c.reminderOn, isFalse);
    expect(f.log.last, 'cancel', reason: 'the child profile has no reminder unless turned on');
  });

  test('other platforms (tests, desktop) stay unsupported and schedule nothing', () async {
    expect(notificationStatus(), 'unsupported');
    expect(await syncReminder(on: true, hhmm: '07:00'), isFalse);
  });

  test('reminder text is EN+FA and never names anyone', () {
    expect(reminderBody, contains('Time for today'));
    expect(reminderBody, contains('وقت انگلیسی'));
    expect(reminderTitle, 'New Life UK');
  });

  test('manifest and build: POST_NOTIFICATIONS only; no vibration, boot or exact-alarm permission; desugaring on', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>'));
    expect(m, contains('android.permission.VIBRATE" tools:node="remove"'));
    for (final p in ['RECEIVE_BOOT_COMPLETED', 'SCHEDULE_EXACT_ALARM', 'USE_EXACT_ALARM', 'WAKE_LOCK']) {
      expect(m, isNot(contains('android.permission.$p"/>')), reason: p);
    }
    expect(m, contains('ScheduledNotificationReceiver'));
    expect(m, isNot(contains('ScheduledNotificationBootReceiver')));
    expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('isCoreLibraryDesugaringEnabled = true'));
  });
}
