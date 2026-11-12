# ارزیابی تحویل صدا و حجم انتشار اندروید (Audio delivery / release-size assessment)

> تاریخ: ۱۲ نوامبر ۲۰۲۶ (لندن). شاخه: `fix/offline-audio-content`، اندازه‌گیری روی tip `57e3e3be`.
> فقط ارزیابی است: هیچ انتشاری روی `main`/Pages انجام نشد، هیچ build یا Flutter test اجرا نشد، هزینهٔ Azure صفر.
> این سند تأیید Google Play یا تأیید حقوقی نیست. اعداد اندازهٔ AAB تخمین‌اند؛ عدد قطعی را فقط Play Console پس از upload می‌دهد.

## ۱. وضعیت فعلی فایل‌ها (اندازه‌گیری واقعی)

| مورد | مقدار |
| --- | --- |
| فایل‌های `app/assets/audio/*.mp3` | **۴۴٬۴۳۸** = ۴۴٬۴۳۷ شناسهٔ `index.json` + `silence.mp3` (۲٬۳۹۶ بایت). هیچ شناسه‌ای بی‌فایل نیست. |
| حجم کل mp3 | **۴۹۵٬۴۲۷٬۶۷۲ بایت** (≈ 495.4 MB = 472.5 MiB). کل پوشه با JSONها: ۴۹۶٬۳۲۴٬۸۱۱ بایت |
| اندازهٔ هر کلیپ | min ۲٬۱۸۰، median ۹٬۱۶۴، mean ۱۱٬۱۴۹، max ۶۳٬۹۵۶ بایت (هیچ فایلی نزدیک سقف 100 MiB گیت‌هاب نیست) |
| `bundled.json` | **۴۱۹** شناسه (کلیپ‌های درس‌های اول)، ۱٬۵۳۰٬۴۶۰ بایت |
| `ver.json` شاخه / زنده | `da11c1351d` / `8e3903c12d` |

عدد «567 MB» در `docs/ANDROID_RELEASE.md` و «~565 MB» در توضیح `speech_io.dart` قدیمی است؛ عدد فعلی 495.4 MB است (اصلاح این متن‌ها در این مرحله انجام نشد).

## ۲. اپ کلیپ‌ها را چطور بار می‌کند (trace کد)

- `app/pubspec.yaml` در `flutter: assets:` خط `- assets/audio/` دارد. طبق مستندات Flutter، ورودی پوشه‌ای **همهٔ فایل‌های مستقیم آن پوشه** را وارد asset bundle می‌کند. پس `flutter build apk/appbundle` مستقیم در `app/` **هر ۴۴٬۴۳۸ mp3** را بسته‌بندی می‌کند. در `app/android` (Gradle) هیچ exclude، `androidResources.ignoreAssetsPattern` یا asset pack وجود ندارد.
- مسیر release رسمی `app/tool/build_android.sh` است: اپ را به `/workspace/android_build` کپی می‌کند، همهٔ mp3ها جز `silence.mp3` را حذف می‌کند و فقط ۴۱۹ کلیپ `bundled.json` را برمی‌گرداند، بعد APK و AAB می‌سازد. نکته: `NEWLIFE_SRC` پیش‌فرض `/workspace/british-life/app` است، نه این checkout؛ باید هنگام build صریحاً تنظیم شود.
- شاهد: AAB موجود `/workspace/run30/release/NewLifeUK-1.1.0.aab` (۶ نوامبر) = ۷۷٬۹۲۰٬۳۷۷ بایت، با **۴۲۰ mp3** (۴۱۹ + silence)، ۱٬۵۳۵٬۲۳۲ بایت خام → ۱٬۳۷۴٬۸۳۷ بایت فشرده (۸۹.۶٪، چون mp3 از قبل فشرده است).
- `lib/core/platform/voice.dart`: فهرست کلیپ‌ها را از `assets/audio/index.json` **داخل APK** می‌خواند.
- `lib/core/platform/speech_io.dart` (Android): `resolveClip` به ترتیب: (۱) اگر کلید در `bundled.json` باشد → `AssetSource` (آفلاین)؛ (۲) اگر در cache باشد → `DeviceFileSource`؛ (۳) وگرنه از `https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/<id>.mp3?v=<ver>` دانلود، در cache ذخیره و پخش؛ (۴) در صورت شکست، `UrlSource` (هرگز TTS دستگاه). `ver` از `ver.json` سایت زنده خوانده می‌شود.
- cache در `Directory.systemTemp/newlifeuk_audio/nl_audio_<ver>` است (در Android همان cache اپ؛ سیستم ممکن است پاکش کند). `arrival_prefetch_io.dart` همان پوشه را پر می‌کند (اصلاح Q29).

