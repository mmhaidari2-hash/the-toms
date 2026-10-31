import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/learner_profile.dart';
import '../engine/weekly.dart';

abstract class ProgressStore {
  String? read();
  Future<void> write(String data);
  Future<void> clear();

  String get activeId;
  List<LearnerProfile> profiles();
  LearnerProfile? activeProfile();
  Future<void> switchTo(String id);
  Future<LearnerProfile> addProfile({required String displayName, required ProfileKind kind});
  Future<void> renameProfile(String id, String displayName);
  Future<void> removeProfile(String id);
  String? readOf(String id);

  CalmCircle readCircle();
  Future<void> writeCircle(CalmCircle c);

  /// Wipe every profile, circle and legacy blob on this device (UK GDPR erasure / Play data deletion).
  Future<void> clearAllLocalData();

  /// Machine-readable export of all local progress for the active device (portability).
  Map<String, String> exportAllLocalData();
}

const _metaKey = 'meta';
const _legacyKey = 'v1';
const _circleKey = 'circle';
String _p(String id) => 'p:$id';

Future<HiveAesCipher> _progressCipher() async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  const keyName = 'nluk_progress_aes_v1';
  var b64 = await storage.read(key: keyName);
  if (b64 == null || b64.isEmpty) {
    final rnd = Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
    b64 = base64Encode(bytes);
    await storage.write(key: keyName, value: b64);
  }
  return HiveAesCipher(base64Decode(b64));
}

Map<String, dynamic> _defaultMeta() => {
      'active': 'adult',
      'profiles': [
        LearnerProfile(id: 'adult', displayName: 'Me', kind: ProfileKind.adult, createdAt: DateTime.now()).toJson(),
      ],
    };

class HiveProgressStore implements ProgressStore {
  static const _boxName = 'progress';
  final Box<String> box;
  HiveProgressStore(this.box);

  static Future<HiveProgressStore> open() async {
    await Hive.initFlutter();
    Box<String> box;
    // Web/PWA: unencrypted IndexedDB (CSP + QA seeding; accepted residual risk in compliance report).
    // Mobile: AES via flutter_secure_storage-backed HiveAesCipher.
    if (kIsWeb) {
      box = await Hive.openBox<String>(_boxName);
    } else {
      final cipher = await _progressCipher();
      try {
        box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
      } catch (_) {
        // Migrate from a legacy unencrypted box if present.
        final legacy = await Hive.openBox<String>(_boxName);
        final data = <String, String>{for (final k in legacy.keys) k.toString(): legacy.get(k) ?? ''};
        await legacy.deleteFromDisk();
        box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
        for (final e in data.entries) {
          if (e.value.isNotEmpty) await box.put(e.key, e.value);
        }
      }
    }
    final s = HiveProgressStore(box);
    await s._migrate();
    return s;
  }

  Future<void> _migrate() async {
    if (box.containsKey(_metaKey)) return;
    final legacy = box.get(_legacyKey);
    final meta = _defaultMeta();
    await box.put(_metaKey, jsonEncode(meta));
    if (legacy != null) {
      await box.put(_p('adult'), legacy);
      await box.delete(_legacyKey);
    }
  }

