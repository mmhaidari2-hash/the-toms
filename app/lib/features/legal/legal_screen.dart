import 'dart:convert';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/legal/publisher_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/backup.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';

/// Privacy, Terms, Children's notice, About/licences + on-device export/delete (EN + FA).
class LegalDoc {
  final String id, title, titleFa, updated;
  final List<(String, String, String)> sections;
  const LegalDoc(
    this.id,
    this.title,
    this.titleFa,
    this.updated,
    this.sections,
  );
}

final privacyDoc = LegalDoc(
  "privacy",
  "Privacy Policy",
  "سیاست حریم خصوصی",
  "Updated · 5 November 2026",
  [
    (
      "Who we are",
      "New Life UK is a British-English learning app published by ${PublisherConfig.businessName}, ${PublisherConfig.postalAddressUk}. Privacy contact: ${PublisherConfig.privacyEmail}. We are the controller for the limited personal data described here. Until placeholders are replaced, treat the product name New Life UK as the service name.",
      "New Life UK اپ یادگیری انگلیسی بریتانیایی است که توسط ${PublisherConfig.businessName}، ${PublisherConfig.postalAddressUk} منتشر می‌شود. تماس حریم خصوصی: ${PublisherConfig.privacyEmail}. ما کنترل‌کنندهٔ دادهٔ محدودی هستیم که اینجا آمده است. تا جایگزینی مقادیر موقتی، نام «New Life UK» همان خدمت است.",
    ),
    (
      "Lawful bases and permissions",
      "Local progress provides the learning features you request. The publisher must document applicable UK GDPR lawful bases and hosting arrangements before public release. Browser permission is a technical control, not by itself a complete data-protection consent process. Microphone use is optional; you can keep reading and listening without it. We do not sell personal data or use it for ads.",
      "پیشرفت محلی برای قابلیت‌های درخواستی یادگیری است. ناشر باید پیش از انتشار مبانی قانونی پردازش و ترتیبات میزبانی را مستند کند. مجوز فنی مرورگر به‌تنهایی فرایند کامل رضایت حفاظت از داده نیست. میکروفون اختیاری است و بدون آن هم می‌توان خواند و گوش داد. داده را نمی‌فروشیم و برای تبلیغ استفاده نمی‌کنیم.",
    ),
    (
      "No account, no analytics, no ads",
      "You do not create an account. The app has no analytics, advertising or tracking SDKs, and fonts are bundled (no calls to Google Fonts). Geolocation is not used and stays off.",
      "حساب کاربری نمی‌سازید. اپ هیچ SDK آمار، تبلیغات یا ردیابی ندارد و فونت‌ها داخل اپ هستند. موقعیت مکانی استفاده نمی‌شود و خاموش است.",
    ),
    (
      "What stays on your device",
      "Progress, saved words, diary, settings, learner profiles and certificate names are stored on this device (Hive and secure key on supported native platforms; browser storage on the PWA). A service worker or on-device cache may keep lesson files for offline use. Storage necessary for a feature you expressly request may qualify for a PECR consent exception; this is not a blanket exemption for all local storage or future tracking. Delete my data clears saved app records; cached lesson downloads may remain until site/app storage is cleared. Export your progress before clearing storage; we cannot recover it.",
      "پیشرفت، واژه‌ها، دفترچه، تنظیمات، پروفایل و نام گواهی روی همین دستگاه ذخیره می‌شود. فایل درس ممکن است در کش آفلاین بماند. ذخیرهٔ لازم برای قابلیت صریحاً درخواستی ممکن است از رضایت PECR معاف باشد؛ این معافیت کلیِ همهٔ حافظه یا ردیابی آینده نیست. «حذف داده‌های من» سوابق اپ را پاک می‌کند؛ فایل کش ممکن است تا پاک‌کردن حافظهٔ سایت یا اپ بماند. اول از پیشرفت خروجی بگیرید؛ بازیابی ممکن نیست.",
    ),
    (
      "Sharing certificates and invites",
      "Share certificate and Invite a friend open your device's own share sheet only when you tap them. The certificate image (with the name you typed) or the invite text goes to the app or person you choose; nothing is sent to us, and the invite link has no referral code or tracking. These buttons are hidden in child profiles.",
      "دکمه‌های «اشتراک گواهی» و «دعوت از دوست» فقط وقتی خودتان بزنید پنجرهٔ اشتراک دستگاه را باز می‌کنند. تصویر گواهی (با نامی که نوشته‌اید) یا متن دعوت فقط به برنامه یا کسی که خودتان انتخاب می‌کنید می‌رود؛ چیزی برای ما ارسال نمی‌شود و لینک دعوت کد معرف یا ردیابی ندارد. این دکمه‌ها در پروفایل کودک نمایش داده نمی‌شوند.",
    ),
    (
      "Internet use and international transfers",
      "The app needs the Internet to download course content, paintings and pre-rendered Azure neural TTS voice clips from our static host (currently GitHub Pages, GitHub Inc., USA). Clips are app assets, not recordings of you. GitHub may log IP and browser metadata under its own privacy statement; we do not receive those logs. Azure Speech was used by us at build time to create clips; your device does not send your voice to Azure during normal play. Browser speech-to-text (microphone coach) may process audio on Google/Apple servers under their policies when you tap the mic.",
      "اپ برای محتوای دوره، تصویر و صداهای ازپیش‌ساختهٔ Azure به اینترنت نیاز دارد (میزبان: GitHub Pages در آمریکا). این کلیپ‌ها دارایی اپ‌اند نه صدای شما. GitHub ممکن است IP را ثبت کند؛ ما آن را نمی‌گیریم. Azure در زمان ساخت کلیپ استفاده شده؛ هنگام بازی صدای شما به Azure نمی‌رود. گفتار به متن مرورگر هنگام زدن میکروفون ممکن است روی سرورهای گوگل/اپل پردازش شود.",
    ),
    (
      "Microphone and speech",
      "The microphone is used only when you tap it. Speech-to-text is done by your browser's own speech service (Google in Chrome, Apple in Safari) or the OS service. New Life UK does not upload or store your recordings on our servers. Shadowing Record clips stay on device and are discarded when you leave.",
      "میکروفون فقط با لمس شما روشن می‌شود. تبدیل گفتار را سرویس گفتار مرورگر (گوگل در کروم، اپل در سافاری) یا سیستم‌عامل انجام می‌دهد. New Life UK ضبط شما را روی سرور ذخیره یا آپلود نمی‌کند. ضبط‌های Record روی دستگاه می‌مانند و با خروج پاک می‌شوند.",
    ),
    (
      "Children (Children's Code)",
      "The app includes kid-friendly profiles. The publisher must assess under-18 use rather than rely on an adult label or a 13+ store rating. Children should use it with a parent/carer. Progress is local, but online downloads contact the host and optional browser speech services may process microphone audio. High privacy defaults alone do not establish compliance with the ICO Children's Code. The release assessment is pending. See the Children tab.",
      "اپ پروفایل کودک دارد؛ ناشر باید استفادهٔ زیر ۱۸ سال را ارزیابی کند و برچسب بزرگسال یا ۱۳+ کافی نیست. کودک با والد استفاده کند. پیشرفت محلی است، اما دانلود به میزبان وصل می‌شود و سرویس گفتار اختیاری ممکن است صدا را پردازش کند. تنظیمات خصوصی به‌تنهایی اثبات انطباق نیست؛ ارزیابی انتشار نهایی نشده است.",
    ),
    (
      "Retention",
      "Local data remains until you delete it, clear site/app storage, or uninstall. We keep no server-side learner database. Cached static assets follow normal CDN/browser cache lifetimes.",
      "دادهٔ محلی تا وقتی خودتان پاک کنید می‌ماند. پایگاه‌دادهٔ یادگیرنده روی سرور نداریم.",
    ),
    (
      "Your rights",
      "Under UK data protection law you can access, correct, erase, restrict or port personal data we hold (normally none on our servers; use Export / Delete below for on-device data), and complain to the ICO (ico.org.uk). DUAA: you can also raise a data-protection complaint with us at ${PublisherConfig.privacyEmail}; we will acknowledge within 30 days and respond without undue delay.",
      "طبق قانون بریتانیا می‌توانید به داده دسترسی، اصلاح، حذف، محدودیت یا انتقال بخواهید (معمولاً روی سرور چیزی نیست؛ از خروجی/حذف زیر برای دادهٔ دستگاه استفاده کنید) و به ICO شکایت کنید. شکایت به ما: ${PublisherConfig.privacyEmail} — ظرف ۳۰ روز تأیید و پاسخ بدون تأخیر ناروا.",
    ),
    (
      "Payments (later)",
      "The app is free in beta; no payment is taken. If subscriptions start, Apple/Google/Stripe will process payments under their terms; we will update this policy and show clear prices, renewal and cancellation (including DMCC cooling-off) before charging.",
      "در بتا رایگان است. اگر اشتراک شروع شود، پرداخت از اپل/گوگل/Stripe است و این سیاست و قوانین لغو به‌روز می‌شود.",
    ),
  ],
);

