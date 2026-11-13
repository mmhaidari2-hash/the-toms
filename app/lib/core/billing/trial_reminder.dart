import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/premium.dart';
import '../platform/native_reminders.dart';
import 'entitlements.dart';

/// One-shot local reminder two days before a yearly 7-day trial ends (Option B).
///
/// Inactive while [PremiumConfig.betaFree] is true. Uses the existing
/// [flutter_local_notifications] plugin and the already-declared
/// POST_NOTIFICATIONS permission; it does not request a new permission or an
/// exact-alarm permission. If notifications are not granted (or the platform
/// cannot schedule, including web), [showBanner] drives an in-app banner
/// fallback during the same two-day window.
const trialReminderTitle = 'New Life UK';
const trialReminderBody =
    'Your yearly Premium trial ends in 2 days. Cancel in Google Play if you do not want to be charged. · دورهٔ رایگان اشتراک سالانه تا دو روز دیگر تمام می‌شود. اگر نمی‌خواهید هزینه گرفته شود، در گوگل‌پلی لغوش کنید.';

abstract final class TrialReminder {
  /// Distinct from the daily reminder (7001) and its immediate preview (7002).
  static const notificationId = 7003;
  static const lead = Duration(days: 2);

  /// Overridable so focused tests can exercise the paid-build path without flipping the shipped flag.
  static bool Function() betaFree = () => PremiumConfig.betaFree;
  static DateTime Function() clock = DateTime.now;

  static final ValueNotifier<bool> showBanner = ValueNotifier(false);
  static DateTime? _dismissedFor;

  @visibleForTesting
  static void debugReset() {
    betaFree = () => PremiumConfig.betaFree;
    clock = DateTime.now;
    showBanner.value = false;
    _dismissedFor = null;
  }

  static void dismissBanner() {
    _dismissedFor = Entitlements.trialEndsAt;
    showBanner.value = false;
  }

  /// Schedule, cancel, or reveal the in-app banner to match current entitlements.
  static Future<void> sync() async {
    if (betaFree() || !Entitlements.paidBuild) {
      await NativeReminders.cancelId(notificationId);
      showBanner.value = false;
      return;
    }
    final ends = Entitlements.trialEndsAt;
    if (ends == null) {
      await NativeReminders.cancelId(notificationId);
      showBanner.value = false;
      return;
    }
    final now = clock();
    final when = ends.subtract(lead);
    final inWindow = !now.isBefore(when) && !now.isAfter(ends);
    var scheduled = false;
    if (when.isAfter(now)) {
      scheduled = await NativeReminders.scheduleAt(
        id: notificationId,
        when: when,
        title: trialReminderTitle,
        body: trialReminderBody,
      );
    } else {
      await NativeReminders.cancelId(notificationId);
    }
    final dismissed = _dismissedFor != null && _dismissedFor == ends;
    // Banner is the fallback when a notification could not be scheduled (denied
    // or unsupported) and the two-day window has started.
    showBanner.value = inWindow && !scheduled && !dismissed;
  }
}

/// Wraps [child] with a bilingual trial-end banner when [TrialReminder.showBanner] is true.
class TrialReminderScope extends StatelessWidget {
  final Widget child;
  const TrialReminderScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TrialReminder.showBanner,
      builder: (context, show, _) {
        if (!show) return child;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: const Color(0xFF1F3A5F),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          trialReminderBody,
                          key: ValueKey('trial-reminder-banner'),
                          style: TextStyle(color: Colors.white, height: 1.35, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('trial-reminder-dismiss'),
                        tooltip: 'Dismiss · بستن',
                        onPressed: TrialReminder.dismissBanner,
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
