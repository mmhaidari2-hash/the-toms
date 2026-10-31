import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/asset_text.dart';

class FormLink {
  final String label, url;
  const FormLink(this.label, this.url);
  factory FormLink.fromJson(Map j) => FormLink(j['label'] as String, j['url'] as String);
}

class FormTip {
  final String en, fa;
  const FormTip(this.en, this.fa);
  factory FormTip.fromJson(Map j) => FormTip(j['en'] as String, j['fa'] as String);
}

class FormFieldDef {
  final String id, type, label, labelFa;
  final String? hint, hintFa, tip, tipFa, pattern, patternMsg, patternMsgFa, correct;
  final List<String> options;
  final bool required;
  final int? min;
  const FormFieldDef({
    required this.id,
    required this.type,
    required this.label,
    required this.labelFa,
    this.hint,
    this.hintFa,
    this.tip,
    this.tipFa,
    this.pattern,
    this.patternMsg,
    this.patternMsgFa,
    this.correct,
    this.options = const [],
    this.required = true,
    this.min,
  });
  factory FormFieldDef.fromJson(Map j) => FormFieldDef(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'text',
        label: j['label'] as String,
        labelFa: j['labelFa'] as String? ?? '',
        hint: j['hint'] as String?,
        hintFa: j['hintFa'] as String?,
        tip: j['tip'] as String?,
        tipFa: j['tipFa'] as String?,
        pattern: j['pattern'] as String?,
        patternMsg: j['patternMsg'] as String?,
        patternMsgFa: j['patternMsgFa'] as String?,
        correct: j['correct'] as String?,
        options: [for (final o in (j['options'] as List? ?? const [])) '$o'],
        required: j['required'] as bool? ?? true,
        min: j['min'] as int?,
      );
}

class PracticeForm {
  final String id, icon, level, title, titleFa, blurb, blurbFa, doneEn, doneFa;
  final String? letterEn, letterFa;
  final List<FormLink> official;
  final List<FormTip> tips;
  final List<FormFieldDef> fields;
  const PracticeForm({
    required this.id,
    required this.icon,
    required this.level,
    required this.title,
    required this.titleFa,
    required this.blurb,
    required this.blurbFa,
    required this.doneEn,
    required this.doneFa,
    this.letterEn,
    this.letterFa,
    required this.official,
    required this.tips,
    required this.fields,
  });
  factory PracticeForm.fromJson(Map j) => PracticeForm(
        id: j['id'] as String,
        icon: j['icon'] as String? ?? 'description',
        level: j['level'] as String? ?? '',
        title: j['title'] as String,
        titleFa: j['titleFa'] as String? ?? '',
        blurb: j['blurb'] as String? ?? '',
        blurbFa: j['blurbFa'] as String? ?? '',
        doneEn: j['done_en'] as String? ?? '',
        doneFa: j['done_fa'] as String? ?? '',
        letterEn: j['letter_en'] as String?,
        letterFa: j['letter_fa'] as String?,
        official: [for (final l in (j['official'] as List? ?? const [])) FormLink.fromJson(l as Map)],
        tips: [for (final t in (j['tips'] as List? ?? const [])) FormTip.fromJson(t as Map)],
        fields: [for (final f in (j['fields'] as List? ?? const [])) FormFieldDef.fromJson(f as Map)],
      );
}

class FormsLab {
  final String title, titleFa, blurb, blurbFa, disclaimerEn, disclaimerFa;
  final List<PracticeForm> forms;
  const FormsLab({
    required this.title,
    required this.titleFa,
    required this.blurb,
    required this.blurbFa,
    required this.disclaimerEn,
    required this.disclaimerFa,
    required this.forms,
  });
  factory FormsLab.fromJson(Map j) => FormsLab(
        title: j['title'] as String,
        titleFa: j['titleFa'] as String? ?? '',
        blurb: j['blurb'] as String? ?? '',
        blurbFa: j['blurbFa'] as String? ?? '',
        disclaimerEn: j['disclaimer_en'] as String? ?? '',
        disclaimerFa: j['disclaimer_fa'] as String? ?? '',
        forms: [for (final f in (j['forms'] as List? ?? const [])) PracticeForm.fromJson(f as Map)],
      );
  PracticeForm? byId(String id) {
    for (final f in forms) {
      if (f.id == id) return f;
    }
    return null;
  }

  static FormsLab parse(String raw) => FormsLab.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Validate one field value. Returns null if OK, else an English error message.
String? validateField(FormFieldDef f, String value) {
  final v = value.trim();
  if (v.isEmpty) {
    if (f.required) return 'This field is required.';
    return null;
  }
  if (f.min != null && v.length < f.min!) return 'Please write at least ${f.min} characters.';
  if (f.pattern != null && f.pattern!.isNotEmpty) {
    final re = RegExp(f.pattern!);
    if (!re.hasMatch(v)) return f.patternMsg ?? 'Please check the format.';
  }
  if (f.correct != null && f.correct!.isNotEmpty && v != f.correct) {
    return 'Try the clearer, more polite option.';
  }
  return null;
}

final formsLabProvider = FutureProvider<FormsLab>((ref) async => FormsLab.parse(await loadAssetText('assets/data/forms_lab.json')));