final termsDoc = LegalDoc(
  "terms",
  "Terms of Use",
  "شرایط استفاده",
  "Updated · 5 November 2026",
  [
    (
      "Agreement",
      "These terms are between you and ${PublisherConfig.businessName} (contact ${PublisherConfig.privacyEmail}). By using New Life UK you agree to them. If you do not agree, do not use the app.",
      "این شرایط میان شما و ${PublisherConfig.businessName} (تماس ${PublisherConfig.privacyEmail}) است. با استفاده می‌پذیرید؛ وگرنه استفاده نکنید.",
    ),
    (
      "Beta and pricing",
      "The app is in a free beta. Features may change. Example prices on the Premium screen are illustrations only — no payment is taken until billing is switched on and these terms are updated.",
      "اپ در بتا رایگان است. قیمت‌های نمونه فقط برای نمایش‌اند و تا فعال شدن پرداخت، پولی گرفته نمی‌شود.",
    ),
    (
      "Subscriptions (not offered in this beta)",
      "No paid subscription contract is offered by this version. Before billing is enabled, the publisher must publish final pricing, renewal, reminder, cancellation, refund and cooling-off terms appropriate to the contract and law then in force. Illustrative prices and a store cancellation link are not a completed compliance process. Opening digital learning content does not automatically remove every cancellation right.",
      "این نسخه قرارداد اشتراک پولی ارائه نمی‌کند. پیش از پرداخت، ناشر باید شرایط نهایی قیمت، تمدید، یادآوری، لغو، بازپرداخت و مهلت انصراف را متناسب با قرارداد و قانون جاری منتشر کند. قیمت نمونه و لینک فروشگاه جای فرایند کامل را نمی‌گیرد. باز کردن محتوا خودبه‌خود همهٔ حقوق انصراف را حذف نمی‌کند.",
    ),
    (
      "Licence",
      "Personal learning use only. Do not copy, resell or redistribute lessons, stories, paintings or audio.",
      "فقط یادگیری شخصی. درس‌ها، داستان‌ها، نقاشی و صدا را کپی یا فروش نکنید.",
    ),
    (
      "Not advice — immigration / legal / medical",
      "New Life UK teaches English, not legal, medical, immigration, financial or professional advice. We are not regulated by the Immigration Advice Authority (IAA, formerly OISC). Visa and Settlement content is general information and signposting only, not an assessment of your eligibility or circumstances. For an individual case use GOV.UK to find a regulated immigration adviser or solicitor. Career Packs are language practice, not job training. Certificates are not an accredited qualification or Home Office SELT test; CEFR levels are indicative only.",
      "اپ آموزش زبان است، نه مشاورهٔ تخصصی. تحت نظارت IAA، نام پیشین OISC، نیستیم. ویزا و اقامت اطلاعات عمومی است، نه بررسی صلاحیت یا پروندهٔ شما. برای پروندهٔ شخصی از GOV.UK مشاور یا وکیل دارای مجوز بیابید. گواهی‌ها مدرک معتبر یا آزمون SELT نیستند.",
    ),
    (
      "AI voices and AI coach",
      "All spoken character voices are AI-generated neural text-to-speech (Microsoft Azure AI Speech), not recordings of real people. The pronunciation coach scores your speech with on-device / browser speech-to-text — it is an automated aid, not a human teacher. Illustrations were created with Grok (xAI). Characters, places and businesses in the stories are fictional unless clearly labelled as real public services.",
      "همهٔ صداها با هوش مصنوعی (Azure TTS) ساخته شده‌اند. مربی تلفظ خودکار است نه معلم انسان. تصویرها با Grok ساخته شده‌اند. شخصیت‌ها و کسب‌وکارهای داستان خیالی‌اند مگر خدمات عمومی واقعی.",
    ),
    (
      "Not affiliated",
      "Not affiliated with or endorsed by any government body, charity, company or brand. Real services (gov.uk, NHS, 999/101, DVSA, Ofsted, Citizens Advice) are named only factually as places to get real help.",
      "وابسته یا مورد تأیید هیچ نهاد دولتی یا برندی نیستیم. خدمات واقعی فقط برای راهنمایی واقعی نام برده می‌شوند.",
    ),
    (
      "Acceptable use",
      "Do not misuse the app, attempt to break security, scrape content at scale, or harass others if community features appear later.",
      "از اپ سوءاستفاده نکنید، امنیت را نشکنید و محتوا را به‌صورت انبوه کپی نکنید.",
    ),
    (
      "Liability",
      "Provided as is during beta. Nothing limits liability that cannot be limited by law, or your statutory consumer rights under the Consumer Rights Act 2015.",
      "در بتا «همان‌طور که هست». حقوق قانونی مصرف‌کننده تحت CRA 2015 محدود نمی‌شود.",
    ),
    (
      "Law",
      "England and Wales law. We may update these terms; the date above is the latest version.",
      "قانون انگلستان و ولز. ممکن است به‌روز شود؛ تاریخ بالا آخرین نسخه است.",
    ),
  ],
);

