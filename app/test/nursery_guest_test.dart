import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vida's Nursery is played as Sara (a new practitioner), never as Mehdi.
void main() {
  final course = jsonDecode(File('assets/data/course.json').readAsStringSync());
  final pack = (course['packs'] as List).firstWhere((p) => p['id'] == 'nursery');
  final ids = [for (final u in pack['units']) for (final l in u['lessons']) ...List<String>.from(l['sceneIds'])];
  final mehdi = RegExp(r'mehdi|مهدی|\{you\}', caseSensitive: false);

  test('the nursery pack has 24 lessons and its own guest, Sara', () {
    expect(ids.length, 24);
    expect(pack['guest'], 'sara');
    final chars = jsonDecode(File('assets/data/characters.json').readAsStringSync()) as List;
    final sara = chars.firstWhere((c) => c['id'] == 'sara');
    expect(sara['name'], 'Sara');
    expect(File(sara['avatar']).existsSync(), isTrue);
    expect(File('tool/render_voices.py').readAsStringSync(), contains("'sara':('en-GB-"));
  });

  test('no Mehdi anywhere in the nursery pack (speakers, lines, Persian, replies)', () {
    expect(mehdi.hasMatch(jsonEncode(pack)), isFalse);
    final bad = <String>[];
    for (final f in Directory('assets/data/scenes').listSync().whereType<File>()) {
      final id = f.uri.pathSegments.last.replaceAll('.json', '');
      final s = jsonDecode(f.readAsStringSync());
      final inPack = ids.contains(id) || ids.contains(s['baseId']);
      if (!inPack) continue;
      if (s['guest'] != 'sara') bad.add('$id: guest ${s['guest']}');
      for (final n in (s['nodes'] as Map).values) {
        if (n['speaker'] == 'mehdi' || n['speaker'] == 'me') bad.add('$id/${n['id']}: speaker ${n['speaker']}');
        if (mehdi.hasMatch(jsonEncode(n))) bad.add('$id/${n['id']}: mentions Mehdi');
      }
    }
    for (final id in ids) {
      if (!File('assets/data/scenes/$id.json').existsSync()) bad.add('$id: missing');
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  test("Sara's replies are recorded in her own voice", () {
    final idx = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
    String k(String t) => md5.convert(utf8.encode('sara|$t')).toString().substring(0, 16);
    final missing = <String>[];
    for (final id in ids) {
      final s = jsonDecode(File('assets/data/scenes/$id.json').readAsStringSync());
      for (final n in (s['nodes'] as Map).values) {
        for (final b in n['branches']) {
          if (!idx.contains(k(b['suggestion']))) missing.add('$id: ${b['suggestion']}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(10).join('\n'));
  });
}
