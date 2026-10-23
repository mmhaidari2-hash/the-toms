import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'package:go_router/go_router.dart';

import 'core/platform/history.dart';
import 'core/platform/voice.dart';
import 'core/data/progress_store.dart';
import 'core/data/providers.dart';
import 'core/i18n/helper_text.dart';
import 'core/models/user_progress.dart';

Future<void> main() async {
  // push() must create real browser-history entries, so browser back / iOS swipe-back pops one screen.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  seedRootHistory();
  WidgetsFlutterBinding.ensureInitialized();
  // Fully offline: Inter, Fraunces and Vazirmatn are bundled in assets/google_fonts (OFL).
  GoogleFonts.config.allowRuntimeFetching = false;
  await Voice.load();
  final store = await HiveProgressStore.open();
  // Activate the saved helper language before the first frame, so screens never flash the wrong language.
  try {
    final raw = store.read();
    if (raw != null) await useHelperLang(UserProgress.decode(raw).lang);
  } catch (_) {}
  runApp(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
}
