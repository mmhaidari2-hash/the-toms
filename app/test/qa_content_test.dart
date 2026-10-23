// QA gate: every practice exercise the course can generate is solvable and has a usable prompt.
import 'dart:convert';
import 'dart:io';
import 'package:british_life/features/course/practice_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'audit_test.dart' show load;

void main() {
  test('every exercise is solvable (build, gap, listen, tap)', () {
    final c = load();
    final ids = [for (final u in c.course.units) ...[u.id, for (final l in u.lessons) l.id]];
    final bad = <String>[];
    var n = 0;
    for (final id in ids) {
      for (final it in buildPractice(c, id, name: 'Sam')) {
        n++;
        switch (it) {
          case BuildSentence():
            final a = [...it.answer]..sort(), s = [...it.shuffled]..sort();
            if (a.join('\u0001') != s.join('\u0001')) bad.add('$id build chips differ: ${it.answer.join(' ')}');
            if (!sentenceMatches(it.answer, it.answer)) bad.add('$id build answer rejected: ${it.answer.join(' ')}');
            if (it.fa.trim().isEmpty) bad.add('$id build has no prompt: ${it.answer.join(' ')}');
            if (it.answer.any((w) => w.contains('{') || w.contains('}'))) bad.add('$id build has a code placeholder: ${it.answer.join(' ')}');
          case FillGap():
            if (!it.options.contains(it.answer)) bad.add('$id gap answer not offered: ${it.before}___${it.after}');
          case ListenPick():
            if (!it.options.contains(it.word)) bad.add('$id listen answer not offered: ${it.word}');
          case TapObject():
            if (it.target.rect == null) bad.add('$id tap target has no area: ${it.label}');
        }
      }
    }
    Directory('build/qa').createSync(recursive: true);
    File('build/qa/content_results.json').writeAsStringSync(jsonEncode({'items': n, 'bad': bad}));
    expect(bad, isEmpty, reason: bad.take(30).join('\n'));
  });

  test('equivalent word orders are accepted, wrong ones are not', () {
    List<String> w(String s) => s.split(' ');
    expect(sentenceMatches(w('We do! Leslie, go on, ask her.'), w('We do! Leslie, go on, ask her.')), isTrue);
    expect(sentenceMatches(w('Leslie, go on, ask her. We do!'), w('We do! Leslie, go on, ask her.'), names: {'Leslie'}), isFalse);
    expect(sentenceMatches(w('Ask her, Leslie.'), w('Leslie, ask her.'), names: {'Leslie'}), isTrue);
    expect(sentenceMatches(w('Tom, thanks!'), w('Thanks, Tom!'), names: {'Tom'}), isTrue);
    expect(sentenceMatches(w('Please can I have tea?'), w('Can I have tea, please?')), isTrue);
    expect(sentenceMatches(w('tea have I Can?'), w('Can I have tea?')), isFalse);
    // Chips that differ only in capitals/punctuation: either order of the same words is the same sentence.
    expect(sentenceMatches(['Yes,', 'yes.'], ['yes,', 'Yes.'].reversed.toList()), isTrue);
  });
}
