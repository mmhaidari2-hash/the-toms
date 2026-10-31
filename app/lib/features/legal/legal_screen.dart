import 'dart:convert';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/legal/publisher_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';

/// Privacy, Terms, Children's notice, About/licences + on-device export/delete (EN + FA).
class LegalDoc {
  final String id, title, titleFa, updated;
  final List<(String, String, String)> sections;
  const LegalDoc(this.id, this.title, this.titleFa, this.updated, this.sections);
}

final privacyDoc = LegalDoc("privacy", "Privacy Policy", "سیاست حریم خصوصی", "Updated · 31 October 2026", [
  ("Who we are", "New Life UK is a British-English learning app published by ${PublisherConfig.businessName}, ${PublisherConfig.postalAddressUk}. Privacy contact: ${PublisherConfig.privacyEmail}. We are the controller for the limited personal data described here. Until placeholders are replaced, treat the product name New Life UK as the service name.",
      "New Life UK اپ یادگیری انگلیسی بریتانیایی است که توسط ${PublisherConfig.businessName}، ${PublisherConfig.postalAddressUk} منتشر می‌شود. تماس حریم خصوصی: ${PublisherConfig.privacyEmail}. ما کنترل‌کنندهٔ دادهٔ محدودی هستیم که اینجا آمده است. تا جایگزینی مقادیر موقتی، نام «New Life UK» همان خدمت است."),
  ("Lawful bases (UK GDPR / DPA 2018 / Data Use and Access Act 2025)", "Most processing is on your device only. Where UK GDPR applies: (1) contract / steps at your request — storing progress so the app works; (2) legitimate interests — securing the static host and preventing abuse, balanced against your rights; (3) consent — only if you grant microphone or notification permission (you can withdraw in system settings). We do not sell personal data or use it for ads.",
      "بیشتر پردازش فقط روی دستگاه شماست. جایی که GDPR بریتانیا اعمال می‌شود: (۱) قرارداد / گام‌های به‌درخواست شما — ذخیرهٔ پیشرفت برای کار اپ؛ (۲) منافع مشروع — امن‌سازی میزبان ایستا و جلوگیری از سوءاستفاده، با سنجش حقوق شما؛ (۳) رضایت — فقط اگر اجازهٔ میکروفون یا اعلان بدهید (در تنظیمات سیستم پس‌گرفتنی است). دادهٔ شخصی را نمی‌فروشیم و برای تبلیغات به‌کار نمی‌بریم."),
  ("No account, no analytics, no ads", "You do not create an account. The app has no analytics, advertising or tracking SDKs, and fonts are bundled (no calls to Google Fonts). Geolocation is not used and stays off.",
      "حساب کاربری نمی‌سازید. اپ هیچ SDK آمار، تبلیغات یا ردیابی ندارد و فونت‌ها داخل اپ هستند. موقعیت مکانی استفاده نمی‌شود و خاموش است."),
  ("What stays on your device", "Progress (lessons, XP, gentle streaks, saved words, diary, settings), learner profiles (including kid-friendly profiles), calm-circle codes, and any name typed on a certificate stay in encrypted local storage on this device where the platform supports it (Hive + secure key on Android/iOS; browser storage on the PWA). A service worker or on-device cache may keep lesson files for offline use. This storage is strictly necessary for the features you chose, so no cookie-consent banner is required under PECR for essential storage. Clearing site data / app storage or using Delete my data below erases it; we cannot recover it.",
      "پیشرفت، پروفایل‌ها (از جمله کودک)، کدهای حلقهٔ آرام و نام روی گواهی در حافظهٔ محلی رمزگذاری‌شده (در صورت پشتیبانی) می‌ماند. سرویس‌ورکر ممکن است فایل درس را برای آفلاین نگه دارد. این ذخیره برای کارکرد ضروری است و بنر رضایت کوکی PECR لازم نیست. پاک‌کردن داده یا دکمهٔ «حذف داده‌های من» آن را پاک می‌کند و ما بازنمی‌گردانیم."),
  ("Internet use and international transfers", "The app needs the Internet to download course content, paintings and pre-rendered Azure neural TTS voice clips from our static host (currently GitHub Pages, GitHub Inc., USA). Clips are app assets, not recordings of you. GitHub may log IP and browser metadata under its own privacy statement; we do not receive those logs. Azure Speech was used by us at build time to create clips; your device does not send your voice to Azure during normal play. Browser speech-to-text (microphone coach) may process audio on Google/Apple servers under their policies when you tap the mic.",
      "اپ برای محتوای دوره، تصویر و صداهای ازپیش‌ساختهٔ Azure به اینترنت نیاز دارد (میزبان: GitHub Pages در آمریکا). این کلیپ‌ها دارایی اپ‌اند نه صدای شما. GitHub ممکن است IP را ثبت کند؛ ما آن را نمی‌گیریم. Azure در زمان ساخت کلیپ استفاده شده؛ هنگام بازی صدای شما به Azure نمی‌رود. گفتار به متن مرورگر هنگام زدن میکروفون ممکن است روی سرورهای گوگل/اپل پردازش شود."),
  ("Microphone and speech", "The microphone is used only when you tap it. Speech-to-text is done by your browser's own speech service (Google in Chrome, Apple in Safari) or the OS service. New Life UK does not upload or store your recordings on our servers. Shadowing Record clips stay on device and are discarded when you leave.",
      "میکروفون فقط با لمس شما روشن می‌شود. تبدیل گفتار را سرویس گفتار مرورگر (گوگل در کروم، اپل در سافاری) یا سیستم‌عامل انجام می‌دهد. New Life UK ضبط شما را روی سرور ذخیره یا آپلود نمی‌کند. ضبط‌های Record روی دستگاه می‌مانند و با خروج پاک می‌شوند."),
  ("Children (Children's Code)", "The app is designed for adult learners (Play target audience 13+). Children should use kid-friendly mode only with a parent/carer on a shared device. Child progress stays on device; we create no child accounts and collect no children's personal data on our servers. High privacy by default, no ads, no profiling, no public leagues, no geolocation, no nudge to weaken privacy — aligned with the ICO Age Appropriate Design Code and DUAA children's duty. See the Children tab.",
      "اپ برای بزرگسالان طراحی شده (مخاطب پلی ۱۳+). کودکان فقط با والد در حالت کودک روی دستگاه مشترک. پیشرفت کودک روی دستگاه است؛ حساب کودک و جمع‌آوری دادهٔ کودک روی سرور نداریم. حریم خصوصی بالا، بدون تبلیغ و لیگ عمومی — هم‌راستا با Children's Code."),
  ("Retention", "Local data remains until you delete it, clear site/app storage, or uninstall. We keep no server-side learner database. Cached static assets follow normal CDN/browser cache lifetimes.",
      "دادهٔ محلی تا وقتی خودتان پاک کنید می‌ماند. پایگاه‌دادهٔ یادگیرنده روی سرور نداریم."),
  ("Your rights", "Under UK data protection law you can access, correct, erase, restrict or port personal data we hold (normally none on our servers; use Export / Delete below for on-device data), and complain to the ICO (ico.org.uk). DUAA: you can also raise a data-protection complaint with us at ${PublisherConfig.privacyEmail}; we will acknowledge within 30 days and respond without undue delay.",
      "طبق قانون بریتانیا می‌توانید به داده دسترسی، اصلاح، حذف، محدودیت یا انتقال بخواهید (معمولاً روی سرور چیزی نیست؛ از خروجی/حذف زیر برای دادهٔ دستگاه استفاده کنید) و به ICO شکایت کنید. شکایت به ما: ${PublisherConfig.privacyEmail} — ظرف ۳۰ روز تأیید و پاسخ بدون تأخیر ناروا."),
  ("Payments (later)", "The app is free in beta; no payment is taken. If subscriptions start, Apple/Google/Stripe will process payments under their terms; we will update this policy and show clear prices, renewal and cancellation (including DMCC cooling-off) before charging.",
      "در بتا رایگان است. اگر اشتراک شروع شود، پرداخت از اپل/گوگل/Stripe است و این سیاست و قوانین لغو به‌روز می‌شود."),
]);

