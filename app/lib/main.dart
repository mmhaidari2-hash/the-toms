import 'dart:async';

import 'core/billing/billing.dart';
import 'core/billing/device_allowance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';

import 'package:go_router/go_router.dart';

import 'core/platform/history.dart';
import 'core/platform/voice.dart';
import 'core/data/progress_locked_screen.dart';
import 'core/data/progress_store.dart';
import 'core/data/providers.dart';
import 'core/i18n/helper_text.dart';
import 'core/models/user_progress.dart';
import 'core/observability/sentry_gate.dart';

Future<void> main() async {
  // push() must create real browser-history entries, so browser back / iOS swipe-back pops one screen.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  seedRootHistory();
  WidgetsFlutterBinding.ensureInitialized();
  await SentryGate.init();
  // Fully offline: Inter, Fraunces and Vazirmatn are bundled in assets/google_fonts (OFL).
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Inter',
      'Fraunces',
      'Vazirmatn',
    ], await rootBundle.loadString('assets/google_fonts/OFL.txt'));
  });
  // Sets Entitlements.paidBuild synchronously; the RevenueCat handshake continues in the background.
  unawaited(Billing.init());
  await Voice.load();
  final HiveProgressStore store;
  try {
    store = await HiveProgressStore.open();
  } on ProgressStoreLocked {
    runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: ProgressLockedScreen()));
    return;
  }
  // Activate the saved helper language before the first frame, so screens never flash the wrong language.
  try {
    final raw = store.read();
    if (raw != null) await useHelperLang(UserProgress.decode(raw).lang);
  } catch (_) {}
  // Device-wide, HMAC-signed daily allowance in secure storage (one pool for every profile; see device_allowance.dart).
  final allowance = await DeviceAllowance.load(const SecureAllowanceVault(), now: DateTime.now())
    ..observe(DateTime.now());
  runApp(
    ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store), deviceAllowanceProvider.overrideWithValue(allowance)],
      child: const BritishLifeApp(),
    ),
  );
}
