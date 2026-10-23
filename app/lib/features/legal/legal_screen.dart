import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../shared/nav.dart';

/// Privacy Policy, Terms of Use and About/credits (EN + FA). DRAFT: business details are placeholders
/// to be filled in (and the text reviewed by a solicitor) before the paid launch — see docs/LEGAL_REVIEW.md.
class LegalDoc {
  final String id, title, titleFa, updated;
  final List<(String, String, String)> sections; // heading, English, Persian
  const LegalDoc(this.id, this.title, this.titleFa, this.updated, this.sections);
}

const legalPlaceholders = '[BUSINESS NAME], [POSTAL ADDRESS], [CONTACT EMAIL]';

const privacyDoc = LegalDoc('privacy', 'Privacy Policy', 'سیاست حریم خصوصی', 'Draft · 17 October 2026', [
  ('Who we are', 'New Life UK is run by [BUSINESS NAME], [POSTAL ADDRESS]. Contact: [CONTACT EMAIL]. We are the controller for the little personal data described here.',
      'اپ New Life UK را [BUSINESS NAME] به نشانی [POSTAL ADDRESS] اداره می‌کند. تماس: [CONTACT EMAIL]. ما مسئول (کنترل‌کنندهٔ) همان دادهٔ اندکی هستیم که اینجا توضیح داده شده است.'),
  ('No account, no analytics, no ads', 'You do not create an account. The app has no analytics, advertising or tracking tools, and fonts are bundled with the app (no calls to Google Fonts).',
      'حساب کاربری نمی‌سازید. اپ هیچ ابزار آمار، تبلیغات یا ردیابی ندارد و فونت‌ها داخل خود اپ هستند (به Google Fonts وصل نمی‌شود).'),
  ('What stays on your device', 'Your progress (lessons, XP, streak, saved words, diary, settings) and any name you type on a certificate are stored only in your browser or app storage on this device. A service-worker cache keeps the app and audio for offline use. This storage is strictly necessary for the features you use, so no cookie consent is needed. Clearing site data or uninstalling deletes it; we cannot recover it.',
      'پیشرفت شما (درس‌ها، امتیاز، رکورد روزانه، واژه‌های ذخیره‌شده، دفتر خاطرات، تنظیمات) و نامی که روی گواهی می‌نویسید فقط در حافظهٔ مرورگر یا اپ روی همین دستگاه ذخیره می‌شود. حافظهٔ پنهان سرویس‌ورکر اپ و صداها را برای استفادهٔ آفلاین نگه می‌دارد. این ذخیره‌سازی برای کارکرد اپ ضروری است و نیاز به رضایت کوکی ندارد. با پاک کردن دادهٔ سایت یا حذف اپ همه‌چیز پاک می‌شود و ما نمی‌توانیم آن را بازگردانیم.'),
  ('Microphone and speech', 'The microphone is used only when you tap it. Speech-to-text is done by your browser\'s own speech service (Google in Chrome, Apple in Safari), which may process your voice on its servers under its own privacy policy. New Life UK does not receive, store or send your recordings itself. "Record" clips for shadowing stay on your device and are discarded when you leave.',
      'میکروفون فقط وقتی رویش می‌زنید استفاده می‌شود. تبدیل گفتار به متن را سرویس گفتار خود مرورگر انجام می‌دهد (گوگل در کروم، اپل در سافاری) که ممکن است صدای شما را طبق سیاست حریم خصوصی خودش روی سرورهایش پردازش کند. New Life UK خودش صدای شما را دریافت، ذخیره یا ارسال نمی‌کند. ضبط‌های «Record» روی دستگاه می‌مانند و با خروج پاک می‌شوند.'),
  ('Hosting', 'The web app is hosted on GitHub Pages (GitHub, Inc.). Like any web host, GitHub may log your IP address and browser details when you load the app, under GitHub\'s privacy statement. We do not receive these logs.',
      'نسخهٔ وب روی GitHub Pages (شرکت GitHub) میزبانی می‌شود. مثل هر میزبان وب، GitHub ممکن است هنگام باز شدن اپ نشانی IP و مشخصات مرورگر شما را طبق بیانیهٔ حریم خصوصی خودش ثبت کند. این گزارش‌ها به دست ما نمی‌رسد.'),
  ('Reminders', 'Daily reminders use your device\'s notification permission or a calendar file (.ics) you download. Nothing is sent to us.',
      'یادآورهای روزانه از اجازهٔ اعلان دستگاه یا فایل تقویم (.ics) که خودتان دانلود می‌کنید استفاده می‌کنند. چیزی برای ما فرستاده نمی‌شود.'),
  ('Payments (later)', 'The app is free during the beta and takes no payments. If paid plans start, payments will be handled by Apple, Google or Stripe, and this policy will be updated before then.',
      'اپ در دورهٔ آزمایشی رایگان است و پولی دریافت نمی‌کند. اگر طرح‌های پولی شروع شود، پرداخت از طریق اپل، گوگل یا Stripe انجام می‌شود و این سیاست پیش از آن به‌روز خواهد شد.'),
  ('Children', 'The app is designed for adult learners. Children under 13 should use it with a parent or carer. We do not knowingly collect children\'s data, and the practice league uses simulated players only.',
      'اپ برای بزرگسالان طراحی شده است. کودکان زیر ۱۳ سال باید همراه والدین یا سرپرست از آن استفاده کنند. ما آگاهانه دادهٔ کودکان را جمع نمی‌کنیم و لیگ تمرینی فقط بازیکنان شبیه‌سازی‌شده دارد.'),
  ('Your rights', 'Under UK data protection law you can ask us about any personal data we hold (we normally hold none). You can complain to the Information Commissioner\'s Office (ico.org.uk).',
      'طبق قانون حفاظت از دادهٔ بریتانیا می‌توانید دربارهٔ هر دادهٔ شخصی که از شما داریم بپرسید (معمولاً هیچ داده‌ای نداریم). می‌توانید به دفتر کمیسر اطلاعات (ico.org.uk) شکایت کنید.'),
]);

