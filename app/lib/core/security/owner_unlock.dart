import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'owner_unlock_hash.dart';

/// Local owner-mode unlock: verifies a code against a salted PBKDF2-HMAC-SHA256
/// hash baked into the app. The plain code is never shipped in the bundle.
class OwnerUnlock {
  OwnerUnlock._();

  static const maxAttempts = 5;
  static const lockoutMs = 15 * 60 * 1000;

  /// PBKDF2-HMAC-SHA256 (same as Python hashlib.pbkdf2_hmac).
  static Uint8List pbkdf2Sha256(String password, List<int> salt, int iterations, int dkLen) {
    final passwordBytes = utf8.encode(password);
    final hLen = 32;
    final blocks = (dkLen + hLen - 1) ~/ hLen;
    final out = BytesBuilder(copy: false);
    for (var i = 1; i <= blocks; i++) {
      out.add(_f(passwordBytes, salt, iterations, i));
    }
    return Uint8List.fromList(out.toBytes().sublist(0, dkLen));
  }

  static List<int> _f(List<int> password, List<int> salt, int iterations, int i) {
    final hmac = Hmac(sha256, password);
    final block = BytesBuilder(copy: false)..add(salt)..add([(i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff]);
    var u = hmac.convert(block.toBytes()).bytes;
    final t = List<int>.from(u);
    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    return t;
  }

  static bool verify(String code) {
    final trimmed = code.trim();
    if (trimmed.length < 16 || trimmed.length > 128) return false;
    final salt = base64Decode(kOwnerUnlockSaltB64);
    final expected = base64Decode(kOwnerUnlockHashB64);
    final got = pbkdf2Sha256(trimmed, salt, kOwnerUnlockIterations, expected.length);
    return _constEq(got, expected);
  }

  static bool _constEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Parse `count|epochMs` attempt stamp. Returns remaining wait ms if locked, else 0.
  static int lockoutRemainingMs(String? stamp, DateTime now) {
    if (stamp == null || stamp.isEmpty) return 0;
    final parts = stamp.split('|');
    if (parts.length != 2) return 0;
    final count = int.tryParse(parts[0]) ?? 0;
    final start = int.tryParse(parts[1]) ?? 0;
    if (count < maxAttempts) return 0;
    final elapsed = now.millisecondsSinceEpoch - start;
    if (elapsed >= lockoutMs) return 0;
    return lockoutMs - elapsed;
  }

  static String nextStamp(String? stamp, DateTime now, {required bool success}) {
    if (success) return '';
    final nowMs = now.millisecondsSinceEpoch;
    if (stamp == null || stamp.isEmpty) return '1|$nowMs';
    final parts = stamp.split('|');
    var count = int.tryParse(parts[0]) ?? 0;
    var start = int.tryParse(parts.length > 1 ? parts[1] : '') ?? nowMs;
    if (count >= maxAttempts && nowMs - start >= lockoutMs) {
      count = 0;
      start = nowMs;
    }
    count += 1;
    if (count == 1) start = nowMs;
    return '$count|$start';
  }
}
