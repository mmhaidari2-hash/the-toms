import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the device allowance lives. Production: encrypted platform storage (Android EncryptedSharedPreferences,
/// the same store that holds the progress AES key). Tests: memory.
abstract class AllowanceVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureAllowanceVault implements AllowanceVault {
  const SecureAllowanceVault();
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

class MemoryAllowanceVault implements AllowanceVault {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// Daily free-lesson allowance for the whole DEVICE (monetisation Option B, hardened t300).
///
/// * One pool for every learner profile: switching or creating profiles never adds lessons.
/// * Clock: "today" is the later of the device clock and the latest time this device has ever seen
///   ([maxSeenMs]), so moving the clock back never refills the allowance; moving it forward only spends
///   future days.
/// * Integrity: the state is HMAC-SHA256-signed with a random 256-bit key held in secure storage. A missing,
///   unreadable or edited state on a device that already has a key is treated as tampering: the state resets
///   with today's allowance spent (costs the learner a day, never grants one).
/// * Clearing all app data (or reinstalling) removes key and state together: that is a fresh device. This is the
///   only remaining client-side limit. Paid content itself is decided by RevenueCat's server-verified entitlement.
class DeviceAllowance {
  static const keyName = 'nluk_allowance_key_v1';
  static const stateName = 'nluk_allowance_v1';
  static const tamperMark = '__tamper__';

  final AllowanceVault _vault;
  final List<int> _key;
  Map<String, String> _claims;
  int _maxSeenMs;
  bool _tampered;

  DeviceAllowance._(this._vault, this._key, this._claims, this._maxSeenMs, this._tampered);

  /// In-memory allowance (tests, and the default before start-up loads the real one).
  factory DeviceAllowance.memory({AllowanceVault? vault}) => DeviceAllowance._(vault ?? MemoryAllowanceVault(), _randomKey(), {}, 0, false);

  bool get tampered => _tampered;
  int get maxSeenMs => _maxSeenMs;
  Map<String, String> get claims => Map.unmodifiable(_claims);

  static List<int> _randomKey() {
    final r = Random.secure();
    return List<int>.generate(32, (_) => r.nextInt(256));
  }

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _sign(List<int> key, String body) => Hmac(sha256, key).convert(utf8.encode(body)).toString();

  /// Loads (or creates) the signed state. Never throws: a platform failure is treated like tampering.
  static Future<DeviceAllowance> load(AllowanceVault vault, {required DateTime now}) async {
    String? keyB64, blob;
    try {
      keyB64 = await vault.read(keyName);
      blob = await vault.read(stateName);
    } catch (_) {
      final a = DeviceAllowance._(vault, _randomKey(), {}, 0, true).._resetTampered(now);
      return a; // storage unreadable: fail closed for today, in memory only
    }
    List<int>? key;
    try {
      key = keyB64 == null || keyB64.isEmpty ? null : base64Decode(keyB64);
    } catch (_) {
      key = null;
    }
    if (key == null || key.length != 32) {
      final fresh = _randomKey();
      try {
        await vault.write(keyName, base64Encode(fresh));
      } catch (_) {}
      final a = DeviceAllowance._(vault, fresh, {}, 0, false);
      // A state without its key means the key was removed on purpose: never a free refill.
      if (blob != null && blob.isNotEmpty) a._resetTampered(now);
      await a._persist();
      return a;
    }
    if (blob == null || blob.isEmpty) {
      // A key exists, the state is gone: deleted on purpose (fresh installs create both together).
      final a = DeviceAllowance._(vault, key, {}, 0, false).._resetTampered(now);
      await a._persist();
      return a;
    }
    try {
      final outer = jsonDecode(blob) as Map<String, dynamic>;
      final body = outer['s'] as String, mac = outer['m'] as String;
      if (_sign(key, body) != mac) throw const FormatException('mac');
      final s = jsonDecode(body) as Map<String, dynamic>;
      return DeviceAllowance._(vault, key, Map<String, String>.from(s['c'] as Map), (s['t'] as num).toInt(), false);
    } catch (_) {
      final a = DeviceAllowance._(vault, key, {}, 0, false).._resetTampered(now);
      await a._persist();
      return a;
    }
  }

  void _resetTampered(DateTime now) {
    _tampered = true;
    _maxSeenMs = max(_maxSeenMs, now.millisecondsSinceEpoch);
    _claims = {tamperMark: _day(DateTime.fromMillisecondsSinceEpoch(_maxSeenMs))};
  }

  /// The signed blob as stored (tests can corrupt it).
  @visibleForTesting
  String encode() {
    final body = jsonEncode({'c': _claims, 't': _maxSeenMs});
    return jsonEncode({'s': body, 'm': _sign(_key, body)});
  }

  Future<void> _persist() async {
    try {
      await _vault.write(keyName, base64Encode(_key));
      await _vault.write(stateName, encode());
    } catch (_) {}
  }

  /// Local day for the allowance: never earlier than the latest moment this device has seen.
  String quotaDay(DateTime now) => _day(DateTime.fromMillisecondsSinceEpoch(max(now.millisecondsSinceEpoch, _maxSeenMs)));

  /// Records the clock moving forward (app start / each check). Persisted when the day changes.
  void observe(DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    if (ms <= _maxSeenMs) return;
    final dayChanged = quotaDay(now) != _day(DateTime.fromMillisecondsSinceEpoch(_maxSeenMs));
    _maxSeenMs = ms;
    if (dayChanged) _persist();
  }

  int usedOn(String day) => _claims.values.where((d) => d == day).length;
  bool claimed(String lessonId) => _claims.containsKey('l:$lessonId');

  /// Spends one of [perDay] lessons today on [lessonId]. Idempotent per lesson.
  bool claim(String lessonId, DateTime now, int perDay) {
    if (claimed(lessonId)) return true;
    observe(now);
    final d = quotaDay(now);
    if (usedOn(d) >= perDay) return false;
    _claims['l:$lessonId'] = d;
    _persist();
    return true;
  }
}