const termsDoc = LegalDoc('terms', 'Terms of Use', 'شرایط استفاده', 'Draft · 17 October 2026', [
  ('Agreement', 'These terms are between you and [BUSINESS NAME] ([CONTACT EMAIL]). By using New Life UK you agree to them. If you do not agree, please do not use the app.',
      'این شرایط میان شما و [BUSINESS NAME] ([CONTACT EMAIL]) است. با استفاده از New Life UK آن را می‌پذیرید؛ اگر موافق نیستید از اپ استفاده نکنید.'),
  ('Beta', 'The app is in a free beta. Features and content may change, and things may occasionally break. No payment is taken; prices shown are examples only.',
      'اپ در دورهٔ آزمایشی رایگان است. امکانات و محتوا ممکن است تغییر کند و گاهی خطا رخ دهد. هیچ پولی دریافت نمی‌شود و قیمت‌های نمایش‌داده فقط نمونه‌اند.'),
  ('Licence', 'You may use the app for your own personal learning. Please do not copy, resell or redistribute its lessons, stories, paintings or audio.',
      'می‌توانید از اپ برای یادگیری شخصی خودتان استفاده کنید. لطفاً درس‌ها، داستان‌ها، نقاشی‌ها یا صداهای آن را کپی، فروش یا بازنشر نکنید.'),
  ('Learning content only', 'New Life UK teaches English. It is not legal, medical, immigration, financial or professional advice. Career Packs are language practice, not job training. Certificates show completion of our course content: they are not an accredited qualification or a Home Office-approved English test (SELT), and CEFR levels are an indication only.',
      'New Life UK زبان انگلیسی آموزش می‌دهد و مشاورهٔ حقوقی، پزشکی، مهاجرتی، مالی یا حرفه‌ای نیست. بسته‌های شغلی تمرین زبان‌اند، نه آموزش شغلی. گواهی‌ها فقط پایان محتوای دورهٔ ما را نشان می‌دهند، مدرک معتبر یا آزمون زبانِ مورد تأیید وزارت کشور (SELT) نیستند و سطح CEFR تقریبی است.'),
  ('Not affiliated', 'New Life UK is not affiliated with or endorsed by any government body, charity, company or brand. Shops, clubs, banks, offices and people in the stories are fictional. Real services (gov.uk, the NHS, NHS 111, 999 and 101, Citizens Advice, the DVSA) are named only factually, as places to get real help.',
      'New Life UK هیچ وابستگی یا تأییدی از هیچ نهاد دولتی، خیریه، شرکت یا برندی ندارد. مغازه‌ها، باشگاه‌ها، بانک‌ها، اداره‌ها و آدم‌های داستان‌ها خیالی‌اند. خدمات واقعی (gov.uk، NHS، NHS 111، ۹۹۹ و ۱۰۱، Citizens Advice، DVSA) فقط به‌عنوان جای گرفتن کمک واقعی نام برده می‌شوند.'),
  ('Liability', 'We provide the app "as is" during the beta. Nothing in these terms limits liability that cannot be limited by law, or your statutory rights as a consumer.',
      'اپ در دورهٔ آزمایشی «همان‌طور که هست» ارائه می‌شود. هیچ‌چیز در این شرایط مسئولیتی را که قانوناً قابل محدود کردن نیست یا حقوق قانونی شما به‌عنوان مصرف‌کننده را محدود نمی‌کند.'),
  ('Law', 'These terms are governed by the law of England and Wales. We may update them; the date above shows the latest version.',
      'این شرایط تابع قانون انگلستان و ولز است. ممکن است آن را به‌روز کنیم؛ تاریخ بالا آخرین نسخه را نشان می‌دهد.'),
]);

