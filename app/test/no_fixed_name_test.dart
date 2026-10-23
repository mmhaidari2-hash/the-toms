import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The learner is "You" or the name they type in. The retired fixed guest name (spelt here by character
/// codes so this guard itself doesn't contain it) must never come back in content, code or file names.
void main() {
  final names = [String.fromCharCodes([109, 101, 104, 100, 105]), String.fromCharCodes([109, 97, 104, 100, 105]), String.fromCharCodes([0x645, 0x647, 0x62f, 0x6cc])];
  test('no retired fixed learner name in assets or lib', () {
    final bad = <String>[];
    for (final dir in ['assets/data', 'lib', 'assets/portraits', 'assets/avatars', 'web']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        final low = f.path.toLowerCase();
        if (names.any(low.contains)) bad.add('file name ${f.path}');
        if (!RegExp(r'\.(json|dart|html|svg|txt|webmanifest)$').hasMatch(low)) continue;
        final s = f.readAsStringSync().toLowerCase();
        for (final n in names) {
          if (s.contains(n)) bad.add('${f.path}: $n');
        }
      }
    }
    expect(bad, isEmpty);
  });
}
