import 'native_reminders.dart';

/// Non-web builds: Android uses local notifications (owner t306 item 3); other platforms report 'unsupported'.
Future<String> requestNotifications() => NativeReminders.request();
String notificationStatus() => NativeReminders.status;
Future<bool> showNotification(String title, String body) => NativeReminders.showNow();
bool downloadFile(String name, String mime, String text) => false;

/// Keeps the scheduled daily reminder in step with the active profile's setting.
Future<bool> syncReminder({required bool on, required String hhmm}) => NativeReminders.sync(on: on, hhmm: hhmm);

/// Start-up hook (Android): set up the notification plugin and the local time zone.
Future<void> startReminders() => NativeReminders.start();
