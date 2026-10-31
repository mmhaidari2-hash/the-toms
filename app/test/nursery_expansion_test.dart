import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// N0 interview + N7 ratios/logs/parents evening/talking to children.
void main() {
  final course = jsonDecode(File('assets/data/course.json').readAsStringSync());
  final pack = (course['packs'] as List).firstWhere((p) => p['id'] == 'nursery');
  final units = {for (final u in pack['units']) u['id'] as String: u};
  const newIds = ['nur_0_1', 'nur_7_1', 'nur_7_2', 'nur_7_3', 'nur_7_4'];

  test('N0 interview and N7 ratios/logs/evening/talk units exist', () {
    expect(units.containsKey('N0'), isTrue);
    expect(units.containsKey('N7'), isTrue);
    expect(units['N0']['title'], 'Getting the job');
    expect(units['N7']['title'], 'Ratios, registers and logs');
    final scenes = [
      for (final u in ['N0', 'N7'])
        for (final l in units[u]!['lessons']) ...List<String>.from(l['sceneIds']),
    ];
    expect(scenes, newIds);
  });

  test('new scenes have Persian, guest Sara, safeguarding/EYFS vocabulary', () {
    final must = {
      'nur_0_1': ['DBS', 'Designated Safeguarding', 'ratio'],
      'nur_7_1': ['ratio', 'headcount', 'register'],
      'nur_7_2': ['nappy', 'sleep log', 'food log'],
      'nur_7_3': ["parents' evening", 'next step', 'observation'],
      'nur_7_4': ['EYFS', 'open question', 'persevering'],
    };
    for (final id in newIds) {
      final f = File('assets/data/scenes/$id.json');
      expect(f.existsSync(), isTrue, reason: id);
      final s = jsonDecode(f.readAsStringSync());
      expect(s['guest'], 'sara');
      expect(s['titleFa'], isNotEmpty);
      final blob = jsonEncode(s).toLowerCase();
      for (final needle in must[id]!) {
        expect(blob.contains(needle.toLowerCase()), isTrue, reason: '$id missing $needle');
      }
      for (final n in (s['nodes'] as Map).values) {
        expect((n['translations'] as Map)['fa'], isNotEmpty, reason: '$id/${n['id']} fa');
        for (final b in n['branches']) {
          expect(b['suggestionFa'], isNotEmpty);
        }
      }
    }
  });

  test('new scene audio clips exist for speakers and Sara replies', () {
    final idx = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List)
        .cast<String>()
        .toSet();
    String k(String sp, String t) =>
        md5.convert(utf8.encode('$sp|$t')).toString().substring(0, 16);
    final missing = <String>[];
    for (final id in newIds) {
      final s = jsonDecode(File('assets/data/scenes/$id.json').readAsStringSync());
      for (final n in (s['nodes'] as Map).values) {
        final kt = k(n['speaker'] as String, n['text'] as String);
        if (!idx.contains(kt)) missing.add('$id/${n['id']} speaker');
        for (final b in n['branches']) {
          final ks = k('sara', b['suggestion'] as String);
          if (!idx.contains(ks)) missing.add('$id/${n['id']} reply: ${b['suggestion']}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(15).join('\n'));
  });
}
