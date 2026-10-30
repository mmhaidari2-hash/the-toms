import 'dart:io';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: startup + route fade must not throw "RenderBox was not laid out".
void main() {
  setUp(() => BL.useGoogleFonts = false);
  setUpAll(() async {
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = {'Roboto': 'Inter', 'Inter': 'Inter', 'Fraunces': 'Fraunces', 'Vazirmatn': 'Vazirmatn'}[fam]!;
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });

  testWidgets('startup and two fades leave no layout exception', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()
      ..data = const UserProgress(onboarded: true, startTier: 1, lang: 'en', unlockAll: true).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    router.go('/family');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    router.go('/course?level=1');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });
}