final termsDoc = LegalDoc("terms", "Terms of Use", "شرایط استفاده", "Updated · 31 October 2026", [
  ("Agreement", "These terms are between you and ${PublisherConfig.businessName} (contact ${PublisherConfig.privacyEmail}). By using New Life UK you agree to them. If you do not agree, do not use the app.",
      "این شرایط میان شما و ${PublisherConfig.businessName} (تماس ${PublisherConfig.privacyEmail}) است. با استفاده می‌پذیرید؛ وگرنه استفاده نکنید."),
  ("Beta and pricing", "The app is in a free beta. Features may change. Example prices on the Premium screen are illustrations only — no payment is taken until billing is switched on and these terms are updated.",
      "اپ در بتا رایگان است. قیمت‌های نمونه فقط برای نمایش‌اند و تا فعال شدن پرداخت، پولی گرفته نمی‌شود."),
  ("Subscriptions (when enabled)", "When paid plans go live: clear price, billing period and what you get will be shown before you pay. You can cancel via the store (Play / App Store) or the in-app path we provide. UK consumers: 14-day cooling-off for distance contracts under CRA 2015 / DMCC Act 2024 subscription rules. For digital content, if you ask us to start supply immediately you may need to acknowledge that the cooling-off right can be lost once supply begins — we will show that wording at checkout. Auto-renewal reminders and easy online cancellation will follow DMCC requirements.",
      "وقتی پلن پولی فعال شد: قیمت و دوره قبل از پرداخت روشن است. لغو از فروشگاه یا مسیر داخل اپ. مصرف‌کنندهٔ بریتانیا: مهلت ۱۴روزه. برای محتوای دیجیتال ممکن است با شروع فوری عرضه، حق انصراف از دست برود — همان متن در پرداخت نشان داده می‌شود."),
  ("Licence", "Personal learning use only. Do not copy, resell or redistribute lessons, stories, paintings or audio.",
      "فقط یادگیری شخصی. درس‌ها، داستان‌ها، نقاشی و صدا را کپی یا فروش نکنید."),
  ("Not advice — immigration / legal / medical", "New Life UK teaches English. It is not legal, medical, immigration, financial or professional advice. We are not regulated by the OISC. Visa Help Desk and Settlement content are general information and GOV.UK / OISC signposts only. For your own case use gov.uk and an OISC-regulated adviser. Career Packs are language practice, not job training. Certificates are not accredited qualifications or Home Office SELT tests; CEFR levels are indicative only.",
      "مشاورهٔ حقوقی، پزشکی، مهاجرتی یا مالی نیست. تحت نظارت OISC نیستیم. ویزا و اقامت فقط اطلاعات عمومی و ارجاع به GOV.UK / مشاور OISC است. گواهی‌ها مدرک رسمی یا SELT نیستند."),
  ("AI voices and AI coach", "All spoken character voices are AI-generated neural text-to-speech (Microsoft Azure AI Speech), not recordings of real people. The pronunciation coach scores your speech with on-device / browser speech-to-text — it is an automated aid, not a human teacher. AI-assisted illustrations are used for scenes. Characters, places and businesses in the stories are fictional unless clearly labelled as real public services.",
      "همهٔ صداها با هوش مصنوعی (Azure TTS) ساخته شده‌اند. مربی تلفظ خودکار است نه معلم انسان. شخصیت‌ها و کسب‌وکارهای داستان خیالی‌اند مگر خدمات عمومی واقعی."),
  ("Not affiliated", "Not affiliated with or endorsed by any government body, charity, company or brand. Real services (gov.uk, NHS, 999/101, DVSA, Ofsted, Citizens Advice) are named only factually as places to get real help.",
      "وابسته یا مورد تأیید هیچ نهاد دولتی یا برندی نیستیم. خدمات واقعی فقط برای راهنمایی واقعی نام برده می‌شوند."),
  ("Acceptable use", "Do not misuse the app, attempt to break security, scrape content at scale, or harass others if community features appear later.",
      "از اپ سوءاستفاده نکنید، امنیت را نشکنید و محتوا را به‌صورت انبوه کپی نکنید."),
  ("Liability", "Provided as is during beta. Nothing limits liability that cannot be limited by law, or your statutory consumer rights under the Consumer Rights Act 2015.",
      "در بتا «همان‌طور که هست». حقوق قانونی مصرف‌کننده تحت CRA 2015 محدود نمی‌شود."),
  ("Law", "England and Wales law. We may update these terms; the date above is the latest version.",
      "قانون انگلستان و ولز. ممکن است به‌روز شود؛ تاریخ بالا آخرین نسخه است."),
]);

