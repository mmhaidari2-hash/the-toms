import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/billing/billing.dart';
import 'package:british_life/core/billing/device_allowance.dart';
import 'package:british_life/core/billing/entitlements.dart';
import 'package:british_life/core/billing/offline_voices.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/course.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/core/platform/speech_io.dart';
import 'package:british_life/features/arrival/arrival_pack_data.dart';
import 'package:british_life/features/arrival/arrival_pack_screen.dart';
import 'package:british_life/features/arrival/arrival_prefetch_io.dart';
import 'package:british_life/features/course/lesson_screen.dart';
import 'package:british_life/features/premium/premium_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monetisation Option B (owner-approved 2026-11-12): free zone, daily allowance, entitlements, offline voices,
/// certificates, paywall copy. Every gate is exercised with PremiumConfig.betaFree = false; the shipped build keeps
/// betaFree = true, so nothing locks there.
void main() {
  final course = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()));
  Unit unit(String id) => course.units.firstWhere((u) => u.id == id);
  final core = [for (var i = 1; i <= 10; i++) ...unit('U$i').lessons];
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
    OfflineVoices.allowed = () => true;
  });

  (ProgressController, ProviderContainer) ctrlWith({int tier = 0, Iterable<Lesson> done = const [], Map<String, String> extra = const {}, Iterable<String> scenes = const [], bool unlockAll = false, bool ownerMode = false, bool spentToday = false, Map<String, DateTime> claimed = const {}, DeviceAllowance? allowance}) {
    final dev = allowance ?? DeviceAllowance.memory();
    claimed.forEach((id, at) => dev.claim(id, at, 99));
    if (spentToday) dev.claim('zz_spent', now, 99);
    final p = UserProgress(
      onboarded: true,
      startTier: tier,
      unlockAll: unlockAll,
      ownerMode: ownerMode,
      completedScenes: {for (final l in done) ...l.sceneIds, ...scenes},
      missionsDone: {for (final l in done) 'course:${l.id}': '100', ...extra},
    );
    final store = MemoryProgressStore()..data = p.encode();
    final c = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => now), deviceAllowanceProvider.overrideWithValue(dev)]);
    addTearDown(c.dispose);
    return (c.read(progressProvider.notifier), c);
  }

  group('beta build (betaFree = true, as shipped)', () {
    test('nothing locks: no daily limit, certificates, offline voices, packs and exams all open', () {
      final (c, _) = ctrlWith(done: core, spentToday: true, extra: {'thy:mocks': '3', 'luk:mocks': '2'});
      expect(c.sellsContent, isFalse);
      expect(c.paywallOn, isFalse);
      expect(c.lessonOpen(course, unit('U51').lessons.first), isTrue);
      expect(c.certificatesUnlocked && c.offlineVoicesUnlocked, isTrue);
      expect(c.examChapterOpen('lifeuk', 3) && c.examMockOpen('theory') && c.drivingLessonOpen(9), isTrue);
      final homes = course.pack('homes')!, nursery = course.pack('nursery')!;
      expect(c.packOwned(homes) && c.packOwned(nursery), isTrue);
    });
  });

  group('paid limits (betaFree = false)', () {
    setUp(() => PremiumConfig.betaFree = false);

    test('free zone: U1–U10 and the first unit of every level (U11, U21, U31, U41)', () {
      final (c, _) = ctrlWith();
      final free = course.units.where((u) => c.inFreeZone(course, u)).map((u) => u.id).toList();
      expect(free, ['U1', 'U2', 'U3', 'U4', 'U5', 'U6', 'U7', 'U8', 'U9', 'U10', 'U11', 'U21', 'U31', 'U41']);
    });

    test('free-zone lessons never use the daily allowance, even when today\'s lesson is spent', () {
      for (var k = 0; k < core.length; k++) {
        final (c, _) = ctrlWith(done: core.take(k), spentToday: true);
        expect(c.freeLessonsLeftToday, 0);
        expect(c.lessonLock(course, core[k]), LessonLock.open, reason: core[k].id);
        expect(c.needsDailyClaim(course, core[k]), isFalse);
      }
    });

    test('placement at B1: the first unit of B1 is free; the second unit uses the daily allowance', () {
      final (c, _) = ctrlWith(tier: 2, spentToday: true);
      expect(c.currentLevel(course), 3);
      final u21 = unit('U21').lessons, u22 = unit('U22').lessons;
      expect(c.lessonLock(course, u21.first), LessonLock.open);
      final (c2, _) = ctrlWith(tier: 2, done: u21, spentToday: true);
      expect(c2.lessonLock(course, u22.first), LessonLock.daily);
    });

    test('daily allowance: one new lesson per local day, review free, date rollover, clock-back cannot refill', () {
      final (c, _) = ctrlWith(done: core);
      final u51 = unit('U51').lessons;
      expect(c.freeLessonsLeftToday, 1);
      expect(c.lessonLock(course, u51[0]), LessonLock.open);
      expect(c.claimDailyLesson(course, u51[0]), isTrue);
      expect(c.freeLessonsLeftToday, 0);
      expect(c.lessonLock(course, u51[0]), LessonLock.open, reason: 'the claimed lesson stays open');
      // Finish it: lesson 2 is next in order but today's free lesson is used.
      c.savePractice(u51[0].id, 100, storyScenes: u51[0].sceneIds);
      expect(c.lessonDone(u51[0]), isTrue);
      expect(c.lessonLock(course, u51[1]), LessonLock.daily);
      expect(c.claimDailyLesson(course, u51[1]), isFalse);
      // Reviewing finished lessons is always free.
      expect(c.lessonLock(course, u51[0]), LessonLock.open);
      expect(c.lessonLock(course, core.last), LessonLock.open);
      // Next local day: a new free lesson.
      now = DateTime(2026, 11, 13, 0, 5);
      expect(c.freeLessonsLeftToday, 1);
      expect(c.lessonLock(course, u51[1]), LessonLock.open);
      expect(c.claimDailyLesson(course, u51[1]), isTrue);
      // Turning the clock back to yesterday does not give the allowance again.
      now = DateTime(2026, 11, 12, 23);
      expect(c.quotaDay, '2026-11-13');
      expect(c.freeLessonsLeftToday, 0);
      expect(c.lessonLock(course, u51[1]), LessonLock.open, reason: 'claimed lesson stays open');
    });

    test('no paywall mid-lesson: a started or claimed lesson stays open after the allowance is used', () {
      final u51 = unit('U51').lessons;
      // Claimed yesterday and half-played; today\'s free lesson already spent elsewhere.
      final (c, _) = ctrlWith(done: core, claimed: {u51[0].id: now.subtract(const Duration(days: 1))}, spentToday: true);
      expect(c.freeLessonsLeftToday, 0);
      expect(c.lessonLock(course, u51[0]), LessonLock.open);
      // A lesson with a finished scene from before payments (beta users) never locks either.
      final u57 = unit('U57').lessons;
      final (c2, _) = ctrlWith(done: [...core, ...u51], scenes: [u57.first.sceneIds.first], spentToday: true);
      expect(c2.lessonStarted(u57.first), isTrue);
      expect(c2.dailyLessonOpen(course, u57.first), isTrue);
      // The conversation screen has no paywall code path at all.
      final chat = File('lib/features/conversation/conversation_screen.dart').readAsStringSync();
      expect(chat.contains('PremiumScreen') || chat.contains('/premium') || chat.contains('PaywallMomentCard'), isFalse);
    });

    test('web: same free zone and daily allowance as Android (t301)', () {
      ProgressController.isWeb = true;
      final (c, _) = ctrlWith(done: core, spentToday: true);
      expect(c.sellsContent, isTrue, reason: 't301: the web has the same free zone + allowance');
      expect(c.lessonLock(course, unit('U51').lessons.first), LessonLock.daily);
      expect(c.lessonLock(course, core.last), LessonLock.open);
      expect(c.certificatesUnlocked || c.offlineVoicesUnlocked, isFalse);
    });

    test('without Premium: certificates, offline voices, packs past lesson 1 and exams past the free part are locked', () {
      Entitlements.paidBuild = true;
      final (c, _) = ctrlWith(extra: {'luk:mocks': '1'});
      expect(c.paywallOn, isTrue);
      expect(c.certificatesUnlocked, isFalse);
      expect(c.offlineVoicesUnlocked, isFalse);
      for (final id in ['homes', 'nursery']) {
        expect(c.packOwned(course.pack(id)!), isFalse, reason: id);
      }
      expect(c.lessonLock(course, course.pack('nursery')!.lessons.first), LessonLock.open, reason: 'lesson 1 is a free preview');
      expect(c.lessonLock(course, course.pack('nursery')!.lessons.elementAt(1)), LessonLock.pack);
      expect(c.examChapterOpen('lifeuk', 0), isTrue);
      expect(c.examChapterOpen('lifeuk', 1), isFalse);
      expect(c.examMockOpen('lifeuk'), isFalse, reason: 'the one free mock is used');
      expect(c.examMockOpen('theory'), isTrue, reason: 'first theory mock is free');
      expect(c.drivingLessonOpen(0), isTrue);
      expect(c.drivingLessonOpen(1), isFalse);
    });

    test('each entitlement unlocks exactly its content (server-verified only)', () {
      Entitlements.paidBuild = true;
      final (c, _) = ctrlWith(done: core, spentToday: true, extra: {'luk:mocks': '1', 'thy:mocks': '1'});
      final u51 = unit('U51').lessons.first;
      final nursery2 = course.pack('nursery')!.lessons.elementAt(1);
      final homes = course.pack('homes')!;

      Entitlements.applyServerState(premium: false, packs: {'lifeuk'});
      expect(c.examUnlocked('lifeuk') && c.examChapterOpen('lifeuk', 3) && c.examMockOpen('lifeuk'), isTrue);
      expect(c.examUnlocked('theory') || c.drivingLessonOpen(1), isFalse);
      expect(c.lessonLock(course, u51), LessonLock.daily);

      Entitlements.applyServerState(premium: false, packs: {'theory'});
      expect(c.examChapterOpen('theory', 4) && c.examMockOpen('theory') && c.drivingLessonOpen(9), isTrue);
      expect(c.examUnlocked('lifeuk'), isFalse);

      Entitlements.applyServerState(premium: false, packs: {'nursery'});
      expect(c.lessonLock(course, nursery2), LessonLock.open);
      expect(c.packOwned(homes), isFalse, reason: 'Homes has no one-off product: Premium only');
      expect(c.certificatesUnlocked || c.offlineVoicesUnlocked, isFalse);

      // premium_monthly / premium_yearly / premium_lifetime all map to the RevenueCat "premium" entitlement.
      Entitlements.applyServerState(premium: true, packs: {});
      expect(c.paywallOn, isFalse);
      expect(c.lessonLock(course, u51), LessonLock.open);
      expect(c.certificatesUnlocked && c.offlineVoicesUnlocked, isTrue);
      expect(c.packOwned(homes) && c.packOwned(course.pack('nursery')!), isTrue);
      expect(c.examUnlocked('lifeuk') && c.examUnlocked('theory'), isTrue);
    });

    test('paid build: owner/demo mode still does not unlock paid content (rule unchanged)', () {
      Entitlements.paidBuild = true;
      final (c, _) = ctrlWith(done: core, unlockAll: true, ownerMode: true, spentToday: true, extra: {'pref:premium': 'on'});
      expect(c.hasPremium, isFalse);
      expect(c.paywallOn, isTrue);
      expect(c.lessonLock(course, unit('U51').lessons.first), LessonLock.daily);
      expect(c.certificatesUnlocked, isFalse);
    });
  });

  test('store trial period parsing (Play ISO-8601)', () {
    expect(Billing.periodDays('P7D'), 7);
    expect(Billing.periodDays('P1W'), 7);
    expect(Billing.periodDays(null), isNull);
    expect(Billing.periodDays('bogus'), isNull);
  });

  test('perks are accurate: no "Unlimited practice"; the certificate disclaimer says not official', () {
    final all = PremiumConfig.perks.map((p) => '${p.$1} ${p.$2}').join(' ');
    expect(all.toLowerCase(), isNot(contains('unlimited practice')));
    expect(all, isNot(contains('تمرین و مرور نامحدود')));
    expect(PremiumConfig.certNotOfficial, contains('not an official or government qualification'));
    expect(PremiumConfig.certNotOfficialFa, contains('مدرک رسمی یا دولتی نیست'));
    for (final r in ['daily', 'core', 'mock', 'download', 'cert', 'exam']) {
      expect(PaywallCopy.reasons[r]!.$1, isNotEmpty, reason: r);
      expect(PaywallCopy.reasons[r]!.$2, isNotEmpty, reason: r);
    }
    expect(PaywallCopy.reasons['download']!.$1, contains('Arrival'));
    expect(PremiumConfig.alwaysFree.first.$1, contains('offline download'));
  });

  group('offline voices', () {
    test('without the entitlement new clips go to the session folder; with it, to the persistent cache', () async {
      SpeechInput.debugSetVer('gatetest');
      OfflineVoices.allowed = () => false;
      final s = await SpeechInput.downloadTarget('k.mp3');
      expect(s.path, contains('/newlifeuk_audio/nl_session/'));
      OfflineVoices.allowed = () => true;
      final p = await SpeechInput.downloadTarget('k.mp3');
      expect(p.path, contains('/newlifeuk_audio/nl_audio_gatetest/'));
    });

    test('the Arrival pack download still fills the persistent cache without Premium', () async {
      SpeechInput.debugSetVer('gatearrival');
      OfflineVoices.allowed = () => false;
      final cache = await SpeechInput.clipCacheDirectory();
      final f = File('${cache.path}/gate_fixture.mp3');
      await f.writeAsBytes(List<int>.filled(80, 7), flush: true);
      addTearDown(() async {
        if (await f.exists()) await f.delete();
      });
      expect(await warmArrivalAudio(['gate_fixture']), 1);
      expect(cache.path, endsWith('/newlifeuk_audio/nl_audio_gatearrival'));
    });

    testWidgets('Arrival download button is never gated (paid build, no Premium)', (t) async {
      PremiumConfig.betaFree = false;
      Entitlements.paidBuild = true;
      final pack = ArrivalPack.parse(File('assets/data/arrival_pack.json').readAsStringSync());
      var called = 0;
      Future<int> warmer(List<String> keys, {void Function(double, int, int)? onProgress, bool Function()? shouldCancel}) async {
        called++;
        return keys.length;
      }

      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
      await t.pumpWidget(ProviderScope(
        overrides: [progressStoreProvider.overrideWithValue(store), arrivalPackProvider.overrideWith((ref) async => pack)],
        child: MaterialApp(home: ArrivalPackScreen(warmer: warmer)),
      ));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('arrival-download')));
      await t.pumpAndSettle();
      expect(called, 1);
      expect(find.byKey(const ValueKey('arrival-ready'), skipOffstage: false), findsOneWidget);
      expect(find.byType(PremiumScreen), findsNothing);
    });
  });

  group('screens', () {
    Future<void> boot(WidgetTester t, UserProgress p, {DeviceAllowance? allowance}) async {
      t.view.physicalSize = const Size(375, 1800) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = p.encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store), if (allowance != null) deviceAllowanceProvider.overrideWithValue(allowance)], child: const BritishLifeApp()));
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
      expect(t.takeException(), isNull, reason: r);
    }

    Future<void> leave(WidgetTester t) async {
      router.go('/');
      await t.pump(const Duration(seconds: 1));
      PremiumConfig.betaFree = true;
      Entitlements.paidBuild = false;
      Entitlements.applyServerState(premium: false, packs: {});
    }

    testWidgets('paywall copy EN+FA: store prices, trial terms, auto-renew, cancel link, close, restore', (t) async {
      final load = PremiumScreen.loadPrices;
      PremiumScreen.loadPrices = () async => {
            Entitlements.premiumYearly: const StorePrice('£31.00', trialDays: 7),
            Entitlements.premiumMonthly: const StorePrice('£5.10'),
            Entitlements.premiumLifetime: const StorePrice('£61.00'),
          };
      addTearDown(() => PremiumScreen.loadPrices = load);
      await boot(t, const UserProgress(onboarded: true));
      PremiumConfig.betaFree = false;
      Entitlements.paidBuild = true;
      await go(t, '/premium?reason=daily&pack=lifeuk');
      expect(find.byKey(const ValueKey('paywall-reason')), findsOneWidget);
      expect(find.textContaining('Today’s free lesson is done'), findsOneWidget);
      expect(find.textContaining('درس رایگان امروز تمام شد'), findsOneWidget);
      // Runtime store prices, never the placeholders; a product the store did not return is not given a price.
      expect(find.textContaining('£31.00 / year'), findsOneWidget);
      expect(find.textContaining('£5.10 / month'), findsOneWidget);
      expect(find.textContaining('£61.00'), findsOneWidget);
      expect(find.textContaining('Price in Google Play'), findsOneWidget, reason: 'pack_lifeuk missing from the store');
      expect(find.textContaining('£29.99'), findsNothing);
      expect(find.textContaining('7-day free trial'), findsOneWidget);
      expect(find.textContaining('Unlimited practice'), findsNothing);
      expect(find.byKey(const ValueKey('cert-not-official')), findsOneWidget);
      expect(find.textContaining('مدرک رسمی یا دولتی نیست'), findsOneWidget);
      expect(find.textContaining('renew automatically'), findsOneWidget);
      expect(find.textContaining('Cancel any time in Google Play'), findsWidgets);
      expect(find.textContaining('خودکار تمدید'), findsWidgets);
      expect(find.textContaining('without subscribing'), findsOneWidget);
      for (final k in ['paywall-close', 'restore-purchases', 'manage-subscription', 'plan-yearly', 'plan-monthly', 'plan-lifetime', 'plan-pack']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      // Yearly consent shows the full price, trial length and the date the trial would end.
      // The paywall is a SingleChildScrollView; the yearly plan can sit just below a tall
      // 1800px frame (centre was at y=1803), so scroll it into view like a real phone would.
      final yearly = find.byKey(const ValueKey('plan-yearly'));
      await t.ensureVisible(yearly);
      await t.pumpAndSettle();
      await t.tap(yearly);
      await t.pumpAndSettle();
      expect(find.textContaining('7-day free trial, then £31.00 a year'), findsOneWidget);
      expect(find.textContaining('the trial ends on ${PaywallCopy.date(DateTime.now().add(const Duration(days: 7)))}'), findsOneWidget);
      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();
      // A running trial shows its end date in the app.
      Entitlements.applyServerState(premium: true, packs: {}, trialEndsAt: DateTime(2026, 11, 19));
      await go(t, '/premium?reason=core');
      expect(find.byKey(const ValueKey('trial-ends')), findsOneWidget);
      expect(find.textContaining('19 Nov 2026'), findsWidgets);
      // Close button leaves the paywall.
      await t.tap(find.byKey(const ValueKey('paywall-close')));
      await t.pump();
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 2));
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      await leave(t);
    });

    testWidgets('daily limit: the lesson page becomes the paywall before anything starts; download needs Premium', (t) async {
      final done = {for (final l in core) 'course:${l.id}': '100'};
      final u51 = unit('U51').lessons;
      await boot(t, UserProgress(onboarded: true, completedScenes: {for (final l in core) ...l.sceneIds}, missionsDone: done), allowance: DeviceAllowance.memory()..claim('zz', DateTime.now(), 9));
      PremiumConfig.betaFree = false;
      Entitlements.paidBuild = true;
      await go(t, '/lesson/${u51.first.id}');
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.textContaining('Today’s free lesson is done'), findsOneWidget);
      // A free-zone lesson opens normally; its download button leads to the paywall without Premium.
      var warmed = 0;
      LessonScreen.warmer = (keys, {onProgress, shouldCancel}) async {
        warmed++;
        return keys.length;
      };
      addTearDown(() => LessonScreen.warmer = null);
      await go(t, '/lesson/${core.first.id}');
      expect(find.byKey(const ValueKey('lesson-start')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('lesson-download')));
      await t.pump(const Duration(seconds: 1));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('Offline voices are part of Premium'), findsOneWidget);
      expect(warmed, 0);
      // With Premium the same button downloads the lesson's clips.
      Entitlements.applyServerState(premium: true, packs: {});
      await go(t, '/lesson/${core.first.id}');
      await t.tap(find.byKey(const ValueKey('lesson-download')));
      await t.pump(const Duration(seconds: 1));
      expect(warmed, 1);
      expect(find.byType(PremiumScreen), findsNothing);
      await leave(t);
    });

    testWidgets('certificate: earned but locked without Premium; named certificate with Premium', (t) async {
      await boot(t, const UserProgress(onboarded: true, unlockAll: true));
      PremiumConfig.betaFree = false;
      Entitlements.paidBuild = true;
      await go(t, '/certificate/1');
      expect(find.byKey(const ValueKey('cert-earned')), findsOneWidget);
      expect(find.byKey(const ValueKey('paywall-moment-cert')), findsOneWidget);
      expect(find.byKey(const ValueKey('cert-name')), findsNothing);
      Entitlements.applyServerState(premium: true, packs: {});
      await go(t, '/certificate/2');
      expect(find.byKey(const ValueKey('cert-name')), findsOneWidget);
      await leave(t);
    });

    testWidgets('exams: chapter 1 and the first mock are free; later chapters show the paywall', (t) async {
      await boot(t, const UserProgress(onboarded: true));
      PremiumConfig.betaFree = false;
      Entitlements.paidBuild = true;
      await go(t, '/lifeuk/values');
      expect(find.byType(PremiumScreen), findsNothing);
      await go(t, '/lifeuk/history');
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.textContaining('Chapter 1 and one mock test are free'), findsOneWidget);
      await go(t, '/theory/mock');
      expect(find.byType(PremiumScreen), findsNothing, reason: 'first mock is free');
      await leave(t);
    });
  });
}
