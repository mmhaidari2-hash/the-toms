import 'dart:convert';

import 'package:flutter/services.dart';

import 'strings.dart';

/// Helper-language text (MASTER BOOK §12). Lessons and screens are authored with a Persian helper line; every other
/// helper language is a full translation table keyed by that Persian text (assets/i18n/<code>.json, built by
/// tool/i18n). Every Text in the app passes its string through [hl], so Persian is just one table among equals.

/// The learner's helper language; set by the app shell before the screens rebuild.
String helperLang = 'fa';
Map<String, String> _table = const {};
final _loaded = <String, Map<String, String>>{};

bool get helperRtl => langOf(helperLang).rtl;
TextDirection get helperDir => helperRtl ? TextDirection.rtl : TextDirection.ltr;
/// Arabic-script helpers use Vazirmatn; Latin and Cyrillic helpers use Inter.
bool get helperArabicScript => const {'fa', 'ar', 'ur', 'ps', 'ckb', 'prs'}.contains(helperLang);

/// English for every Persian helper string (assets/i18n/en.json): the fallback while a beta language is still
/// being translated, so a learner never sees Persian they did not choose.
Map<String, String> _en = const {};
bool _enLoaded = false;

Future<Map<String, String>> _read(String code) async {
  try {
    final raw = await rootBundle.loadString('assets/i18n/$code.json');
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  } catch (_) {
    return const {};
  }
}

/// Loads (once) and activates a helper language table. Persian needs none: the source text is Persian.
Future<void> useHelperLang(String code) async {
  if (code == 'fa') {
    helperLang = code;
    _table = const {};
    return;
  }
  if (!_enLoaded) {
    _en = await _read('en');
    _enLoaded = true;
  }
  final t = code == 'en' ? _en : (_loaded[code] ??= await _read(code));
  helperLang = code;
  _table = t;
}

/// For tests: activate a table directly.
void setHelperTable(String code, Map<String, String> table) {
  _loaded[code] = table;
  helperLang = code;
  _table = table;
}

bool isHelperLoaded(String code) => code == 'fa' || (_enLoaded && (code == 'en' || _loaded.containsKey(code)));

/// For tests: the English fallback table.
void setEnglishFallback(Map<String, String> en) {
  _en = en;
  _enLoaded = true;
}

String? _look(String k) => _table[k] ?? _en[k];

final _sep = RegExp(r'(\s*(?:·|•|\n|\||—)\s*)');
final _run = RegExp('[\u0600-\u06FF\u200c][\u0600-\u06FF\u200c\\s،؛؟!.:()«»0-9۰-۹\\-/]*');

bool _hasFa(String s) {
  for (final c in s.codeUnits) {
    if (c >= 0x0600 && c <= 0x06FF) return true;
  }
  return false;
}

/// The helper-language version of a Persian helper string; English and other text passes through unchanged.
String hl(String? s) {
  if (s == null) return '';
  if (helperLang == 'fa' || !_hasFa(s)) return s;
  final whole = _look(s.trim());
  if (whole != null) return whole;
  return _digits(_compose(s));
}

String _compose(String s) {
  // "English · Persian" labels and composed lines: translate each Persian part. A part that falls back to the
  // English already next to it ("Town · Town") is dropped together with its separator.
  final parts = <String>[], seps = <String>[];
  var last = 0;
  for (final m in _sep.allMatches(s)) {
    parts.add(s.substring(last, m.start));
    seps.add(m.group(0)!);
    last = m.end;
  }
  parts.add(s.substring(last));
  final out = StringBuffer();
  String norm(String x) => x.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final done = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final t = _part(parts[i]);
    if (i > 0 && _hasFa(parts[i]) && norm(t).isNotEmpty && done.any((d) => norm(d) == norm(t))) continue;
    if (i > 0) out.write(seps[i - 1]);
    out.write(t);
    done.add(t);
  }
  return out.toString();
}

String _part(String p) {
  if (!_hasFa(p)) return p;
  final t = _look(p.trim());
  if (t != null) return p.replaceFirst(p.trim(), t);
  return p.replaceAllMapped(_run, (m) {
    final raw = m.group(0)!;
    final k = raw.trim();
    final v = _look(k) ?? _look(k.replaceAll(RegExp(r'[\s.:()\-/]+$'), ''));
    if (v != null) return raw.replaceFirst(k, v);
    // Last resort for composed text (dates, counts): word by word.
    return raw.replaceAllMapped(_word, (w) => _look(w.group(0)!) ?? w.group(0)!);
  });
}

final _word = RegExp('[\u0600-\u06FF\u200c]+');
String _digits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final r in s.runes) {
    final i = fa.indexOf(String.fromCharCode(r));
    b.write(i >= 0 ? '$i' : String.fromCharCode(r));
  }
  return b.toString();
}

/// Untranslated Persian left in a string the app shows (for the language audit).
bool hasPersian(String s) => _hasFa(s);