  Map<String, dynamic> _meta() {
    final raw = box.get(_metaKey);
    if (raw == null) return _defaultMeta();
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return _defaultMeta();
    }
  }

  Future<void> _putMeta(Map<String, dynamic> m) => box.put(_metaKey, jsonEncode(m));

  @override
  String get activeId => (_meta()['active'] as String?) ?? 'adult';

  @override
  List<LearnerProfile> profiles() {
    final list = (_meta()['profiles'] as List?) ?? const [];
    return [for (final p in list) LearnerProfile.fromJson(Map<String, dynamic>.from(p as Map))];
  }

  @override
  LearnerProfile? activeProfile() {
    final id = activeId;
    for (final p in profiles()) {
      if (p.id == id) return p;
    }
    return profiles().isEmpty ? null : profiles().first;
  }

  @override
  String? read() => box.get(_p(activeId)) ?? box.get(_legacyKey);

  @override
  String? readOf(String id) => box.get(_p(id));

  @override
  Future<void> write(String data) => box.put(_p(activeId), data);

  @override
  Future<void> clear() => box.delete(_p(activeId));

  @override
  Future<void> switchTo(String id) async {
    final m = _meta();
    final ids = {for (final p in profiles()) p.id};
    if (!ids.contains(id)) throw StateError('unknown profile $id');
    m['active'] = id;
    await _putMeta(m);
  }

  @override
  Future<LearnerProfile> addProfile({required String displayName, required ProfileKind kind}) async {
    final m = _meta();
    final list = List<Map<String, dynamic>>.from((m['profiles'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    if (list.length >= 4) throw StateError('max 4 profiles on one device');
    final id = '${kind.name}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final p = LearnerProfile(id: id, displayName: displayName.trim().isEmpty ? (kind == ProfileKind.child ? 'Child' : 'Me') : displayName.trim(), kind: kind, createdAt: DateTime.now());
    list.add(p.toJson());
    m['profiles'] = list;
    await _putMeta(m);
    // Child starts empty; adult could copy nothing — fresh progress.
    return p;
  }

  @override
  Future<void> renameProfile(String id, String displayName) async {
    final m = _meta();
    final list = List<Map<String, dynamic>>.from((m['profiles'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    for (final p in list) {
      if (p['id'] == id) {
        p['name'] = displayName.trim().isEmpty ? p['name'] : displayName.trim();
      }
    }
    m['profiles'] = list;
    await _putMeta(m);
  }

  @override
  Future<void> removeProfile(String id) async {
    final m = _meta();
    var list = List<Map<String, dynamic>>.from((m['profiles'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    if (list.length <= 1) throw StateError('keep at least one profile');
    list = [for (final p in list) if (p['id'] != id) p];
    m['profiles'] = list;
    if (m['active'] == id) m['active'] = list.first['id'];
    await _putMeta(m);
    await box.delete(_p(id));
  }

  @override
  CalmCircle readCircle() => CalmCircle.decode(box.get(_circleKey), WeeklyChallenge.weekKey(DateTime.now()));

  @override
  Future<void> writeCircle(CalmCircle c) => box.put(_circleKey, c.encode());

  @override
  Future<void> clearAllLocalData() async {
    await box.clear();
    await box.put(_metaKey, jsonEncode(_defaultMeta()));
  }

  @override
  Map<String, String> exportAllLocalData() {
    final out = <String, String>{};
    for (final k in box.keys) {
      final v = box.get(k);
      if (v != null) out[k.toString()] = v;
    }
    return out;
  }
}

class MemoryProgressStore implements ProgressStore {
  final Map<String, String> _blobs = {};
  Map<String, dynamic> _meta = _defaultMeta();
  String? _circle;

  MemoryProgressStore({String? data}) {
    if (data != null) _blobs[_p('adult')] = data;
  }

  /// Test helper matching old API.
  String? get data => read();
  set data(String? v) {
    if (v == null) {
      _blobs.remove(_p(activeId));
    } else {
      _blobs[_p(activeId)] = v;
    }
  }

  @override
  String get activeId => (_meta['active'] as String?) ?? 'adult';

  @override
  List<LearnerProfile> profiles() {
    final list = (_meta['profiles'] as List?) ?? const [];
    return [for (final p in list) LearnerProfile.fromJson(Map<String, dynamic>.from(p as Map))];
  }

  @override
  LearnerProfile? activeProfile() {
    final id = activeId;
    for (final p in profiles()) {
      if (p.id == id) return p;
    }
    return profiles().isEmpty ? null : profiles().first;
  }

  @override
  String? read() => _blobs[_p(activeId)];

  @override
  String? readOf(String id) => _blobs[_p(id)];

  @override
  Future<void> write(String d) async => _blobs[_p(activeId)] = d;

  @override
  Future<void> clear() async => _blobs.remove(_p(activeId));

  @override
  Future<void> switchTo(String id) async {
    final ids = {for (final p in profiles()) p.id};
    if (!ids.contains(id)) throw StateError('unknown profile $id');
    _meta = Map<String, dynamic>.from(_meta)..['active'] = id;
  }

  @override
  Future<LearnerProfile> addProfile({required String displayName, required ProfileKind kind}) async {
    final list = List<Map<String, dynamic>>.from(((_meta['profiles'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    if (list.length >= 4) throw StateError('max 4 profiles');
    final id = '${kind.name}_${Random().nextInt(1 << 32).toRadixString(36)}';
    final p = LearnerProfile(id: id, displayName: displayName.trim().isEmpty ? (kind == ProfileKind.child ? 'Child' : 'Me') : displayName.trim(), kind: kind, createdAt: DateTime.now());
    list.add(p.toJson());
    _meta = Map<String, dynamic>.from(_meta)..['profiles'] = list;
    return p;
  }

  @override
  Future<void> renameProfile(String id, String displayName) async {
    final list = List<Map<String, dynamic>>.from(((_meta['profiles'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    for (final p in list) {
      if (p['id'] == id) p['name'] = displayName.trim().isEmpty ? p['name'] : displayName.trim();
    }
    _meta = Map<String, dynamic>.from(_meta)..['profiles'] = list;
  }

  @override
  Future<void> removeProfile(String id) async {
    var list = List<Map<String, dynamic>>.from(((_meta['profiles'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    if (list.length <= 1) throw StateError('keep at least one');
    list = [for (final p in list) if (p['id'] != id) p];
    _meta = Map<String, dynamic>.from(_meta)
      ..['profiles'] = list
      ..['active'] = _meta['active'] == id ? list.first['id'] : _meta['active'];
    _blobs.remove(_p(id));
  }

  @override
  CalmCircle readCircle() => CalmCircle.decode(_circle, WeeklyChallenge.weekKey(DateTime.now()));

  @override
  Future<void> writeCircle(CalmCircle c) async => _circle = c.encode();

  @override
  Future<void> clearAllLocalData() async {
    _blobs.clear();
    _circle = null;
    _meta = _defaultMeta();
  }

  @override
  Map<String, String> exportAllLocalData() {
    final out = <String, String>{for (final e in _blobs.entries) e.key: e.value};
    out[_metaKey] = jsonEncode(_meta);
    if (_circle != null) out[_circleKey] = _circle!;
    return out;
  }
}

/// Generate a private study-buddy code (local only; no server).
String newBuddyCode([Random? rng]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rng ?? Random.secure();
  return String.fromCharCodes(List.generate(6, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length))));
}

bool validBuddyCode(String raw) {
  final c = normalizeBuddyCode(raw);
  // Exact alphabet used by [newBuddyCode] — reject lookalikes (0/O, 1/I) and wrong length.
  return RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(c);
}

String normalizeBuddyCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
