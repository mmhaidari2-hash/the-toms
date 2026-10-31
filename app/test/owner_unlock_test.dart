import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/security/owner_unlock.dart';
import 'package:british_life/core/security/owner_unlock_hash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner hash constants exist and wrong code fails', () {
    expect(kOwnerUnlockIterations, greaterThanOrEqualTo(200000));
    expect(kOwnerUnlockSaltB64, isNotEmpty);
    expect(kOwnerUnlockHashB64, isNotEmpty);
    expect(OwnerUnlock.verify('definitely-not-the-code'), isFalse);
  });

  test('file code activates ownerMode and opens gates; wrong codes rate-limit', () {
    final path = '/home/box/keys/owner_unlock_code.txt';
    expect(File(path).existsSync(), isTrue, reason: 'owner code file must exist for this test');
    final code = File(path).readAsStringSync().trim();
    expect(code.length, greaterThanOrEqualTo(24));

    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final container = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    final ctrl = container.read(progressProvider.notifier);

    expect(ctrl.state.gatesOpen, isFalse);
    expect(ctrl.tryActivateOwner('nope'), isNotNull);
    expect(ctrl.state.ownerMode, isFalse);

    expect(ctrl.tryActivateOwner(code), isNull);
    expect(ctrl.state.ownerMode, isTrue);
    expect(ctrl.state.gatesOpen, isTrue);
    expect(ctrl.hasPremium, isTrue);

    // Turning owner off restores gates without wiping progress fields
    final before = ctrl.state.completedScenes;
    ctrl.setOwnerMode(false);
    expect(ctrl.state.ownerMode, isFalse);
    expect(ctrl.state.gatesOpen, isFalse);
    expect(ctrl.state.completedScenes, before);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('ownerMode persists in UserProgress encode/decode', () {
    final p = const UserProgress(ownerMode: true, unlockAll: false);
    expect(p.gatesOpen, isTrue);
    final round = UserProgress.decode(p.encode());
    expect(round.ownerMode, isTrue);
    expect(round.gatesOpen, isTrue);
    expect(round.unlockAll, isFalse);
  });

  test('bundle sources never contain the plain owner code', () {
    final path = '/home/box/keys/owner_unlock_code.txt';
    if (!File(path).existsSync()) return;
    final code = File(path).readAsStringSync().trim();
    final roots = [Directory('lib'), Directory('assets'), Directory('web'), Directory('test')];
    const skipExt = ['.png', '.webp', '.jpg', '.jpeg', '.gif', '.mp3', '.ogg', '.wav', '.ttf', '.otf', '.woff', '.woff2', '.bin', '.ico'];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final f in root.listSync(recursive: true).whereType<File>()) {
        final name = f.path.toLowerCase();
        if (skipExt.any(name.endsWith)) continue;
        String text;
        try {
          text = f.readAsStringSync();
        } catch (_) {
          continue;
        }
        expect(text.contains(code), isFalse, reason: f.path);
      }
    }
  });
}
