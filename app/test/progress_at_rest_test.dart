import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_locked_screen.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _ThrowingKeys implements ProgressKeyStore {
  int writes = 0;

  @override
  Future<String?> readKey() async => throw PlatformException(code: 'keystore_unavailable');

  @override
  Future<void> writeKey(String next) async => writes += 1;
}

class _MemoryKeys implements ProgressKeyStore {
  String? value;
  int writes = 0;

  @override
  Future<String?> readKey() async => value;

  @override
  Future<void> writeKey(String next) async {
    writes += 1;
    value = next;
  }
}

String _key(int seed) => base64Encode(List<int>.generate(32, (i) => (seed + i) & 0xff));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nluk-progress-');
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('wrong key leaves the encrypted file and the stored key unchanged', () async {
    Hive.init(dir.path);
    final original = _key(1);
    final box = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(original)), crashRecovery: false);
    await box.put('p:child_legacy', 'CHILD_PROGRESS_MARKER');
    await box.close();
    final before = await File('${dir.path}/progress.hive').readAsBytes();
    final keys = _MemoryKeys()..value = _key(9);

    await expectLater(
      HiveProgressStore.openAt(dir.path, keys: keys),
      throwsA(isA<ProgressStoreLocked>()),
    );

    final after = await File('${dir.path}/progress.hive').readAsBytes();
    expect(after, before);
    expect(keys.value, _key(9));
    expect(keys.writes, 0);
    expect(File('${dir.path}/progress.hive.kept').existsSync(), isFalse);

    final again = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(original)), crashRecovery: false);
    expect(again.get('p:child_legacy'), 'CHILD_PROGRESS_MARKER');
    await again.close();
  });

  test('missing key does not replace an existing encrypted box', () async {
    Hive.init(dir.path);
    final original = _key(4);
    final box = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(original)), crashRecovery: false);
    await box.put('meta', '{"active":"adult"}');
    await box.close();
    final before = await File('${dir.path}/progress.hive').readAsBytes();
    final keys = _MemoryKeys();

    await expectLater(HiveProgressStore.openAt(dir.path, keys: keys), throwsA(isA<ProgressStoreLocked>()));

    expect(await File('${dir.path}/progress.hive').readAsBytes(), before);
    expect(keys.value, isNull);
    expect(keys.writes, 0);
  });

  test('legacy plaintext box migrates and stays readable with the same key', () async {
    Hive.init(dir.path);
    final plain = await Hive.openBox<String>('progress', crashRecovery: false);
    final meta = jsonEncode({
      'active': 'child_legacy',
      'profiles': [
        LearnerProfile(id: 'adult', displayName: 'Me', kind: ProfileKind.adult, createdAt: DateTime.utc(2020, 1, 1)).toJson(),
        LearnerProfile(id: 'child_legacy', displayName: 'Sara', kind: ProfileKind.child, createdAt: DateTime.utc(2020, 2, 2)).toJson(),
      ],
    });
    await plain.put('meta', meta);
    await plain.put('p:child_legacy', 'CHILD_PROGRESS_MARKER');
    await plain.close();
    final keys = _MemoryKeys();

    final store = await HiveProgressStore.openAt(dir.path, keys: keys);
    expect(store.readOf('child_legacy'), 'CHILD_PROGRESS_MARKER');
    expect(store.activeProfile()?.id, 'child_legacy');
    expect(store.activeProfile()?.isChild, isTrue);
    expect(keys.writes, 1);
    final stored = keys.value;
    await store.box.close();

    final bytes = await File('${dir.path}/progress.hive').readAsBytes();
    expect(String.fromCharCodes(bytes).contains('CHILD_PROGRESS_MARKER'), isFalse);
    expect(File('${dir.path}/progress.hive.kept').existsSync(), isFalse);

    final again = await HiveProgressStore.openAt(dir.path, keys: keys);
    expect(again.readOf('child_legacy'), 'CHILD_PROGRESS_MARKER');
    expect(keys.value, stored);
    expect(keys.writes, 1);
    await again.box.close();
  });

  test('a kept plaintext copy is restored when the hive file is missing', () async {
    Hive.init(dir.path);
    final plain = await Hive.openBox<String>('progress', crashRecovery: false);
    await plain.put('p:adult', 'KEPT_MARKER');
    await plain.close();
    await File('${dir.path}/progress.hive').copy('${dir.path}/progress.hive.kept');
    await File('${dir.path}/progress.hive').delete();
    final keys = _MemoryKeys();

    final store = await HiveProgressStore.openAt(dir.path, keys: keys);
    expect(store.read(), 'KEPT_MARKER');
    expect(File('${dir.path}/progress.hive.kept').existsSync(), isFalse);
    await store.box.close();
  });

  test('a nonempty partial encrypted box keeps every legacy entry from .kept', () async {
    Hive.init(dir.path);
    final plain = await Hive.openBox<String>('progress', crashRecovery: false);
    await plain.put('p:adult', 'ADULT_MARKER');
    await plain.put('p:child_legacy', 'CHILD_PROGRESS_MARKER');
    await plain.close();
    await File('${dir.path}/progress.hive').copy('${dir.path}/progress.hive.kept');
    await File('${dir.path}/progress.hive').delete();
    final key = _key(8);
    final partial = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(key)), crashRecovery: false);
    await partial.put('p:adult', 'ADULT_MARKER');
    await partial.close();
    expect(partial.isOpen, isFalse);
    final keys = _MemoryKeys()..value = key;
    final keptBefore = await File('${dir.path}/progress.hive.kept').readAsBytes();

    final store = await HiveProgressStore.openAt(dir.path, keys: keys);

    expect(store.readOf('adult'), 'ADULT_MARKER');
    expect(store.readOf('child_legacy'), 'CHILD_PROGRESS_MARKER');
    expect(keys.value, key);
    expect(keys.writes, 0);
    expect(File('${dir.path}/progress.hive.kept').existsSync(), isFalse);
    await store.box.close();

    final again = await HiveProgressStore.openAt(dir.path, keys: keys);
    expect(again.readOf('child_legacy'), 'CHILD_PROGRESS_MARKER');
    expect(keys.writes, 0);
    await again.box.close();
    expect(keptBefore, isNotEmpty);
  });

  test('a finished encrypted box plus a leftover .kept drops only the copy', () async {
    Hive.init(dir.path);
    final key = _key(11);
    final plain = await Hive.openBox<String>('progress', crashRecovery: false);
    await plain.put('p:adult', 'ADULT_MARKER');
    await plain.put('p:child_legacy', 'CHILD_PROGRESS_MARKER');
    await plain.put('empty_note', '');
    await plain.close();
    await File('${dir.path}/progress.hive').copy('${dir.path}/progress.hive.kept');
    await File('${dir.path}/progress.hive').delete();
    final done = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(key)), crashRecovery: false);
    await done.put('p:adult', 'ADULT_MARKER');
    await done.put('p:child_legacy', 'CHILD_PROGRESS_MARKER');
    await done.close();
    final keys = _MemoryKeys()..value = key;

    final store = await HiveProgressStore.openAt(dir.path, keys: keys);

    expect(store.readOf('adult'), 'ADULT_MARKER');
    expect(store.readOf('child_legacy'), 'CHILD_PROGRESS_MARKER');
    expect(keys.writes, 0);
    expect(File('${dir.path}/progress.hive.kept').existsSync(), isFalse);
    await store.box.close();
  });

  test('readKey platform exception locks without changing either file', () async {
    Hive.init(dir.path);
    final key = _key(12);
    final box = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(key)), crashRecovery: false);
    await box.put('p:child_legacy', 'CHILD_PROGRESS_MARKER');
    await box.close();
    await File('${dir.path}/progress.hive').copy('${dir.path}/progress.hive.kept');
    final before = await File('${dir.path}/progress.hive').readAsBytes();
    final keptBefore = await File('${dir.path}/progress.hive.kept').readAsBytes();
    final keys = _ThrowingKeys();

    await expectLater(HiveProgressStore.openAt(dir.path, keys: keys), throwsA(isA<ProgressStoreLocked>()));

    expect(await File('${dir.path}/progress.hive').readAsBytes(), before);
    expect(await File('${dir.path}/progress.hive.kept').readAsBytes(), keptBefore);
    expect(keys.writes, 0);
    expect(File('${dir.path}/progress_kept_check.hive').existsSync(), isFalse);
    final again = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(key)), crashRecovery: false);
    expect(again.get('p:child_legacy'), 'CHILD_PROGRESS_MARKER');
    await again.close();
  });

  test('an empty encrypted box does not discard a kept plaintext copy', () async {
    Hive.init(dir.path);
    final plain = await Hive.openBox<String>('progress', crashRecovery: false);
    await plain.put('p:adult', 'KEPT_MARKER');
    await plain.close();
    await File('${dir.path}/progress.hive').copy('${dir.path}/progress.hive.kept');
    await File('${dir.path}/progress.hive').delete();
    final key = _key(6);
    final empty = await Hive.openBox<String>('progress', encryptionCipher: HiveAesCipher(base64Decode(key)), crashRecovery: false);
    await empty.close();
    final keys = _MemoryKeys()..value = key;

    final store = await HiveProgressStore.openAt(dir.path, keys: keys);
    expect(store.read(), 'KEPT_MARKER');
    expect(File('${dir.path}/progress.hive.kept').existsSync(), isFalse);
    expect(keys.value, key);
    await store.box.close();
  });

  test('backup rules exclude cloud and device transfer', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    expect(manifest.contains('android:allowBackup="false"'), isTrue);
    expect(manifest.contains('android:dataExtractionRules="@xml/data_extraction_rules"'), isTrue);
    expect(manifest.contains('android:usesCleartextTraffic="false"'), isTrue);
    for (final section in ['<cloud-backup>', '<device-transfer>']) {
      final start = rules.indexOf(section);
      final end = rules.indexOf(section == '<cloud-backup>' ? '</cloud-backup>' : '</device-transfer>');
      expect(start, greaterThanOrEqualTo(0));
      final body = rules.substring(start, end);
      for (final domain in ['root', 'file', 'database', 'sharedpref', 'external', 'device_root', 'device_file', 'device_database', 'device_sharedpref']) {
        expect(body.contains('<exclude domain="$domain" />'), isTrue, reason: domain);
      }
    }
  });

  testWidgets('locked screen explains the key failure in English and Persian', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProgressLockedScreen()));
    expect(find.textContaining('Nothing was deleted'), findsOneWidget);
    expect(find.textContaining('هیچ چیز پاک نشده است'), findsOneWidget);
    expect(find.textContaining('فایل ذخیره‌شده پاک نمی‌شود'), findsOneWidget);
  });
}
