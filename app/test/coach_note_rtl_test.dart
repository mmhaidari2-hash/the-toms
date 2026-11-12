import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:british_life/features/speaking/speaking_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA 2026-11-12: the Pronunciation coach AI note rendered English + Persian in ONE left-to-right Text,
/// so the Persian line's punctuation flipped (". متن مرورگر" at the wrong end). The helper line is now its own RTL Text.
void main() {
  setUp(() => BL.useGoogleFonts = false);
  testWidgets('coach AI note: helper line is a separate right-to-left Text', (t) async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
    for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 100));
    }
    router.go('/coach');
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(seconds: 2));
    for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 200));
    }
    final note = find.byKey(const ValueKey('ai-coach-note-helper'), skipOffstage: false);
    expect(note, findsOneWidget);
    final txt = t.widget<Text>(note);
    expect(txt.textDirection, TextDirection.rtl);
    expect(txt.data, coachAiNote().$2);
    // The English line no longer carries the Persian text.
    expect(find.textContaining('${coachAiNote().$1}\n', skipOffstage: false), findsNothing);
    expect(t.takeException(), isNull);
    router.go('/');
    await t.pump(const Duration(seconds: 1));
  });
}