final childrenDoc = LegalDoc("children", "Children's notice", "اطلاعیهٔ کودکان", "Updated · 31 October 2026", [
  ("Who this is for", "New Life UK is built for adult learners. Google Play target audience: 13 and older (not Designed for Families as a primary child app). Kid-friendly mode is a parental control on a shared device.",
      "برای بزرگسالان ساخته شده. مخاطب پلی: ۱۳+. حالت کودک کنترل والد روی دستگاه مشترک است."),
  ("Best interests and high privacy", "If a child uses kid mode: progress stays only on this device; no child account; no ads; no tracking; no public leagues; geolocation off; no prompts to turn off privacy. Parents can delete the child profile or all local data any time.",
      "در حالت کودک: پیشرفت فقط روی دستگاه؛ بدون حساب کودک، تبلیغ، ردیابی، لیگ عمومی؛ موقعیت خاموش. والد می‌تواند پروفایل یا همهٔ داده را پاک کند."),
  ("DPIA", "We keep an internal Data Protection Impact Assessment for children use (local-only profiles). Contact ${PublisherConfig.privacyEmail} for a summary.",
      "ارزیابی تأثیر حفاظت از داده (DPIA) برای استفادهٔ کودکان داریم. خلاصه: ${PublisherConfig.privacyEmail}."),
  ("Speak with a parent", "If you are under 13, please use the app with a parent or carer.",
      "اگر زیر ۱۳ سال هستید، با والد یا سرپرست استفاده کنید."),
]);

