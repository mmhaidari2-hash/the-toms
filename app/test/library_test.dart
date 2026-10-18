import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/voice.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/library/library_data.dart';
import 'package:british_life/features/library/library_gate.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Library (graded readers): content rules + the shelf → book → reader → quiz → finished flow.
void main() {
  final books = Library.parse(File('assets/data/library.json').readAsStringSync());
  final audio = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();

  test('A1/A2 shelves have 8+ books, B1/B2/C1 4+; each with chapters, quizzes and full glossaries', () {
    for (final lv in ['A1', 'A2']) {
      expect(books.where((b) => b.level == lv).length, greaterThanOrEqualTo(8), reason: lv);
    }
    for (final lv in ['B1', 'B2', 'C1']) {
      expect(books.where((b) => b.level == lv).length, greaterThanOrEqualTo(4), reason: lv);
    }
    expect(books.map((b) => b.id).toSet().length, books.length, reason: 'unique ids');
    for (final b in books) {
      expect(File(b.coverAsset).existsSync(), isTrue, reason: '${b.id} cover');
      expect(b.chapters.length, greaterThanOrEqualTo(2), reason: b.id);
      for (final c in b.chapters) {
        expect(c.sentences.length, greaterThanOrEqualTo(6), reason: '${b.id} ${c.title}');
        expect(c.quiz.length, greaterThanOrEqualTo(2), reason: '${b.id} ${c.title} quiz');
        for (final q in c.quiz) {
          expect(q.options.length, 3, reason: q.q);
          expect(q.options.toSet().length, 3, reason: q.q);
        }
        for (final s in c.sentences) {
          expect(s.fa.trim(), isNotEmpty, reason: s.en);
          expect(s.segs.map((e) => e.$1).join(), s.en, reason: 'segments rebuild the sentence');
          for (final (w, k) in s.segs) {
            if (k.isNotEmpty) expect(b.gloss[k] ?? '', isNotEmpty, reason: '${b.id}: "$w" has no Persian');
          }
          expect(audio.contains(Voice.key(s.voice, s.en)), isTrue, reason: '${s.voice} clip for "${s.en}"');
        }
      }
    }
  });

  test('B1+ books are voiced per character: dialogue lines are pure quotes with a named, known speaker', () {
    final voices = RegExp(r"'([a-z]+)':\('en-").allMatches(File('tool/render_voices.py').readAsStringSync()).map((m) => m.group(1)!).toSet();
    for (final b in books.where((b) => !b.level.startsWith('A'))) {
      final ss = [for (final c in b.chapters) ...c.sentences];
      final spoken = ss.where((s) => s.sp != null).toList();
      expect(spoken.map((s) => s.sp).toSet().length, greaterThanOrEqualTo(2), reason: '${b.id} needs 2+ voiced characters');
      for (final s in spoken) {
        expect(voices, contains(s.sp), reason: '${b.id}: unknown voice ${s.sp}');
        expect(s.spName ?? '', isNotEmpty, reason: '${b.id}: ${s.sp} has no display name');
        expect(s.en.startsWith('"') && s.en.endsWith('"'), isTrue, reason: 'only the quote is voiced: ${s.en}');
      }
    }
  });

  test('shelves unlock with the Grammar School / course level rule', () async {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    LibraryGate gate() => LibraryGate(ctrl, content, topics, books);
    expect(gate().shelfOpen('A1'), isTrue);
    for (final lv in ['A2', 'B1', 'B2', 'C1']) {
      expect(gate().shelfOpen(lv), isFalse, reason: '$lv shut for a new learner');
    }
    expect(LibraryGate(ctrl, content, topics, books, unlockAll: true).shelfOpen('C1'), isTrue);
    // Finishing the A1 shelf opens A2.
    for (final b in gate().of('A1')) {
      ctrl.saveChapter(b.id, 0, 100, 2);
      ctrl.saveChapter(b.id, 1, 100, 2);
    }
    expect(gate().shelfOpen('A2'), isTrue);
    expect(gate().shelfOpen('B1'), isFalse);
    // Passing Grammar Class A2 opens B1 (A1 already passed opens A2 via grammar too).
    for (final t in topics.where((t) => t.level == 'A1' || t.level == 'A2')) {
      ctrl.saveGrammar(t.id, 80);
    }
    expect(gate().shelfOpen('B1'), isTrue);
    expect(gate().shelfOpen('B2'), isFalse);
    // A book already started keeps its shelf open.
    ctrl.saveChapter('c1_letters', 0, 30, 2);
    expect(gate().shelfOpen('C1'), isTrue, reason: 'nobody loses a book they are reading');
    expect(gate().shelfOpen('B2'), isFalse);
    for (final t in topics.where((t) => t.level == 'B1')) {
      ctrl.saveGrammar(t.id, 80);
    }
    expect(gate().shelfOpen('B2'), isTrue);
    expect(LibraryGate.why('B2').$1, contains('Grammar Class B1'));
  });

  test('level-appropriate length and British spelling', () {
    final us = RegExp(r"\b(color|favorite|mom|apartment|cookie|candy|pants|vacation|soccer|theater|center|traveled|gotten|sidewalk|truck|elevator|trash|garbage|diaper|realize)\b", caseSensitive: false);
    for (final b in books) {
      final ss = [for (final c in b.chapters) ...c.sentences];
      final lens = ss.map((s) => s.en.split(RegExp(r'\s+')).length).toList();
      final avg = lens.reduce((a, b) => a + b) / lens.length;
      final (maxAvg, maxOne, maxWords) = switch (b.level) { 'A1' => (8.5, 13, 160), 'A2' => (14.0, 20, 320), _ => (22.0, 34, 900) };
      expect(avg, lessThanOrEqualTo(maxAvg), reason: '${b.id} avg sentence length $avg');
      expect(lens.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(maxOne), reason: '${b.id} longest sentence');
      expect(b.words, lessThanOrEqualTo(maxWords), reason: '${b.id} total words');
      for (final s in ss) {
        expect(us.hasMatch(s.en), isFalse, reason: 'American usage in "${s.en}"');
      }
    }
  });

  test('chapter quiz saves the best score, awards XP and finishes the book', () {
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final c = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]).read(progressProvider.notifier);
    expect(c.nextChapter('a1_bus', 2), 0);
    expect(c.saveChapter('a1_bus', 0, 50, 2).xp, 10);
    expect(c.saveChapter('a1_bus', 0, 0, 2).xp, 3);
    expect(c.readScore('a1_bus', 0), 50, reason: 'best score kept');
    expect(c.nextChapter('a1_bus', 2), 1);
    expect(c.bookDone('a1_bus'), isFalse);
    final a = c.saveChapter('a1_bus', 1, 100, 2);
    expect(a.xp, 15);
    expect(c.bookDone('a1_bus'), isTrue);
    expect(c.booksDone, 1);
    expect(a.newBadges.map((b) => b.id), contains('book1'));
  });

  group('screens at 375x667', () {
    setUp(() => BL.useGoogleFonts = false);
    setUpAll(() async {
      for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
        final file = {'Roboto': 'Inter', 'Inter': 'Inter', 'Fraunces': 'Fraunces', 'Vazirmatn': 'Vazirmatn'}[fam]!;
        final l = FontLoader(fam);
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
          l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
        }
        await l.load();
      }
    });
    testWidgets('shelves → book card → reader (tap a word, save it, translation) → quiz → finished', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
      final scope = ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp());
      await t.pumpWidget(scope);
      for (var i = 0; i < 40 && find.text('The Toms').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> settle() async {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 400));
        }
        for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull);
      }

      router.go('/library');
      await settle();
      expect(find.byKey(const ValueKey('shelf-A1')), findsOneWidget);
      expect(find.byKey(const ValueKey('shelf-A2')), findsOneWidget);
      expect(find.byKey(const ValueKey('shelf-B1'), skipOffstage: false), findsOneWidget, reason: 'B1 shelf listed (locked)');
      await t.tap(find.byKey(const ValueKey('book-a1_bus')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const ValueKey('booksheet-a1_bus')), findsOneWidget);
      expect(find.text('Start reading'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('book-read')));
      await settle();
      expect(find.byKey(const ValueKey('reader-text')), findsOneWidget);
      expect(find.text('Chapter 1 of 2  ·  A1'), findsOneWidget);

      // Tap the word "three" in "William is three."
      final rich = t.widget<RichText>(find.descendant(of: find.byKey(const ValueKey('sent-0')), matching: find.byType(RichText)));
      TapGestureRecognizer? rec;
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.text == 'three') rec = s.recognizer as TapGestureRecognizer?;
        return true;
      });
      rec!.onTap!();
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const ValueKey('word-sheet')), findsOneWidget);
      expect(find.text('سه'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('word-save')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('reader-text')))).read(progressProvider.notifier);
      expect(ctrl.state.leitnerBox.containsKey('three'), isTrue, reason: 'saved to the word list');
      await t.pump(const Duration(seconds: 3));

      // Persian translation toggle
      expect(find.byKey(const ValueKey('fa-0')), findsNothing);
      await t.tap(find.byKey(const ValueKey('toggle-fa')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('fa-0')), findsOneWidget);
      expect(t.takeException(), isNull);

      Future<void> passQuiz() async {
        await t.scrollUntilVisible(find.byKey(const ValueKey('start-quiz')), 300, scrollable: find.descendant(of: find.byKey(const ValueKey('reader-text')), matching: find.byType(Scrollable)).first);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const ValueKey('start-quiz')));
        await t.pump(const Duration(milliseconds: 500));
        while (find.byKey(const ValueKey('quiz-q')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('opt-0')));
          await t.pump(const Duration(seconds: 1));
          await t.pump(const Duration(milliseconds: 300));
        }
        expect(find.byKey(const ValueKey('reader-celebrate')), findsOneWidget);
        expect(t.takeException(), isNull);
      }

      await passQuiz();
      expect(find.text('Chapter complete!'), findsOneWidget);
      expect(ctrl.readScore('a1_bus', 0), 100);
      await t.tap(find.text('Continue').first);
      await settle();
      expect(find.text('Chapter 2 of 2  ·  A1'), findsOneWidget);
      await passQuiz();
      expect(find.text('Book finished!'), findsOneWidget);
      expect(ctrl.bookDone('a1_bus'), isTrue);
      expect(ctrl.badgesEarned, contains('book1'));
      router.go('/library');
      await settle();
      expect(find.byKey(const ValueKey('finished-a1_bus')), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
    });
  });
}
