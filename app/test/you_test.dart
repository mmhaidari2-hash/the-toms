import 'package:british_life/core/i18n/you.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('learner name is shown when set, never Mehdi by default', () {
    expect(fillYou('Morning, {you}! Kettle\'s on.', 'Sara'), "Morning, Sara! Kettle's on.");
    expect(fillYou('Morning, {you}! Kettle\'s on.', ''), "Morning! Kettle's on.");
    expect(fillYou("Hi Nicola! I'm {you}, nice to meet you.", ''), "Hi Nicola! I'm your new neighbour, nice to meet you.");
    expect(fillYou('Thanks Mehdi.', ''), 'Thanks.');
    expect(fillYou('{you}! Over here!', ''), 'Over here!');
    expect(fillYouFa('صبح بخیر، مهدی!', ''), 'صبح بخیر!');
    expect(fillYouFa('صبح بخیر، {you}!', 'سارا'), 'صبح بخیر، سارا!');
    expect(youRawOf[fillYou('Hiya, {you}.', 'Ali')], 'Hiya, {you}.');
  });
}
