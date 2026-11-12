/// App identity shown in Legal → About and in feedback reports. A test keeps [version] equal to pubspec.yaml.
abstract final class AppInfo {
  static const version = '1.1.0';
  static const build = 5;
  static String get label => '$version ($build)';
}

/// Support contact for the feedback & bug-report box (owner t308).
abstract final class SupportConfig {
  /// TODO_OWNER_SUPPORT_EMAIL: the owner must put a real, monitored support address here before release.
  /// While it is the placeholder (or not an email address) the send button says "not configured yet".
  static const String email = 'TODO_OWNER_SUPPORT_EMAIL';

  static bool get configured => isConfigured(email);
  static bool isConfigured(String e) => !e.startsWith('TODO') && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
}
