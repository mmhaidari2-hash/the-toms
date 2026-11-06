import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('leaving a chat does not mark the audio notice dirty during dispose', (t) async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true).encode();
    await t.pumpWidget(ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: const BritishLifeApp(),
    ));
    router.go('/chat/nicola_park');
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    router.go('/');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });
}
