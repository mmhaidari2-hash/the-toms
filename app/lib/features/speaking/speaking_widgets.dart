import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/engine/pronunciation.dart';
import '../../core/platform/speech.dart';

const markGood = Color(0xFF3FB27F), markClose = Color(0xFFE9B949), markMissed = Color(0xFFE5484D);

/// The target sentence with every word coloured by how clearly it was recognised.
class PronunciationCard extends StatelessWidget {
  final PronResult result;
  final bool dark;
  final VoidCallback? onRetry, onListen, onSend;
  const PronunciationCard({super.key, required this.result, this.dark = true, this.onRetry, this.onListen, this.onSend});
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : BL.ink;
    final sub = dark ? Colors.white60 : BL.muted;
    final s = result.score;
    final col = s >= Pronunciation.passScore
        ? markGood
        : s >= 40
        ? markClose
        : markMissed;
    return Container(
      key: const ValueKey('pron-card'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: .07) : BL.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: .7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                key: const ValueKey('pron-score'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  '$s%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s >= 90
                      ? 'Spot on!'
                      : s >= Pronunciation.passScore
                      ? 'Clear. Nicely done!'
                      : s >= 40
                      ? 'Nearly. Try the coloured words again.'
                      : 'Not quite. Listen, then try again.',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final w in result.words)
                Tooltip(
                  message: w.mark == WordMark.good ? 'Clear' : (w.heard == null ? 'Not heard' : 'Heard “${w.heard}”'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          (w.mark == WordMark.good
                                  ? markGood
                                  : w.mark == WordMark.close
                                  ? markClose
                                  : markMissed)
                              .withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        bottom: BorderSide(
                          color: w.mark == WordMark.good
                              ? markGood
                              : w.mark == WordMark.close
                              ? markClose
                              : markMissed,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      w.word,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You said: “${result.heard}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: sub, fontSize: 12, fontStyle: FontStyle.italic),
          ),
          Row(
            children: [
              const Expanded(child: Wrap(children: [_Legend(markGood, 'clear'), _Legend(markClose, 'nearly'), _Legend(markMissed, 'missed')])),
              if (onListen != null)
                IconButton(
                  key: const ValueKey('pron-listen'),
                  tooltip: 'Listen',
                  visualDensity: VisualDensity.compact,
                  onPressed: onListen,
                  icon: Icon(Icons.volume_up_rounded, color: fg, size: 20),
                ),
              if (onRetry != null)
                IconButton(
                  key: const ValueKey('pron-retry'),
                  tooltip: 'Try again',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRetry,
                  icon: Icon(Icons.replay_rounded, color: fg, size: 20),
                ),
              if (onSend != null)
                TextButton(
                  key: const ValueKey('pron-send'),
                  onPressed: onSend,
                  child: Text(
                    result.passed ? 'Send' : 'Send anyway',
                    style: const TextStyle(color: BL.gold, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color c;
  final String t;
  const _Legend(this.c, this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(t, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      ],
    ),
  );
}

/// Friendly help when the microphone or speech recognition is blocked, or not available at all.
Future<void> showMicHelp(BuildContext context, String? error, {VoidCallback? onType}) {
  final unsupported = error == 'unsupported';
  final dictation = error == 'service-not-allowed';
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: BL.cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            key: const ValueKey('mic-help'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(unsupported ? Icons.mic_off_rounded : Icons.mic_none_rounded, color: BL.red, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      unsupported
                          ? 'Speaking isn\'t available here'
                          : dictation
                          ? 'Turn on Dictation'
                          : 'Allow the microphone',
                      style: BL.display(22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (unsupported) ...[
                const Text('This browser can\'t recognise speech. Open the app in Safari (iPhone) or Chrome (Android, computer) to speak your replies.'),
                const SizedBox(height: 6),
                const Text('Meanwhile you can still tap "Record" to hear yourself and compare with the character.'),
              ] else if (dictation) ...[
                const Text('On iPhone, Safari needs Dictation for speech recognition:'),
                const SizedBox(height: 6),
                const Text('Settings › General › Keyboard › Enable Dictation (on).'),
                const SizedBox(height: 6),
                const Text('Then come back and tap the microphone again.'),
              ] else ...[
                const Text(
                  key: ValueKey('mic-privacy'),
                  'New Life UK only listens while the microphone is red. Your speech is turned into text by your browser\'s speech service (Google in Chrome, Apple in Safari), which may process your voice on its servers. The Toms doesn\'t store or send your recordings itself; "Record" clips stay on your device.',
                ),
                const SizedBox(height: 4),
                Text('میکروفون فقط وقتی قرمز است گوش می‌دهد. گفتار شما را سرویس گفتار مرورگرتان (گوگل در کروم، اپل در سافاری) به متن تبدیل می‌کند و ممکن است صدایتان را روی سرورهای خودش پردازش کند. The Toms خودش صدای شما را ذخیره یا ارسال نمی‌کند؛ ضبط‌های «Record» فقط روی دستگاه شما می‌مانند.', textDirection: TextDirection.rtl, style: BL.fa(12.5, color: BL.muted)),
                const SizedBox(height: 8),
                const Text('iPhone (Safari): tap "aA" in the address bar › Website Settings › Microphone › Allow. Or Settings › Apps › Safari › Microphone.'),
                const SizedBox(height: 6),
                const Text('Android / Chrome: tap the lock icon by the address › Permissions › Microphone › Allow.'),
              ],
              const SizedBox(height: 6),
              Text(
                unsupported ? 'تشخیص گفتار در این مرورگر در دسترس نیست. سافاری یا کروم را امتحان کنید.' : 'اجازهٔ میکروفون را در تنظیمات مرورگر بدهید و دوباره امتحان کنید.',
                textDirection: TextDirection.rtl,
                style: BL.fa(12.5, color: BL.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (onType != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheet);
                          onType();
                        },
                        child: const Text('Type instead'),
                      ),
                    ),
                  if (onType != null) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: BL.red),
                      onPressed: () => Navigator.pop(sheet),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Short message for a recognition error that is not a permission problem.
String speechErrorText(String? e) => switch (e) {
  'no-speech' => 'I didn\'t catch anything. Tap the mic and speak a little louder.',
  'audio-capture' => 'No microphone found. Is another app using it?',
  'network' => 'Speech recognition needs the internet on this device.',
  'aborted' => 'Stopped.',
  _ => 'Something went wrong. Please try again.',
};

bool get speechAvailable => SpeechInput.sttSupported;
