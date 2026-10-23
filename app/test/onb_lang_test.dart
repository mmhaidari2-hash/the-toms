import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:british_life/app/app.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/app/theme.dart';

void main() {
  setUp(() => BL.useGoogleFonts = false);
  testWidgets('onboarding language chip switches instantly', (t) async {
    t.view.physicalSize = const Size(375 * 3, 812 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = const UserProgress().encode())], child: const BritishLifeApp()));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    final hi = find.byKey(const ValueKey('lang-hi'));
    await t.ensureVisible(hi);
    await t.pumpAndSettle();
    await t.tap(hi);
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    final c = t.element(find.byKey(const ValueKey('lang-hi')));
    final ac = c.findAncestorWidgetOfExactType<Padding>();
    debugPrint('PAD key ${ac?.key}');
    expect(find.descendant(of: find.byKey(const ValueKey('lang-hi')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
  });
}
