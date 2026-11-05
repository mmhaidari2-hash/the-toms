import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  dynamic read(String path) => jsonDecode(File(path).readAsStringSync());

  test('runtime bundle exactly matches every indexed source scene', () {
    final ids = List<String>.from(read('assets/data/scenes_index.json'));
    final bundle =
        read('assets/data/scenes_bundle.json') as Map<String, dynamic>;
    expect(ids.toSet().length, ids.length, reason: 'Duplicate scene IDs');
    expect(bundle.keys.toSet(), ids.toSet());
    for (final id in ids) {
      expect(bundle[id], read('assets/data/scenes/$id.json'), reason: id);
    }
  });

  test('every published course scene exists in the runtime bundle', () {
    final bundle =
        read('assets/data/scenes_bundle.json') as Map<String, dynamic>;
    void check(dynamic value) {
      if (value is Map) {
        for (final id in value['sceneIds'] ?? const []) {
          expect(
            bundle.containsKey(id),
            isTrue,
            reason: 'Missing course scene $id',
          );
        }
        value.values.forEach(check);
      } else if (value is List) {
        value.forEach(check);
      }
    }

    check(read('assets/data/course.json'));
  });
}
