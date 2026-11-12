import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA 2026-11-12: input hints are Strings, not Text widgets, so they skip hl(). The Leitner "add a word" hint showed
/// Persian to every helper language; it now goes through hl(). (The chat reply hint is NOT wrapped yet: several helper
/// tables map it to a raw key name such as "storyDone"; see docs/qa/STRESS_TEST_2026-11-12_FA.md.)
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
}
