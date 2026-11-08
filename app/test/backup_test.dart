import 'dart:convert';

import 'package:british_life/core/data/backup.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Restore from a copy (Privacy screen): a copy made by "Export all local data" comes back whole on another
/// device, a bad or edited copy is refused before anything is replaced, and owner mode never comes back.
void main() {
  Future<MemoryProgressStore> deviceWithTwoLearners() async {
    final s = MemoryProgressStore()..data = const UserProgress(onboarded: true, streak: 9, missionsDone: {'pref:name': 'Sam'}).encode();
    final kid = await s.addProfile(displayName: 'Nima', kind: ProfileKind.child);
    await s.switchTo(kid.id);
    await s.write(const UserProgress(onboarded: true, streak: 2).encode());
    await s.switchTo('adult');
    return s;
  }

  String exportOf(ProgressStore s) => const JsonEncoder.withIndent('  ').convert(s.exportAllLocalData());

  test('a copy from one device restores every profile on another', () async {
    final old = await deviceWithTwoLearners();
    final check = parseBackup(exportOf(old));
    expect(check.ok, isTrue, reason: check.error);
    expect(check.profileCount, 2);

    final fresh = MemoryProgressStore()..data = const UserProgress(streak: 1).encode();
    await fresh.importAllLocalData(check.data!);
    expect(fresh.profiles().map((p) => p.displayName), ['Me', 'Nima']);
    expect(fresh.activeId, 'adult');
    final adult = UserProgress.decode(fresh.read()!);
    expect(adult.streak, 9);
    expect(adult.missionsDone['pref:name'], 'Sam');
    final kid = fresh.profiles().firstWhere((p) => p.isChild);
    expect(UserProgress.decode(fresh.readOf(kid.id)!).streak, 2);
  });

  test('owner mode is never restored, even if the copy was edited to turn it on', () async {
    final s = MemoryProgressStore()..data = const UserProgress(onboarded: true, ownerMode: true).encode();
    final check = parseBackup(exportOf(s));
    expect(check.ok, isTrue);
    final fresh = MemoryProgressStore();
    await fresh.importAllLocalData(check.data!);
    expect(UserProgress.decode(fresh.read()!).ownerMode, isFalse);
    expect(UserProgress.decode(fresh.read()!).onboarded, isTrue);
  });

  test('bad copies are refused with English and Persian, and nothing is replaced', () {
    final good = MemoryProgressStore()..data = const UserProgress().encode();
    final meta = good.exportAllLocalData()['meta']!;
    final cases = <String>[
      '',
      'hello',
      '[1,2]',
      jsonEncode({'meta': meta, 'evil': 'x'}), // unknown key
      jsonEncode({'p:adult': const UserProgress().encode()}), // no profile list
      jsonEncode({'meta': jsonEncode({'active': 'nobody', 'profiles': jsonDecode(meta)['profiles']})}),
      jsonEncode({
        'meta': jsonEncode({
          'active': 'a',
          'profiles': [for (final id in ['a', 'b', 'c', 'd', 'e']) {'id': id, 'name': id, 'kind': 'adult'}],
        }),
      }), // more than 4 profiles
      jsonEncode({'meta': meta, 'p:adult': '{"streak": "not a number"}'}), // damaged progress
      jsonEncode({'meta': meta, 'p:adult': 7}), // not text
    ];
    for (final c in cases) {
      final r = parseBackup(c);
      expect(r.ok, isFalse, reason: c);
      expect(r.error, isNotEmpty);
      expect(RegExp(r'[؀-ۿ]').hasMatch(r.errorFa!), isTrue, reason: 'Persian for: $c');
    }
  });

  test('progress for a profile that is not in the list is left out', () {
    final s = MemoryProgressStore()..data = const UserProgress(streak: 3).encode();
    final m = s.exportAllLocalData()..['p:ghost'] = const UserProgress(streak: 50).encode();
    final r = parseBackup(jsonEncode(m));
    expect(r.ok, isTrue);
    expect(r.data!.containsKey('p:ghost'), isFalse);
    expect(r.data!.containsKey('p:adult'), isTrue);
  });
}
