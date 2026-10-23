import 'package:british_life/core/i18n/helper_text.dart';
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
                  hl('$s%'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hl(s >= 90
                      ? 'Spot on!'
                      : s >= Pronunciation.passScore
                      ? 'Clear. Nicely done!'
                      : s >= 40
                      ? 'Nearly. Try the coloured words again.'
                      : 'Not quite. Listen, then try again.'),
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
                  message: hl(w.mark == WordMark.good ? 'Clear' : (w.heard == null ? 'Not heard' : 'Heard “${w.heard}”')),
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
                      hl(w.word),
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hl('You said: “${result.heard}”'),
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
                    hl(result.passed ? 'Send' : 'Send anyway'),
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
        Text(hl(t), style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
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
                      hl(unsupported
                          ? 'Speaking isn\'t available here'
                          : dictation
                          ? 'Turn on Dictation'
                          : 'Allow the microphone'),
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
                if (SpeechInput.isStandalone) ...[
                  const SizedBox(height: 6),
                  const Text(key: ValueKey('mic-help-standalone'), 'Opened from your Home Screen? Apple may not allow speech there: open New Life UK in Safari to speak, or type / tap your reply.'),
                ],
              ] else ...[
                const Text(
                  key: ValueKey('mic-privacy'),
                  'New Life UK only listens while the microphone is red. Your speech is turned into text by your browser\'s speech service (Google in Chrome, Apple in Safari), which may process your voice on its servers. The Toms doesn\'t store or send your recordings itself; "Record" clips stay on your device.',
                ),
                const SizedBox(height: 4),
                Text(hl('میکروفون فقط وقتی قرمز است گوش می‌دهد. گفتار شما را سرویس گفتار مرورگرتان (گوگل در کروم، اپل در سافاری) به متن تبدیل می‌کند و ممکن است صدایتان را روی سرورهای خودش پردازش کند. New Life UK خودش صدای شما را ذخیره یا ارسال نمی‌کند؛ ضبط‌های «Record» فقط روی دستگاه شما می‌مانند.'), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
                const SizedBox(height: 8),
                const Text('iPhone (Safari): tap "aA" in the address bar › Website Settings › Microphone › Allow. Or Settings › Apps › Safari › Microphone.'),
                const SizedBox(height: 6),
                const Text('Android / Chrome: tap the lock icon by the address › Permissions › Microphone › Allow.'),
              ],
              const SizedBox(height: 6),
              Text(
                hl(unsupported ? 'تشخیص گفتار در این مرورگر در دسترس نیست. سافاری یا کروم را امتحان کنید.' : 'اجازهٔ میکروفون را در تنظیمات مرورگر بدهید و دوباره امتحان کنید.'),
                textDirection: helperDir,
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
  'no-speech' => 'I didn\'t catch that. Tap the mic, wait for red, then speak — or tap a reply above.',
  'start-failed' => SpeechInput.isStandalone
      ? 'Speech isn\'t working in the Home Screen app. Open it in Safari to speak, or type / tap a reply.'
      : 'The microphone didn\'t start. Check Dictation is on, or type / tap a reply.',
  'audio-capture' => 'No microphone found. Is another app using it?',
  'network' => 'Speech recognition needs the internet on this device.',
  'aborted' => 'Stopped.',
  _ => 'Something went wrong. Try again, or type / tap a reply.',
};

/// The same message in the helper language.
String speechErrorFa(String? e) => switch (e) {
  'no-speech' => 'صدایت را نشنیدم. میکروفون را بزن، صبر کن قرمز شود، بعد حرف بزن — یا یکی از جواب‌های بالا را بزن.',
  'start-failed' => SpeechInput.isStandalone
      ? 'گفتار در نسخهٔ صفحهٔ اصلی کار نمی‌کند. برنامه را در سافاری باز کن، یا جوابت را بنویس یا انتخاب کن.'
      : 'میکروفون روشن نشد. دیکته (Dictation) را روشن کن، یا جوابت را بنویس یا انتخاب کن.',
  'audio-capture' => 'میکروفونی پیدا نشد. شاید برنامهٔ دیگری از آن استفاده می‌کند.',
  'network' => 'تشخیص گفتار روی این دستگاه به اینترنت نیاز دارد.',
  'aborted' => 'متوقف شد.',
  _ => 'مشکلی پیش آمد. دوباره امتحان کن، یا جوابت را بنویس یا انتخاب کن.',
};

bool get speechAvailable => SpeechInput.sttSupported;
