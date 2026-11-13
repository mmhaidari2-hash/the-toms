import 'package:british_life/app/theme.dart';
import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/i18n/strings.dart';
import 'package:british_life/features/shared/bilingual_text.dart';
import 'package:british_life/features/shared/sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Samsung-style frames from the 13 Nov 2026 phone screenshots: 360×780 and 412×915,
/// text scales 1.0 / 1.3 / 1.6, and a 48dp 3-button navigation inset.
const _sizes = [Size(360, 780), Size(412, 915)];
const _scales = [1.0, 1.3, 1.6];
const _inset = 48.0;

Future<List<String>> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double scale,
}) async {
  final overflows = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.toString();
    if (s.contains('overflowed') || s.contains('OVERFLOWING') || s.contains('RenderFlex')) {
      overflows.add(s);
    }
    old?.call(d);
  };
  addTearDown(() => FlutterError.onError = old);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(bottom: _inset),
          viewPadding: const EdgeInsets.only(bottom: _inset),
          viewInsets: EdgeInsets.zero,
        ),
        child: Scaffold(backgroundColor: const Color(0xFFFBF7F0), body: child),
      ),
    ),
  );
  await tester.pump();
  final ex = tester.takeException();
  if (ex != null) overflows.add(ex.toString());
  return overflows;
}

bool _exceeded(WidgetTester tester, Finder f) {
  for (final e in f.evaluate()) {
    final ro = e.renderObject;
    if (ro is RenderParagraph && ro.didExceedMaxLines) return true;
  }
  return false;
}

void main() {
  setUp(() {
    BL.useGoogleFonts = false;
    helperLang = 'fa';
  });

  for (final size in _sizes) {
    for (final scale in _scales) {
      testWidgets('spot start CTA shows the full lesson title at ${size.width.toInt()}x${size.height.toInt()} @${scale}x + 48dp inset', (tester) async {
        tester.view.physicalSize = Size(size.width * 3, size.height * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const title = 'The nursery interview';
        final overflows = await _pump(
          tester,
          SafeSheetList(
            listKey: const ValueKey('safe-sheet-list'),
            children: [
              const Text('Primrose Lane Nursery', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('مهدکودک پریمروز لین'),
              const SizedBox(height: 12),
              const SpotStartCta(lessonTitle: title, onPressed: null),
              const SizedBox(height: 10),
              for (var i = 0; i < 8; i++)
                ListTile(
                  key: ValueKey('spot-lesson-$i'),
                  title: Text(i == 7 ? 'Wash your hands — Primrose Lane Nursery' : 'Lesson ${i + 1}'),
                ),
            ],
          ),
          size: size,
          scale: scale,
        );
        expect(overflows, isEmpty, reason: overflows.join('\n'));

        final list = tester.widget<ListView>(find.byKey(const ValueKey('safe-sheet-list')));
        expect(list.padding, isA<EdgeInsets>());
        final pad = list.padding! as EdgeInsets;
        expect(pad.bottom, greaterThanOrEqualTo(_inset),
            reason: 'sheet list padding ${pad.bottom} < system inset $_inset');

        expect(find.byKey(const ValueKey('spot-start')), findsOneWidget);
        expect(find.textContaining('The nursery interview'), findsOneWidget);
        expect(find.textContaining('Start:'), findsOneWidget);
        expect(_exceeded(tester, find.textContaining('The nursery interview')), isFalse,
            reason: 'CTA truncated at $size scale $scale');
      });

      testWidgets('conversation app bar titles wrap, hint is short and RTL for FA at ${size.width.toInt()} @${scale}x', (tester) async {
        tester.view.physicalSize = Size(size.width * 3, size.height * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final hint = hl(tr('fa', 'replyHintShort'));
        final overflows = await _pump(
          tester,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 40, height: 40),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AdaptiveTitle('The nursery interview', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w800), maxLines: 2, minScale: 0.75),
                          AdaptiveTitle('B1  ·  Getting the job', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40, height: 40),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey('reply-field'),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                    hintTextDirection: scriptDirection(hint) ?? helperDir,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                ),
              ],
            ),
          ),
          size: size,
          scale: scale,
        );
        expect(overflows, isEmpty, reason: overflows.join('\n'));
        expect(find.text('The nursery interview'), findsOneWidget);
        expect(_exceeded(tester, find.text('The nursery interview')), isFalse);
        expect(find.text('B1  ·  Getting the job'), findsOneWidget);
        expect(_exceeded(tester, find.text('B1  ·  Getting the job')), isFalse);
        expect(hint, 'به انگلیسی…');
        expect(hint.contains('جواب بده'), isFalse);
        final field = tester.widget<TextField>(find.byKey(const ValueKey('reply-field')));
        expect(field.textDirection, TextDirection.ltr);
        expect(field.decoration?.hintTextDirection, TextDirection.rtl);
        expect(field.decoration?.hintStyle?.fontSize, lessThanOrEqualTo(14));
      });
    }
  }

  testWidgets('BilingualText stacks EN and FA, each with its own direction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BilingualText(
              '🌱 Now you are Vida  ·  نقش عوض شد',
              key: ValueKey('role-sys'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    expect(find.text('🌱 Now you are Vida'), findsOneWidget);
    expect(find.text('نقش عوض شد'), findsOneWidget);
    final en = tester.widget<Text>(find.text('🌱 Now you are Vida'));
    final fa = tester.widget<Text>(find.text('نقش عوض شد'));
    expect(en.textDirection, TextDirection.ltr);
    expect(fa.textDirection, TextDirection.rtl);
  });

  test('scriptDirection and bidiIsolate cover FA/AR/UR/PS vs English', () {
    expect(scriptDirection('به انگلیسی…'), TextDirection.rtl);
    expect(scriptDirection('ردّ بالإنجليزية…'), TextDirection.rtl);
    expect(scriptDirection('انگریزی میں…'), TextDirection.rtl);
    expect(scriptDirection('په انګلیسي…'), TextDirection.rtl);
    expect(scriptDirection('In English…'), TextDirection.ltr);
    expect(bidiIsolate('نقش عوض شد'), startsWith('\u2067'));
    expect(bidiIsolate('Now you are Vida'), startsWith('\u2066'));
  });
}