const aboutDoc = LegalDoc('about', 'About & credits', 'دربارهٔ اپ و منابع', '', [
  ('New Life UK', 'British English through the everyday life of a London family. Made by [BUSINESS NAME]. Contact: [CONTACT EMAIL].',
      'انگلیسی بریتانیایی از دل زندگی روزمرهٔ یک خانوادهٔ لندنی. ساخت [BUSINESS NAME]. تماس: [CONTACT EMAIL].'),
  ('Voices and pictures', 'All voices are synthetic (text-to-speech). Characters and stories are fictional. Paintings are original illustrations made for the app.',
      'همهٔ صداها مصنوعی (تبدیل متن به گفتار) هستند. شخصیت‌ها و داستان‌ها خیالی‌اند. نقاشی‌ها تصویرسازی‌های اختصاصی همین اپ هستند.'),
  ('Trade marks', 'Brand and place names are used for realistic, descriptive purposes. New Life UK is not affiliated with or endorsed by any of them.',
      'نام برندها و مکان‌ها فقط برای توصیف واقع‌گرایانه آمده‌اند و New Life UK با هیچ‌کدام وابستگی یا تأییدی ندارد.'),
  ('Open source', 'Built with Flutter and open-source packages (BSD/MIT licences). Fonts: Fraunces, Inter and Vazirmatn (SIL Open Font Licence).',
      'با Flutter و بسته‌های متن‌باز (مجوزهای BSD/MIT) ساخته شده است. فونت‌ها: Fraunces، Inter و Vazirmatn (مجوز SIL Open Font).'),
]);

class LegalScreen extends StatefulWidget {
  final String tab;
  const LegalScreen({super.key, this.tab = 'privacy'});
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static const docs = [privacyDoc, termsDoc, aboutDoc];
  late String tab = docs.any((d) => d.id == widget.tab) ? widget.tab : 'privacy';
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final d = docs.firstWhere((x) => x.id == tab);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: ValueKey('legal-$tab'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('LEGAL & ABOUT', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final x in docs) ButtonSegment(value: x.id, label: Text(x.id == 'about' ? 'About' : (x.id == 'privacy' ? 'Privacy' : 'Terms'), key: ValueKey('legal-tab-${x.id}')))],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          const SizedBox(height: 18),
          Text(d.title, style: BL.display(26)),
          Text(d.titleFa, textDirection: TextDirection.rtl, style: BL.fa(14)),
          if (d.updated.isNotEmpty) Text(d.updated, style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600)),
          for (final (h, en, fa) in d.sections) ...[
            const SizedBox(height: 16),
            Text(h, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
            const SizedBox(height: 4),
            Text(en, style: const TextStyle(fontSize: 14, height: 1.4, color: BL.ink)),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: Text(fa, textDirection: TextDirection.rtl, style: BL.fa(13, color: BL.muted))),
          ],
          if (d.id == 'about') ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: () => showLicensePage(context: context, applicationName: 'New Life UK'), icon: const Icon(Icons.description_outlined), label: const Text('Open-source licences')),
          ],
        ],
      ),
    );
  }
}
