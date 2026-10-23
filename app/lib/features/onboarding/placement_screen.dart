import 'package:british_life/core/i18n/helper_text.dart';
import '../../core/platform/asset_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../shared/nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/platform/speech.dart';
import '../../core/platform/voice.dart';
import '../shared/widgets.dart';

class PlacementItem {
  final int level;
  final String type, text, fa, answer;
  final String? speaker, passage, passageFa;
  final List<String> choices, choicesFa;
  PlacementItem.fromJson(Map<String, dynamic> j)
    : level = j['level'],
      type = j['type'],
      text = j['text'],
      fa = j['fa'] ?? '',
      answer = j['answer'],
      speaker = j['speaker'],
      passage = j['passage'],
      passageFa = j['passageFa'],
      choices = List<String>.from(j['choices']),
      choicesFa = List<String>.from(j['choicesFa'] ?? j['choices']);
}

final placementProvider = FutureProvider<(List<PlacementItem>, Map<String, dynamic>?)>((ref) async {
  final j = jsonDecode(await loadAssetText('assets/data/placement.json'));
  return ([for (final i in j['items']) PlacementItem.fromJson(i)], j['speak'] as Map<String, dynamic>?);
});

/// Adaptive placement, A1–C1. Each level is one block (grammar, vocabulary, reading + 2 listening).
/// The test starts at A2: pass a block (≥70%) to climb a level, fail it and the test stops — or, if A2 is failed,
/// drops to A1 to check the basics. Result = highest level passed (minimum A1).
int? placementNext(Map<int, bool> passed) {
  if (passed.isEmpty) return 2;
  if (passed[2] == false) return passed.containsKey(1) ? null : 1;
  final top = passed.keys.reduce((a, b) => a > b ? a : b);
  return passed[top] == true && top < 5 ? top + 1 : null;
}

int placementLevel(Map<int, bool> passed) {
  final ok = [for (final e in passed.entries) if (e.value) e.key];
  return ok.isEmpty ? 1 : ok.reduce((a, b) => a > b ? a : b);
}

/// Pass mark for a block of [n] questions (70%, rounded up: 4 of 5).
int placementPassMark(int n) => (n * .7).ceil();

/// Legacy helper kept for the audit: blocks in level order, the first failure stops the climb.
int placementResult(List<bool?> blockPassed) {
  var lv = 1;
  for (var i = 0; i < blockPassed.length; i++) {
    if (blockPassed[i] == true) {
      lv = i + 1;
    } else {
      break;
    }
  }
  return lv;
}

const placementSkills = {'grammar': ('Grammar', 'دستور زبان'), 'vocab': ('Vocabulary', 'واژگان'), 'listen': ('Listening', 'شنیدن'), 'read': ('Reading', 'خواندن')};

/// What each level means in everyday life (CEFR can-do, plain words).
const placementCanDo = {
  1: ('You can handle simple everyday phrases: greetings, numbers, family, food.', 'جمله‌های ساده روزمره را می‌فهمی: سلام، عدد، خانواده، غذا.'),
  2: ('You can manage routine tasks: shops, buses, short notices and simple past events.', 'کارهای روزمره را انجام می‌دهی: مغازه، اتوبوس، اطلاعیه‌های کوتاه و گذشتهٔ ساده.'),
  3: ('You can deal with most daily situations: school letters, appointments, plans and opinions.', 'از پس بیشتر موقعیت‌های روزمره برمی‌آیی: نامهٔ مدرسه، وقت قبلی، برنامه و نظر.'),
  4: ('You can follow detailed talk and texts on work, housing and the community, and argue a point.', 'گفتگو و متن‌های مفصل دربارهٔ کار، مسکن و محله را می‌فهمی و از نظرت دفاع می‌کنی.'),
  5: ('You can understand complex, implicit meaning and use English flexibly — British understatement included.', 'معنای پیچیده و ضمنی را می‌فهمی و انگلیسی را منعطف به کار می‌بری — حتی کم‌گویی بریتانیایی.'),
};

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});
  @override
  ConsumerState<PlacementScreen> createState() => _PlacementState();
}

class _PlacementState extends ConsumerState<PlacementScreen> {
  int _level = 2, _i = 0, _right = 0;
  final _passed = <int, bool>{};
  final _blockScore = <int, (int, int)>{};
  final _skill = <String, (int, int)>{};
  String? _picked;
  bool _intro = true, _speak = false, _done = false, _listening = false;
  String? _heard;

  List<PlacementItem> _block(List<PlacementItem> all) => all.where((x) => x.level == _level).toList();

