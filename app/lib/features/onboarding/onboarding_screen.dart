import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/strings.dart';
import '../shared/widgets.dart';

class _Q {
  final String q;
  final List<String> options;
  final int answer;
  const _Q(this.q, this.options, this.answer);
}

const _quiz = [
  _Q('“Hello! How are you?”  — the best reply is…', ['I am 20.', 'Fine, thanks. And you?', 'Yes, please.'], 1),
  _Q('In a British shop, “Do you need a bag?” — “No thanks, I’ve got my ___.”', ['own', 'self', 'mine bag'], 0),
  _Q('“Fancy a cuppa?” means…', ['Do you want a cup of tea?', 'Do you like cups?', 'Are you hungry?'], 0),
  _Q('“If I ___ more time, I’d join the library.”', ['have', 'had', 'will have'], 1),
  _Q('Your manager says “We’ll be in touch.” This usually means…', ['You got the job.', 'You failed.', 'They will contact you later — no decision yet.'], 2),
  _Q('“I was absolutely chuffed!” means…', ['very pleased', 'very tired', 'a bit annoyed'], 0),
];

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
  int _step = 0; // 0 language · 1 level · 2 quiz · 3 result
  String _lang = 'fa';
  int _level = 0, _q = 0, _score = 0;
  int? _picked;

  void _finish(int tier) {
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
                  for (var i = 0; i < 4; i++)
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
                child: KeyedSubtree(key: ValueKey('$_step-$_q'), child: [_langStep, _levelStep, _quizStep, _resultStep][_step]()),
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
          for (final l in helperLanguages)
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
      const SizedBox(height: 18),
      _cta('Continue', () => setState(() => _step = 1)),
    ],
  );

  Widget _levelStep() => _frame(
    title: 'Your level',
    sub: tr(_lang, 'pick_level'),
    children: [
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
      TextButton(
        onPressed: () => setState(() => _step = 2),
        child: Text(
          tr(_lang, 'take_quiz'),
          textDirection: dirOf(_lang),
          style: const TextStyle(color: BL.gold, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _quizStep() {
    final q = _quiz[_q];
    return _frame(
      title: 'Question ${_q + 1} of ${_quiz.length}',
      sub: tr(_lang, 'quiz'),
      children: [
        Text(
          q.q,
          style: BL.display(21, color: Colors.white, w: FontWeight.w500),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < q.options.length; i++)
          _tile(
            selected: _picked == i,
            onTap: () => setState(() => _picked = i),
            child: Text(q.options[i], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          ),
        _cta(
          _q == _quiz.length - 1 ? 'See my level' : 'Next',
          _picked == null
              ? null
              : () => setState(() {
                  if (_picked == q.answer) _score++;
                  _picked = null;
                  if (_q == _quiz.length - 1) {
                    _step = 3;
                  } else {
                    _q++;
                  }
                }),
        ),
      ],
    );
  }

  int get _recommended => (_score - 1).clamp(0, 5);

  Widget _resultStep() {
    final l = _levels[_recommended];
    return _frame(
      title: '$_score / ${_quiz.length} ✨',
      sub: tr(_lang, 'quiz_result'),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Text(l.$1, style: BL.display(40, color: BL.red)),
              Text(
                '${l.$2}  ·  ${l.$3}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink),
              ),
              const SizedBox(height: 4),
              Text(l.$4, style: const TextStyle(color: BL.muted)),
            ],
          ),
        ),
        _cta(tr(_lang, 'start_here'), () => _finish(_recommended)),
      ],
    );
  }
}
