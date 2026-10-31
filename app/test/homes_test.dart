import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hartley & Wren Homes (fictional estate agent): free, level-gated A2–B2, own map building and role-play.
void main() {
  final raw = jsonDecode(File('assets/data/course.json').readAsStringSync()) as Map<String, dynamic>;
  final course = Course.fromJson(raw);
  final pack = course.packs.firstWhere((p) => p.id == 'homes');
  ProgressController ctrl(UserProgress p) {
    final store = MemoryProgressStore()..data = p.encode();
    return ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]).read(progressProvider.notifier);
  }

  test('the pack is free, gated and spans A2 to B2', () {
    expect(pack.gated, isTrue);
    expect(pack.premium, isFalse);
    expect(pack.lessons.length, 16);
    expect({for (final u in pack.units) u.cefr}, {'A2', 'B1', 'B2'});
  });

  test('A2 opens at Level 2; B1 and B2 stay locked until the learner gets there', () {
    Lesson first(String cefr) => pack.units.firstWhere((u) => u.cefr == cefr).lessons.first;
    final a1 = ctrl(const UserProgress(onboarded: true));
    expect(a1.lessonOpen(course, first('A2')), isFalse);
    final a2 = ctrl(const UserProgress(onboarded: true, startTier: 1));
    expect(a2.lessonOpen(course, first('A2')), isTrue);
    expect(a2.lessonOpen(course, first('B2')), isFalse);
    final b2 = ctrl(const UserProgress(onboarded: true, startTier: 3));
    expect(b2.lessonOpen(course, first('B2')), isTrue);
  });

  test('the map building, role-play and mission exist; content never names a real agent or the old AST', () {
    final spots = File('assets/data/spots.json').readAsStringSync();
    expect(spots, contains('"homes"'));
    final rps = jsonDecode(File('assets/data/roleplays.json').readAsStringSync());
    expect(jsonEncode(rps), contains('rp_homes'));
    expect(File('assets/data/missions.json').readAsStringSync(), contains('m_b1_viewing'));
    final text = jsonEncode(raw['packs']);
    for (final bad in ['Hackney Homes', 'Hearth & Key', 'break clause']) {
      expect(text.contains(bad), isFalse, reason: bad);
    }
    final chars = jsonDecode(File('assets/data/characters.json').readAsStringSync()) as List;
    final g = chars.firstWhere((c) => c['id'] == 'graham');
    expect(File(g['avatar']).existsSync(), isTrue);
  });
}
