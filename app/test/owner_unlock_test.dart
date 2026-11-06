import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/preview_flags.dart';
import 'package:british_life/core/security/owner_unlock.dart';
import 'package:british_life/core/security/owner_unlock_hash.dart';
import 'package:british_life/features/map/map_home.dart' show mapRegions, regionOpen;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String? _ownerCode() {
  final env = Platform.environment['NEWLIFE_OWNER_CODE'];
  if (env != null && env.trim().isNotEmpty) return env.trim();
  final f = File('/home/box/keys/owner_unlock_code.txt');
  return f.existsSync() ? f.readAsStringSync().trim() : null;
}

void main() {
  final configuredCode = _ownerCode();
  final secretUnavailable = configuredCode == null
      ? 'Requires optional NEWLIFE_OWNER_CODE; production secrets are not in this checkout.'
      : false;
  test('owner hash constants exist and wrong code fails', () {
    expect(kOwnerUnlockIterations, greaterThanOrEqualTo(200000));
    expect(kOwnerUnlockSaltB64, isNotEmpty);
    expect(kOwnerUnlockHashB64, isNotEmpty);
    expect(OwnerUnlock.verify('definitely-not-the-code'), isFalse);
  });

  test(
    'env/file code activates ownerMode and opens gates; wrong codes rate-limit',
    () {
      final code = configuredCode!;
      expect(code.length, greaterThanOrEqualTo(12));

      final store = MemoryProgressStore()
        ..data = const UserProgress(onboarded: true).encode();
      final container = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final ctrl = container.read(progressProvider.notifier);

      expect(ctrl.state.gatesOpen, isFalse);
      expect(ctrl.tryActivateOwner('nope'), isNotNull);
      expect(ctrl.state.ownerMode, isFalse);

      expect(ctrl.tryActivateOwner(code), isNull);
      expect(ctrl.state.ownerMode, isTrue);
      expect(ctrl.state.gatesOpen, isTrue);
      expect(ctrl.hasPremium, isTrue);

      final before = ctrl.state.completedScenes;
      ctrl.setOwnerMode(false);
      expect(ctrl.state.ownerMode, isFalse);
      expect(ctrl.state.gatesOpen, isFalse);
      expect(ctrl.state.completedScenes, before);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: secretUnavailable,
  );

  test('ownerMode persists in UserProgress encode/decode', () {
    final p = const UserProgress(ownerMode: true, unlockAll: false);
    expect(p.gatesOpen, isTrue);
    final round = UserProgress.decode(p.encode());
    expect(round.ownerMode, isTrue);
    expect(round.gatesOpen, isTrue);
    expect(round.unlockAll, isFalse);
  });

  test('PBKDF2-HMAC-SHA256 matches the published test vector', () {
    // RFC 7914 / common SHA-256 vector: password "password", salt "salt", c=1, dkLen=32.
    final got = OwnerUnlock.pbkdf2Sha256('password', utf8.encode('salt'), 1, 32);
    expect(
      got,
      Uint8List.fromList([
        0x12, 0x0f, 0xb6, 0xcf, 0xfc, 0xf8, 0xb3, 0x2c, 0x43, 0xe7, 0x22, 0x52, 0x56, 0xc4, 0xf8, 0x37,
        0xa8, 0x65, 0x48, 0xc9, 0x2c, 0xcc, 0x35, 0x48, 0x08, 0x05, 0x98, 0x7c, 0xb7, 0x0b, 0xe1, 0x7b,
      ]),
    );
  });

  test('synthetic code opens locked lessons, persists on restart, and leaves other profiles gated', () async {
    expect(kPreviewUnlock, isFalse, reason: 'this test must not depend on PREVIEW_UNLOCK');
    expect(kPreviewAudioBase, isEmpty, reason: 'this test must not depend on PREVIEW_AUDIO_BASE');

    const code = 'synthetic-owner-code-1';
    final hash = OwnerUnlock.pbkdf2Sha256(code, utf8.encode('salt'), 2, 32);
    final material = OwnerUnlockMaterial(
      saltB64: base64Encode(utf8.encode('salt')),
      hashB64: base64Encode(hash),
      iterations: 2,
    );
    expect(OwnerUnlock.verify(code, material: material), isTrue);
    expect(OwnerUnlock.verify('synthetic-owner-code-2', material: material), isFalse);
    expect(OwnerUnlock.verify(code), isFalse, reason: 'synthetic code must not match the baked production hash');
    expect(OwnerUnlock.verify(''), isFalse);
    expect(OwnerUnlock.verify('short'), isFalse);

    final course = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()));
    final locked = course.lessons.elementAt(1);
    final later = mapRegions.firstWhere((r) => r.level == 2);
    var now = DateTime.utc(2026, 11, 6, 12);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final container = ProviderContainer(overrides: [
      progressStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    final ctrl = container.read(progressProvider.notifier);

    expect(ctrl.state.ownerMode, isFalse);
    expect(ctrl.state.unlockAll, isFalse);
    expect(ctrl.state.gatesOpen, isFalse);
    expect(ctrl.lessonOpen(course, locked), isFalse);
    expect(regionOpen(ctrl, course, later), isFalse);
    expect(ctrl.tryActivateOwner('definitely-not-the-code'), 'Incorrect code');
    expect(ctrl.lessonOpen(course, locked), isFalse);

    expect(ctrl.tryActivateOwner(code, material: material), isNull);
    expect(ctrl.state.ownerMode, isTrue);
    expect(ctrl.state.unlockAll, isFalse);
    expect(ctrl.state.gatesOpen, isTrue);
    expect(ctrl.lessonOpen(course, locked), isTrue);
    expect(regionOpen(ctrl, course, later), isTrue);
    final progress = ctrl.state.completedScenes;

    final restarted = ProviderContainer(overrides: [
      progressStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(restarted.dispose);
    final again = restarted.read(progressProvider.notifier);
    expect(again.state.ownerMode, isTrue);
    expect(again.state.unlockAll, isFalse);
    expect(again.lessonOpen(course, locked), isTrue);
    expect(again.state.completedScenes, progress);

    final child = await again.addProfile(displayName: 'Kid', kind: ProfileKind.child);
    await again.switchProfile(child.id);
    expect(again.state.ownerMode, isFalse);
    expect(again.lessonOpen(course, locked), isFalse);
    expect(regionOpen(again, course, later), isFalse);
    await again.switchProfile('adult');
    expect(again.state.ownerMode, isTrue);
    expect(again.lessonOpen(course, locked), isTrue);

    again.setOwnerMode(false);
    expect(again.state.ownerMode, isFalse);
    expect(again.state.gatesOpen, isFalse);
    expect(again.lessonOpen(course, locked), isFalse);
    expect(again.state.completedScenes, progress);

    final fresh = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final ordinaryBox = ProviderContainer(overrides: [
      progressStoreProvider.overrideWithValue(fresh),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(ordinaryBox.dispose);
    final ordinary = ordinaryBox.read(progressProvider.notifier);
    for (var i = 0; i < OwnerUnlock.maxAttempts; i++) {
      expect(ordinary.tryActivateOwner('wrong-code-$i-xxxx'), 'Incorrect code');
    }
    expect(ordinary.tryActivateOwner(code, material: material), contains('Too many attempts'));
    expect(ordinary.state.ownerMode, isFalse);
    expect(ordinary.lessonOpen(course, locked), isFalse);
    now = now.add(const Duration(minutes: 16));
    expect(ordinary.tryActivateOwner(code, material: material), isNull);
    expect(ordinary.state.ownerMode, isTrue);
    expect(ordinary.lessonOpen(course, locked), isTrue);
  });

  test('bundle sources never contain the plain owner code', () {
    final code = configuredCode!;
    final roots = [
      Directory('lib'),
      Directory('assets'),
      Directory('web'),
      Directory('test'),
    ];
    const skipExt = [
      '.png',
      '.webp',
      '.jpg',
      '.jpeg',
      '.gif',
      '.mp3',
      '.ogg',
      '.wav',
      '.ttf',
      '.otf',
      '.woff',
      '.woff2',
      '.bin',
      '.ico',
    ];
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
  }, skip: secretUnavailable);
}
