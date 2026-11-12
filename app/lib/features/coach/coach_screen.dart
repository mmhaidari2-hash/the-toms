import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/engine/practice_loop.dart';
import '../../core/engine/pronunciation.dart';
import '../../core/platform/speech.dart';
import '../../core/platform/voice.dart';
import '../shared/nav.dart';
import '../speaking/speaking_widgets.dart';

/// Pronunciation coach: hear the model (Azure clip, normal or slow), then speak; the browser's or (Android) the
/// phone's speech-to-text shows which words came through. A practice loop, not a phoneme score (owner t306 item 4).
/// No Azure Pronunciation Assessment (keeps spend $0 and matches the privacy policy).
/// Test seam: replaces the recognizer (alternatives for one try).
abstract final class CoachScreenTest {
  static Future<SpeechResult> Function()? listen;
}

class CoachScreen extends ConsumerStatefulWidget {
  final String? seed;
  const CoachScreen({super.key, this.seed});
  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  static const _lines = [
    ('hollie', 'Hello. How can I help you today?'),
    ('abbi', 'Could you speak a little more slowly, please?'),
    ('hollie', 'I would like to book an appointment.'),
    ('abbi', 'Where is the nearest tube station?'),
    ('hollie', 'My National Insurance number is on the letter.'),
    ('abbi', 'I have lived in the United Kingdom for five years.'),
    ('hollie', 'Could you repeat that, please?'),
    ('abbi', 'Thank you for your help. Have a nice day.'),
  ];

  late int _i;
  PronResult? _result;
  bool _listening = false;
  String? _err;
  String _partial = '';
  late PracticeLoop _loop;


  @override
  void initState() {
    super.initState();
    final seed = widget.seed?.toLowerCase() ?? '';
    final hit = _lines.indexWhere((e) => e.$2.toLowerCase().contains(seed) && seed.isNotEmpty);
    _i = hit >= 0 ? hit : 0;
    _loop = PracticeLoop(_cur.$2);
  }

  void _go(int i) => setState(() {
        _i = i % _lines.length;
        _result = null;
        _err = null;
        _loop = PracticeLoop(_cur.$2);
      });

  (String, String) get _cur => _lines[_i % _lines.length];

  Future<void> _hear({bool slow = false}) async {
    final (v, t) = _cur;
    await Voice.say(v, t, rate: slow ? Voice.rates.first : 1);
  }

  Future<void> _speak() async {
    if (CoachScreenTest.listen == null && !SpeechInput.sttSupported) {
      setState(() { _listening = false; _err = 'unsupported'; _result = null; });
      return;
    }
    setState(() { _listening = true; _err = null; _partial = ''; });
    try {
      final r = CoachScreenTest.listen != null ? await CoachScreenTest.listen!() : await SpeechInput.listenDetailed(onPartial: (p) {
        if (mounted) setState(() => _partial = p);
      });
      if (!mounted) return;
      if (!r.ok) {
        setState(() { _listening = false; _err = r.permissionDenied || r.error == 'unsupported' ? r.error : 'mic'; });
        return;
      }
      setState(() {
        _listening = false;
        _result = _loop.add(r.alternatives);
      });
    } catch (_) {
      if (mounted) setState(() { _listening = false; _err = 'mic'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (voice, text) = _cur;
    final r = _result;
    return Scaffold(
      key: const ValueKey('coach-hub'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              const NavBack(fallback: '/'),
              const SizedBox(width: 4),
              Expanded(child: Text(hl('Pronunciation coach'), style: BL.display(22))),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(coachIntro().$1, style: const TextStyle(fontSize: 13.5, height: 1.4, color: BL.ink)),
                const SizedBox(height: 6),
                Text(coachIntro().$2, textDirection: helperDir, textAlign: TextAlign.right, style: BL.fa(13, color: BL.muted)),
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('ai-coach-note'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: BL.mist)),
                  // English line LTR, Persian line its own RTL Text (was one LTR Text: Persian punctuation flipped). The coach strings
                  // have no helper-table entries yet, so they stay Persian rather than going through hl() word by word.
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(coachAiNote().$1, style: const TextStyle(fontSize: 12, height: 1.35, color: BL.muted)),
                    Text(coachAiNote().$2, key: const ValueKey('ai-coach-note-helper'), textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
                  ]),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: BL.mist)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(hl('LINE ${_i + 1} / ${_lines.length}'), style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: BL.red)),
                    const SizedBox(height: 8),
                    Text(hl(text), key: const ValueKey('coach-line'), style: BL.display(22).copyWith(height: 1.35)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('coach-hear'),
                          onPressed: _hear,
                          style: FilledButton.styleFrom(backgroundColor: BL.green, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text(hl('Hear model'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('coach-speak'),
                          onPressed: _listening ? null : _speak,
                          style: FilledButton.styleFrom(backgroundColor: BL.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded),
                          label: Text(hl(_listening ? 'Listening…' : 'I say it'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ]),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('coach-mic-help'),
                    onPressed: () => showMicHelp(context, _err, onType: null),
                    icon: const Icon(Icons.mic_off_rounded),
                    label: Text(_err == 'unsupported' ? 'Why speaking is unavailable' : 'Microphone help — tap to see how to allow it'),
                  ),
                ],
                if (_listening && _partial.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(hl('Heard so far: $_partial'), key: const ValueKey('coach-partial'), style: const TextStyle(color: BL.muted, fontStyle: FontStyle.italic)),
                ],
                if (r != null) ...[
                  const SizedBox(height: 16),
                  PronunciationCard(result: r, dark: false, onRetry: _speak, onListen: _hear),
                  const SizedBox(height: 10),
                  Text(hl(_loop.tip.$1), key: const ValueKey('coach-tip'), style: const TextStyle(fontWeight: FontWeight.w700, color: BL.ink)),
                  Text(_loop.tip.$2, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                  if (_loop.focusWords.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, key: const ValueKey('coach-focus'), children: [
                      Text(hl('Focus:'), style: const TextStyle(fontWeight: FontWeight.w800, color: BL.red)),
                      for (final w in _loop.focusWords) Chip(label: Text(w), visualDensity: VisualDensity.compact, backgroundColor: markClose.withValues(alpha: .15)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    hl('Tries: ${[for (var k = 0; k < _loop.attempts.length; k++) '${k + 1}: ${_loop.attempts[k].score}%'].join(' · ')}   Best: ${_loop.bestScore}%'),
                    key: const ValueKey('coach-history'),
                    style: const TextStyle(fontSize: 12, color: BL.muted),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('coach-slow'),
                  onPressed: () => _hear(slow: true),
                  icon: const Icon(Icons.slow_motion_video_rounded),
                  label: Text(hl('Hear slowly · آهسته بشنو')),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  TextButton(key: const ValueKey('coach-prev'), onPressed: () => _go(_i - 1), child: Text(hl('Previous'))),
                  const Spacer(),
                  TextButton(key: const ValueKey('coach-next'), onPressed: () => _go(_i + 1), child: Text(hl(_loop.passed ? 'Next line ✓' : 'Next line'))),
                ]),
                const SizedBox(height: 8),
                TextButton(onPressed: () => context.go('/'), child: Text(hl('Back to the map'))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
