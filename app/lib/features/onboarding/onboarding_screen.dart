import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/strings.dart';
import '../shared/widgets.dart';
import 'howto.dart';

const _levels = [
  ('A0–A1', 'Beginner', 'مبتدی', 'Home life with William and Nicola'),
  ('A1–A2', 'Elementary', 'مقدماتی', 'School, park and the corner shop'),
  ('A2–B1', 'Pre-intermediate', 'پیش‌متوسط', 'Café, dentist, library, GP'),
  ('B1–B2', 'Intermediate', 'متوسط', 'Bus, bank, doctor, job interview'),
  ('B2–C1', 'Upper-intermediate', 'فوق‌متوسط', 'University and conferences'),
  ('C1–C2', 'Advanced', 'پیشرفته', 'Slang, idioms and accents'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0 language · 1 how it works (Tom & Nicola) · 2 level / placement test
  String _lang = 'fa';
  int _level = 0;
  final _name = TextEditingController();

  void _saveName() => ref.read(progressProvider.notifier).setPref('name', _name.text.trim());

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _finish(int tier) {
    _saveName();
    ref.read(progressProvider.notifier).finishOnboarding(startTier: tier, lang: _lang);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF22355C), BL.ink]),
        ),
        child: Column(
          children: [
            SizedBox(height: pad.top + 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 4,
                        decoration: BoxDecoration(color: i <= _step ? BL.gold : Colors.white12, borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(a),
                    child: c,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey('$_step'), child: [_langStep, _howStep, _levelStep][_step]()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frame({required String title, String? sub, required List<Widget> children}) => ListView(
    padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.paddingOf(context).bottom),
    children: [
      Text(title, style: BL.display(30, color: Colors.white)),
      if (sub != null) ...[
        const SizedBox(height: 6),
        Text(
          sub,
          textDirection: dirOf(_lang),
          style: BL.fa(14, color: Colors.white70),
        ),
      ],
      const SizedBox(height: 22),
      ...children,
    ],
  );

  Widget _tile({required Widget child, required bool selected, required VoidCallback onTap}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? BL.cream : Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? BL.gold : Colors.white12, width: 1.5),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: selected ? BL.ink : Colors.white),
          child: child,
        ),
      ),
    ),
  );

  Widget _cta(String label, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: BL.red,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    ),
  );

  Widget _langStep() => _frame(
    title: 'Hiya! 👋',
    sub: '${tr(_lang, 'welcome')}\n${tr(_lang, 'welcome_sub')}',
    children: [
      Text(
        tr(_lang, 'pick_lang'),
        textDirection: dirOf(_lang),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in helperLanguages.where((l) => readyLanguages.contains(l.code)))
            Pressable(
              onTap: () => setState(() => _lang = l.code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _lang == l.code ? BL.gold : Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _lang == l.code ? BL.gold : Colors.white24),
                ),
                child: Text(
                  '${l.native}  ·  ${l.name}',
                  style: TextStyle(color: _lang == l.code ? BL.ink : Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Coming soon: ${helperLanguages.where((l) => !readyLanguages.contains(l.code)).map((l) => l.name).join(' · ')}',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      const SizedBox(height: 22),
      const Text('What should the family call you?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('onb-name'),
        controller: _name,
        textCapitalization: TextCapitalization.words,
        maxLength: 24,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Your first name (optional)',
          hintStyle: const TextStyle(color: Colors.white38),
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: .08),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Shown in chats. The recorded voices never say a name.', style: TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 18),
      _cta('Continue', () {
        _saveName();
        setState(() => _step = 1);
      }),
    ],
  );

  Widget _levelStep() => _frame(
    title: 'Your level',
    sub: tr(_lang, 'pick_level'),
    children: [
      Pressable(
        key: const ValueKey('take-placement'),
        onTap: () {
          ref.read(progressProvider.notifier).setLang(_lang);
          _saveName();
          context.go('/placement');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(18)),
          child: const Row(children: [
            Icon(Icons.quiz_rounded, color: BL.ink),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Take the placement test', style: TextStyle(color: BL.ink, fontWeight: FontWeight.w800, fontSize: 16)),
              Text('About 5 minutes · listening + choices · skippable', style: TextStyle(color: BL.ink, fontSize: 12.5)),
            ])),
            Icon(Icons.chevron_right_rounded, color: BL.ink),
          ]),
        ),
      ),
      const Text('…or pick your level', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      for (var i = 0; i < _levels.length; i++)
        _tile(
          selected: _level == i,
          onTap: () => setState(() => _level = i),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(_levels[i].$1, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_levels[i].$2}  ·  ${_levels[i].$3}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_levels[i].$4, style: const TextStyle(fontSize: 12.5, color: BL.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      _cta('Start at ${_levels[_level].$1}', () => _finish(_level)),
    ],
  );

  Widget _howStep() => HowToPages(onDone: () => setState(() => _step = 2));
}
