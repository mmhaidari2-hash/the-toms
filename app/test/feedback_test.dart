import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/app_info.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/feedback/feedback_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 1×1 transparent PNG.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

Future<void> _boot(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 1800) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  router.go('/'); // the router is global: never start on the previous test's screen
  final store = MemoryProgressStore()..data = const UserProgress(onboarded: true).encode();
  await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
  for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _until(WidgetTester t, Finder f) async {
  for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 200));
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  // Real metrics (the default test font is a wide box font that fakes overflows).
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
  setUp(() {
    BL.useGoogleFonts = false;
    FeedbackCapture.last = null;
  });
  tearDown(() {
    FeedbackScreen.debugLaunch = null;
    FeedbackScreen.debugShare = null;
    FeedbackScreen.debugEmail = null;
  });

  test('support address is the marked placeholder (not configured); version matches pubspec', () {
    expect(SupportConfig.email, 'TODO_OWNER_SUPPORT_EMAIL');
    expect(SupportConfig.configured, isFalse);
    expect(SupportConfig.isConfigured('help@example.org'), isTrue);
    expect(SupportConfig.isConfigured('not an email'), isFalse);
    final v = RegExp(r'^version: (\S+)\+(\d+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(AppInfo.version, v.group(1));
    expect(AppInfo.build, int.parse(v.group(2)!));
  });

  test('report has category, version, platform, OS, locale and screen; mailto is encoded', () {
    const d = FeedbackDevice(platform: 'android', os: 'Android 14', locale: 'en-GB', appLang: 'fa', screen: '/course');
    final b = FeedbackReport.body(FeedbackKind.content, '  The audio says "colour" wrong & fast ', d);
    for (final s in ['The audio says', 'Category: Content error', 'App version: ${AppInfo.label}', 'Platform: android', 'OS version: Android 14', 'Locale: en-GB', 'Screen: /course']) {
      expect(b, contains(s));
    }
    final u = FeedbackReport.mailto('help@example.org', FeedbackKind.bug, b);
    expect(u.scheme, 'mailto');
    expect(u.path, 'help@example.org');
    expect(Uri.decodeComponent(u.query), contains('Screen: /course'));
    expect(u.toString(), isNot(contains(' ')));
  });

  testWidgets('not configured: preview shows everything, send says "Not configured yet" and launches nothing', (t) async {
    var launched = 0;
    FeedbackScreen.debugLaunch = (_) async => ++launched > 0;
    await _boot(t);
    router.go('/feedback?from=%2Fcourse');
    await _until(t, find.byKey(const ValueKey('fb-message')));
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('fb-review'))).onPressed, isNull, reason: 'empty message');
    await _tap(t, 'fb-kind-bug');
    await t.enterText(find.byKey(const ValueKey('fb-message')), 'The Next button does nothing');
    await t.pump();
    expect(find.byKey(const ValueKey('fb-shot')), findsNothing, reason: 'no screenshot captured → no option');
    await _tap(t, 'fb-review');
    final preview = t.widget<SelectableText>(find.byKey(const ValueKey('fb-preview'))).data!;
    expect(preview, contains('The Next button does nothing'));
    expect(preview, contains('Category: Bug'));
    expect(preview, contains('Screen: /course'));
    expect(preview, contains('OS version: '));
    expect(find.text('To: —'), findsOneWidget);
    expect(find.textContaining('Not configured yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('fb-not-configured')), findsOneWidget);
    final send = find.ancestor(of: find.textContaining('Not configured yet'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(t.widget<ButtonStyleButton>(send).onPressed, isNull);
    expect(launched, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('configured: only the button after review opens the mail app, with the previewed text', (t) async {
    final uris = <Uri>[];
    FeedbackScreen.debugEmail = 'help@example.org';
    FeedbackScreen.debugLaunch = (u) async {
      uris.add(u);
      return true;
    };
    await _boot(t);
    router.go('/feedback?from=%2Fleitner');
    await _until(t, find.byKey(const ValueKey('fb-message')));
    await t.enterText(find.byKey(const ValueKey('fb-message')), 'More Leitner cards please');
    await t.pump();
    await _tap(t, 'fb-review');
    expect(uris, isEmpty);
    expect(find.text('To: help@example.org'), findsOneWidget);
    await _tap(t, 'fb-send');
    await t.pump(const Duration(milliseconds: 300));
    expect(uris, hasLength(1));
    final q = Uri.decodeComponent(uris.single.query);
    expect(uris.single.path, 'help@example.org');
    expect(q, contains('More Leitner cards please'));
    expect(q, contains('Category: Suggestion'));
    expect(q, contains('Screen: /leitner'));
    expect(find.textContaining('check it and press send there'), findsOneWidget);
  });

  testWidgets('optional screenshot: off by default; when ticked it is previewed and shared with the report', (t) async {
    final shared = <(String, String, Uint8List)>[];
    FeedbackScreen.debugEmail = 'help@example.org';
    FeedbackScreen.debugLaunch = (_) async => fail('mailto must not be used with a screenshot');
    FeedbackScreen.debugShare = (text, subject, png) async {
      shared.add((text, subject, png));
      return true;
    };
    await _boot(t);
    FeedbackCapture.last = _png;
    router.go('/feedback?from=%2F');
    await _until(t, find.byKey(const ValueKey('fb-message')));
    expect(t.widget<CheckboxListTile>(find.byKey(const ValueKey('fb-shot'))).value, isFalse);
    await t.enterText(find.byKey(const ValueKey('fb-message')), 'Typo on this screen');
    await t.pump();
    await _tap(t, 'fb-kind-content');
    await _tap(t, 'fb-shot');
    expect(find.byKey(const ValueKey('fb-shot-preview')), findsOneWidget);
    await _tap(t, 'fb-review');
    expect(t.widget<SelectableText>(find.byKey(const ValueKey('fb-preview'))).data, contains('Screenshot: attached'));
    await _tap(t, 'fb-send');
    await t.pump(const Duration(milliseconds: 300));
    expect(shared, hasLength(1));
    expect(shared.single.$1, startsWith('To: help@example.org'));
    expect(shared.single.$1, contains('Category: Content error'));
    expect(shared.single.$3, _png);
  });

  testWidgets('menu has Feedback & bug report and it opens the box', (t) async {
    await _boot(t);
    await t.tap(find.byKey(const ValueKey('menu')));
    await t.pump(const Duration(milliseconds: 600));
    final m = find.byKey(const ValueKey('menu-#feedback'), skipOffstage: false);
    expect(m, findsOneWidget);
    await t.ensureVisible(m);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(m);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await _until(t, find.byKey(const ValueKey('feedback')));
    expect(find.byKey(const ValueKey('feedback')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
