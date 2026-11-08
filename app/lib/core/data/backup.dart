import 'dart:convert';

import '../models/user_progress.dart';

/// Restoring a copy made by "Export all local data" (Privacy screen). Local only: nothing is sent anywhere.
///
/// The copy is the store's own key/value map. A restore replaces everything on this device, so the copy is
/// checked first: known keys only, a valid profile list, and every progress blob must load. Owner mode is a
/// device-only unlock behind a private code, so it is always switched off in a restored copy.
class BackupCheck {
  final Map<String, String>? data;
  final String? error;

  /// Persian next to the English, for the dialog.
  final String? errorFa;
  const BackupCheck.ok(Map<String, String> this.data)
      : error = null,
        errorFa = null;
  const BackupCheck.fail(String this.error, String this.errorFa) : data = null;
  bool get ok => data != null;

  /// How many learner profiles the copy holds.
  int get profileCount {
    final m = data?['meta'];
    if (m == null) return 0;
    return ((jsonDecode(m) as Map)['profiles'] as List).length;
  }
}

/// Copies larger than this are not a real export (a long-used device is well under 1 MB).
const backupMaxChars = 5 * 1024 * 1024;

BackupCheck parseBackup(String raw) {
  const bad = BackupCheck.fail(
    'This is not a New Life UK copy. Paste the whole text from "Export all local data".',
    'این متن نسخهٔ پشتیبان New Life UK نیست. کل متنی را که با «Export all local data» کپی کردید بچسبانید.',
  );
  final text = raw.trim();
  if (text.isEmpty || text.length > backupMaxChars) return bad;
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return bad;
  }
  if (decoded is! Map) return bad;
  final out = <String, String>{};
  for (final e in decoded.entries) {
    final k = e.key, v = e.value;
    if (k is! String || v is! String) return bad;
    if (k != 'meta' && k != 'circle' && k != 'v1' && !k.startsWith('p:')) return bad;
    out[k] = v;
  }

  // Profiles: 1 to 4, unique ids, and the active one must exist.
  final metaRaw = out['meta'];
  if (metaRaw == null) return bad;
  final Set<String> ids;
  try {
    final meta = jsonDecode(metaRaw) as Map;
    final list = meta['profiles'] as List;
    if (list.isEmpty || list.length > 4) return bad;
    ids = {for (final p in list) (p as Map)['id'] as String};
    if (ids.length != list.length || !ids.contains(meta['active'])) return bad;
  } catch (_) {
    return bad;
  }

  // Progress blobs: only for listed profiles, each must load; owner mode is dropped.
  final result = <String, String>{'meta': metaRaw};
  if (out['circle'] != null) result['circle'] = out['circle']!;
  for (final e in out.entries) {
    final isBlob = e.key.startsWith('p:') || e.key == 'v1';
    if (!isBlob) continue;
    if (e.key.startsWith('p:') && !ids.contains(e.key.substring(2))) continue;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(e.value) as Map);
      j['own'] = false;
      final blob = jsonEncode(j);
      UserProgress.decode(blob);
      result[e.key] = blob;
    } catch (_) {
      return const BackupCheck.fail(
        'Part of this copy is damaged, so nothing was restored.',
        'بخشی از این نسخه خراب است، پس چیزی بازگردانده نشد.',
      );
    }
  }
  return BackupCheck.ok(result);
}
