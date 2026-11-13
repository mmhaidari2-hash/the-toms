import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/i18n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper-language JSONs must not all sit in RAM at startup: only the active
/// language and the English fallback are kept (t345).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => useHelperLang('fa'));

  test('startup path does not preload every helper language', () async {
    await useHelperLang('fa');
    for (final code in ['hi', 'ur', 'ar', 'ps', 'ro', 'pl']) {
      expect(loadedHelperLangs.contains(code), isFalse, reason: '$code loaded before it was chosen');
    }
  });

  test('switching language keeps only the active table plus English', () async {
    await useHelperLang('ur');
    expect(loadedHelperLangs, containsAll(['en', 'ur']));
    expect(loadedHelperLangs.contains('hi'), isFalse);
    expect(loadedHelperLangs.contains('ar'), isFalse);
    expect(loadedHelperLangs.contains('ps'), isFalse);

    await useHelperLang('hi');
    expect(loadedHelperLangs, containsAll(['en', 'hi']));
    expect(loadedHelperLangs.contains('ur'), isFalse, reason: 'previous language should be evicted');

    await useHelperLang('fa');
    expect(loadedHelperLangs.contains('hi'), isFalse);
    expect(loadedHelperLangs.contains('ur'), isFalse);
  });

  test('short reply hint looks up in the English fallback and other tables', () async {
    await useHelperLang('en');
    expect(hl(tr('fa', 'replyHintShort')), 'In English…');
    await useHelperLang('hi');
    final hi = hl(tr('fa', 'replyHintShort'));
    expect(hi, isNot('به انگلیسی…'));
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(hi), isFalse, reason: 'Hindi hint still Persian: $hi');
  });
}
