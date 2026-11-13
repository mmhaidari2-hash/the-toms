import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/billing/offline_voices.dart';
import '../core/billing/trial_reminder.dart';
import '../core/data/providers.dart';
import '../features/library/library_data.dart';
import '../core/i18n/helper_text.dart';
import '../core/models/user_progress.dart';

import '../core/platform/remind.dart' show startReminders, syncReminder;
import '../core/platform/retry_bundle.dart';
import '../core/platform/speech_result.dart';
import '../features/speaking/speaking_widgets.dart' show showMicRationale;
import '../features/leitner/leitner_add.dart';
import '../features/shared/voice_feedback.dart';
import 'route_guard.dart';
import 'router.dart';
import '../features/feedback/feedback_screen.dart';
import 'theme.dart';

class BritishLifeApp extends StatelessWidget {
  const BritishLifeApp({super.key});
  static final bundle = RetryAssetBundle();
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'New Life UK',
    debugShowCheckedModeBanner: false,
    theme: BL.theme(),
    routerConfig: router,
    builder: (context, child) => DefaultAssetBundle(
      bundle: bundle,
      child: ColoredBox(
        color: const Color(0xFFE9E2D6),
        // Keep a phone-width column on tablets/desktop browsers.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: RepaintBoundary(
              key: screenBoundaryKey,
              child: HelperLangScope(
                child: VoiceFeedback(
                  child: LeitnerSelect(
                    child: TrialReminderScope(
                      child: kPreviewUnlock
                          ? Banner(
                              message: 'PREVIEW',
                              location: BannerLocation.topEnd,
                              color: const Color(0xFF1F3A5F),
                              child: child ?? const SizedBox(),
                            )
                          : child ?? const SizedBox(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Keeps the helper-language table in step with the learner's choice. Switching language loads that table, then
/// rebuilds every widget in place (state and the current screen are kept), since every Text passes through hl().
class HelperLangScope extends ConsumerStatefulWidget {
  final Widget child;
  const HelperLangScope({super.key, required this.child});
  @override
  ConsumerState<HelperLangScope> createState() => _HelperLangScopeState();
}

class _HelperLangScopeState extends ConsumerState<HelperLangScope> {
  String? _want;

  @override
  void initState() {
    super.initState();
    // Offline voices (Premium): read live per clip so a purchase/restore applies at once (see OfflineVoices).
    OfflineVoices.allowed = () => mounted
        ? ref.read(progressProvider.notifier).offlineVoicesUnlocked
        : false;
    // Android daily reminder (t306): local notification, rescheduled on every start for the active profile.
    startReminders().then((_) async {
      if (!mounted) return;
      final c = ref.read(progressProvider.notifier);
      syncReminder(on: c.reminderOn, hhmm: c.reminderTime);
      await TrialReminder.sync();
    });
    // Android speech recognition (t306): explain before the system microphone prompt.
    SpeechHooks.rationale = () async {
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      return ctx == null ? false : showMicRationale(ctx);
    };
    // Central route guard (every navigation and deep link) with live progress and content.
    RouteGuard.check = (uri) => mounted
        ? guardLocation(
            uri,
            ref.read(progressProvider.notifier),
            ref.read(contentProvider).value?.course,
            books: ref.read(libraryProvider).value,
          )
        : null;
  }

  void _rebuildAll(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_rebuildAll);
  }

  Future<void> _switch(String code) async {
    _want = code;
    await useHelperLang(code);
    if (!mounted || _want != code) return;
    setState(() {});
    (context as Element).visitChildren(_rebuildAll);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(progressProvider.select((p) => p.lang));
    if (lang != helperLang && lang != _want) {
      if (isHelperLoaded(lang)) {
        useHelperLang(lang);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) (context as Element).visitChildren(_rebuildAll);
        });
      } else {
        _switch(lang);
      }
    }
    return widget.child;
  }
}