  void _play(PlacementItem it) {
    if (it.type == 'listen' && it.speaker != null) Voice.say(it.speaker!, it.text);
  }

  void _start(List<PlacementItem> all) {
    setState(() {
      _intro = _speak = _done = false;
      _level = placementNext(const {})!;
      _i = _right = 0;
      _passed.clear();
      _blockScore.clear();
      _skill.clear();
      _heard = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _play(_block(all)[0]));
  }

  void _answer(List<PlacementItem> all, PlacementItem it, String choice) {
    if (_picked != null) return;
    setState(() => _picked = choice);
    final ok = choice == it.answer;
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      final block = _block(all);
      setState(() {
        if (ok) _right++;
        final sk = _skill[it.type] ?? (0, 0);
        _skill[it.type] = (sk.$1 + (ok ? 1 : 0), sk.$2 + 1);
        _picked = null;
        _i++;
        if (_i >= block.length) {
          _passed[_level] = _right >= placementPassMark(block.length);
          _blockScore[_level] = (_right, block.length);
          final nx = placementNext(_passed);
          if (nx != null) {
            _level = nx;
          } else {
            _speak = true;
          }
          _i = 0;
          _right = 0;
        }
      });
      if (!_speak) {
        final b = _block(all);
        if (_i < b.length) WidgetsBinding.instance.addPostFrameCallback((_) => _play(b[_i]));
      }
    });
  }

  void _finish(int level, {bool save = true}) {
    final ctrl = ref.read(progressProvider.notifier);
    final tier = level - 1;
    if (save) ctrl.setPref('placement', '$level|${DateTime.now().toIso8601String().substring(0, 10)}');
    if (ref.read(progressProvider).onboarded) {
      ctrl.setStartTier(tier);
    } else {
      ctrl.finishOnboarding(startTier: tier, lang: ref.read(progressProvider).lang);
      ctrl.setStartTier(tier);
    }
    // After a real result, go on to set a personal study plan (goal level + target date).
    context.go(save ? '/plan?first=1' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(placementProvider).value;
    final lang = ref.watch(progressProvider).lang;
    final pad = MediaQuery.paddingOf(context);
    final items = data?.$1 ?? const <PlacementItem>[];
    // Progress: blocks finished out of the most the adaptive route can still need.
    final perBlock = items.isEmpty ? 5 : items.where((x) => x.level == 1).length;
    final asked = _blockScore.length * perBlock + _i;
    final total = (_blockScore.length + (_speak || _done ? 0 : 6 - _level).clamp(1, 5)) * perBlock;
    Widget body;
    if (data == null) {
      body = const Center(child: CircularProgressIndicator(color: BL.gold));
    } else if (_intro) {
      body = _introStep(items);
    } else if (_done) {
      body = _result(placementLevel(_passed), items);
    } else if (_speak) {
      body = _speakStep(data.$2);
    } else {
      final it = _block(items)[_i];
      body = _question(items, it, lang);
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF22355C), BL.ink])),
        child: Column(children: [
          SizedBox(height: pad.top + 8),
          Row(children: [
            const SizedBox(width: 8),
            NavBack(light: true, fallback: ref.read(progressProvider).onboarded ? '/' : '/onboarding'),
            const SizedBox(width: 10),
            Expanded(child: Text('PLACEMENT TEST · A1–C1', style: const TextStyle(color: BL.gold, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800))),
            if (!ref.read(progressProvider).onboarded || !_intro) TextButton(key: const ValueKey('placement-skip'), onPressed: () => ref.read(progressProvider).onboarded ? context.go('/') : _finish(1, save: false), child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: _intro ? 0 : _done || _speak ? 1 : (total == 0 ? 0 : asked / total), minHeight: 5, backgroundColor: Colors.white12, color: BL.gold)),
          ),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: KeyedSubtree(key: ValueKey('$_intro-$_level-$_i-$_speak-$_done'), child: body))),
        ]),
      ),
    );
  }

  Widget _question(List<PlacementItem> all, PlacementItem it, String lang) {
    final listen = it.type == 'listen';
    final showFa = listen && lang == 'fa';
    final shown = showFa ? it.choicesFa : it.choices;
    final sk = placementSkills[it.type] ?? placementSkills['grammar']!;
    final (head, headFa) = switch (it.type) {
      'listen' => ('Listen. What does it mean?', 'گوش کن. یعنی چه؟'),
      'read' => ('Read, then answer', 'بخوان و جواب بده'),
      'vocab' => ('Pick the right word', 'کلمهٔ درست را انتخاب کن'),
      _ => ('Choose the correct form', 'شکل درست را انتخاب کن'),
    };
    return ListView(padding: EdgeInsets.fromLTRB(22, 22, 22, 24 + MediaQuery.paddingOf(context).bottom), children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: BL.gold, borderRadius: BorderRadius.circular(8)),
          child: Text(hl(ProgressController.cefrOf(_level)), style: const TextStyle(color: BL.ink, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Text(hl('${sk.$1} · ${sk.$2}'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      Text(hl(head), style: BL.display(26, color: Colors.white)),
      Text(hl(headFa), textDirection: helperDir, style: BL.fa(13, color: Colors.white60)),
      const SizedBox(height: 20),
      if (it.passage != null) ...[
        Container(
          key: const ValueKey('placement-passage'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
          child: Text(hl(it.passage!), style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
        ),
        const SizedBox(height: 12),
      ],
      if (listen)
        Center(
          child: Pressable(
            key: const ValueKey('placement-play'),
            onTap: () => _play(it),
            child: Container(width: 96, height: 96, decoration: const BoxDecoration(color: BL.gold, shape: BoxShape.circle), child: const Icon(Icons.volume_up_rounded, size: 46, color: BL.ink)),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hl(it.text), style: BL.display(20)),
            if (it.fa.isNotEmpty) SizedBox(width: double.infinity, child: Text(hl(it.fa), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted))),
          ]),
        ),
      const SizedBox(height: 20),
      for (var k = 0; k < it.choices.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pressable(
            key: ValueKey('placement-choice-$k'),
            onTap: () => _answer(all, it, it.choices[k]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _picked == null
                    ? Colors.white.withValues(alpha: .08)
                    : it.choices[k] == it.answer
                    ? BL.green
                    : _picked == it.choices[k]
                    ? BL.red
                    : Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(hl(shown[k]), textDirection: showFa ? helperDir : TextDirection.ltr, style: showFa ? BL.fa(14.5, color: Colors.white) : const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
    ]);
  }

  Widget _speakStep(Map<String, dynamic>? sp) {
    if (sp == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _done = true));
      return const SizedBox.shrink();
    }
    final text = sp['text'] as String;
    final ok = _heard != null && _overlap(_heard!, text) >= .6;
    return ListView(padding: EdgeInsets.fromLTRB(22, 22, 22, 24 + MediaQuery.paddingOf(context).bottom), children: [
      const Text('Optional · speaking', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Say it like Tom', style: BL.display(26, color: Colors.white)),
      Text(hl('مثل تام بگو (اختیاری)'), textDirection: helperDir, style: BL.fa(13, color: Colors.white60)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hl('“$text”'), style: BL.display(21)),
          SizedBox(width: double.infinity, child: Text(hl(sp['fa'] ?? ''), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted))),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => Voice.say(sp['speaker'] ?? 'tom', text), icon: const Icon(Icons.volume_up_rounded), label: const Text('Hear it')),
        ]),
      ),
      const SizedBox(height: 18),
      if (SpeechInput.sttSupported)
        Center(
          child: Pressable(
            onTap: () async {
              if (_listening) return;
              setState(() => _listening = true);
              final h = await SpeechInput.listen();
              if (mounted) setState(() { _listening = false; _heard = h ?? ''; });
            },
            child: Container(width: 84, height: 84, decoration: BoxDecoration(color: _listening ? BL.gold : BL.red, shape: BoxShape.circle), child: const Icon(Icons.mic_rounded, color: Colors.white, size: 40)),
          ),
        ),
      if (_heard != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(hl(ok ? 'Lovely — that sounded great! 👏' : 'Good try! You said: “$_heard”'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      const SizedBox(height: 18),
      FilledButton(
        key: const ValueKey('placement-speak-next'),
        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
        onPressed: () => setState(() => _done = true),
        child: Text(hl(_heard == null ? 'Skip this one' : 'See my level'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    ]);
  }

  static double _overlap(String a, String b) {
    List<String> w(String s) => s.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').split(' ').where((x) => x.isNotEmpty).toList();
    final want = w(b), got = w(a).toSet();
    return want.isEmpty ? 0 : want.where(got.contains).length / want.length;
  }

  Widget _introStep(List<PlacementItem> items) {
    final ctrl = ref.read(progressProvider.notifier);
    final last = ctrl.pref('placement').split('|');
    final lastLv = int.tryParse(last.first);
    return ListView(padding: EdgeInsets.fromLTRB(22, 26, 22, 24 + MediaQuery.paddingOf(context).bottom), children: [
      Text('Find your level', style: BL.display(32, color: Colors.white)),
      Text(hl('سطحت را پیدا کن'), textDirection: helperDir, style: BL.fa(14, color: Colors.white60)),
      const SizedBox(height: 14),
      const Text('An adaptive test from A1 to C1. It starts at A2 and moves up when you do well — or down to check the basics. About 5–8 minutes.',
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
      Text(hl('آزمون تطبیقی از A1 تا C1. از A2 شروع می‌شود؛ اگر خوب جواب بدهی بالا می‌رود، وگرنه پایه‌ها را می‌سنجد. حدود ۵ تا ۸ دقیقه.'),
          textDirection: helperDir, style: BL.fa(12.5, color: Colors.white60)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in placementSkills.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(switch (e.key) { 'listen' => Icons.headphones_rounded, 'read' => Icons.menu_book_rounded, 'vocab' => Icons.translate_rounded, _ => Icons.rule_rounded }, size: 16, color: BL.gold),
              const SizedBox(width: 6),
              Flexible(child: Text(hl('${e.value.$1} · ${e.value.$2}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
            ]),
          ),
      ]),
      const SizedBox(height: 16),
      if (lastLv != null)
        Container(
          key: const ValueKey('placement-last'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(14)),
          child: Text(hl('Last result: ${ProgressController.cefrOf(lastLv)} on ${last.length > 1 ? last[1] : ''}. You can retake it any time.'),
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 18),
      FilledButton(
        key: const ValueKey('placement-begin'),
        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
        onPressed: items.isEmpty ? null : () => _start(items),
        child: Text(hl(lastLv == null ? 'Start the test' : 'Retake the test'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    ]);
  }

  Widget _result(int lv, List<PlacementItem> items) {
    const names = {1: 'Home', 2: 'Neighbourhood', 3: 'High Street', 4: 'Town centre', 5: 'The city'};
    final cefr = ProgressController.cefrOf(lv);
    final can = placementCanDo[lv]!;
    final failedAll = _passed.values.every((v) => !v);
    final levels = _blockScore.keys.toList()..sort();
    return ListView(padding: EdgeInsets.fromLTRB(22, 26, 22, 24 + MediaQuery.paddingOf(context).bottom), children: [
      Text('Your level', style: BL.display(30, color: Colors.white)),
      Text(hl('سطح تو'), textDirection: helperDir, style: BL.fa(13, color: Colors.white60)),
      const SizedBox(height: 16),
      Container(
        key: ValueKey('placement-result-$lv'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Text(hl(cefr), style: BL.display(48, color: BL.red)),
          Text(hl('Level $lv · ${names[lv]}'), style: const TextStyle(fontWeight: FontWeight.w800, color: BL.ink)),
          const SizedBox(height: 10),
          Text(hl(can.$1), textAlign: TextAlign.center, style: const TextStyle(color: BL.ink, height: 1.35, fontWeight: FontWeight.w600)),
          SizedBox(width: double.infinity, child: Text(hl(can.$2), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(12.5, color: BL.muted))),
        ]),
      ),
      const SizedBox(height: 16),
      Text('Why this level', style: BL.display(19, color: Colors.white)),
      const SizedBox(height: 6),
      for (final l in levels)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(_passed[l]! ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: _passed[l]! ? const Color(0xFF4CC28A) : const Color(0xFFFF7A6E)),
            const SizedBox(width: 8),
            Expanded(child: Text(hl('${ProgressController.cefrOf(l)}: ${_blockScore[l]!.$1} of ${_blockScore[l]!.$2} right — ${_passed[l]! ? 'passed' : 'not yet (need ${placementPassMark(_blockScore[l]!.$2)})'}'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
        ),
      Text(
        hl(failedAll
            ? 'We\'ll start at A1 so the basics feel easy — you\'ll move up fast.'
            : 'You passed $cefr${lv < 5 ? ' but not ${ProgressController.cefrOf(lv + 1)} yet' : ''}, so your path starts at $cefr. Earlier levels stay open to revisit; pass $cefr\'s level test to move up.'),
        style: const TextStyle(color: Colors.white70, height: 1.35),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in placementSkills.entries)
          if (_skill[e.key] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
              child: Text(hl('${e.value.$1} ${_skill[e.key]!.$1}/${_skill[e.key]!.$2}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
      ]),
      const SizedBox(height: 18),
      FilledButton(
        key: const ValueKey('placement-start'),
        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
        onPressed: () => _finish(lv),
        child: Text(hl('Start at $cefr'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      TextButton(key: const ValueKey('placement-retake'), onPressed: () => _start(items), child: const Text('Retake the test', style: TextStyle(color: Colors.white70))),
      if (lv > 1) TextButton(onPressed: () => _finish(1), child: const Text('Start from A1 instead', style: TextStyle(color: Colors.white54))),
    ]);
  }
}