final childrenDoc = LegalDoc(
  "children",
  "Children's notice",
  "اطلاعیهٔ کودکان",
  "Updated · 5 November 2026",
  [
    (
      "Who this is for",
      "New Life UK includes family and kid-friendly learning. Children should use it with a parent or carer. Profile switching is not age verification or a secure parental lock. The publisher must confirm age suitability and store declarations before public release.",
      "اپ یادگیری خانوادگی و کودک دارد. کودک با والد یا سرپرست استفاده کند. تعویض پروفایل احراز سن یا قفل امن والد نیست. ناشر باید تناسب سنی و اظهارنامهٔ فروشگاه را پیش از انتشار تأیید کند.",
    ),
    (
      "Best interests and high privacy",
      "If a child uses kid mode: progress stays only on this device; no child account; no ads; no tracking; no public leagues; geolocation off; no prompts to turn off privacy. Parents can delete the child profile or all local data any time.",
      "در حالت کودک: پیشرفت فقط روی دستگاه؛ بدون حساب کودک، تبلیغ، ردیابی، لیگ عمومی؛ موقعیت خاموش. والد می‌تواند پروفایل یا همهٔ داده را پاک کند.",
    ),
    (
      "Children's risk assessment",
      "An internal draft covers local profiles; it is not an approved or complete Data Protection Impact Assessment. Hosting, speech-service transfers, shared devices, under-18 age groups and parental controls still require publisher review before public release. Contact: ${PublisherConfig.privacyEmail}.",
      "پیش‌نویس داخلی پروفایل محلی، DPIA کامل و تأییدشده نیست. میزبانی، انتقال گفتار، دستگاه مشترک، گروه‌های زیر ۱۸ سال و کنترل والد هنوز نیاز به بررسی ناشر دارد. تماس: ${PublisherConfig.privacyEmail}.",
    ),
    (
      "Speak with a parent",
      "If you are under 13, please use the app with a parent or carer.",
      "اگر زیر ۱۳ سال هستید، با والد یا سرپرست استفاده کنید.",
    ),
  ],
);

