import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/route_guard.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/billing/device_allowance.dart';
import 'package:british_life/core/billing/entitlements.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/learner_profile.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/premium/premium_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hardening t300/t301: one central guard for every content route and deep link (Android and web), a device-wide
/// HMAC-signed daily allowance, and no premium decision resting on a value the user can trivially edit.
/// Every case runs with PremiumConfig.betaFree = false; shipped builds keep betaFree = true.
void main() {
  final course = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()));
  Unit unit(String id) => course.units.firstWhere((u) => u.id == id);
  final core = [for (var i = 1; i <= 10; i++) ...unit('U$i').lessons];
  final u51 = unit('U51').lessons;
  var now = DateTime(2026, 11, 12, 10);

  setUp(() {
    BL.useGoogleFonts = false;
    now = DateTime(2026, 11, 12, 10);
  });
  tearDown(() {
    PremiumConfig.betaFree = true;
    Entitlements.paidBuild = false;
    Entitlements.applyServerState(premium: false, packs: {});
    ProgressController.isWeb = false;
  });

  (ProgressController, ProviderContainer, DeviceAllowance) ctrlWith({
    Iterable<Lesson> done = const [],
    Map<String, String> extra = const {},
    bool unlockAll = false,
    bool ownerMode = false,
    DeviceAllowance? dev,
    MemoryProgressStore? store,
  }) {
    final a = dev ?? DeviceAllowance.memory();
    final p = UserProgress(
      onboarded: true,
      unlockAll: unlockAll,
      ownerMode: ownerMode,
      completedScenes: {for (final l in done) ...l.sceneIds},
      missionsDone: {for (final l in done) 'course:${l.id}': '100', ...extra},
    );
    final s = store ?? (MemoryProgressStore()..data = p.encode());
    final c = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(s), clockProvider.overrideWithValue(() => now), deviceAllowanceProvider.overrideWithValue(a)]);
    addTearDown(c.dispose);
    return (c.read(progressProvider.notifier), c, a);
  }

  String? guard(ProgressController c, String path) => guardLocation(Uri.parse(path), c, course);

  group('central route guard (betaFree = false)', () {
    test('betaFree = true: nothing is redirected', () {
      final (c, _, _) = ctrlWith();
      for (final r in ['/lesson/${u51[1].id}', '/chat/${u51[1].sceneIds.first}', '/lifeuk/mock', '/theory/speed', '/driving/petrol', '/practice/U51']) {
        expect(guard(c, r), isNull, reason: r);
      }
    });

    for (final web in [false, true]) {
      final label = web ? 'web (kIsWeb override)' : 'android';
      test('$label: lesson, story (chat) and practice deep links pass the free-zone / allowance check', () {
        PremiumConfig.betaFree = false;
        ProgressController.isWeb = web;
        final (c, _, a) = ctrlWith(done: core);
        // Free zone: always open, never spends the allowance.
        expect(guard(c, '/lesson/${core.last.id}'), isNull);
        expect(guard(c, '/chat/${core.last.sceneIds.first}'), isNull);
        expect(guard(c, '/practice/${core.last.id}'), isNull);
        expect(c.freeLessonsLeftToday, 1);
        // Viewing the lesson page does not spend; starting its story does (once).
        expect(guard(c, '/lesson/${u51[0].id}'), isNull);
        expect(c.freeLessonsLeftToday, 1);
        expect(guard(c, '/chat/${u51[0].sceneIds.first}__as_x'), isNull);
        expect(a.claimed(u51[0].id), isTrue);
        expect(c.freeLessonsLeftToday, 0);
        expect(guard(c, '/practice/${u51[0].id}'), isNull, reason: 'claimed lesson stays open');
        // A deep link to the next (sequence-locked) lesson goes back to the course.
        expect(guard(c, '/lesson/${u51[1].id}'), '/course');
        // Finish lesson 1: lesson 2 is in order but today's free lesson is spent.
        c.savePractice(u51[0].id, 100, storyScenes: u51[0].sceneIds);
        expect(guard(c, '/lesson/${u51[1].id}'), '/premium?reason=daily');
        expect(guard(c, '/chat/${u51[1].sceneIds.first}'), '/premium?reason=daily');
        expect(guard(c, '/practice/${u51[1].id}'), '/premium?reason=daily');
        expect(a.claimed(u51[1].id), isFalse);
        // Unit test of a unit not yet reached.
        expect(guard(c, '/practice/U52'), '/course');
        expect(guard(c, '/practice/mistakes'), isNull);
        // Premium (server-verified) opens it.
        Entitlements.applyServerState(premium: true, packs: {});
        expect(guard(c, '/chat/${u51[1].sceneIds.first}'), isNull);
      });

      test('$label: exam chapters, cards, quizzes, mocks and driving lessons', () {
        PremiumConfig.betaFree = false;
        ProgressController.isWeb = web;
        final (c, _, _) = ctrlWith(extra: {'luk:mocks': '1', 'thy:mocks': '1'});
        expect(guard(c, '/lifeuk/values'), isNull);
        expect(guard(c, '/lifeuk/values/quiz'), isNull);
        expect(guard(c, '/lifeuk/history'), '/premium?pack=lifeuk&reason=exam');
        expect(guard(c, '/lifeuk/history/cards'), '/premium?pack=lifeuk&reason=exam');
        expect(guard(c, '/lifeuk/mock'), '/premium?pack=lifeuk&reason=mock');
        expect(guard(c, '/theory/attitude/cards'), isNull);
        expect(guard(c, '/theory/speed/quiz'), '/premium?pack=theory&reason=exam');
        expect(guard(c, '/theory/mock'), '/premium?pack=theory&reason=mock');
        expect(guard(c, '/driving/cockpit'), isNull);
        expect(guard(c, '/driving/petrol'), '/premium?pack=theory&reason=exam');
        Entitlements.applyServerState(premium: false, packs: {'lifeuk'});
        expect(guard(c, '/lifeuk/history'), isNull);
        expect(guard(c, '/lifeuk/mock'), isNull);
        expect(guard(c, '/theory/speed'), isNotNull);
      });

      test('$label: career pack lessons and pack unit tests need the pack', () {
        PremiumConfig.betaFree = false;
        ProgressController.isWeb = web;
        final (c, _, _) = ctrlWith(done: core);
        final nur = course.pack('nursery')!;
        expect(guard(c, '/lesson/${nur.lessons.first.id}'), isNull, reason: 'free preview');
        expect(guard(c, '/lesson/${nur.lessons.elementAt(1).id}'), '/premium?pack=nursery');
        expect(guard(c, '/chat/${nur.lessons.elementAt(1).sceneIds.first}'), '/premium?pack=nursery');
        expect(guard(c, '/practice/${nur.units.first.id}'), '/premium?pack=nursery');
        Entitlements.applyServerState(premium: false, packs: {'nursery'});
        expect(guard(c, '/lesson/${nur.lessons.elementAt(1).id}'), isNull);
      });
    }

    test('free first chapters / lesson in the guard match the data files', () {
      final luk = jsonDecode(File('assets/data/lifeuk.json').readAsStringSync()) as Map;
      final thy = jsonDecode(File('assets/data/theory.json').readAsStringSync()) as Map;
      final drv = jsonDecode(File('assets/data/driving.json').readAsStringSync()) as Map;
      expect((luk['chapters'] as List).first['id'], RouteGuard.lifeukFree);
      expect((thy['chapters'] as List).first['id'], RouteGuard.theoryFree);
      expect((drv['lessons'] as List).first['id'], RouteGuard.drivingFree);
    });

    test('router: the guard is the GoRouter top-level redirect', () {
      expect(router.configuration.topRedirect, isNotNull);
    });
  });

  group('device-wide allowance', () {
    test('one allowance per DEVICE: switching or adding profiles gives no extra lesson', () async {
      PremiumConfig.betaFree = false;
      final dev = DeviceAllowance.memory();
      final (c, _, _) = ctrlWith(done: core, dev: dev);
      expect(c.claimDailyLesson(course, u51[0]), isTrue);
      final kid = await c.addProfile(displayName: 'Second', kind: ProfileKind.adult);
      await c.switchProfile(kid.id);
      expect(c.freeLessonsLeftToday, 0, reason: 'the second profile shares the device allowance');
      // A second app container on the same device (same secure storage) also sees it.
      final (c2, _, _) = ctrlWith(done: core, dev: dev);
      expect(c2.freeLessonsLeftToday, 0);
      expect(c2.claimDailyLesson(course, u51[1]), isFalse);
      expect(c2.lessonLock(course, u51[0]), isNot(LessonLock.daily), reason: 'a claimed lesson stays unlocked');
    });

    test('signed state round-trips; clock back grants nothing; next day refills', () async {
      final vault = MemoryAllowanceVault();
      final a = await DeviceAllowance.load(vault, now: now);
      expect(a.tampered, isFalse);
      expect(a.claim('l1', now, 1), isTrue);
      expect(a.claim('l2', now, 1), isFalse);
      await _settle();
      final b = await DeviceAllowance.load(vault, now: now);
      expect(b.tampered, isFalse);
      expect(b.claimed('l1'), isTrue);
      expect(b.claim('l2', now.subtract(const Duration(days: 3)), 1), isFalse, reason: 'clock moved back');
      expect(b.quotaDay(now.subtract(const Duration(days: 3))), '2026-11-12');
      expect(b.claim('l2', now.add(const Duration(days: 1)), 1), isTrue);
      await _settle();
      final c = await DeviceAllowance.load(vault, now: now);
      expect(c.claim('l3', now, 1), isFalse, reason: 'the last-seen time is persisted');
    });

    test('tampering: edited or deleted state costs today, never refills', () async {
      final vault = MemoryAllowanceVault();
      final a = await DeviceAllowance.load(vault, now: now);
      a.claim('l1', now.subtract(const Duration(days: 1)), 1);
      await _settle(); // writes are fire-and-forget
      // Edit the claims without the key (e.g. clear today's entry).
      final blob = jsonDecode(vault.data[DeviceAllowance.stateName]!) as Map<String, dynamic>;
      blob['s'] = jsonEncode({'c': <String, String>{}, 't': 0});
      vault.data[DeviceAllowance.stateName] = jsonEncode(blob);
      final b = await DeviceAllowance.load(vault, now: now);
      expect(b.tampered, isTrue);
      expect(b.claim('l2', now, 1), isFalse, reason: 'tamper spends today');
      // Delete only the state: also tampering.
      vault.data.remove(DeviceAllowance.stateName);
      final c = await DeviceAllowance.load(vault, now: now);
      expect(c.tampered, isTrue);
      expect(c.claim('l2', now, 1), isFalse);
      await _settle();
      // Delete only the key: state without its key is tampering too.
      vault.data.remove(DeviceAllowance.keyName);
      final d = await DeviceAllowance.load(vault, now: now);
      expect(d.tampered, isTrue);
      expect(d.claim('l2', now, 1), isFalse);
      expect(d.claim('l2', now.add(const Duration(days: 1)), 1), isTrue, reason: 'only costs a day');
      await _settle();
      // Garbage instead of JSON.
      vault.data[DeviceAllowance.stateName] = 'not json';
      expect((await DeviceAllowance.load(vault, now: now)).tampered, isTrue);
      // Unreadable storage: fail closed for today.
      final e = await DeviceAllowance.load(_BrokenVault(), now: now);
      expect(e.claim('l9', now, 1), isFalse);
    });

    test('clearing all app data (key and state together) is a fresh device: the one documented client-side limit', () async {
      final vault = MemoryAllowanceVault();
      (await DeviceAllowance.load(vault, now: now)).claim('l1', now, 1);
      await _settle();
      vault.data.clear();
      final a = await DeviceAllowance.load(vault, now: now);
      expect(a.tampered, isFalse);
      expect(a.claim('l2', now, 1), isTrue);
    });
  });

  group('no premium decision from user-editable values (before/after t300)', () {
    test('demo toggle, owner mode, pref:premium and pack:x=owned grant nothing once content is sold', () {
      final (c, _, _) = ctrlWith(done: core, unlockAll: true, ownerMode: true, extra: {'pref:premium': 'on', 'pack:nursery': 'owned', 'pack:lifeuk': 'owned', 'pack:theory': 'owned'});
      expect(c.hasPremium, isTrue, reason: 'free beta: demo opens everything');
      for (final web in [false, true]) {
        PremiumConfig.betaFree = false;
        ProgressController.isWeb = web;
        expect(c.hasPremium, isFalse);
        expect(c.packOwned(course.pack('nursery')!), isFalse);
        expect(c.examUnlocked('lifeuk') || c.examUnlocked('theory'), isFalse);
        expect(c.certificatesUnlocked || c.offlineVoicesUnlocked, isFalse);
        expect(guard(c, '/lifeuk/history'), isNotNull);
        // Demo/owner open the course order (sequence), never the daily allowance.
        c.claimDailyLesson(course, u51[0]);
        expect(c.lessonLock(course, u51[2]), LessonLock.daily);
      }
    });

    test('web: edited browser progress (scores / scenes) does not open lessons; only signed device claims do', () {
      PremiumConfig.betaFree = false;
      ProgressController.isWeb = true;
      final dev = DeviceAllowance.memory()..claim('zz', now, 9);
      final (c, _, _) = ctrlWith(done: [...core, u51[0], u51[1]], dev: dev);
      expect(c.lessonLock(course, u51[1]), LessonLock.daily, reason: 'scores in IndexedDB are editable on the web');
      ProgressController.isWeb = false; // Android: progress is AES-encrypted with a keystore-held key
      expect(c.lessonLock(course, u51[1]), LessonLock.open);
    });
  });

  group('screens', () {
    Future<void> boot(WidgetTester t, UserProgress p, DeviceAllowance dev) async {
      t.view.physicalSize = const Size(375, 1800) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = p.encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store), deviceAllowanceProvider.overrideWithValue(dev)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> go(WidgetTester t, String r) async {
      router.go(r);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 1));
      for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 200));
      }
      await t.pump(const Duration(milliseconds: 500));
    }

    Future<void> leave(WidgetTester t) async {
      router.go('/');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }

    for (final web in [false, true]) {
      testWidgets('${web ? 'web' : 'android'}: a deep link to a story beyond the allowance lands on the paywall${web ? ' with the Google Play link, no plans' : ''}', (t) async {
        final done = {
          for (final l in [...core, u51[0]]) 'course:${l.id}': '100',
        };
        await boot(
          t,
          UserProgress(
            onboarded: true,
            completedScenes: {
              for (final l in [...core, u51[0]]) ...l.sceneIds,
            },
            missionsDone: done,
          ),
          DeviceAllowance.memory()..claim(u51[0].id, DateTime.now(), 9),
        );
        PremiumConfig.betaFree = false;
        ProgressController.isWeb = web;
        await go(t, '/chat/${u51[1].sceneIds.first}');
        expect(router.routerDelegate.currentConfiguration.uri.toString(), '/premium?reason=daily');
        expect(find.byType(PremiumScreen), findsOneWidget);
        expect(find.textContaining('Today’s free lesson is done'), findsOneWidget);
        expect(find.byKey(const ValueKey('get-on-play')), web ? findsOneWidget : findsNothing);
        expect(find.byKey(const ValueKey('plan-yearly')), web ? findsNothing : findsOneWidget);
        expect(find.textContaining('دریافت از گوگل‌پلی'), web ? findsOneWidget : findsNothing);
        await leave(t);
      });
    }

    testWidgets('web under betaFree = true: nothing locks, the normal paywall stays', (t) async {
      await boot(t, const UserProgress(onboarded: true), DeviceAllowance.memory()..claim('zz', DateTime.now(), 9));
      ProgressController.isWeb = true;
      await go(t, '/lifeuk/mock');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/lifeuk/mock');
      await go(t, '/premium');
      expect(find.byKey(const ValueKey('get-on-play')), findsNothing);
      await leave(t);
    });
  });
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

class _BrokenVault implements AllowanceVault {
  @override
  Future<String?> read(String key) => Future.error(StateError('keystore'));
  @override
  Future<void> write(String key, String value) => Future.error(StateError('keystore'));
}