### پیامد مهم
GitHub Pages زنده (از `main`) الان **۲۲٬۲۳۹ فایل صوتی (۲۷۴٬۵۷۷٬۶۶۷ بایت)** دارد. نسبت به این شاخه: ۵٬۹۶۵ کلیپ یکسان، **۱۶٬۲۷۱ کلیپ عوض‌شده** (روی سایت هنوز نسخهٔ صدای قدیمی) و **۲۲٬۲۰۲ کلیپ اصلاً روی سایت نیست**. اگر APK از این شاخه ساخته شود ولی صداها منتشر نشوند، آن ۲۲٬۲۰۲ کلیپ با 404 روبه‌رو می‌شوند و پخش نمی‌شوند (به‌جز ۴۱۹ کلیپ bundled).

## ۳. سقف‌های رسمی (منابع در پایان)

**Google Play** (Play Console Help 9859372، بر اساس compressed download size):
- Base module: **500 MB** (توجه: نه 200 MB؛ 200 MB آستانهٔ نمایش هشدار حجم زیاد برای کاربر روی دیتای موبایل است، non-blocking).
- هر feature module: 500 MB؛ هر asset pack: **1.5 GB**؛ مجموع ماژول‌ها + install-time packs: 4 GB؛ مجموع fast-follow/on-demand: 30 GB؛ حداکثر ۱۰۰ asset pack.
- APK قدیمی (بدون AAB): 100 MB.
- install-time asset packs حدود ۲ برابر حجمشان فضای خالی می‌خواهند؛ fast-follow/on-demand فقط چند صد MB.

**GitHub Pages / GitHub:**
- سایت منتشرشده حداکثر **1 GB**؛ مخزن منبع Pages: توصیهٔ **1 GB**؛ soft bandwidth **100 GB/ماه**؛ deployment پس از 10 دقیقه timeout؛ soft limit ۱۰ build در ساعت (برای workflow سفارشی Actions اعمال نمی‌شود)؛ امکان 429.
- Pages «free web-hosting service to run your online business… or commercial SaaS» نیست (اپ SDK خرید دارد؛ این ریسک سیاستی است، نه نتیجه‌گیری حقوقی).
- فایل: هشدار بالای 50 MiB، **مسدود بالای 100 MiB**. مخزن: ترجیحاً < 1 GB، اکیداً < 5 GB.

## ۴. حجم‌ها برای هر گزینه

- مخزن `the-toms` طبق GitHub API الان ≈ **2.0 GB** (`size` = 2,012,367 KB) — همین حالا بالای توصیهٔ 1 GB.
- سایت زندهٔ `main`: ۲۲٬۶۰۸ فایل، ۳۶۶٬۳۱۲٬۰۰۸ بایت. با جایگزینی کامل صداها ≈ 366.3 − 274.6 + 495.4 + 0.9 ≈ **۵۸۸ MB** (≈ ۵۹٪ سقف 1 GB).
- انتشار کامل حدود **۳۹۲ MB blob تازه** (۲۳۱.۲ MB جدید + ۱۶۱.۰ MB عوض‌شده) به تاریخچهٔ git اضافه می‌کند → مخزن ≈ **2.4 GB** (زیر 5 GB، بالای 1 GB).
- AAB فعلی: base فشرده ۴۵٬۳۰۸٬۵۶۸ بایت با کتابخانه‌های هر ۳ ABI (۲۷.۷ MB)؛ برای دستگاه arm64 ≈ **۲۷ MB** دانلود (تخمین).
- اگر همهٔ صداها داخل AAB بروند: +≈ **444–448 MB** فشرده (۸۹.۶٪ نسبت per-file در AAB؛ ۹۰.۳٪ با gzip کل) → دانلود base برای arm64 ≈ **۴۷۰ MB**، فایل AAB ≈ ۵۲۰ MB.

## ۵. مقایسهٔ گزینه‌ها

