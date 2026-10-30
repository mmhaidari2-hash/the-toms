import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/engine/pronunciation.dart';
import '../../core/platform/speech.dart';
import '../../core/platform/voice.dart';
import '../shared/nav.dart';
import '../speaking/speaking_widgets.dart';

/// Pronunciation coach: hear the model (Azure clip), then speak; score via browser STT.
/// No Azure Pronunciation Assessment (keeps spend $0 and matches the privacy policy).
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

  @override
  void initState() {
    super.initState();
    final seed = widget.seed?.toLowerCase() ?? '';
    final hit = _lines.indexWhere((e) => e.$2.toLowerCase().contains(seed) && seed.isNotEmpty);
    _i = hit >= 0 ? hit : 0;
  }

  (String, String) get _cur => _lines[_i % _lines.length];

  Future<void> _hear() async {
    final (v, t) = _cur;
    await Voice.say(v, t);
  }

  Future<void> _speak() async {
    setState(() { _listening = true; _err = null; _result = null; });
    try {
      final heard = await SpeechInput.listen();
      if (!mounted) return;
      if (heard == null || heard.trim().isEmpty) {
        setState(() { _listening = false; _err = 'mic'; });
        return;
      }
      setState(() {
        _listening = false;
        _result = Pronunciation.score(_cur.$2, heard);
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
                Text(hl('Hear the model, then say the same line. Your browser turns speech into text for the score — nothing is uploaded by New Life UK.'),
                    style: const TextStyle(fontSize: 13.5, height: 1.4, color: BL.ink)),
                const SizedBox(height: 6),
                Text(hl('مدل را بشنو، بعد همان جمله را بگو. مرورگر صدایت را به متن تبدیل می‌کند — اپ چیزی آپلود نمی‌کند.'),
                    textDirection: helperDir, textAlign: TextAlign.right, style: BL.fa(13, color: BL.muted)),
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
                    label: Text(hl('Microphone help — tap to see how to allow it')),
                  ),
                ],
                if (r != null) ...[
                  const SizedBox(height: 16),
                  PronunciationCard(result: r, onRetry: _speak, onListen: _hear),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  TextButton(key: const ValueKey('coach-prev'), onPressed: () => setState(() { _i = (_i - 1) % _lines.length; _result = null; _err = null; }), child: Text(hl('Previous'))),
                  const Spacer(),
                  TextButton(key: const ValueKey('coach-next'), onPressed: () => setState(() { _i = (_i + 1) % _lines.length; _result = null; _err = null; }), child: Text(hl('Next line'))),
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