final aboutDoc = LegalDoc("about", "About & licences", "درباره و مجوزها", "", [
  (
    "New Life UK",
    "British English through everyday life with a fictional London family. Publisher: ${PublisherConfig.businessName}. Contact: ${PublisherConfig.privacyEmail}.",
    "انگلیسی بریتانیایی با یک خانوادهٔ خیالی لندنی. ناشر: ${PublisherConfig.businessName}. تماس: ${PublisherConfig.privacyEmail}.",
  ),
  (
    "Characters are fictional",
    "All characters, family names, schools, nurseries, estate agencies and other businesses in the stories (for example Hartley and Wren Homes, Primrose Lane Nursery, Maple Grove Primary) are fictional. Any likeness to real people or companies is unintended. Paintings and avatars are original AI-assisted illustrations, not photos of real people or logos.",
    "همهٔ شخصیت‌ها، مدارس، مهدکودک‌ها و کسب‌وکارهای داستان (مثل Hartley and Wren، Primrose Lane، Maple Grove) خیالی‌اند. شباهت اتفاقی به افراد یا شرکت‌های واقعی ناخواسته است. تصویرها عکس افراد واقعی یا لوگو نیستند.",
  ),
  (
    "AI voices and pictures",
    "Voices: Microsoft Azure AI Speech neural TTS (pre-rendered). Illustrations: Created with Grok. All voices are AI-generated neural text-to-speech.",
    "صداها: Azure TTS. تصویرها: ساخته‌شده با Grok (Created with Grok). همهٔ صداها با هوش مصنوعی ساخته شده‌اند.",
  ),
  (
    "Open source and fonts",
    "Flutter and packages under BSD/MIT and similar licences (see licence screen). Fonts: Fraunces, Inter, Vazirmatn (SIL Open Font Licence).",
    "Flutter و بسته‌های متن‌باز. فونت‌ها: Fraunces، Inter، Vazirmatn (SIL OFL).",
  ),
  (
    "Trade marks",
    "Brand and place names of real public services are used descriptively. New Life UK is used as a product name; see the compliance report for the UKIPO search note.",
    "نام خدمات عمومی واقعی فقط توصیفی است.",
  ),
]);

