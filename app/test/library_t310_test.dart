import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/device_tts.dart';
import 'package:british_life/features/grammar/grammar_data.dart';
import 'package:british_life/features/library/library_data.dart';
import 'package:british_life/features/library/library_gate.dart';
import 'package:british_life/features/library/library_screen.dart';
import 'package:british_life/features/library/reading_state.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device voice that records what it was asked to say and keeps "speaking" until stopped.
class FakeTts implements DeviceTtsBackend {
  bool has;
  FakeTts({this.has = true});
  final said = <String>[];
  Completer<bool>? _c;
  @override
  Future<bool> available() async => has;
  @override
  Future<bool> speak(String text, double rate) {
    said.add(text);
    return (_c = Completer<bool>()).future;
  }

  @override
  Future<void> stop() async {
    if (_c != null && !_c!.isCompleted) _c!.complete(false);
  }
}

ProgressController freshCtrl([Map<String, String> done = const {}]) {
  final store = MemoryProgressStore()..data = UserProgress(onboarded: true, missionsDone: done).encode();
  return ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]).read(progressProvider.notifier);
}

/// t310 Library: book metadata and sources, the free dictionary, reading state, filters, the level notice,
/// the device-voice fallback and the reader / pull-out flows.
void main() {
  final books = Library.parse(File('assets/data/library.json').readAsStringSync());
  Book book(String id) => books.firstWhere((b) => b.id == id);

  test('science, biography and reference each have several books across levels', () {
    for (final id in ['science', 'biography', 'reference']) {
      final shelf = books.where((b) => b.category == id).toList();
      expect(shelf.length, greaterThanOrEqualTo(4), reason: id);
      expect({for (final b in shelf) b.level}.length, greaterThanOrEqualTo(3), reason: '$id spans levels');
      for (final b in shelf.where((b) => b.deviceVoice)) {
        expect(b.source, isNotEmpty, reason: b.id);
        expect(b.chapters.length, greaterThanOrEqualTo(3), reason: b.id);
        expect(b.blurbFa, isNotEmpty, reason: b.id);
      }
    }
    expect(books.length, greaterThanOrEqualTo(70));
    expect(books.where((b) => b.category == 'history').length, greaterThanOrEqualTo(4), reason: 'history shelf');
    expect(books.where((b) => b.category == 'poetry').length, greaterThanOrEqualTo(4), reason: 'poetry shelf');
    expect(books.any((b) => b.category == 'science' && b.level == 'C1'), isTrue, reason: 'C1 science');
    expect(books.any((b) => b.category == 'children' && b.level == 'A2'), isTrue, reason: 'A2 children');
    expect(books.any((b) => b.category == 'biography' && b.level == 'A1'), isTrue, reason: 'A1 biography');
    expect(books.any((b) => b.category == 'reference' && b.level == 'A1'), isTrue, reason: 'A1 reference');
    expect(books.any((b) => b.category == 'uklife' && b.level == 'A1'), isTrue, reason: 'A1 UK life');
  });

  test('every book is shelved in a known section; every section has books; new books carry sources', () {
    final ids = Library.categories.map((c) => c.id).toSet();
    expect(ids, containsAll(['fiction', 'children', 'poetry', 'history', 'science', 'biography', 'uklife', 'reference']));
    for (final b in books) {
      expect(ids, contains(b.category), reason: '${b.id} section');
      expect(Library.dewey[b.category] ?? '', isNotEmpty, reason: '${b.id} shelf mark');
      expect(b.minutes, greaterThan(0));
    }
    for (final id in ids) {
      expect(books.where((b) => b.category == id), isNotEmpty, reason: 'section $id is empty');
    }
    expect(books.length, greaterThanOrEqualTo(44));
    for (final b in books.where((b) => b.deviceVoice)) {
      expect(b.source, isNotEmpty, reason: '${b.id} records where its text comes from');
      expect(b.vocab, isNotEmpty, reason: '${b.id} new-word list');
      for (final k in b.vocab) {
        expect(b.gloss[k] ?? '', isNotEmpty, reason: '${b.id} vocab "$k" has Persian');
      }
    }
  });

  test('public-domain classics: every named author died 70+ years ago (UK term); no Wodehouse', () {
    final cutoff = DateTime.now().year - 71; // died in or before this year → UK PD from 1 Jan
    final died = RegExp(r'(?:–|-|d\. )(\d{4})');
    for (final b in books.where((b) => b.source.contains('Gutenberg') || b.source.contains('Original text'))) {
      final years = died.allMatches('${b.author} ${b.source}').map((m) => int.parse(m.group(1)!)).toList();
      expect(years, isNotEmpty, reason: '${b.id}: author death year recorded');
      for (final y in years) {
        expect(y, lessThanOrEqualTo(cutoff), reason: '${b.id}: died $y');
      }
      expect(b.source, contains('Public domain in the UK'), reason: b.id);
    }
    expect(books.any((b) => '${b.author} ${b.title} ${b.source}'.contains('Wodehouse')), isFalse, reason: 'Wodehouse died 1975');
    expect(books.where((b) => b.original).length, greaterThanOrEqualTo(3), reason: 'original-text editions');
  });

  test('free offline dictionary: Open English WordNet (CC BY 4.0) entries for book words', () {
    final raw = File('assets/data/library_dict.json').readAsStringSync();
    final dict = LibraryDict.parse(raw);
    expect((jsonDecode(raw) as Map)['licence'] ?? (jsonDecode(raw) as Map)['license'] ?? LibraryDict.attribution, contains('CC BY 4.0'));
    expect(dict.entries.length, greaterThan(1500));
    for (final w in ['garden', 'happy', 'castle']) {
      final s = dict.of(w);
      expect(s, isNotEmpty, reason: w);
      expect(s.first.pos, isNotEmpty);
      expect(s.first.def, isNotEmpty);
    }
    expect(dict.of('zzzz-not-a-word'), isEmpty);
  });

  test('reading state: exact resume place, furthest point, percent, last book', () {
    final c = freshCtrl();
    final b = book('a2_giant');
    expect(c.readPos(b.id), isNull);
    expect(c.readPercent(b), 0);
    expect(c.bookStarted(b), isFalse);
    c.saveReadPos(b, 1, 2);
    expect(c.readPos(b.id), (1, 2));
    expect(c.lastBook, b.id);
    final g = globalIndex(b, 1, 2) + 1;
    expect(c.readMax(b.id), g);
    expect(c.readPercent(b), (g * 100 / b.sentenceCount).floor());
    expect(c.bookStarted(b), isTrue);
    // Going back keeps the furthest point; out-of-range positions are clamped.
    c.saveReadPos(b, 0, 0);
    expect(c.readPos(b.id), (0, 0));
    expect(c.readMax(b.id), g);
    c.saveReadPos(b, 99, 99);
    expect(c.readPos(b.id), (b.chapters.length - 1, b.chapters.last.sentences.length - 1));
    expect(c.readPercent(b), 99, reason: 'only a finished book shows 100');
    for (var i = 0; i < b.chapters.length; i++) {
      c.saveChapter(b.id, i, 100, b.chapters.length);
    }
    expect(c.readPercent(b), 100);
  });

  test('reader settings are clamped and remembered', () {
    final c = freshCtrl();
    expect(c.readerFont, 19);
    expect(c.readerLine, 1.5);
    expect(c.readerTheme, ReaderTheme.light);
    c.setPref('libFont', '40');
    c.setPref('libLine', '0.5');
    c.setPref('libTheme', 'sepia');
    expect(c.readerFont, 30);
    expect(c.readerLine, 1.2);
    expect(c.readerTheme.id, 'sepia');
    c.setPref('libTheme', 'nonsense');
    expect(c.readerTheme, ReaderTheme.light);
  });

  test('level notice: higher books are "above your level", never locked', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
    final pc = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    final ctrl = pc.read(progressProvider.notifier);
    final content = await pc.read(contentProvider.future);
    final topics = Grammar.parse(File('assets/data/grammar.json').readAsStringSync());
    final gate = LibraryGate(ctrl, content, topics, books);
    expect(gate.aboveLevel(book('a1_bus')), isFalse);
    expect(gate.aboveLevel(book('c1_giant')), isTrue);
    expect(LibraryGate.aboveNotice('C1').$1, contains('above your current level (C1)'));
    expect(LibraryGate.aboveNotice('C1').$2, isNotEmpty);
  });

  test('shelf search, filters and sort', () {
    final c = freshCtrl();
    final poetry = filterBooks(books, c, section: 'poetry');
    expect(poetry.map((b) => b.id), containsAll(['b1_firstpoems', 'c1_poems']));
    expect(filterBooks(books, c, query: 'dickens').map((b) => b.id), contains('b1_carol'));
    expect(filterBooks(books, c, query: 'غول').map((b) => b.id), containsAll(['a2_giant', 'c1_giant']));
    expect(filterBooks(books, c, level: 'C1').every((b) => b.level == 'C1'), isTrue);
    final short = filterBooks(books, c, sort: 'short');
    for (var i = 1; i < short.length; i++) {
      expect(short[i].words, greaterThanOrEqualTo(short[i - 1].words));
    }
    final lv = filterBooks(books, c);
    for (var i = 1; i < lv.length; i++) {
      expect(lv[i].levelIndex, greaterThanOrEqualTo(lv[i - 1].levelIndex));
    }
    expect(filterBooks(books, c, status: 'reading'), isEmpty);
    c.saveReadPos(book('b2_boat'), 1, 0);
    expect(filterBooks(books, c, status: 'reading').map((b) => b.id), ['b2_boat']);
    expect(filterBooks(books, c, status: 'finished'), isEmpty);
    expect(filterBooks(books, c, status: 'unread').length, books.length - 1);
  });

  test('device voice: only books without recorded clips use it; fake backend speaks', () async {
    expect(book('a1_bus').deviceVoice, isFalse, reason: 'recorded books keep their clips');
    expect(book('a2_giant').deviceVoice, isTrue);
    final f = FakeTts(has: false);
    DeviceTts.debugBackend = f;
    addTearDown(() => DeviceTts.debugBackend = null);
    expect(await DeviceTts.available, isFalse);
    f.has = true;
    expect(await DeviceTts.available, isTrue);
    final done = DeviceTts.speak('Hello there.');
    await DeviceTts.stop();
    expect(await done, isFalse, reason: 'stopped');
    expect(f.said, ['Hello there.']);
  });

  group('reader at 375x667', () {
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

    testWidgets('resume, device-voice narrator, settings, TOC, new words → Leitner', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final tts = FakeTts();
      DeviceTts.debugBackend = tts;
      addTearDown(() => DeviceTts.debugBackend = null);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99', 'pref:libPos:a2_giant': '2:1', 'pref:libMax:a2_giant': '20'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
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

      // Opening without a chapter resumes at the saved place (chapter 3).
      router.go('/read/a2_giant');
      await settle();
      expect(find.byKey(const ValueKey('reader-text')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('reader-where'))).data, contains('Chapter 3 of 4'));
      if (find.byKey(const ValueKey('above-level-close')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const ValueKey('above-level-close')));
        await t.pump(const Duration(milliseconds: 300));
      }

      // The narrator reads with the device voice (fake backend).
      await t.tap(find.byKey(const ValueKey('play')));
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 100));
      }
      final ch3 = book('a2_giant').chapters[2].sentences.map((s) => s.en).toList();
      expect(tts.said, isNotEmpty);
      expect(ch3, contains(tts.said.first));
      await t.tap(find.byKey(const ValueKey('play')));
      await t.pump(const Duration(milliseconds: 300));

      // Settings: theme is remembered.
      await t.tap(find.byKey(const ValueKey('reader-settings')));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('settings-sheet')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('theme-dark')));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byKey(const ValueKey('theme-dark')));
      await t.pump(const Duration(milliseconds: 300));
      final ctrl = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('reader-text')))).read(progressProvider.notifier);
      expect(ctrl.readerTheme.id, 'dark');
      Navigator.of(t.element(find.byKey(const ValueKey('settings-sheet')))).pop();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }

      // Table of contents jumps to chapter 1.
      await t.tap(find.byKey(const ValueKey('toc')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      expect(find.byKey(const ValueKey('toc-sheet')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('toc-0')));
      await settle();
      expect(t.widget<Text>(find.byKey(const ValueKey('reader-where'))).data, contains('Chapter 1 of 4'));
      expect(find.byKey(const ValueKey('device-voice-label')), findsOneWidget, reason: 'device voice is labelled');

      // Pull-out on the shelf: "You'll learn N new words" → send all to the Leitner box.
      router.go('/library');
      await settle();
      await t.tap(find.byKey(const ValueKey('sign-fiction')));
      await settle();
      final aisles = find.byKey(const ValueKey('library-list'));
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('book-a2_giant')),
        300,
        scrollable: find.descendant(of: aisles, matching: find.byType(Scrollable)).first,
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('book-a2_giant')));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('booksheet-a2_giant')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('new-words-open')));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byKey(const ValueKey('new-words-open')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      expect(find.byKey(const ValueKey('new-words-sheet')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('send-all')));
      await t.tap(find.byKey(const ValueKey('send-all')));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      final vocab = book('a2_giant').vocab;
      expect(vocab.every(ctrl.state.leitnerBox.containsKey), isTrue, reason: 'every new word is in the Leitner box');
      await t.pump(const Duration(seconds: 3));
    });
  });
}
