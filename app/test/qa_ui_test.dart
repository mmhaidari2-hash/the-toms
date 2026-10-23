// QA gate (tool/qa/run_qa.py): every route in build/qa/routes.json at each phone size and helper language
// (incl. right-to-left Arabic/Persian) must render with no overflow, no exception, no missing image and no
// "page not found". Results go to build/qa/ui_results.json for the QA report.
import 'dart:convert';
import 'dart:io';
import 'package:british_life/app/app.dart';
import 'package:british_life/app/router.dart';
import 'package:british_life/app/theme.dart';
import 'package:british_life/core/data/progress_store.dart';
import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/models/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final f = File('build/qa/routes.json');
  if (!f.existsSync()) return;
  final cfg = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final routes = List<String>.from(cfg['routes'] as List);
  final sizes = [for (final s in cfg['sizes'] as List) Size((s[0] as num).toDouble(), (s[1] as num).toDouble())];
  final langs = List<String>.from(cfg['langs'] as List);
  final results = <Map<String, dynamic>>[];
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
  tearDownAll(() => File('build/qa/ui_results.json').writeAsStringSync(jsonEncode(results)));
  for (final lang in langs) {
    for (final size in sizes) {
      testWidgets('QA UI $lang ${size.width.toInt()}x${size.height.toInt()}', (t) async {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await t.pumpWidget(ProviderScope(
            overrides: [progressStoreProvider.overrideWithValue(MemoryProgressStore()..data = UserProgress(onboarded: true, unlockAll: true, lang: lang).encode())],
            child: const BritishLifeApp()));
        router.go('/');
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(seconds: 2));
        final bad = <String>[];
        final orig = FlutterError.onError;
        final where = <String>[];
        FlutterError.onError = (d) {
          final m = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString());
          if (m != null) where.add(m.group(0)!);
          orig?.call(d);
        };
        for (final r in routes) {
          where.clear();
          router.go(r);
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
          await t.pump(const Duration(seconds: 2));
          final ex = t.takeException();
          String? why;
          if (ex != null) {
            final s = ex is FlutterError ? ex.diagnostics.map((d) => d.toString()).where((l) => l.contains('overflow') || l.contains('Column') || l.contains('Row') || l.contains('file:') || l.contains('Unable to load')).take(4).join(' | ') : '$ex';
            why = s.isEmpty ? '$ex'.split('\n').first : s;
            if (where.isNotEmpty) why = '$why @ ${where.toSet().join(', ')}';
          } else if (find.textContaining('Page Not Found').evaluate().isNotEmpty || find.textContaining('GoException').evaluate().isNotEmpty) {
            why = 'route not found';
          }
          results.add({'route': r, 'lang': lang, 'size': '${size.width.toInt()}x${size.height.toInt()}', 'ok': why == null, if (why != null) 'why': why});
          if (why != null) bad.add('$r: $why');
        }
        FlutterError.onError = orig;
        router.go('/');
        await t.pump(const Duration(seconds: 1));
        expect(bad, isEmpty, reason: bad.take(20).join('\n'));
      }, timeout: const Timeout(Duration(minutes: 30)));
    }
  }
}
