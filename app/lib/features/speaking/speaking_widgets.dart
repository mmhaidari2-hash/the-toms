import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../shared/sheets.dart';

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

/// Privacy line for Android speech recognition (owner t306): honest about Google, nothing uploaded by the app.
const androidSttPrivacy = "Android turns your speech into text with the phone's own speech recognizer (usually Google's). On phones with an offline English model it runs on the device; otherwise, depending on your Android settings, Google may process your voice on its servers. New Life UK does not record, store or upload your voice.";
const androidSttPrivacyFa = 'اندروید گفتار شما را با تشخیص گفتار خود گوشی (معمولاً گوگل) به متن تبدیل می‌کند. اگر گوشی مدل آفلاین انگلیسی داشته باشد روی خود دستگاه انجام می‌شود؛ وگرنه بسته به تنظیمات اندروید، ممکن است گوگل صدایتان را روی سرورهایش پردازش کند. New Life UK صدای شما را ضبط، ذخیره یا ارسال نمی‌کند.';

/// True on the installed Android app when the phone's speech recognizer is in use.
bool nativeStt({bool? web, bool? sttSupported}) => !(web ?? kIsWeb) && (sttSupported ?? SpeechInput.sttSupported);

/// Explanation shown once before Android's microphone prompt. Returns true when the learner continues.
Future<bool> showMicRationale(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      key: const ValueKey('mic-rationale'),
      title: const Text('Use your voice?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('To practise speaking, New Life UK needs the microphone. It only listens while the microphone button is red.'),
          const SizedBox(height: 6),
          Text('برای تمرین صحبت، New Life UK به میکروفون نیاز دارد. فقط وقتی دکمهٔ میکروفون قرمز است گوش می‌دهد.', textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
          const SizedBox(height: 10),
          const Text(androidSttPrivacy, style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(androidSttPrivacyFa, textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
          const SizedBox(height: 10),
          const Text('You can always type instead. · همیشه می‌توانید به‌جایش بنویسید.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      ),
      actions: [
        TextButton(key: const ValueKey('mic-rationale-no'), onPressed: () => Navigator.pop(d, false), child: const Text('Type instead · نوشتن')),
        FilledButton(key: const ValueKey('mic-rationale-yes'), style: FilledButton.styleFrom(backgroundColor: BL.red), onPressed: () => Navigator.pop(d, true), child: const Text('Continue · ادامه')),
      ],
    ),
  );
  return ok ?? false;
}

/// Native builds without a recognizer report both flags false. Do not promise OS recognition or in-app recording there.
bool get nativeSpeechOff => !kIsWeb && !SpeechInput.sttSupported && !SpeechInput.recordSupported;

/// Tooltip for the reply microphone. Web can still point at the keyboard mic; the installed app cannot.
String replyMicTip({bool? web, bool? sttSupported, bool? sttBroken, bool? recordSupported}) {
  final webOn = web ?? kIsWeb;
  final stt = sttSupported ?? SpeechInput.sttSupported;
  final broken = sttBroken ?? SpeechInput.sttBroken;
  final record = recordSupported ?? SpeechInput.recordSupported;
  if (stt && !broken) return 'Speak your replies';
  if (!webOn && !stt && !record) return 'Type your reply';
  return 'Speak with the keyboard mic';
}

class MicHelpCopy {
  final String title, body, bodyFa;
  const MicHelpCopy(this.title, this.body, this.bodyFa);
}

/// Wording for the microphone sheet. [web] false with both capabilities false is the installed app.
MicHelpCopy micHelpCopy(String? error, {bool? web, bool? sttSupported, bool? recordSupported}) {
  final webOn = web ?? kIsWeb;
  final stt = sttSupported ?? SpeechInput.sttSupported;
  final record = recordSupported ?? SpeechInput.recordSupported;
  final installed = !webOn && !stt && !record;
  if (!webOn && stt) {
    if (error == 'unsupported') {
      return const MicHelpCopy(
        "Speaking isn't available on this phone",
        'This phone has no speech recognition service. Type a reply, or tap one of the answers.',
        'این گوشی سرویس تشخیص گفتار ندارد. جواب را بنویس، یا یکی از پاسخ‌ها را بزن.',
      );
    }
    return const MicHelpCopy('Allow the microphone', androidSttPrivacy, androidSttPrivacyFa);
  }
  if (installed) {
    return const MicHelpCopy(
      "Speaking isn't available in this app",
      "This installed app cannot turn your voice into text, and it does not record you. It does not use Android speech recognition. Type a reply, or tap one of the answers.",
      "این نسخهٔ نصب‌شده گفتار را به متن تبدیل نمی‌کند و صدایت را ضبط نمی‌کند. تشخیص گفتار اندروید در این برنامه نیست. جواب را بنویس، یا یکی از پاسخ‌ها را بزن.",
    );
  }
  if (error == 'unsupported') {
    final extra = record
        ? ' You can still tap Record to hear yourself and compare with the character. That clip stays in this browser; this app does not upload it.'
        : ' This browser cannot record you either. Type a reply, or tap one of the answers.';
    return MicHelpCopy(
      "Speaking isn't available here",
      "This browser can't recognise speech. Open the app in Safari (iPhone) or Chrome (Android, computer) to speak your replies.$extra",
      "تشخیص گفتار در این مرورگر در دسترس نیست. سافاری یا کروم را امتحان کن، یا جواب را بنویس یا انتخاب کن.",
    );
  }
  if (error == 'service-not-allowed') {
    return const MicHelpCopy(
      'Turn on Dictation',
      'On iPhone, Safari needs Dictation for speech recognition: Settings › General › Keyboard › Enable Dictation (on). Then come back and tap the microphone again.',
      'در آیفون، سافاری برای تشخیص گفتار به Dictation نیاز دارد. بعد برگرد و میکروفون را دوباره بزن، یا جواب را بنویس.',
    );
  }
  final recordLine = record ? ' "Record" clips stay on your device.' : '';
  return MicHelpCopy(
    'Allow the microphone',
    "New Life UK only listens while the microphone is red. Your speech is turned into text by your browser's speech service (Google in Chrome, Apple in Safari), which may process your voice on its servers. The app does not store or send your recordings itself.$recordLine",
    'میکروفون فقط وقتی قرمز است گوش می‌دهد. گفتار شما را سرویس گفتار مرورگرتان (گوگل در کروم، اپل در سافاری) به متن تبدیل می‌کند و ممکن است صدایتان را روی سرورهای خودش پردازش کند. New Life UK خودش صدای شما را ذخیره یا ارسال نمی‌کند.',
  );
}

/// Note under a web scoring microphone, or the honest installed-app substitute.
(String, String) scoreMicNote({bool? web, bool? sttSupported}) {
  final webOn = web ?? kIsWeb;
  final stt = sttSupported ?? SpeechInput.sttSupported;
  if (!webOn && stt) return (androidSttPrivacy, androidSttPrivacyFa);
  if (!webOn && !stt) {
    return (
      'This installed app cannot turn your voice into text, and it does not record you. Type your answer instead.',
      'این نسخهٔ نصب‌شده گفتار را به متن تبدیل نمی‌کند و صدایت را ضبط نمی‌کند. به‌جای آن جواب را بنویس.',
    );
  }
  return (
    "Your browser turns your speech into text (Google in Chrome, Apple in Safari) and may process your voice on its servers. This screen does not keep a recording.",
    'مرورگر گفتار را به متن تبدیل می‌کند (گوگل در کروم، اپل در سافاری) و ممکن است صدا را روی سرورهای خودش پردازش کند. این صفحه ضبط را نگه نمی‌دارد.',
  );
}

/// Coach introduction. The installed app must not claim device or browser scoring.
(String, String) coachIntro({bool? web, bool? sttSupported}) {
  final webOn = web ?? kIsWeb;
  final stt = sttSupported ?? SpeechInput.sttSupported;
  if (!webOn && stt) {
    return (
      'Hear the model, then say the same line. Your phone\'s speech recognizer turns it into text and the words it heard are highlighted. This checks words, not sounds — New Life UK does not record or upload your voice.',
      'مدل را بشنو، بعد همان جمله را بگو. تشخیص گفتار گوشی آن را به متن تبدیل می‌کند و واژه‌های شنیده‌شده پررنگ می‌شوند. این واژه‌ها را می‌سنجد، نه صداها را — اپ صدایت را ضبط یا آپلود نمی‌کند.',
    );
  }
  if (!webOn && !stt) {
    return (
      'This installed app cannot score your voice and does not record you. Hear the model, then type the line if you want to practise the words.',
      'این نسخهٔ نصب‌شده صدایت را امتیاز نمی‌دهد و ضبط نمی‌کند. مدل را بشنو؛ اگر می‌خواهی واژه‌ها را تمرین کنی، جمله را بنویس.',
    );
  }
  return (
    'Hear the model, then say the same line. Your browser turns speech into text for the score — nothing is uploaded by New Life UK.',
    'مدل را بشنو، بعد همان جمله را بگو. مرورگر صدایت را به متن تبدیل می‌کند — اپ چیزی آپلود نمی‌کند.',
  );
}

(String, String) coachAiNote({bool? web, bool? sttSupported}) {
  final webOn = web ?? kIsWeb;
  final stt = sttSupported ?? SpeechInput.sttSupported;
  if (!webOn && stt) {
    return (
      'AI aid: model audio is neural text-to-speech; the check uses your phone\'s speech-to-text — not a human teacher and not a phoneme score.',
      'کمک هوش مصنوعی: صدای نمونه TTS است؛ سنجش با گفتار به متن گوشی — معلم انسان نیست و نمرهٔ واجی نیست.',
    );
  }
  if (!webOn && !stt) {
    return (
      'AI aid: the model audio is neural text-to-speech. This installed app does not turn your speech into text.',
      'کمک هوش مصنوعی: صدای نمونه با TTS ساخته شده است. این نسخهٔ نصب‌شده گفتار را به متن تبدیل نمی‌کند.',
    );
  }
  return (
    'AI aid: model audio is neural text-to-speech; scoring uses your browser\'s speech-to-text — not a human teacher.',
    'کمک هوش مصنوعی: صدای نمونه TTS است؛ امتیازدهی با گفتار به متن مرورگر — معلم انسان نیست.',
  );
}

/// Chat fallback when the app microphone cannot start. Web may use the keyboard mic; the installed app may only type.
(String, String) dictateFallback({bool? web, bool? sttSupported, bool? recordSupported}) {
  final webOn = web ?? kIsWeb;
  final stt = sttSupported ?? SpeechInput.sttSupported;
  final record = recordSupported ?? SpeechInput.recordSupported;
  if (!webOn && stt) {
    return (
      'Speech recognition didn\'t start on this phone. Type your reply, or tap one above.',
      'تشخیص گفتار روی این گوشی شروع نشد. جوابت را بنویس، یا یکی از جواب‌های بالا را بزن.',
    );
  }
  if (!webOn && !stt && !record) {
    return (
      'This app cannot turn speech into text on this device, and it does not record you. Type your reply, or tap one above.',
      'این برنامه روی این دستگاه گفتار را به متن تبدیل نمی‌کند و صدایت را ضبط نمی‌کند. جواب را بنویس، یا یکی از جواب‌های بالا را بزن.',
    );
  }
  return (
    'Speech recognition isn\'t available in this browser mode. Tap “Keyboard mic”, then the 🎤 on your keyboard and say your reply — or just type it.',
    'تشخیص گفتار در این حالت مرورگر در دسترس نیست. «Keyboard mic» را بزن، بعد 🎤 روی کیبورد را بزن و جوابت را بگو — یا فقط تایپش کن.',
  );
}

/// Friendly help when the microphone or speech recognition is blocked, or not available at all.
Future<void> showMicHelp(BuildContext context, String? error, {VoidCallback? onType}) {
  final copy = micHelpCopy(error);
  final unsupported = error == 'unsupported' || nativeSpeechOff;
  final dictation = error == 'service-not-allowed' && !nativeSpeechOff;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: BL.cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SheetSafeArea(
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
                  Expanded(child: Text(copy.title, style: BL.display(22))),
                ],
              ),
              const SizedBox(height: 10),
              Text(copy.body, key: const ValueKey('mic-privacy')),
              const SizedBox(height: 6),
              Text(copy.bodyFa, textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
              if (dictation && SpeechInput.isStandalone) ...[
                const SizedBox(height: 6),
                const Text(key: ValueKey('mic-help-standalone'), 'Opened from your Home Screen? Apple may not allow speech there: open New Life UK in Safari to speak, or type / tap your reply.'),
              ],
              if (!unsupported && !dictation && nativeStt()) ...[
                const SizedBox(height: 8),
                const Text(key: ValueKey('mic-help-android'), 'Android: Settings › Apps › New Life UK › Permissions › Microphone › Allow. For speech without the internet, add English (UK) under Settings › System › Languages › On-device speech recognition (names vary by phone).'),
                const SizedBox(height: 6),
                Text('اندروید: تنظیمات › برنامه‌ها › New Life UK › مجوزها › میکروفون › اجازه. برای گفتار بدون اینترنت، انگلیسی (بریتانیا) را در «تشخیص گفتار روی دستگاه» اضافه کنید.', textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
              ] else if (!unsupported && !dictation) ...[
                const SizedBox(height: 8),
                const Text('iPhone (Safari): tap "aA" in the address bar › Website Settings › Microphone › Allow. Or Settings › Apps › Safari › Microphone.'),
                const SizedBox(height: 6),
                const Text('Android / Chrome: tap the lock icon by the address › Permissions › Microphone › Allow.'),
              ],
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