final aboutDoc = LegalDoc("about", "About & licences", "درباره و مجوزها", "", [
  ("New Life UK", "British English through everyday life with a fictional London family. Publisher: ${PublisherConfig.businessName}. Contact: ${PublisherConfig.privacyEmail}.",
      "انگلیسی بریتانیایی با یک خانوادهٔ خیالی لندنی. ناشر: ${PublisherConfig.businessName}. تماس: ${PublisherConfig.privacyEmail}."),
  ("Characters are fictional", "All characters, family names, schools, nurseries, estate agencies and other businesses in the stories (for example Hartley and Wren Homes, Primrose Lane Nursery, Maple Grove Primary) are fictional. Any likeness to real people or companies is unintended. Paintings and avatars are original AI-assisted illustrations, not photos of real people or logos.",
      "همهٔ شخصیت‌ها، مدارس، مهدکودک‌ها و کسب‌وکارهای داستان (مثل Hartley and Wren، Primrose Lane، Maple Grove) خیالی‌اند. شباهت اتفاقی به افراد یا شرکت‌های واقعی ناخواسته است. تصویرها عکس افراد واقعی یا لوگو نیستند."),
  ("AI voices and pictures", "Voices: Microsoft Azure AI Speech neural TTS (pre-rendered). Illustrations: original AI-assisted art for the app. All voices are AI-generated neural text-to-speech.",
      "صداها: Azure TTS. تصویرها: هنر اختصاصی با کمک هوش مصنوعی. همهٔ صداها با هوش مصنوعی ساخته شده‌اند."),
  ("Open source and fonts", "Flutter and packages under BSD/MIT and similar licences (see licence screen). Fonts: Fraunces, Inter, Vazirmatn (SIL Open Font Licence).",
      "Flutter و بسته‌های متن‌باز. فونت‌ها: Fraunces، Inter، Vazirmatn (SIL OFL)."),
  ("Trade marks", "Brand and place names of real public services are used descriptively. New Life UK is used as a product name; see the compliance report for the UKIPO search note.",
      "نام خدمات عمومی واقعی فقط توصیفی است."),
]);


class LegalScreen extends ConsumerStatefulWidget {
  final String tab;
  const LegalScreen({super.key, this.tab = 'privacy'});
  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  static final docs = [privacyDoc, termsDoc, childrenDoc, aboutDoc];
  late String tab = docs.any((d) => d.id == widget.tab) ? widget.tab : 'privacy';

  Future<void> _export() async {
    final store = ref.read(progressStoreProvider);
    final data = store.exportAllLocalData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('Export copied to clipboard (JSON). Paste into a notes app to keep it.'))));
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('legal-delete-dialog'),
        title: Text(hl('Delete all local data?')),
        content: Text(hl('This erases every profile (including kids), progress, diary and calm-circle codes on this device. It cannot be undone. No server copy exists.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hl('Cancel'))),
          FilledButton(key: const ValueKey('legal-delete-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(hl('Delete everything'))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(progressStoreProvider).clearAllLocalData();
    ref.invalidate(progressProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('All local data deleted.'))));
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
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('LEGAL & ABOUT', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            segments: [for (final x in docs) ButtonSegment(value: x.id, label: Text(hl(tabLabel(x.id)), key: ValueKey('legal-tab-${x.id}'), style: const TextStyle(fontSize: 12)))],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          const SizedBox(height: 18),
          Text(hl(d.title), style: BL.display(26)),
          Text(hl(d.titleFa), textDirection: helperDir, style: BL.fa(14)),
          if (d.updated.isNotEmpty) Text(hl(d.updated), style: const TextStyle(fontSize: 12, color: BL.muted, fontWeight: FontWeight.w600)),
          for (final (h, en, fa) in d.sections) ...[
            const SizedBox(height: 16),
            Text(hl(h), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BL.ink)),
            const SizedBox(height: 4),
            Text(hl(en), style: const TextStyle(fontSize: 14, height: 1.45, color: BL.ink)),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: Text(hl(fa), textDirection: helperDir, style: BL.fa(13, color: BL.muted))),
          ],
          if (d.id == 'privacy') ...[
            const SizedBox(height: 22),
            Text(hl('Your data on this device'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('legal-export'),
              onPressed: _export,
              icon: const Icon(Icons.download_outlined),
              label: Text(hl('Export all local data')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('legal-delete'),
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_forever_outlined, color: BL.red),
              label: Text(hl('Delete all local data'), style: const TextStyle(color: BL.red)),
            ),
            const SizedBox(height: 6),
            Text(hl('خروجی گرفتن از همهٔ داده‌های محلی / حذف همهٔ داده‌های محلی'), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
          ],
          if (d.id == 'about') ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: () => showLicensePage(context: context, applicationName: 'New Life UK'), icon: const Icon(Icons.description_outlined), label: Text(hl('Open-source licences'))),
          ],
        ],
      ),
    );
  }
}
