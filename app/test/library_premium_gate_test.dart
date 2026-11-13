import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/route_guard.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/billing/entitlements.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/library/library_data.dart';
import 'package:british_life/features/library/library_gate.dart';
import 'package:british_life/features/library/reading_state.dart';
import 'package:british_life/features/premium/premium_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Option B library gate: A1/A2 shelves and the first book of every section stay free;
/// the rest lock only when PremiumConfig.betaFree is false and the book is not already started.
/// The shipped build keeps betaFree = true, so nothing locks there.
void main() {
  final books = Library.parse(File('assets/data/library.json').readAsStringSync());
  Book book(String id) => books.firstWhere((b) => b.id == id);

  ProgressController ctrlOf({Map<String, String> prefs = const {}}) {
    final p = UserProgress(onboarded: true, missionsDone: prefs);
    final store = MemoryProgressStore()..data = p.encode();
    final c = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    return c.read(progressProvider.notifier);
  }

  setUp(() => BL.useGoogleFonts = false);
  tearDown(() {
    PremiumConfig.betaFree = true;
    Entitlements.paidBuild = false;
    Entitlements.applyServerState(premium: false, packs: {});
  });

  test('A1/A2 books and the first book of every section are free; later B1+ books are not', () {
    for (final b in books) {
      if (b.level == 'A1' || b.level == 'A2') {
        expect(LibraryGate.bookFree(b, books), isTrue, reason: b.id);
      }
    }
    for (final cat in Library.categories.map((c) => c.id)) {
      final shelf = LibraryGate.sectionSorted(books, cat);
      expect(shelf, isNotEmpty, reason: cat);
      expect(LibraryGate.bookFree(shelf.first, books), isTrue, reason: 'first of $cat (${shelf.first.id})');
      // Sorted by level, then id.
      for (var i = 1; i < shelf.length; i++) {
        expect(shelf[i].levelIndex, greaterThanOrEqualTo(shelf[i - 1].levelIndex), reason: '${shelf[i].id} after ${shelf[i - 1].id}');
        if (shelf[i].level == shelf[i - 1].level) {
          expect(shelf[i].id.compareTo(shelf[i - 1].id), greaterThan(0));
        }
      }
    }
    expect(LibraryGate.bookFree(book('b1_flood'), books), isFalse);
    expect(LibraryGate.bookFree(book('c1_climate'), books), isFalse);
    expect(LibraryGate.bookFree(book('b1_history'), books), isFalse);
  });

  test('betaFree = true (as shipped): nothing is premium-locked', () {
    PremiumConfig.betaFree = true;
    final c = ctrlOf();
    expect(c.paywallOn, isFalse);
    for (final b in books) {
      expect(LibraryGate.isPremiumLocked(c, b, books), isFalse, reason: b.id);
    }
    expect(guardLocation(Uri.parse('/read/b1_flood'), c, null, books: books), isNull);
  });

  test('betaFree = false: later B1+ books lock; A1/A2, first-of-section, started books and Premium stay open', () {
    PremiumConfig.betaFree = false;
    final c = ctrlOf();
    expect(c.sellsContent, isTrue);
    expect(c.paywallOn, isTrue);
    expect(c.hasPremium, isFalse);

    expect(LibraryGate.isPremiumLocked(c, book('a1_bus'), books), isFalse);
    expect(LibraryGate.isPremiumLocked(c, book('a2_giant'), books), isFalse);
    for (final cat in Library.categories.map((c) => c.id)) {
      final first = LibraryGate.sectionSorted(books, cat).first;
      expect(LibraryGate.isPremiumLocked(c, first, books), isFalse, reason: first.id);
    }
    expect(LibraryGate.isPremiumLocked(c, book('b1_flood'), books), isTrue);
    expect(guardLocation(Uri.parse('/library'), c, null, books: books), isNull);
    expect(guardLocation(Uri.parse('/read/a1_bus'), c, null, books: books), isNull);
    expect(guardLocation(Uri.parse('/read/b1_flood'), c, null, books: books), '/premium?reason=library');

    c.saveReadPos(book('b1_flood'), 0, 0);
    expect(c.bookStarted(book('b1_flood')), isTrue);
    expect(LibraryGate.isPremiumLocked(c, book('b1_flood'), books), isFalse);
    expect(guardLocation(Uri.parse('/read/b1_flood'), c, null, books: books), isNull);
  });

  test('betaFree = false: a verified Premium entitlement unlocks the rest of the Library', () {
    PremiumConfig.betaFree = false;
    Entitlements.paidBuild = true;
    Entitlements.applyServerState(premium: true, packs: {});
    final c = ctrlOf();
    expect(c.hasPremium, isTrue);
    expect(c.paywallOn, isFalse);
    expect(LibraryGate.isPremiumLocked(c, book('b1_flood'), books), isFalse);
    expect(guardLocation(Uri.parse('/read/b1_flood'), c, null, books: books), isNull);
  });

  test('paywall copy, always-free list and perks mention the library rule (EN+FA)', () {
    expect(PaywallCopy.reasons['library']!.$1, contains('A1 and A2'));
    expect(PaywallCopy.reasons['library']!.$2, contains('قفسه‌های A1 و A2'));
    expect(PremiumConfig.alwaysFree.any((e) => e.$1.contains('first book of every section') && e.$2.contains('نخستین کتاب هر بخش')), isTrue);
    expect(PremiumConfig.perks.any((e) => e.$1.contains('rest of the Library') && e.$2.contains('بقیهٔ کتابخانه')), isTrue);
    expect(LibraryGate.premiumNotice.$1, contains('already started'));
    expect(LibraryGate.premiumNotice.$2, contains('شروع کرده‌ای'));
    expect(LibraryGate.premiumRibbon.$1, 'Premium');
    expect(LibraryGate.premiumRibbon.$2, 'ویژه');
  });

  group('library premium widgets at 375x667 (betaFree = false)', () {
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

    testWidgets('locked spine shows a ribbon; /read of a paid book goes to the paywall; a free book still opens', (t) async {
      PremiumConfig.betaFree = false;
      addTearDown(() => PremiumConfig.betaFree = true);
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));

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

      // Deep link to a later B1 book is sent to the paywall, not the reader.
      router.go('/read/b1_flood');
      await settle();
      expect(find.byKey(const ValueKey('reader-text')), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/premium?reason=library');

      // The library hall itself stays open. A locked fiction spine carries a ribbon;
      // pulling it out offers Premium, not Start reading.
      router.go('/library');
      await settle();
      await t.tap(find.byKey(const ValueKey('sign-fiction')));
      await settle();
      final aisles = find.byKey(const ValueKey('library-list'));
      await t.scrollUntilVisible(find.byKey(const ValueKey('book-b1_flood')), 300, scrollable: find.descendant(of: aisles, matching: find.byType(Scrollable)).first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('lock-b1_flood')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('book-b1_flood')));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('booksheet-b1_flood')), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-cta')), findsOneWidget);
      expect(find.byKey(const ValueKey('book-read')), findsNothing);
      await t.tapAt(const Offset(5, 5));
      await t.pump(const Duration(milliseconds: 600));

      // An A1 book on the same shelves has no ribbon and still opens.
      await t.scrollUntilVisible(find.byKey(const ValueKey('book-a1_lostkey')), -300, scrollable: find.descendant(of: aisles, matching: find.byType(Scrollable)).first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('lock-a1_lostkey')), findsNothing);
      await t.tap(find.byKey(const ValueKey('book-a1_lostkey')));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('booksheet-a1_lostkey')), findsOneWidget);
      expect(find.byKey(const ValueKey('book-read')), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-cta')), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
