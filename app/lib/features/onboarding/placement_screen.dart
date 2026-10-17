import 'dart:convert';

import 'package:flutter/material.dart';
import '../shared/nav.dart';
import 'package:flutter/services.dart';
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
  final String? speaker;
  final List<String> choices, choicesFa;
  PlacementItem.fromJson(Map<String, dynamic> j)
    : level = j['level'],
      type = j['type'],
      text = j['text'],
      fa = j['fa'] ?? '',
      answer = j['answer'],
      speaker = j['speaker'],
      choices = List<String>.from(j['choices']),
      choicesFa = List<String>.from(j['choicesFa'] ?? j['choices']);
}

final placementProvider = FutureProvider<(List<PlacementItem>, Map<String, dynamic>?)>((ref) async {
  final j = jsonDecode(await rootBundle.loadString('assets/data/placement.json'));
  return ([for (final i in j['items']) PlacementItem.fromJson(i)], j['speak'] as Map<String, dynamic>?);
});

/// Adaptive placement: one block (2 listening + 1 choice) per level, starting at Level 1.
/// Pass a block (2 of 3) to climb; the first failed block stops the test. Result = highest level passed (min 1).
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

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});
  @override
  ConsumerState<PlacementScreen> createState() => _PlacementState();
}

class _PlacementState extends ConsumerState<PlacementScreen> {
  int _level = 1, _i = 0, _right = 0, _passed = 0;
  String? _picked;
  bool _speak = false, _done = false, _listening = false;
  String? _heard;

  List<PlacementItem> _block(List<PlacementItem> all) => all.where((x) => x.level == _level).toList();

  void _play(PlacementItem it) {
    if (it.type == 'listen' && it.speaker != null) Voice.say(it.speaker!, it.text);
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
        _picked = null;
        _i++;
        if (_i >= block.length) {
          final pass = _right >= 2;
          if (pass) _passed = _level;
          if (pass && _level < 5) {
            _level++;
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

  void _finish(int level) {
    final ctrl = ref.read(progressProvider.notifier);
    final tier = level - 1;
    if (ref.read(progressProvider).onboarded) {
      ctrl.setStartTier(tier);
    } else {
      ctrl.finishOnboarding(startTier: tier, lang: ref.read(progressProvider).lang);
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(placementProvider).value;
    final lang = ref.watch(progressProvider).lang;
    final pad = MediaQuery.paddingOf(context);
    final items = data?.$1 ?? const <PlacementItem>[];
    final total = items.length;
    final asked = items.where((x) => x.level < _level).length + _i;
    Widget body;
    if (data == null) {
      body = const Center(child: CircularProgressIndicator(color: BL.gold));
    } else if (_done) {
      final lv = _passed < 1 ? 1 : _passed;
      body = _result(lv);
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
            Expanded(child: Text('PLACEMENT TEST · ~5 MIN', style: const TextStyle(color: BL.gold, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800))),
            TextButton(key: const ValueKey('placement-skip'), onPressed: () => _finish(1), child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: _done || _speak ? 1 : (total == 0 ? 0 : asked / total), minHeight: 5, backgroundColor: Colors.white12, color: BL.gold)),
          ),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: KeyedSubtree(key: ValueKey('$_level-$_i-$_speak-$_done'), child: body))),
        ]),
      ),
    );
  }

  Widget _question(List<PlacementItem> all, PlacementItem it, String lang) {
    final listen = it.type == 'listen';
    final showFa = listen && lang == 'fa';
    final shown = showFa ? it.choicesFa : it.choices;
    return ListView(padding: EdgeInsets.fromLTRB(22, 22, 22, 24 + MediaQuery.paddingOf(context).bottom), children: [
      Text('Level $_level', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(listen ? 'Listen. What does it mean?' : 'Choose the best answer', style: BL.display(26, color: Colors.white)),
      Text(listen ? 'گوش کن. یعنی چه؟' : 'بهترین گزینه را انتخاب کن', textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white60)),
      const SizedBox(height: 20),
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
            Text(it.text, style: BL.display(20)),
            if (it.fa.isNotEmpty) SizedBox(width: double.infinity, child: Text(it.fa, textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted))),
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
              child: Text(shown[k], textDirection: showFa ? TextDirection.rtl : TextDirection.ltr, style: showFa ? BL.fa(14.5, color: Colors.white) : const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
      Text('مثل تام بگو (اختیاری)', textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white60)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('“$text”', style: BL.display(21)),
          SizedBox(width: double.infinity, child: Text(sp['fa'] ?? '', textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted))),
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
      if (_heard != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(ok ? 'Lovely — that sounded great! 👏' : 'Good try! You said: “$_heard”', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      const SizedBox(height: 18),
      FilledButton(
        key: const ValueKey('placement-speak-next'),
        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
        onPressed: () => setState(() => _done = true),
        child: Text(_heard == null ? 'Skip this one' : 'See my level', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    ]);
  }

  static double _overlap(String a, String b) {
    List<String> w(String s) => s.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').split(' ').where((x) => x.isNotEmpty).toList();
    final want = w(b), got = w(a).toSet();
    return want.isEmpty ? 0 : want.where(got.contains).length / want.length;
  }

  Widget _result(int lv) {
    const names = {1: ('Home', 'A0 → A1'), 2: ('Neighbourhood', 'A1 → A2'), 3: ('High Street', 'A2 → B1'), 4: ('Town centre', 'B1 → B2'), 5: ('The city', 'B2 → C1')};
    final n = names[lv]!;
    return ListView(padding: EdgeInsets.fromLTRB(22, 30, 22, 24 + MediaQuery.paddingOf(context).bottom), children: [
      Text('Your level', style: BL.display(30, color: Colors.white)),
      Text('سطح تو', textDirection: TextDirection.rtl, style: BL.fa(13, color: Colors.white60)),
      const SizedBox(height: 20),
      Container(
        key: ValueKey('placement-result-$lv'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: BL.cream, borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Text('Level $lv', style: BL.display(40, color: BL.red)),
          Text('${n.$1}  ·  ${n.$2}', style: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink)),
        ]),
      ),
      const SizedBox(height: 18),
      FilledButton(
        key: const ValueKey('placement-start'),
        style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
        onPressed: () => _finish(lv),
        child: Text('Start at Level $lv', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      if (lv > 1) TextButton(onPressed: () => _finish(1), child: const Text('Start from the beginning instead', style: TextStyle(color: Colors.white70))),
    ]);
  }
}