| گزینه | حجم | مزایا | معایب |
| --- | --- | --- | --- |
| (a) همه در AAB (base) | ≈ 470 MB/دستگاه | کاملاً آفلاین، بدون وابستگی به Pages | فقط ~30 MB فاصله تا سقف 500 MB (تخمینی؛ رشد محتوا آن را رد می‌کند)؛ هشدار بالای 200 MB؛ نیاز به ~۲ برابر فضای خالی؛ هر نسخهٔ صوتی تازه = آپدیت بزرگ اپ؛ کد/اسکریپت build باید عوض شود. **توصیه نمی‌شود.** |
| (b) دانلود از Pages پس از انتشار روی `main` | اپ ≈ 27 MB؛ سایت ≈ 588 MB | همان چیزی که کد فعلی انجام می‌دهد؛ صفر تغییر کد؛ re-voice بدون آپدیت اپ (`ver.json`) | نیاز به مجوز مالک برای `main`/Pages؛ مخزن ≈ 2.4 GB؛ soft bandwidth 100 GB ≈ ۲۰۰ دانلود کامل ۴۹۵ MB در ماه (کاربر عادی فقط کلیپ‌های درس‌هایش را می‌گیرد)؛ ریسک سیاست «commercial»؛ نیاز به اینترنت؛ cache قابل پاک‌شدن |
| (c) Play Asset Delivery (fast-follow/on-demand) | یک pack ≈ 445 MB (سقف 1.5 GB) | میزبانی و پهنای باند با Google Play، رایگان؛ در اندازهٔ نمایش‌داده‌شدهٔ اپ حساب نمی‌شود؛ آفلاین بعد از دانلود | Flutter پشتیبانی داخلی PAD ندارد → کد native/plugin + platform channel + ماژول asset pack در Gradle؛ فقط برای نصب از Play (sideload/web نه)؛ آپدیت pack وابسته به آپدیت اپ؛ تست با bundletool/internal sharing؛ کار مهندسی و تست واقعی لازم |
| (d) فقط زیرمجموعهٔ هسته در APK | الان ۴۱۹ کلیپ = 1.53 MB | پیاده‌سازی‌شده؛ درس‌های اول آفلاین | به‌تنهایی کافی نیست؛ بقیه باید از (b) یا (c) بیایند |

## ۶. توصیه
- **کوتاه‌مدت: (d) + (b)** — همان معماری فعلی (۴۱۹ کلیپ bundled + دانلود و cache بقیه). حجم دانلود Play ≈ 27 MB می‌ماند و هیچ کدی لازم نیست. **شرط لازم:** انتشار ۴۴٬۴۳۷ کلیپ روی Pages (`main`) که فقط با تصمیم مالک انجام می‌شود؛ بدون آن هر build اندروید از این شاخه برای ۲۲٬۲۰۲ کلیپ صدا ندارد. اندازه‌ها (۵۸۸ MB سایت، فایل‌ها ≤ 64 KB) زیر سقف‌های سخت‌اند؛ مخزن بالای توصیهٔ 1 GB است.
- **میان‌مدت (اختیاری): (c)** یک fast-follow pack حدود 445 MB، اگر آفلاین کامل لازم شد یا پهنای باند/سیاست Pages مشکل شد. قبل از آن به نمونهٔ اولیه و تست روی گوشی واقعی نیاز است.
- **(a) نه.**
- همیشه از `tool/build_android.sh` (با `NEWLIFE_SRC` درست) build شود، نه `flutter build appbundle` مستقیم در `app/`؛ وگرنه ≈ 445 MB صدا وارد AAB می‌شود.

## ۷. شرط تست بستهٔ Google Play (تأییدشده)
طبق Play Console Help 14151465: حساب‌های developer شخصی که **بعد از ۱۳ نوامبر ۲۰۲۳** ساخته شده‌اند، قبل از دسترسی به Production باید یک **closed test با دست‌کم ۱۲ تستر** اجرا کنند که **۱۴ روز پیوسته** opt-in بوده‌اند؛ سپس از Dashboard برای production access درخواست می‌دهند (بررسی معمولاً ≤ ۷ روز). Internal testing شرطی ندارد ولی جای این را نمی‌گیرد. تاریخ ساخت حساب مالک بررسی نشده است.

## منابع
- Google Play size limits: https://support.google.com/googleplay/android-developer/answer/9859372
- Play Asset Delivery: https://developer.android.com/guide/playcore/asset-delivery
- Testing requirements for new personal accounts: https://support.google.com/googleplay/android-developer/answer/14151465
- GitHub Pages limits: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
- GitHub large files / repo size: https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
- Flutter assets: https://docs.flutter.dev/ui/assets/assets-and-images
- اندازهٔ سایت زنده: GitHub API `git/trees/main?recursive=1` و `repos/mmhaidari2-hash/the-toms` (۱۲ نوامبر ۲۰۲۶).
