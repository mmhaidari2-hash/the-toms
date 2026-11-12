import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/premium.dart';
import '../shared/nav.dart';

/// Who can use a section once sales are switched on (while [PremiumConfig.betaFree] is true, everything is free).
enum GuideAccess { free, mixed, premium }

class GuideEntry {
  final String route;
  final IconData icon;
  final String title, titleFa, what, whatFa, how, howFa;
  final GuideAccess access;
  /// What is free / paid for [GuideAccess.mixed] (EN, FA).
  final (String, String)? accessNote;
  const GuideEntry(this.route, this.icon, this.title, this.titleFa, this.what, this.whatFa, this.how, this.howFa, this.access, [this.accessNote]);
}

/// In-app user guide (owner t306 item 6): every section, what it is and how to use it, in English and Persian.
/// Kept to features that exist in this build; free/paid wording matches [PremiumConfig] and the route guard.
abstract final class UserGuide {
  static const groups = <(String, String, List<GuideEntry>)>[
    ('Start here', 'از این‌جا شروع کن', [
      GuideEntry('/', Icons.map_rounded, 'The town map', 'نقشهٔ شهر',
          'Your home screen: a painted map of Hackney. Each area is a level (Home A1 → The city C1) and the buildings open sections of the app.',
          'صفحهٔ اصلی: نقشهٔ نقاشی‌شدهٔ هکنی. هر محله یک سطح است (خانه A1 تا شهر C1) و ساختمان‌ها بخش‌های اپ را باز می‌کنند.',
          'Tap "Continue" for your next lesson. Tap an area or building to open it. The ☰ menu lists every section.',
          'برای درس بعدی «Continue» را بزن. روی محله یا ساختمان بزن تا باز شود. منوی ☰ همهٔ بخش‌ها را دارد.', GuideAccess.free),
      GuideEntry('/course', Icons.route_rounded, 'Course path', 'مسیر درس‌ها',
          'The main course: units of short lessons, each with a story (a conversation with the Thompson family and neighbours) and practice.',
          'دورهٔ اصلی: واحدهایی از درس‌های کوتاه، هر کدام با یک داستان (گفتگو با خانوادهٔ تامسون و همسایه‌ها) و تمرین.',
          'Open a lesson, read the words, play the Story (tap, type or say your replies), then do the Practice. Finish a unit to open the next.',
          'درس را باز کن، واژه‌ها را ببین، داستان را بازی کن (جواب را بزن، بنویس یا بگو)، بعد تمرین. با تمام کردن هر واحد، بعدی باز می‌شود.',
          GuideAccess.mixed, ('Free: Units 1–10, the first unit of every level, then one new lesson a day and reviewing finished lessons. Premium: unlimited new lessons.', 'رایگان: واحدهای ۱ تا ۱۰، واحد اول هر سطح، بعد روزی یک درس جدید و مرور درس‌های تمام‌شده. ویژه: درس جدید نامحدود.')),
      GuideEntry('/placement', Icons.quiz_rounded, 'Placement test', 'تعیین سطح',
          'A short adaptive test (A1–C1) that chooses where your course starts.',
          'آزمون کوتاه تطبیقی (A1 تا C1) که نقطهٔ شروع دوره‌ات را انتخاب می‌کند.',
          'Answer grammar, vocabulary, reading and listening questions. Your result sets your course level; you can still go back to earlier levels.',
          'به سؤال‌های دستور، واژه، خواندن و شنیدن جواب بده. نتیجه سطح دوره را تعیین می‌کند؛ سطح‌های قبلی همچنان باز می‌مانند.', GuideAccess.free),
      GuideEntry('/plan', Icons.flag_rounded, 'My study plan', 'برنامهٔ مطالعه',
          'Set a goal level, minutes a day and a target date, and see the pace you need.',
          'سطح هدف، دقیقه در روز و تاریخ هدف را تعیین کن و سرعت لازم را ببین.',
          'Pick your goal and date; the plan card on your path shows if you are on track this week.',
          'هدف و تاریخ را انتخاب کن؛ کارت برنامه در مسیرت نشان می‌دهد این هفته طبق برنامه هستی یا نه.', GuideAccess.free),
    ]),
    ('Practise', 'تمرین', [
      GuideEntry('/school', Icons.school_rounded, 'Grammar school', 'دستور زبان',
          'Mrs Ellis teaches grammar topics by level, with Persian explanations, practice, mini tests and a class exam.',
          'خانم الیس دستور زبان را سطح به سطح درس می‌دهد، با توضیح فارسی، تمرین، آزمونک و امتحان کلاس.',
          'Open a class and do the topics in order; pass a mini test to open the next topic. Mixed review revisits passed topics.',
          'یک کلاس را باز کن و موضوع‌ها را به ترتیب برو؛ با قبولی در آزمونک، موضوع بعدی باز می‌شود. مرور ترکیبی موضوع‌های گذرانده را تکرار می‌کند.', GuideAccess.free),
      GuideEntry('/leitner', Icons.inventory_2_rounded, 'Leitner box', 'جعبهٔ لایتنر',
          'Spaced review of words you saved: five boxes, cards come back after 0, 1, 3, 7 and 14 days.',
          'مرور فاصله‌دار واژه‌های ذخیره‌شده: پنج خانه؛ کارت‌ها بعد از ۰، ۱، ۳، ۷ و ۱۴ روز برمی‌گردند.',
          'Save words while reading or in lessons, then review today\'s cards. Right moves a card up; wrong sends it back to box 1.',
          'هنگام خواندن یا در درس‌ها واژه ذخیره کن، بعد کارت‌های امروز را مرور کن. درست = خانهٔ بالاتر؛ غلط = برگشت به خانهٔ ۱.', GuideAccess.free),
      GuideEntry('/practice/mistakes', Icons.replay_rounded, 'My mistakes', 'اشتباه‌های من',
          'Practice built from the questions you got wrong.', 'تمرینی از سؤال‌هایی که اشتباه جواب دادی.',
          'Open it after lessons to try your mistakes again until they stick.', 'بعد از درس‌ها بازش کن و اشتباه‌ها را دوباره امتحان کن تا یاد بگیری.', GuideAccess.free),
      GuideEntry('/coach', Icons.record_voice_over_rounded, 'Pronunciation coach', 'مربی تلفظ',
          'Hear a model sentence (normal or slow), say it, and see which words came through. It checks words, not sounds — not a phoneme score.',
          'جملهٔ نمونه را (عادی یا آهسته) بشنو، بگو و ببین کدام واژه‌ها درست شنیده شد. واژه‌ها را می‌سنجد نه صداها — نمرهٔ واجی نیست.',
          'Tap Speak and say the line. Try again on the focus words until you pass, then go to the next line. Needs the microphone permission.',
          'Speak را بزن و جمله را بگو. روی واژه‌های Focus دوباره تلاش کن تا قبول شوی، بعد جملهٔ بعدی. اجازهٔ میکروفون لازم است.', GuideAccess.free),
      GuideEntry('/check', Icons.insights_rounded, 'Progress check', 'سنجش پیشرفت',
          'A short repeatable quiz that gives an unofficial level estimate and a history chart. Not a CEFR certificate or official test.',
          'آزمون کوتاه قابل تکرار با تخمین غیررسمی سطح و نمودار تاریخچه. گواهی CEFR یا آزمون رسمی نیست.',
          'Take it every few weeks; each time the questions are new. It never changes your course level.',
          'هر چند هفته یک بار بزن؛ هر بار سؤال تازه است. سطح دوره‌ات را عوض نمی‌کند.', GuideAccess.free),
      GuideEntry('/park', Icons.sports_esports_rounded, 'Park games', 'بازی‌های پارک',
          'Five quick word games per level (for example word match against the clock, listen & tap).',
          'پنج بازی سریع واژه در هر سطح (مثلاً جفت‌کردن واژه با زمان، بشنو و بزن).',
          'Pick a level and a game; rounds are shuffled each time and your best score is kept.', 'سطح و بازی را انتخاب کن؛ هر بار ترتیب عوض می‌شود و بهترین امتیازت ذخیره می‌شود.', GuideAccess.free),
    ]),
    ('Read, watch & listen', 'بخوان، ببین، گوش کن', [
      GuideEntry('/library', Icons.local_library_rounded, 'Library', 'کتابخانه',
          'A British public library: a front desk (continue reading, new arrivals, your loans), signed sections (fiction, science, history and more) with swipeable aisles and level-coloured shelves. Any book can be opened; one above your level just shows a notice.',
          'یک کتابخانهٔ عمومی بریتانیایی: میز امانت (ادامهٔ خواندن، تازه‌ها، امانت‌های تو)، بخش‌های تابلودار (داستان، علم، تاریخ و…) با راهروهای کشیدنی و قفسه‌های رنگی هر سطح. هر کتابی باز می‌شود؛ کتاب بالاتر از سطحت فقط یک هشدار نشان می‌دهد.',
          'Tap a spine to pull the book out, then Read. The narrator reads the chapter or the whole book with the sentence highlighted (recorded voice, or your phone\'s own voice where a book has none — it is labelled). Tap any word for its dictionary card (Persian, part of speech, definition, example, pronunciation) and Add to Leitner; the book shows how many new words it has and can send them all. Change font, spacing and light/sepia/dark, open the chapter list, and answer the quiz after each chapter. There is also a list view with search, filter and sort.',
          'روی عطف کتاب بزن تا بیرون بیاید، بعد «Read». راوی فصل یا کل کتاب را می‌خواند و جمله پررنگ می‌شود (صدای ضبط‌شده، یا صدای خود گوشی برای کتاب‌های بدون صدا — برچسب دارد). روی هر واژه بزن تا کارت دیکشنری (فارسی، نوع واژه، تعریف، مثال، تلفظ) باز شود و به لایتنر بفرستی؛ کتاب تعداد واژه‌های تازه‌اش را نشان می‌دهد و می‌تواند همه را بفرستد. اندازهٔ قلم، فاصلهٔ خط و تم روشن/کاغذی/تیره را عوض کن، فهرست فصل‌ها را باز کن و بعد از هر فصل به کوییز جواب بده. نمای فهرستی با جست‌وجو، فیلتر و مرتب‌سازی هم هست.', GuideAccess.free),
      GuideEntry('/cinema', Icons.movie_rounded, 'Cinema', 'سینما و دوبله',
          'Short scenes to watch with subtitles, dub a character and answer questions.', 'صحنه‌های کوتاه برای دیدن با زیرنویس، دوبله کردن یک شخصیت و جواب به سؤال‌ها.',
          'Watch first, then say the character\'s lines (speech recognition scores the words), then the questions.', 'اول ببین، بعد جمله‌های شخصیت را بگو (بازشناسی گفتار واژه‌ها را می‌سنجد)، بعد سؤال‌ها.', GuideAccess.free),
      GuideEntry('/radio', Icons.radio_rounded, 'Radio', 'رادیو',
          'Hackney Hum: short programmes per level for listening practice.', 'رادیو هکنی هام: برنامه‌های کوتاه هر سطح برای تمرین شنیدن.',
          'Listen without text first, then open the transcript with Persian if you need it, then answer the questions.', 'اول بدون متن گوش کن، اگر لازم شد متن و فارسی را باز کن، بعد به سؤال‌ها جواب بده.', GuideAccess.free),
      GuideEntry('/messages', Icons.chat_rounded, 'Messages', 'پیام‌ها',
          'A pretend phone inbox: texts and voice notes from the family and friends, with texting talk explained.', 'صندوق پیام یک گوشی خیالی: پیامک و پیام صوتی از خانواده و دوستان، با توضیح زبان پیامکی.',
          'Open a chat, listen to voice notes (show the transcript if needed), do the quick check, then reply by picking, typing or saying it.', 'گفتگو را باز کن، پیام صوتی را گوش کن (در صورت نیاز متن را ببین)، تمرین کوتاه را انجام بده، بعد با انتخاب، نوشتن یا گفتن جواب بده.', GuideAccess.free),
    ]),
    ('Life in the UK', 'زندگی در بریتانیا', [
      GuideEntry('/missions', Icons.hiking_rounded, 'Missions & role-plays', 'مأموریت‌ها و نقش‌آفرینی',
          'Real-life tasks to try outside (for example at a shop or GP), with role-plays to practise first in the app.', 'کارهای واقعی برای امتحان بیرون (مثلاً مغازه یا پزشک عمومی)، با نقش‌آفرینی برای تمرین قبلی در اپ.',
          'Prepare the phrases, practise the role-play, go and do it, then check in on how it went.', 'جمله‌ها را آماده کن، نقش‌آفرینی را تمرین کن، برو انجامش بده، بعد ثبت کن چطور گذشت.', GuideAccess.free),
      GuideEntry('/lifeuk', Icons.account_balance_rounded, 'Life in the UK test practice', 'تمرین آزمون زندگی در بریتانیا',
          'Notes, flashcards, chapter quizzes and timed mock tests for the Life in the UK test. Practice only — not the official test.', 'یادداشت، فلش‌کارت، کوییز فصل و آزمون آزمایشی زمان‌دار برای آزمون Life in the UK. فقط تمرین — آزمون رسمی نیست.',
          'Read a chapter, flip the cards, take the quiz, then try a mock test and review your mistakes.', 'فصل را بخوان، کارت‌ها را برگردان، کوییز بده، بعد آزمون آزمایشی بزن و اشتباه‌ها را مرور کن.',
          GuideAccess.mixed, ('Free: the first chapter and the first mock test. Premium or the Life in the UK pack: everything.', 'رایگان: فصل اول و اولین آزمون آزمایشی. ویژه یا بستهٔ Life in the UK: همه.')),
      GuideEntry('/theory', Icons.fact_check_rounded, 'Driving theory & Driving School', 'آزمون تئوری و آموزشگاه رانندگی',
          'Theory test notes, flashcards, quizzes and mock tests, plus Driving School dialogues with an instructor.', 'یادداشت، فلش‌کارت، کوییز و آزمون آزمایشی تئوری رانندگی، به‌علاوهٔ گفتگوهای آموزشگاه با مربی.',
          'Work through the chapters, then the mock test; open Driving School for the English you need in lessons.', 'فصل‌ها را برو، بعد آزمون آزمایشی؛ برای انگلیسی لازم در جلسه‌های رانندگی، آموزشگاه را باز کن.',
          GuideAccess.mixed, ('Free: the first chapter, the first mock test and the first Driving School lesson. Premium or the Theory pack: everything.', 'رایگان: فصل اول، اولین آزمون آزمایشی و اولین درس آموزشگاه. ویژه یا بستهٔ تئوری: همه.')),
      GuideEntry('/forms', Icons.description_rounded, 'UK Forms Practice Lab', 'آزمایشگاه فرم‌ها',
          'Practice versions of common UK forms. What you type stays in memory only and is never uploaded.', 'نسخهٔ تمرینی فرم‌های رایج بریتانیا. آنچه می‌نویسی فقط در حافظه می‌ماند و هرگز ارسال نمی‌شود.',
          'Pick a form and fill it in with help on each field; links go to the official sites for the real thing.', 'یک فرم انتخاب کن و با راهنمای هر خانه پرش کن؛ برای فرم واقعی لینک سایت رسمی هست.', GuideAccess.free),
      GuideEntry('/visa', Icons.badge_rounded, 'Visa Help Desk', 'میز کمک ویزا',
          'General information and signposts to GOV.UK and regulated advisers. Not legal or immigration advice for your case.', 'اطلاعات عمومی و راهنمایی به GOV.UK و مشاوران مجاز. مشاورهٔ حقوقی یا مهاجرتی برای پروندهٔ تو نیست.',
          'Read the topic you need and follow the official links. For your own case, speak to a regulated adviser.', 'موضوع لازم را بخوان و لینک‌های رسمی را دنبال کن. برای پروندهٔ خودت با مشاور مجاز صحبت کن.', GuideAccess.free),
      GuideEntry('/settlement', Icons.account_balance_outlined, 'Settlement pathway (B2)', 'مسیر اقامت (B2)',
          'A B2 study pathway: modules on the English and knowledge often needed on the way to settlement. General study only — not immigration advice.', 'مسیر مطالعهٔ B2: بخش‌هایی دربارهٔ انگلیسی و دانسته‌هایی که در مسیر اقامت معمولاً لازم است. فقط مطالعهٔ عمومی — مشاورهٔ مهاجرتی نیست.',
          'Work through the modules in order. Confirm every rule on GOV.UK or with an IAA-regulated adviser.', 'بخش‌ها را به ترتیب برو. هر قانون را در GOV.UK یا با مشاور تحت نظارت IAA چک کن.', GuideAccess.free),
      GuideEntry('/arrival', Icons.offline_pin_rounded, 'Arrival Offline Pack', 'بستهٔ آفلاین ورود',
          'Week-one lessons, forms and emergency phrases you can download for low-data or offline use.', 'درس‌های هفتهٔ اول، فرم‌ها و جمله‌های اضطراری که برای کم‌اینترنتی یا آفلاین دانلود می‌شوند.',
          'Tap download once while on Wi-Fi; the pack then works without internet.', 'یک بار با وای‌فای دانلود را بزن؛ بعد بدون اینترنت کار می‌کند.', GuideAccess.free),
      GuideEntry('/seasons', Icons.calendar_month_rounded, 'Seasons', 'مناسبت‌ها',
          'British celebrations through the year, with a family scene, words and a short quiz.', 'جشن‌های بریتانیا در طول سال، با صحنهٔ خانوادگی، واژه‌ها و کوییز کوتاه.',
          'The nearest celebration is at the top; open any one to learn about it.', 'نزدیک‌ترین مناسبت بالای صفحه است؛ هر کدام را باز کن.', GuideAccess.free),
    ]),
    ('You & your progress', 'تو و پیشرفتت', [
      GuideEntry('/progress', Icons.local_fire_department_rounded, 'Progress', 'پیشرفت و نشان‌ها',
          'Streak, daily goal, badges, the progress check and an optional daily reminder.', 'زنجیرهٔ روزها، هدف روزانه، نشان‌ها، سنجش پیشرفت و یادآور روزانهٔ اختیاری.',
          'Turn on the reminder and choose a time if you want one (Android asks for notification permission). It is off by default.', 'اگر یادآور می‌خواهی روشنش کن و ساعت را انتخاب کن (اندروید اجازهٔ اعلان می‌خواهد). پیش‌فرض خاموش است.', GuideAccess.free),
      GuideEntry('/diary', Icons.menu_book_rounded, 'Diary', 'دفتر خاطرات',
          'Write short entries in English and get friendly feedback from the family (an offline coach, no AI server).', 'جمله‌های کوتاه به انگلیسی بنویس و از خانواده بازخورد دوستانه بگیر (مربی آفلاین، بدون سرور هوش مصنوعی).',
          'Write a few sentences about your day and read the comments.', 'چند جمله دربارهٔ روزت بنویس و نظرها را بخوان.', GuideAccess.free),
      GuideEntry('/profiles', Icons.manage_accounts_rounded, 'Profiles', 'پروفایل‌ها',
          'Separate progress for each adult using this phone.', 'پیشرفت جدا برای هر بزرگسالی که از این گوشی استفاده می‌کند.',
          'Add a profile and switch between them; each keeps its own progress and settings.', 'پروفایل اضافه کن و بینشان جابه‌جا شو؛ هر کدام پیشرفت و تنظیمات خودش را دارد.', GuideAccess.free),
      GuideEntry('/certificate/1', Icons.verified_rounded, 'Certificates', 'گواهی‌ها',
          'A completion certificate for each course level. A record of progress in this app only — not an official qualification.', 'گواهی پایان هر سطح دوره. فقط نشان پیشرفت در این اپ — مدرک رسمی نیست.',
          'Finish a level to unlock its certificate; locked levels show your progress.', 'سطح را تمام کن تا گواهی‌اش باز شود؛ سطح‌های قفل پیشرفتت را نشان می‌دهند.', GuideAccess.premium),
      GuideEntry('/feedback', Icons.feedback_outlined, 'Feedback & bug report', 'بازخورد و گزارش خطا',
          'Send a suggestion, report a bug or a content error (wrong English, translation or audio).', 'پیشنهاد بفرست، یا خطا و اشتباه محتوا (انگلیسی، ترجمه یا صدا) را گزارش بده.',
          'Menu ☰ → Feedback & bug report. Pick a category, write your message, optionally attach a screenshot, review it, then your own email app sends it. Nothing is sent without you.',
          'منو ☰ ← بازخورد و گزارش خطا. نوع را انتخاب کن، پیامت را بنویس، اگر خواستی تصویر صفحه را پیوست کن، بازبینی کن؛ بعد خود برنامهٔ ایمیلت آن را می‌فرستد. بدون تو چیزی ارسال نمی‌شود.', GuideAccess.free),
      GuideEntry('/legal', Icons.gavel_rounded, 'Privacy & terms', 'حریم خصوصی',
          'Privacy policy, terms, licences, and tools to export or delete your data on this device.', 'سیاست حریم خصوصی، شرایط، مجوزها و ابزار خروجی یا حذف داده‌ها روی همین دستگاه.',
          'Open it any time; export or delete works on this device without an account.', 'هر وقت خواستی بازش کن؛ خروجی یا حذف روی همین دستگاه و بدون حساب کار می‌کند.', GuideAccess.free),
    ]),
  ];

