// Saved mistakes re-look up their prompt in the current lesson content, so a translation fix reaches learners
// who saved the mistake earlier (run 24). Every helper language is derived from this prompt, so all languages follow.
import 'package:british_life/features/course/practice_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'audit_test.dart' show load;

void main() {
  test('a mistake saved with the old Persian prompt shows the corrected one', () {
    final c = load();
    final saved = {'t': 's', 'a': ['We', 'do!', 'Leslie,', 'go', 'on,', 'ask', 'her.'], 'fa': 'آره! لزلی، بپرس.', 'l': 'l3_u5_1', 'n': 1};
    final it = buildMistakes(c, [('s:We do! Leslie, go on, ask her.', saved)]).single as BuildSentence;
    expect(it.fa, 'آره، کمکش می‌کنیم! لزلی، یالا، ازش بپرس.');
  });

  test('every saved build/gap mistake gets the current prompt, whatever was stored', () {
    final c = load();
    var n = 0;
    for (final u in c.course.units.take(12)) {
      for (final it in buildPractice(c, u.id, name: 'Sam')) {
        final m = mistakeOf(it, u.id);
        if (m == null || m.$2['t'] == 'w') continue;
        final stale = {...m.$2, 'fa': 'STALE'};
        final back = buildMistakes(c, [(m.$1, stale)], name: 'Sam').single;
        final fa = switch (back) { BuildSentence() => back.fa, FillGap() => back.fa, _ => '' };
        final want = switch (it) { BuildSentence() => it.fa, FillGap() => it.fa, _ => '' };
        expect(fa, want, reason: m.$1);
        n++;
      }
    }
    expect(n, greaterThan(20));
  });

  test('a sentence that no longer exists keeps its saved prompt', () {
    final c = load();
    final saved = {'t': 's', 'a': ['Zzz', 'qqq', 'xxx.'], 'fa': 'قدیمی', 'l': 'nope'};
    final it = buildMistakes(c, [('s:Zzz qqq xxx.', saved)]).single as BuildSentence;
    expect(it.fa, 'قدیمی');
  });
}
