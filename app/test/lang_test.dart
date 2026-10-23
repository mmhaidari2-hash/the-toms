import 'dart:convert';
import 'dart:io';

import 'package:british_life/core/i18n/strings.dart';
import 'package:british_life/features/shared/lang_bar.dart';
import 'package:flutter_test/flutter_test.dart';

/// A helper language is only offered when it fully works: every UI string and every lesson line is translated.
void main() {
  final bundle = jsonDecode(File('assets/data/scenes_bundle.json').readAsStringSync()) as Map<String, dynamic>;

  test('the selector lists exactly the ready languages, all the same way', () {
    expect(HelperLangBar.languages.map((l) => l.code).toSet(), readyLanguages);
    expect(readyLanguages, isNotEmpty);
  });

  for (final code in readyLanguages) {
    test('$code: UI strings complete', () {
      expect(missingStrings(code), isEmpty);
    });
    test('$code: every spoken lesson line has a gloss', () {
      final missing = <String>[];
      for (final e in bundle.entries) {
        for (final n in (e.value['nodes'] as Map<String, dynamic>).values) {
          if ((n['text'] ?? '').toString().isEmpty || n['speaker'] == null || n['speaker'] == 'narrator') continue;
          if (code != 'en' && ((n['translations'] ?? {})[code] ?? '').toString().isEmpty) missing.add('${e.key}: ${n['text']}');
        }
      }
      expect(missing, isEmpty, reason: missing.take(5).join('\n'));
    });
  }
}