class LegalScreen extends ConsumerStatefulWidget {
  final String tab;
  const LegalScreen({super.key, this.tab = 'privacy'});
  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  static final docs = [privacyDoc, termsDoc, childrenDoc, aboutDoc];
  late String tab = docs.any((d) => d.id == widget.tab)
      ? widget.tab
      : 'privacy';
  int _versionTaps = 0;
  DateTime? _lastTap;

  Future<void> _onVersionTap() async {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _versionTaps = 0;
    }
    _lastTap = now;
    _versionTaps += 1;
    if (_versionTaps < 7) return;
    _versionTaps = 0;
    await _showOwnerDialog();
  }

  Future<void> _showOwnerDialog() async {
    final ctrl = ref.read(progressProvider.notifier);
    final p = ref.read(progressProvider);
    if (p.ownerMode) {
      final off = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(hl('Owner mode')),
          content: Text(
            hl(
              'Owner mode is on. Turn it off to restore normal lesson locks on this device.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(hl('Keep on')),
            ),
            FilledButton(
              key: const ValueKey('owner-about-off'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(hl('Turn off')),
            ),
          ],
        ),
      );
      if (off == true) ctrl.setOwnerMode(false);
      return;
    }
    final box = TextEditingController();
    final err = ValueNotifier<String?>(null);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('owner-code-dialog'),
        title: Text(hl('Owner unlock')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hl('Enter the owner code for this device. Attempts are limited.'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('owner-code-field'),
              controller: box,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: hl('Code')),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: err,
              builder: (_, e, _) => e == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        hl(e),
                        style: const TextStyle(color: BL.red, fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(hl('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('owner-code-submit'),
            onPressed: () {
              final e = ctrl.tryActivateOwner(box.text);
              if (e == null) {
                Navigator.pop(ctx, true);
              } else {
                err.value = e;
              }
            },
            child: Text(hl('Unlock')),
          ),
        ],
      ),
    );
    box.dispose();
    err.dispose();
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hl('Owner mode on — everything unlocked on this device.'),
          ),
        ),
      );
    }
  }

  Future<void> _export() async {
    final store = ref.read(progressStoreProvider);
    final data = store.exportAllLocalData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hl(
            'Export copied to clipboard (JSON). Paste into a notes app to keep it.',
          ),
        ),
      ),
    );
  }

  /// Restore a copy made by [_export] (for example on a new phone). Checked first, then confirmed, because it
  /// replaces every profile on this device.
  Future<void> _restore() async {
    final box = TextEditingController();
    final err = ValueNotifier<String?>(null);
    final paste = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('legal-restore-dialog'),
        title: Text(hl('Restore from a copy')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hl('Paste the text you saved with "Export all local data".')),
              Text(
                hl('متنی را که با «Export all local data» ذخیره کردید اینجا بچسبانید.'),
                textDirection: helperDir,
                style: BL.fa(12, color: BL.muted),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('legal-restore-input'),
                controller: box,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '{ "meta": … }'),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: err,
                builder: (_, e, _) => e == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(e, key: const ValueKey('legal-restore-error'), style: const TextStyle(color: BL.red, fontSize: 13)),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(hl('Cancel'))),
          FilledButton(
            key: const ValueKey('legal-restore-check'),
            onPressed: () {
              final c = parseBackup(box.text);
              if (c.ok) {
                Navigator.pop(ctx, c.data);
              } else {
                err.value = '${c.error}\n${hl(c.errorFa)}';
              }
            },
            child: Text(hl('Next')),
          ),
        ],
      ),
    );
    box.dispose();
    err.dispose();
    if (paste == null || !mounted) return;
    final n = BackupCheck.ok(paste).profileCount;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('legal-restore-confirm-dialog'),
        title: Text(hl('Replace the progress on this device?')),
        content: Text(
          '${hl('The copy has $n learner profile(s). Everything on this device now will be replaced by it.')}\n\n'
          '${hl('این نسخه $n پروفایل دارد. همهٔ داده‌های فعلی این دستگاه با آن جایگزین می‌شود.')}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hl('Cancel'))),
          FilledButton(
            key: const ValueKey('legal-restore-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hl('Restore')),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(progressStoreProvider).importAllLocalData(paste);
    ref.invalidate(progressProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${hl('Progress restored.')} ${hl('پیشرفت بازگردانده شد.')}')),
    );
    context.go('/');
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('legal-delete-dialog'),
        title: Text(hl('Delete all local data?')),
        content: Text(
          hl(
            'This erases every profile (including kids), progress, diary and calm-circle codes on this device. It cannot be undone. No server copy exists.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(hl('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('legal-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hl('Delete everything')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(progressStoreProvider).clearAllLocalData();
    ref.invalidate(progressProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(hl('All local data deleted.'))));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final d = docs.firstWhere((x) => x.id == tab);
    String tabLabel(String id) => switch (id) {
      'privacy' => 'Privacy',
      'terms' => 'Terms',
      'children' => 'Children',
      _ => 'About',
    };
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: ValueKey('legal-$tab'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Text(
                'LEGAL & ABOUT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: BL.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final x in docs)
                ButtonSegment(
                  value: x.id,
                  label: Text(
                    hl(tabLabel(x.id)),
                    key: ValueKey('legal-tab-${x.id}'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          const SizedBox(height: 18),
          Text(hl(d.title), style: BL.display(26)),
          Text(hl(d.titleFa), textDirection: helperDir, style: BL.fa(14)),
          if (d.updated.isNotEmpty)
            Text(
              hl(d.updated),
              style: const TextStyle(
                fontSize: 12,
                color: BL.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          for (final (h, en, fa) in d.sections) ...[
            const SizedBox(height: 16),
            Text(
              hl(h),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: BL.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hl(en),
              style: const TextStyle(fontSize: 14, height: 1.45, color: BL.ink),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: Text(
                hl(fa),
                textDirection: helperDir,
                style: BL.fa(13, color: BL.muted),
              ),
            ),
          ],
          if (d.id == 'privacy') ...[
            const SizedBox(height: 22),
            Text(
              hl('Your data on this device'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('legal-export'),
              onPressed: _export,
              icon: const Icon(Icons.download_outlined),
              label: Text(hl('Export all local data')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('legal-restore'),
              onPressed: _restore,
              icon: const Icon(Icons.upload_outlined),
              label: Text(hl('Restore from a copy')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('legal-delete'),
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_forever_outlined, color: BL.red),
              label: Text(
                hl('Delete all local data'),
                style: const TextStyle(color: BL.red),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hl('خروجی گرفتن از همهٔ داده‌های محلی / بازگرداندن از یک نسخه / حذف همهٔ داده‌های محلی'),
              textDirection: helperDir,
              style: BL.fa(12, color: BL.muted),
            ),
          ],
          if (d.id == 'about') ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'New Life UK',
              ),
              icon: const Icon(Icons.description_outlined),
              label: Text(hl('Open-source licences')),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              key: const ValueKey('about-version'),
              behavior: HitTestBehavior.opaque,
              onTap: _onVersionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hl('Version 1.1.0 (5)'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: BL.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hl('New Life UK · local build'),
                      style: const TextStyle(fontSize: 12, color: BL.muted),
                    ),
                    if (ref.watch(progressProvider).ownerMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          key: const ValueKey('owner-about-badge'),
                          onPressed: _showOwnerDialog,
                          child: Text(hl('Owner mode on — tap to manage')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
