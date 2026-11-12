import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The daily reminder text (EN+FA). It never names a learner or a child.
const reminderTitle = 'New Life UK';
const reminderBody = 'Time for today’s English — five minutes keeps your streak going. · وقت انگلیسی امروز است — پنج دقیقه کافی است.';

/// Local notification backend behind a seam so tests can fake it.
abstract class ReminderBackend {
  Future<void> init();
  Future<bool> enabled();
  Future<bool> request();
  Future<void> scheduleDaily(int hour, int minute);
  Future<void> cancel();
  Future<void> showNow();
}

/// flutter_local_notifications on Android. Local only: no server, no FCM, no account. Inexact daily alarm, so no
/// exact-alarm permission; no vibration (VIBRATE is removed from the manifest); no boot receiver (the reminder is
/// rescheduled every time the app starts).
class PluginReminderBackend implements ReminderBackend {
  final _p = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? get _android => _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  static const _id = 7001;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Daily reminder',
      channelDescription: 'One reminder a day to practise English (you choose the time).',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(reminderBody),
    ),
  );

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/London'));
    }
    await _p.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  }

  @override
  Future<bool> enabled() async => await _android?.areNotificationsEnabled() ?? false;
  @override
  Future<bool> request() async => await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _p.zonedSchedule(
      id: _id,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: reminderTitle,
      body: reminderBody,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() => _p.cancel(id: _id);
  @override
  Future<void> showNow() => _p.show(id: _id + 1, title: reminderTitle, body: reminderBody, notificationDetails: _details);
}

/// Daily reminder notifications for the installed Android app (owner t306 item 3). Opt-in (off by default for every
/// profile, child profiles included); POST_NOTIFICATIONS is asked at runtime on Android 13+ only when the learner
/// turns the reminder on or taps "Allow notifications".
abstract final class NativeReminders {
  static ReminderBackend? _backend;
  static String _status = 'unsupported';
  static String get status => _status;

  @visibleForTesting
  static Future<void> debugUse(ReminderBackend? b) async {
    _backend = b;
    _status = 'unsupported';
    if (b != null) await _start(b);
  }

  /// Called once at app start. Non-Android platforms stay 'unsupported'.
  static Future<void> start() async {
    if (_backend != null || !Platform.isAndroid) return;
    await _start(PluginReminderBackend());
  }

  static Future<void> _start(ReminderBackend b) async {
    try {
      await b.init();
      _backend = b;
      _status = await b.enabled() ? 'granted' : 'default';
    } catch (_) {
      _backend = null;
      _status = 'unsupported';
    }
  }

  static Future<String> request() async {
    final b = _backend;
    if (b == null) return 'unsupported';
    try {
      _status = (await b.enabled() || await b.request()) ? 'granted' : 'denied';
    } catch (_) {
      _status = 'denied';
    }
    return _status;
  }

  /// Schedules (or cancels) the one daily reminder to match the active profile's setting.
  static Future<bool> sync({required bool on, required String hhmm}) async {
    final b = _backend;
    if (b == null) return false;
    try {
      await b.cancel();
      if (!on || _status != 'granted') return false;
      final p = hhmm.split(':');
      await b.scheduleDaily(int.parse(p[0]), int.parse(p[1]));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showNow() async {
    final b = _backend;
    if (b == null || _status != 'granted') return false;
    try {
      await b.showNow();
      return true;
    } catch (_) {
      return false;
    }
  }
}
