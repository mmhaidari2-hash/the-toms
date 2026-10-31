import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/forms/forms_data.dart';
import 'package:british_life/features/shared/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UK Forms Practice Lab — content rules, validation, disclaimer, UI smoke.
void main() {
  final lab = FormsLab.parse(File('assets/data/forms_lab.json').readAsStringSync());

  test('four practice forms, practice-only disclaimers, HTTPS links to NHS/GOV.UK', () {
    expect(lab.forms.map((f) => f.id), ['gp_register', 'nhs111', 'council_tax', 'job_application']);
    expect(lab.disclaimerEn.toUpperCase(), contains('PRACTICE ONLY'));
    expect(lab.disclaimerFa.trim(), isNotEmpty);
    for (final f in lab.forms) {
      expect(f.titleFa.trim(), isNotEmpty, reason: f.id);
      expect(f.fields, isNotEmpty, reason: f.id);
      expect(f.official, isNotEmpty, reason: f.id);
      for (final l in f.official) {
        expect(l.url.startsWith('https://'), isTrue, reason: '${f.id} ${l.label}');
        expect(
          l.url.contains('nhs.uk') || l.url.contains('gov.uk') || l.url.contains('nationalcareers.service.gov.uk'),
          isTrue,
          reason: 'trusted UK domain: ${l.url}',
        );
      }
      for (final field in f.fields) {
        expect(field.label.trim(), isNotEmpty, reason: '${f.id}.${field.id}');
        if (field.type == 'choice') expect(field.options.length, greaterThanOrEqualTo(2), reason: '${f.id}.${field.id}');
      }
    }
  });

  test('validateField teaches format without accepting empty required', () {
    final dob = lab.byId('gp_register')!.fields.firstWhere((f) => f.id == 'dob');
    expect(validateField(dob, ''), 'This field is required.');
    expect(validateField(dob, '1990-03-14'), isNotNull);
    expect(validateField(dob, '14/03/1990'), isNull);

    final post = lab.byId('gp_register')!.fields.firstWhere((f) => f.id == 'postcode');
    expect(validateField(post, 'SW1A 1AA'), isNull);
    expect(validateField(post, 'not-a-postcode'), isNotNull);

    final phrase = lab.byId('nhs111')!.fields.firstWhere((f) => f.id == 'phrase');
    expect(validateField(phrase, 'Give me a doctor now.'), isNotNull);
    expect(validateField(phrase, phrase.correct!), isNull);
  });

  test('council-tax letter present and comprehension has a correct answer', () {
    final f = lab.byId('council_tax')!;
    expect(f.letterEn, contains('PRACTICE letter'));
    expect(f.letterFa!.trim(), isNotEmpty);
    final amount = f.fields.firstWhere((x) => x.id == 'q_amount');
    expect(amount.correct, '£1,452.00');
  });

  testWidgets('hub and GP form open without exception', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemoryProgressStore()..data = const UserProgress(onboarded: true, startTier: 5, lang: 'en', unlockAll: true).encode();
    await t.pumpWidget(ProviderScope(overrides: [
      progressStoreProvider.overrideWithValue(store),
      formsLabProvider.overrideWith((ref) async => lab),
    ], child: const BritishLifeApp()));

    Future<void> settle() async {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      for (var i = 0; i < 40 && find.byType(NavLoading, skipOffstage: false).evaluate().isNotEmpty; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    router.go('/forms');
    await settle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('forms-lab')), findsOneWidget);
    expect(find.byKey(const ValueKey('forms-disclaimer')), findsOneWidget);
    expect(find.textContaining('UK Forms Practice Lab'), findsWidgets);
    final card = find.byKey(const ValueKey('form-card-gp_register'));
    if (card.evaluate().isEmpty) {
      await t.drag(find.byKey(const ValueKey('forms-lab')), const Offset(0, -600));
      await settle();
    }
    expect(card, findsOneWidget);

    router.go('/forms/gp_register');
    await settle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('form-practice-gp_register')), findsOneWidget);
    expect(find.byKey(const ValueKey('form-check')), findsOneWidget);
    expect(find.byKey(const ValueKey('form-practice-banner'), skipOffstage: false), findsOneWidget);
  });
}
