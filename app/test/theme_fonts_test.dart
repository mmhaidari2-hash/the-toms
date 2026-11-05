import 'package:british_life/app/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bundled production fonts include Persian fallback on mixed-script labels',
    () {
      final before = BL.useGoogleFonts;
      BL.useGoogleFonts = true;
      addTearDown(() => BL.useGoogleFonts = before);
      final labels = BL.theme().textTheme.labelLarge!;
      expect(labels.fontFamily, 'Inter');
      expect(labels.fontFamilyFallback, contains('Vazirmatn'));
      expect(BL.display(20).fontFamily, 'Fraunces');
      expect(BL.display(20).fontFamilyFallback, contains('Vazirmatn'));
    },
  );
}
