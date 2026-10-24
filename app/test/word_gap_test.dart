// QA gate (tool/qa/run_qa.py runs this with the UI sweep): an English word and its helper-language gloss must never
// run together ("readingپڑھنا"). Checked for every helper language that has a table, on the lesson word chips and on
// every rich text the lesson screen renders.
import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:british_life/features/shared/gloss.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codes = [
    for (final f in Directory('assets/i18n').listSync().whereType<File>())
      if (f.path.endsWith('.json') && !f.path.endsWith('/en.json')) f.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();
  final course = jsonDecode(File('assets/data/course.json').readAsStringSync()) as Map<String, dynamic>;
  final words = <String>{
    for (final u in course['units'] as List)
      for (final l in u['lessons'] as List)
        for (final w in (l['words'] as List? ?? const [])) w['fa'] as String,
  };
  tearDown(() => setHelperTable('fa', const {}));

  test('the glue detector finds "readingپڑھنا" and accepts "reading  پڑھنا"', () {
    TextSpan two(String a, String b) => TextSpan(children: [TextSpan(text: a), TextSpan(text: b)]);
    expect(gluedScripts(two('reading', 'پڑھنا')), isNotNull);
    expect(gluedScripts(two('reading', 'पढ़ना')), isNotNull);
    expect(gluedScripts(two('قراءة', 'reading')), isNotNull);
    expect(gluedScripts(two('reading', '  پڑھنا')), isNull);
    expect(gluedScripts(two('reading ', 'पढ़ना')), isNull);
    expect(gluedScripts(two('Town', ' · شهر')), isNull);
  });

  test('a translated helper line keeps the spacing around it in every language (${codes.join(', ')})', () {
    expect(codes, containsAll(['ar', 'hi', 'ur']));
    for (final c in codes) {
      final t = (jsonDecode(File('assets/i18n/$c.json').readAsStringSync()) as Map<String, dynamic>).cast<String, String>();
      setHelperTable(c, t);
      var n = 0;
      for (final fa in words) {
        if (!t.containsKey(fa.trim())) continue;
        n++;
        expect(hl('  $fa'), startsWith('  '), reason: '$c: "$fa"');
        expect(hl('$fa  '), endsWith('  '), reason: '$c: "$fa"');
      }
      expect(n, greaterThan(100), reason: '$c: too few lesson words translated to test');
    }
  });

  setUp(() => BL.useGoogleFonts = false);
  setUpAll(() async {
    for (final fam in ['Roboto', 'Inter', 'Fraunces', 'Vazirmatn']) {
      final file = fam == 'Roboto' ? 'Inter' : fam;
      final l = FontLoader(fam);
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/google_fonts/$file-$w.ttf').readAsBytesSync())));
      }
      await l.load();
    }
  });
  for (final c in ['fa', 'en', ...codes]) {
    testWidgets('lesson word chips are separated in $c', (t) async {
      t.view.physicalSize = const Size(375, 667) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
          overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = UserProgress(onboarded: true, unlockAll: true, lang: c).encode())],
          child: const BritishLifeApp()));
      router.go('/');
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(seconds: 2));
      for (final id in ['l1_u1_1', 'l3_u5_1']) {
        router.go('/lesson/$id');
        for (var i = 0; i < 20 && find.byType(GlossLabel).evaluate().isEmpty; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
          await t.pump(const Duration(milliseconds: 500));
        }
        expect(find.byType(GlossLabel), findsWidgets, reason: '$c $id');
        final glued = [
          for (final e in find.byType(RichText).evaluate())
            if (gluedScripts((e.widget as RichText).text) case final g?) g,
        ];
        expect(glued, isEmpty, reason: '$c $id: ${glued.take(5).join(' / ')}');
        if (c != 'fa' && c != 'en') {
          final gloss = find.descendant(of: find.byType(GlossLabel).first, matching: find.byKey(const ValueKey('gloss')));
          expect(gloss, findsOneWidget, reason: '$c $id: first word has a gloss');
          final g = t.widget<Text>(gloss);
          expect(g.textDirection, const {'ar', 'ur', 'fa', 'ps', 'ckb', 'prs'}.contains(c) ? TextDirection.rtl : TextDirection.ltr);
        }
      }
      router.go('/');
      await t.pump(const Duration(seconds: 1));
    });
  }
}
