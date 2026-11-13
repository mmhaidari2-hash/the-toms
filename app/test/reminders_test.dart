import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/billing/entitlements.dart';
import 'package:british_life/core/billing/trial_reminder.dart';
import 'package:british_life/core/platform/native_reminders.dart';
import 'package:british_life/core/platform/remind.dart';
import 'package:flutter/material.dart';
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
  @override
  Future<void> scheduleAt(int id, DateTime when, {required String title, required String body}) async =>
      log.add('at $id ${when.toIso8601String()} $title $body');
  @override
  Future<void> cancelId(int id) async => log.add('cancelId $id');
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  tearDown(() async {
    await NativeReminders.debugUse(null);
    TrialReminder.debugReset();
    Entitlements.paidBuild = false;
    Entitlements.applyServerState(premium: false, packs: {});
  });

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

  group('yearly trial reminder', () {
    final now = DateTime(2026, 11, 13, 12);
    final ends = DateTime(2026, 11, 20, 12); // 7-day trial
    final remindAt = DateTime(2026, 11, 18, 12);

    Future<void> paidTrial({required FakeReminders fake, DateTime? trialEndsAt, bool premium = true}) async {
      await NativeReminders.debugUse(fake);
      TrialReminder.betaFree = () => false;
      TrialReminder.clock = () => now;
      Entitlements.paidBuild = true;
      Entitlements.applyServerState(premium: premium, packs: {}, trialEndsAt: trialEndsAt);
      await TrialReminder.sync();
    }

    test('betaFree leaves the reminder inactive even if a trial date is present', () async {
      final f = FakeReminders(allowed: true);
      await NativeReminders.debugUse(f);
      TrialReminder.clock = () => now;
      Entitlements.paidBuild = true;
      Entitlements.applyServerState(premium: true, packs: {}, trialEndsAt: ends);
      await TrialReminder.sync();
      expect(f.log.where((l) => l.startsWith('at')), isEmpty);
      expect(TrialReminder.showBanner.value, isFalse);
    });

    test('schedules a local notification two days before trial end with EN+FA copy', () async {
      final f = FakeReminders(allowed: true);
      await paidTrial(fake: f, trialEndsAt: ends);
      expect(
        f.log.where((l) => l.startsWith('at ${TrialReminder.notificationId}')),
        isNotEmpty,
      );
      expect(f.log.last, contains(remindAt.toIso8601String()));
      expect(f.log.last, contains('Your yearly Premium trial ends in 2 days'));
      expect(f.log.last, contains('دورهٔ رایگان اشتراک سالانه'));
      expect(TrialReminder.showBanner.value, isFalse);
      expect(trialReminderBody, contains('Google Play'));
      expect(trialReminderBody, contains('گوگل‌پلی'));
    });

    test('cancels the notification when the user converts or cancels the trial', () async {
      final f = FakeReminders(allowed: true);
      await paidTrial(fake: f, trialEndsAt: ends);
      Entitlements.applyServerState(premium: true, packs: {}, trialEndsAt: null);
      await TrialReminder.sync();
      expect(f.log.last, 'cancelId ${TrialReminder.notificationId}');
      expect(TrialReminder.showBanner.value, isFalse);
      Entitlements.applyServerState(premium: false, packs: {}, trialEndsAt: ends);
      await TrialReminder.sync();
      expect(f.log.last, 'cancelId ${TrialReminder.notificationId}');
    });

    test('denied notifications are not scheduled; a banner is shown in the 2-day window', () async {
      final f = FakeReminders(allowed: false, grantOnRequest: false);
      await NativeReminders.debugUse(f);
      TrialReminder.betaFree = () => false;
      TrialReminder.clock = () => DateTime(2026, 11, 18, 12);
      Entitlements.paidBuild = true;
      Entitlements.applyServerState(premium: true, packs: {}, trialEndsAt: ends);
      await TrialReminder.sync();
      expect(f.log.where((l) => l.startsWith('at')), isEmpty);
      expect(TrialReminder.showBanner.value, isTrue);
    });

    testWidgets('in-app banner is visible and can be dismissed', (tester) async {
      final f = FakeReminders(allowed: false);
      await NativeReminders.debugUse(f);
      TrialReminder.betaFree = () => false;
      TrialReminder.clock = () => DateTime(2026, 11, 19, 12);
      Entitlements.paidBuild = true;
      Entitlements.applyServerState(premium: true, packs: {}, trialEndsAt: ends);
      await TrialReminder.sync();
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(width: 400, height: 800, child: TrialReminderScope(child: Text('home'))),
        ),
      );
      expect(find.byKey(const ValueKey('trial-reminder-banner')), findsOneWidget);
      expect(find.textContaining('Your yearly Premium trial ends in 2 days'), findsOneWidget);
      expect(find.textContaining('دورهٔ رایگان'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trial-reminder-dismiss')));
      await tester.pump();
      expect(find.byKey(const ValueKey('trial-reminder-banner')), findsNothing);
      expect(TrialReminder.showBanner.value, isFalse);
    });
  });
}
