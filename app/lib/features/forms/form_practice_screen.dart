import 'package:british_life/core/data/providers.dart';
import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../shared/nav.dart';
import 'forms_data.dart';

/// One interactive practice form. Values stay in memory only — never uploaded.
class FormPracticeScreen extends ConsumerStatefulWidget {
  final String id;
  const FormPracticeScreen({super.key, required this.id});
  @override
  ConsumerState<FormPracticeScreen> createState() => _FormPracticeState();
}

class _FormPracticeState extends ConsumerState<FormPracticeScreen> {
  final _values = <String, String>{};
  final _errors = <String, String>{};
  bool _showTips = true, _done = false;
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(formsLabProvider);
    final pad = MediaQuery.paddingOf(context);
    return async.when(
      loading: () => const Scaffold(backgroundColor: BL.cream, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(backgroundColor: BL.cream, body: Center(child: Text(hl('$e')))),
      data: (lab) {
        final form = lab.byId(widget.id);
        if (form == null) {
          return Scaffold(
            backgroundColor: BL.cream,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(hl('Form not found')),
                TextButton(onPressed: () => context.go('/forms'), child: Text(hl('Back to Forms Lab'))),
              ]),
            ),
          );
        }
        if (_done) return _doneView(pad, form);
        return Scaffold(
          backgroundColor: BL.cream,
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                key: const ValueKey('form-check'),
                style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
                onPressed: () => _submit(form),
                child: Text(hl('Check my answers'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
          body: ListView(
            key: ValueKey('form-practice-${form.id}'),
            // ignore: deprecated_member_use
            cacheExtent: 5000,
            padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 24),
            children: [
              const Row(children: [NavButtons(), SizedBox(width: 10), Text('PRACTICE FORM', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red))]),
              const SizedBox(height: 10),
              Text(hl(form.title), style: BL.display(22)),
              Text(hl(form.titleFa), textDirection: helperDir, style: BL.fa(13.5)),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('form-practice-banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0A800))),
                child: Text(hl('Practice only — nothing is submitted. Do not enter real passwords or bank details.'), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35, fontSize: 12.5)),
              ),
              if (form.letterEn != null) ...[
                const SizedBox(height: 14),
                Text(hl('Sample letter'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  key: const ValueKey('form-letter'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.mist)),
                  child: Text(form.letterEn!, style: const TextStyle(height: 1.45, fontSize: 13.5)),
                ),
                if (form.letterFa != null) ...[
                  const SizedBox(height: 6),
                  Text(hl(form.letterFa!), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
                ],
              ],
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                key: const ValueKey('form-tips-toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(hl('Show field tips'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(hl('نمایش راهنمای هر فیلد'), textDirection: helperDir, style: BL.fa(12)),
                value: _showTips,
                activeThumbColor: BL.red,
                onChanged: (v) => setState(() => _showTips = v),
              ),
              if (form.tips.isNotEmpty && _step == 0) ...[
                for (final t in form.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: BL.mist, borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(hl(t.en), style: const TextStyle(height: 1.35, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(hl(t.fa), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
                      ]),
                    ),
                  ),
              ],
              const SizedBox(height: 6),
              for (final f in form.fields) _field(f),
              const SizedBox(height: 10),
              Text(hl('GOV.UK / NHS links'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              for (final l in form.official)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Align(alignment: Alignment.centerLeft, child: Text(hl(l.label))),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _field(FormFieldDef f) {
    final err = _errors[f.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hl(f.label), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        if (f.labelFa.isNotEmpty) Text(hl(f.labelFa), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
        if (_showTips && (f.tip ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(hl(f.tip!), style: const TextStyle(fontSize: 12.5, height: 1.35, color: BL.navy)),
          if ((f.tipFa ?? '').isNotEmpty) Text(hl(f.tipFa!), textDirection: helperDir, style: BL.fa(11.5, color: BL.muted)),
        ],
        const SizedBox(height: 6),
        if (f.type == 'choice')
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in f.options)
                ChoiceChip(
                  key: ValueKey('form-${widget.id}-${f.id}-$o'),
                  label: Text(hl(o), style: const TextStyle(fontSize: 13)),
                  selected: _values[f.id] == o,
                  selectedColor: BL.red.withValues(alpha: .15),
                  onSelected: (_) => setState(() {
                    _values[f.id] = o;
                    _errors.remove(f.id);
                  }),
                ),
            ],
          )
        else
          TextField(
            key: ValueKey('form-${widget.id}-${f.id}'),
            onChanged: (v) {
              _values[f.id] = v;
              if (_errors.containsKey(f.id)) setState(() => _errors.remove(f.id));
            },
            decoration: InputDecoration(
              hintText: f.hint,
              filled: true,
              fillColor: Colors.white,
              errorText: err,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BL.mist)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: err != null ? BL.red : BL.mist)),
            ),
          ),
        if (err != null && f.type == 'choice')
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(hl(err), style: const TextStyle(color: BL.red, fontSize: 12.5))),
      ]),
    );
  }

  void _submit(PracticeForm form) {
    final next = <String, String>{};
    for (final f in form.fields) {
      final err = validateField(f, _values[f.id] ?? '');
      if (err != null) next[f.id] = err;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(next);
      _step = 1;
    });
    if (next.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('Check the highlighted fields (${next.length}).'))));
      return;
    }
    // Local XP only — never leaves the device.
    ref.read(progressProvider.notifier).awardXp(15);
    setState(() => _done = true);
  }

  Widget _doneView(EdgeInsets pad, PracticeForm form) => Scaffold(
        backgroundColor: BL.cream,
        body: ListView(
          key: ValueKey('form-done-${form.id}'),
          padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
          children: [
            const Row(children: [NavButtons(), SizedBox(width: 10), Text('COMPLETE', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.green))]),
            const SizedBox(height: 16),
            const Text('✅', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
            Text(hl('Practice complete'), textAlign: TextAlign.center, style: BL.display(24)),
            const SizedBox(height: 8),
            Text(hl(form.doneEn), textAlign: TextAlign.center, style: const TextStyle(height: 1.4, fontSize: 14.5)),
            const SizedBox(height: 6),
            Text(hl(form.doneFa), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(13.5)),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('form-done-lab'),
              style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
              onPressed: () => context.go('/forms'),
              child: Text(hl('Back to Forms Lab'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextButton(key: const ValueKey('form-done-retry'), onPressed: () => setState(() { _done = false; _values.clear(); _errors.clear(); }), child: Text(hl('Practise again'))),
            for (final l in form.official)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(hl(l.label)),
              ),
          ],
        ),
      );
}
