import 'dart:io';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/features/motivation/motivation_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    BL.useGoogleFonts = false;
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = {'Roboto': 'Inter', 'Inter': 'Inter', 'Fraunces': 'Fraunces', 'Vazirmatn': 'Vazirmatn'}[fam]!;
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
    final m = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('build/web/assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await m.load();
  });
  testWidgets('celebration with next lesson (screenshot)', (t) async {
    t.view.physicalSize = const Size(576, 1024) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    Celebration.autoAdvance = true;
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(fontFamily: 'Inter'), home: Scaffold(backgroundColor: BL.cream, body: Celebration(award: const XpAward(xp: 15, total: 40, today: 15, goal: 20, streak: 1, streakUp: true), pass: true, checkpoint: false, right: 9, total: 10, onContinue: () {}, onNext: () {}))));
    await t.pump(const Duration(milliseconds: 1500));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('/tmp/gold/celebrate_next.png'));
    await t.pump(const Duration(seconds: 3));
  });
}
