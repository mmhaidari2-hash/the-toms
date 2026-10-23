import '../../core/platform/asset_text.dart';
import 'dart:convert';

import 'package:flutter/services.dart';

/// One glossary entry (tool/make_glossary.py -> assets/data/glossary.json).
class Gloss {
  final String word, fa, ex, exSp;
  const Gloss(this.word, this.fa, this.ex, this.exSp);
}

/// Every authored word/phrase with its Persian meaning and a real example line from the app.
class Glossary {
  static Map<String, dynamic>? _m;
  static Future<void>? _loading;

  static Future<void> load([AssetBundle? b]) => _loading ??= () async {
        try {
          _m = jsonDecode(await loadAssetText('assets/data/glossary.json', b)) as Map<String, dynamic>;
        } catch (_) {
          _m = {};
        }
      }();

  /// For tests.
  static void seed(Map<String, List<String>> m) {
    _m = m;
    _loading = Future.value();
  }

  static String clean(String t) => t
      .replaceAll('\u2019', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r"^[^A-Za-z0-9'£]+|[^A-Za-z0-9'%]+$"), '');

  static Gloss? lookup(String text) {
    final m = _m;
    if (m == null) return null;
    final n = clean(text).toLowerCase();
    if (n.isEmpty) return null;
    final tries = <String>[
      n,
      if (n.endsWith('ies')) '${n.substring(0, n.length - 3)}y',
      if (n.endsWith('es')) n.substring(0, n.length - 2),
      if (n.endsWith('s')) n.substring(0, n.length - 1),
      if (n.endsWith('ed')) n.substring(0, n.length - 2),
      if (n.endsWith('ed')) n.substring(0, n.length - 1),
      if (n.endsWith('ing')) n.substring(0, n.length - 3),
      if (n.endsWith('ing')) '${n.substring(0, n.length - 3)}e',
      if (n.startsWith('the ')) n.substring(4),
      if (n.startsWith('a ')) n.substring(2),
      if (n.startsWith('to ')) n.substring(3),
    ];
    for (final t in tries) {
      final v = m[t];
      if (v is List && v.length >= 4) return Gloss(v[0] as String, v[1] as String, v[2] as String, v[3] as String);
    }
    return null;
  }

  /// A line from the app that uses [phrase], for words that aren't in the glossary themselves.
  static Gloss? exampleFor(String phrase) {
    final m = _m;
    final p = clean(phrase);
    if (m == null || p.length < 2) return null;
    final rx = RegExp(r'\b' + RegExp.escape(p) + r'\b', caseSensitive: false);
    for (final v in m.values) {
      if (v is List && v.length >= 4 && rx.hasMatch(v[2] as String)) return Gloss(p, '', v[2] as String, v[3] as String);
    }
    return null;
  }
}
