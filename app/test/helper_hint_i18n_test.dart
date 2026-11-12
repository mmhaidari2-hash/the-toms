import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/i18n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA 2026-11-12: input hints are Strings, not Text widgets, so they skip hl(). The Leitner "add a word" hint showed
/// Persian to every helper language; it now goes through hl(). The chat reply hint and the "Listen" tooltip are wrapped
/// too, now that tool/i18n/extract.py pairs strings.dart values with their English value instead of the map key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => useHelperLang('fa'));
  test('Leitner meaning hint translates for Pashto and Hindi, unchanged for Persian', () async {
    const fa = 'معنی فارسی (اختیاری)';
    for (final code in ['ps', 'hi']) {
      await useHelperLang(code);
      final out = hl(fa);
      expect(out, isNot(fa), reason: code);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(out) && code == 'hi', isFalse, reason: 'Hindi must not show Persian');
    }
    await useHelperLang('fa');
    expect(hl(fa), fa);
  });

  test('chat reply hint, story-finished hint and Listen tooltip: no raw key names, no Persian in other languages', () async {
    final key = RegExp(r'^[a-z][a-z0-9]*([A-Z_][A-Za-z0-9_]*)+$');
    for (final code in ['en', 'hi', 'ar', 'ur', 'ps']) {
      await useHelperLang(code);
      for (final k in ['replyHint', 'storyDone', 'listen']) {
        final out = hl(tr('fa', k));
        expect(out.trim(), isNotEmpty, reason: '$code $k');
        expect(key.hasMatch(out.trim()), isFalse, reason: '$code $k shows a raw key: $out');
        expect(out, isNot(tr('fa', k)), reason: '$code $k still Persian');
      }
    }
    await useHelperLang('en');
    expect(hl(tr('fa', 'storyDone')), 'Story finished');
    expect(hl(tr('fa', 'replyHint')), tr('en', 'replyHint'));
  });
}
