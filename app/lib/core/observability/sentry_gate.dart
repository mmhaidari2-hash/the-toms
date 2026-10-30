/// Sentry integration gate. Off unless a DSN is provided at build/run time.
///
/// Pass `--dart-define=SENTRY_DSN=https://...@...` to enable. When unset or empty,
/// [init] is a no-op and nothing is sent.
///
/// Dependency on `sentry_flutter` is optional: add it to pubspec when you are ready
/// to ship crash reporting; this file stays compile-safe without it.
class SentryGate {
  static const dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static bool get enabled => dsn.isNotEmpty;

  /// Call from main() after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> init() async {
    if (!enabled) return;
    // When sentry_flutter is added:
    // await SentryFlutter.init((o) { o.dsn = dsn; o.tracesSampleRate = 0.1; }, appRunner: () {});
    // For now we only record that a DSN was supplied (no network).
    assert(() {
      // ignore: avoid_print
      print('SentryGate: DSN present — add sentry_flutter to activate reporting.');
      return true;
    }());
  }
}
