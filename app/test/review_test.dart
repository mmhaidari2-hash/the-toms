import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/grammar/review_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mixed review per class (Q43): interleaves practice items from passed topics only.
void main() {
  final all = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
  test('review mixes every passed topic and uses practice items only', () {
    final a1 = all.where((t) => t.level == 'A1').take(3).toList();
    final items = reviewItems(a1, 1);
    expect(items.length, reviewSize);
    for (final t in a1) {
      expect(items.where((it) => t.practice.contains(it)).length, greaterThanOrEqualTo(3), reason: t.id);
    }
    final tests = {for (final t in a1) ...t.test};
    expect(items.where(tests.contains), isEmpty);
  });

  setUp(() => BL.useGoogleFonts = false);
  setUpAll(() async {
    for (final (fam, file) in [('Roboto', 'Inter'), ('Inter', 'Inter'), ('Fraunces', 'Fraunces'), ('Vazirmatn', 'Vazirmatn')]) {
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });

  testWidgets('class card shows Mixed review after two passes and the screen opens', (t) async {
    t.view.physicalSize = const Size(375, 667) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99', 'gram:a1_be': '80', 'gram:a1_this': '100'}).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    Future<void> settle() async {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(t.takeException(), isNull);
    }

    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/school/A1');
    await settle();
    await t.scrollUntilVisible(find.byKey(const ValueKey('class-review-A1')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('class-review-A1')), findsOneWidget);
    router.go('/school/A1/review');
    await settle();
    expect(find.byKey(const ValueKey('review-stage')), findsOneWidget);
    expect(find.textContaining('1/$reviewSize'), findsOneWidget);
    router.go('/school/A2/review');
    await settle();
    expect(find.byKey(const ValueKey('review-locked')), findsOneWidget);
    router.go('/');
    await t.pump(const Duration(seconds: 2));
  });
}
