import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/app.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/i18n/coverage.g.dart';
import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/i18n/strings.dart';
import 'package:british_life/features/shared/lang_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper languages: all listed equally, ready / beta / coming soon by translation coverage, instant switching, RTL.
void main() {
  Map<String, String> table(String code) =>
      (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map<String, dynamic>).cast<String, String>();
  final sources = jsonDecode(File('tool/i18n/sources.json').readAsStringSync()) as Map<String, dynamic>;
  final ui = [for (final e in sources.entries) if (e.value['ui'] == true) e.key];

  tearDown(() => setHelperTable('fa', const {}));

  test('every helper language is listed, Persian among them, none twice', () {
    final codes = HelperLangBar.languages.map((l) => l.code).toList();
    expect(codes.toSet().length, codes.length);
    expect(codes.length, greaterThanOrEqualTo(15));
    expect(codes, contains('fa'));
    expect(codes.first, isNot('fa'), reason: 'ordered by newcomer numbers, not with Persian first');
    for (final c in ['ur', 'ar', 'fa', 'prs', 'ps', 'ckb']) {
      expect(langOf(c).rtl, isTrue, reason: c);
    }
    expect(langOf('hi').rtl || langOf('zh').rtl || langOf('uk').rtl, isFalse);
  });

  test('status follows the translation tables', () {
    for (final l in helperLanguages.where((l) => l.code != 'fa')) {
      final f = File('assets/i18n/${l.code}.json');
      final c = helperCoverage[l.code] ?? 0;
      expect(f.existsSync(), c > 0, reason: '${l.code}: coverage $c but table ${f.existsSync() ? 'present' : 'missing'}');
      expect(langStatus(l.code), helperComplete.contains(l.code) && c >= .85 ? LangStatus.ready : (c > 0 ? LangStatus.beta : LangStatus.soon));
    }
    expect(readyLanguages, contains('fa'));
  });

  test('ready languages translate every UI string', () {
    for (final code in readyLanguages.where((c) => c != 'fa')) {
      if (langStatus(code) != LangStatus.ready) continue;
      final t = table(code);
      final miss = ui.where((k) => !t.containsKey(k)).toList();
      expect(miss.length, lessThanOrEqualTo(ui.length ~/ 50), reason: '$code: ${miss.take(5)}');
    }
  });

  test('beta falls back to English, never leaves the Persian it cannot translate', () {
    setEnglishFallback({'شهر': 'town', 'مسیر من': 'My path'});
    setHelperTable('xx', {'مسیر من': 'मेरा रास्ता'});
    expect(hl('مسیر من'), 'मेरा रास्ता');
    expect(hl('شهر'), 'town');
    expect(hl('Town · شهر'), 'Town', reason: 'the English fallback next to the same English is not repeated');
    expect(hl('My path · مسیر من'), 'My path · मेरा रास्ता');
    expect(hl('Hello'), 'Hello');
    setHelperTable('fa', const {});
    expect(hl('Town · شهر'), 'Town · شهر');
  });

  testWidgets('switching language updates helper text at once, with RTL only for RTL languages', (t) async {
    await t.runAsync(() async {
      await useHelperLang('hi');
      await useHelperLang('fa');
    });
    final store = MemoryProgressStore();
    await t.pumpWidget(ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        home: HelperLangScope(
          child: Scaffold(
            body: Column(children: [
              const HelperLangBar(),
              Builder(builder: (_) => Text(hl('مسیر من'), key: const ValueKey('probe'), textDirection: helperDir)),
            ]),
          ),
        ),
      ),
    ));
    String probe() => t.widget<Text>(find.byKey(const ValueKey('probe'))).data!;
    TextDirection dir() => t.widget<Text>(find.byKey(const ValueKey('probe'))).textDirection!;
    expect(probe(), 'مسیر من');
    expect(dir(), TextDirection.rtl);
    await t.ensureVisible(find.byKey(const ValueKey('lang-hi')));
    await t.tap(find.byKey(const ValueKey('lang-hi')));
    await t.pump();
    await t.pump();
    expect(probe(), table('hi')['مسیر من']);
    expect(dir(), TextDirection.ltr);
    await t.ensureVisible(find.byKey(const ValueKey('lang-fa')));
    await t.tap(find.byKey(const ValueKey('lang-fa')));
    await t.pump();
    await t.pump();
    expect(probe(), 'مسیر من');
    expect(dir(), TextDirection.rtl);
  });
}
