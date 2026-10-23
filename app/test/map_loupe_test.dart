import 'dart:convert';
import 'dart:io';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/course/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:british_life/features/map/map_loupe.dart';

/// The glass loupe: press-hold-slide over the map magnifies the spot under the finger with its name and level.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  setUpAll(() async {
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = fam == 'Roboto' ? 'Inter' : fam;
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });

  testWidgets('hold and slide: loupe follows, names the spot with its level, release opens it', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress(onboarded: true).encode())], child: const BritishLifeApp()));
    router.go('/');
    for (var i = 0; i < 40 && find.byKey(const ValueKey('spot-home')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(seconds: 1));
    // A visible spot.
    final spot = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('spot-') && !'${(w.key as ValueKey).value}'.startsWith('spot-focus')).hitTestable().first;
    final id = '${(t.widget(spot).key as ValueKey).value}'.substring(5);
    final r = t.getRect(spot);
    final orb = Offset(r.center.dx, r.top + 22);
    final g = await t.startGesture(orb + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(MapLoupe), findsOneWidget, reason: 'lens appears after a short hold');
    await g.moveTo(orb + const Offset(14, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g.moveTo(orb);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('loupe-label')), findsOneWidget, reason: 'spot $id named under the lens');
    final loupe = t.widget<MapLoupe>(find.byType(MapLoupe));
    expect(loupe.title, isNotEmpty);
    expect(loupe.level, isNotNull);
    expect(find.text(loupe.title!), findsWidgets);
    await g.up();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(MapLoupe), findsNothing);
    expect(find.byKey(ValueKey('spot-sheet-$id')).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue, reason: 'letting go on a spot opens it');
    expect(t.takeException(), isNull);
  });
}