  static (String, String) accessLabel(GuideAccess a) => switch (a) {
        GuideAccess.free => ('Free', 'رایگان'),
        GuideAccess.mixed => ('Partly free', 'بخشی رایگان'),
        GuideAccess.premium => ('Premium', 'ویژه'),
      };

  /// Shown above the plans section; true to the current build.
  static (String, String) get betaNote => PremiumConfig.betaFree
      ? ('Public beta: right now everything in the app is free, including Premium features. When paid plans start, the free parts below stay free.', 'نسخهٔ آزمایشی عمومی: فعلاً همه‌چیز در اپ رایگان است، حتی امکانات ویژه. وقتی طرح‌های پولی شروع شود، بخش‌های رایگان زیر همچنان رایگان می‌مانند.')
      : ('Some sections need Premium or a pack. Prices come from Google Play.', 'بعضی بخش‌ها اشتراک ویژه یا بسته لازم دارند. قیمت‌ها از گوگل‌پلی می‌آید.');
}

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final note = UserGuide.betaNote;
    return Scaffold(
      key: const ValueKey('user-guide'),
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              const NavBack(fallback: '/'),
              const SizedBox(width: 4),
              Expanded(child: Text(hl('User guide'), style: BL.display(22))),
              Text('راهنمای کاربر', textDirection: TextDirection.rtl, style: BL.fa(13, color: BL.muted)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
              Text(hl('What each part of New Life UK is for and how to use it. Tap a section for details, then "Open".'), style: const TextStyle(height: 1.35)),
              Text('هر بخش New Life UK برای چیست و چطور از آن استفاده کنی. روی هر بخش بزن تا جزئیات را ببینی، بعد «Open».', textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
              const SizedBox(height: 10),
              _Plans(note: note),
              for (final (en, fa, items) in UserGuide.groups) ...[
                const SizedBox(height: 16),
                Text(hl(en), style: BL.display(19)),
                Text(fa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
                const SizedBox(height: 4),
                for (final e in items) _EntryTile(e),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const ValueKey('guide-tour'),
                onPressed: () => context.push('/howto'),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: Text(hl('Replay the quick tour · تور کوتاه')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Plans extends StatelessWidget {
  final (String, String) note;
  const _Plans({required this.note});
  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('guide-plans'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BL.mist)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hl('Free and Premium'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('رایگان و ویژه', textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          const SizedBox(height: 6),
          Container(
            key: const ValueKey('guide-beta-note'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(hl(note.$1), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
              Text(note.$2, textDirection: TextDirection.rtl, style: BL.fa(12)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(hl('Always free'), style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final f in PremiumConfig.alwaysFree) _bullet(f),
          const SizedBox(height: 6),
          Text(hl('Premium adds'), style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final f in PremiumConfig.perks) _bullet(f),
        ]),
      );

  Widget _bullet((String, String) f) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(hl('• ${f.$1}'), style: const TextStyle(fontSize: 13)),
          Text(f.$2, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
        ]),
      );
}

class _EntryTile extends StatelessWidget {
  final GuideEntry e;
  const _EntryTile(this.e);
  @override
  Widget build(BuildContext context) {
    final (al, alFa) = UserGuide.accessLabel(e.access);
    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: BL.mist)),
      child: ExpansionTile(
        key: ValueKey('guide-${e.route}'),
        leading: Icon(e.icon, color: BL.red),
        title: Text(hl(e.title), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${e.titleFa} · ${hl(al)} · $alFa', style: BL.fa(11.5, color: BL.muted)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hl(e.what), style: const TextStyle(height: 1.35)),
          Text(e.whatFa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          const SizedBox(height: 8),
          Text(hl('How to use it'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text(hl(e.how), style: const TextStyle(height: 1.35)),
          Text(e.howFa, textDirection: TextDirection.rtl, style: BL.fa(12, color: BL.muted)),
          if (e.accessNote != null) ...[
            const SizedBox(height: 8),
            Text(hl(e.accessNote!.$1), style: const TextStyle(fontSize: 12.5, color: BL.ink, fontWeight: FontWeight.w600)),
            Text(e.accessNote!.$2, textDirection: TextDirection.rtl, style: BL.fa(11.5, color: BL.muted)),
          ],
          if (PremiumConfig.betaFree && e.access != GuideAccess.free)
            Text(hl('Free during the beta · در دورهٔ آزمایشی رایگان'), style: const TextStyle(fontSize: 12, color: Color(0xFF2E8B57), fontWeight: FontWeight.w700)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(key: ValueKey('guide-open-${e.route}'), onPressed: () => context.push(e.route), child: Text(hl('Open'))),
          ),
        ],
      ),
    );
  }
}
