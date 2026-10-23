import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/legal/legal_screen.dart';
import 'package:british_life/features/premium/certificate_screen.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Legal fixes (docs/LEGAL_REVIEW.md): privacy/terms screens, certificate wording, pack disclaimers, no risky claims.
void main() {
  test('privacy policy is accurate and bilingual; no risky claims in the app', () {
    final all = [privacyDoc, termsDoc, aboutDoc].expand((d) => d.sections).toList();
    for (final (h, en, fa) in all) {
      expect(en, isNotEmpty, reason: h);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(fa), isTrue, reason: '$h has Persian');
    }
    final p = privacyDoc.sections.map((s) => s.$2).join(' ');
    for (final must in ['Google in Chrome', 'Apple in Safari', 'GitHub Pages', 'no analytics', 'only in your browser', '[BUSINESS NAME]', '[CONTACT EMAIL]', 'ico.org.uk']) {
      expect(p.toLowerCase(), contains(must.toLowerCase()), reason: must);
    }
    final t = termsDoc.sections.map((s) => s.$2).join(' ');
    for (final must in ['not an accredited qualification', 'DVSA', 'Home Office', 'England and Wales']) {
      expect(t.toLowerCase(), contains(must.toLowerCase()), reason: must);
    }
    expect(CertificateScreen.disclaimer, startsWith('Not an accredited qualification. CEFR level is an indication only.'));
    // No "certify", "official" or "nothing is sent" claims anywhere in the UI code.
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      expect(RegExp(r'certify|nothing is recorded or sent|Everything stays on the device|\bOfficial\b').hasMatch(src), isFalse, reason: f.path);
      expect(RegExp(r'Duolingo', caseSensitive: false).hasMatch(src), isFalse, reason: f.path);
    }
    expect(File('../IMAGE_PROMPTS.md').readAsStringSync().contains('with roundel'), isFalse);
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
    testWidgets('legal tabs, certificate disclaimer and the nursery pack note render without overflow', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, unlockAll: true, missionsDone: {'pref:chapter': '99'}).encode();
      await t.pumpWidget(ProviderScope(overrides: [progressStoreProvider.overrideWithValue(store)], child: const BritishLifeApp()));
      for (var i = 0; i < 40 && find.text('New Life UK').evaluate().isEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> go(String r) async {
        router.go(r);
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 400));
        }
        for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull, reason: r);
      }

      await go('/legal');
      expect(find.text('Privacy Policy'), findsOneWidget);
      for (final tab in ['terms', 'about', 'privacy']) {
        await t.tap(find.byKey(ValueKey('legal-tab-$tab')));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.byKey(ValueKey('legal-$tab')), findsOneWidget);
        expect(t.takeException(), isNull, reason: tab);
      }
      await go('/certificate/1');
      expect(find.byKey(const ValueKey('cert-disclaimer'), skipOffstage: false), findsOneWidget);
      expect(find.textContaining('certify', skipOffstage: false), findsNothing);
      await go('/pack/nursery');
      expect(find.byKey(const ValueKey('pack-disclaimer'), skipOffstage: false), findsOneWidget);
      expect(find.textContaining('EYFS framework (England only)', skipOffstage: false), findsOneWidget);
      router.go('/');
      await t.pump(const Duration(seconds: 2));
    });
  });

  test('AI disclosure: voices are labelled AI-generated in the menu and in About (Azure TTS code of conduct)', () {
    final menu = File('lib/features/map/map_home.dart').readAsStringSync();
    expect(menu, contains("ValueKey('ai-voices-note')"));
    expect(menu, contains('Voices are AI-generated (text-to-speech), not real people.'));
    final legal = File('lib/features/legal/legal_screen.dart').readAsStringSync();
    expect(legal, contains('All voices are AI-generated'));
    expect(File('tool/render_voices.py').readAsStringSync(), isNot(contains('AZURE_SPEECH_KEY_1=')), reason: 'no key in the repo');
  });
}
