
import 'dart:io';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('diag routes', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, startTier: 1, lang: 'fa', unlockAll: true).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40; i++) { await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200))); await t.pump(const Duration(milliseconds: 100)); }
    const routes = ['/','/family','/course?level=1','/lesson/l1_u1_1','/practice/l1_u1_1','/school','/school/A1','/school/B1','/school/C1','/library','/cinema','/lifeuk','/park','/messages','/driving','/theory','/seasons','/missions','/radio','/progress','/leitner','/diary','/legal?tab=privacy','/place/kitchen','/place/nursery','/place/homes','/howto','/plan','/place/hospital','/place/museum','/place/cinema','/place/viewing','/mistakes','/settings','/glossary'];
    for (final r in routes) {
      router.go(r);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 8; i++) await t.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 20 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
        await t.pump(const Duration(milliseconds: 200));
      }
      final err = t.takeException();
      debugPrint('ROUTE $r => ${err ?? "ok"}');
    }
  });
}
