import 'dart:convert';
import 'dart:io';

import 'package:british_life/app/theme.dart';
import 'package:british_life/features/arrival/arrival_pack_data.dart';
import 'package:british_life/features/arrival/arrival_pack_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final pack = ArrivalPack.parse(File('assets/data/arrival_pack.json').readAsStringSync());

  test('arrival pack lists week-1 scenes, forms, phrases and existing audio', () {
    expect(pack.formsLab, isTrue);
    expect(pack.units.length, greaterThanOrEqualTo(3));
    expect(pack.sceneIds.length, greaterThanOrEqualTo(12));
    expect(pack.phrases.length, greaterThanOrEqualTo(5));
    expect(pack.disclaimer.toLowerCase(), contains('999'));
    expect(pack.disclaimerFa, isNotEmpty);
    expect(pack.audioKeys, isNotEmpty);

    final idx = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as List).cast<String>().toSet();
    final missing = [for (final k in pack.audioKeys) if (!idx.contains(k)) k];
    expect(missing, isEmpty, reason: missing.take(10).join(', '));

    String key(String sp, String t) => md5.convert(utf8.encode('$sp|$t')).toString().substring(0, 16);
    for (final p in pack.phrases) {
      expect(idx.contains(key(p.sp, p.en)), isTrue, reason: p.en);
      expect(p.fa, isNotEmpty);
    }
  });

  testWidgets('arrival screen shows pack title and download', (t) async {
    BL.useGoogleFonts = false;
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const ArrivalPackScreen()),
      GoRoute(path: '/forms', builder: (_, _) => const SizedBox()),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [arrivalPackProvider.overrideWith((ref) async => pack)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('arrival-pack')), findsOneWidget);
    expect(find.byKey(const ValueKey('arrival-disclaimer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('arrival-download')).evaluate().isNotEmpty ||
          find.textContaining('Download offline pack').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.textContaining('Arrival Offline Pack'), findsWidgets);
  });
}
