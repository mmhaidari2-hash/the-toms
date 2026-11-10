# نقطهٔ ثبت — ۱۰ نوامبر ۲۰۲۶، واقعیت‌های حریم و آمادگی

درخت خوانده‌شده: `51d67f6d1914a3fe15ead57b5e44eed36deccb29` روی `fix/offline-audio-content`. این سند کد محصول، سیاست حقوقی، یا پیش‌نویس فروشگاه را عوض نمی‌کند. تأیید حقوقی یا آمادگی Play نیست.

English: Facts read from `51d67f6d`. No product or legal-policy edit. Not legal approval and not Play-ready.

نسخهٔ فشرده برای نویسندهٔ متن فروشگاه: `privacy-store-facts-2026-11-10.md` در خروجی همین بررسی. همان واقعیت‌ها اینجاست تا دوباره کشف نشوند.

## چه چیزی تاریخی ماند

- مجموعهٔ سریال روی `9daa52a988fd7abda121a759ff2a683d02694b2b`: `+259 ~2 -4`، خروج ۱. شکست‌ها کلیپ‌های arrival و سه آزمون audit صوت بودند. دوباره اجرا نشد.
- پذیرش مرورگر روی ساخت `c2a81fa6d` (Dart برابر همان SHA) بود. آب‌نبات، کمک، زعفران و چرخش PASS. املای نزدیک، پیش‌نویس نفرستاده، و بنر صدا NOT-RUN. پیش‌نمایش منتشر نشد.
- Azure در ۶ نوامبر ۱۸:۲۵ لندن `401` بود. این مرحله کلید نخواند، ورود نخواست، و کلیپ نساخت. سهمیهٔ F0 هنوز اثبات نشده است.
- Q03 در `docs/compliance/OPEN_QUESTIONS_FA.md` خط ۳۶ تا ۳۸ به تعویق مانده تا ثبت شرکت. دوباره پرسیده نشد. Q04 تا Q06 با همان تصمیم منتظر می‌مانند.

## ناشر

`app/lib/core/legal/publisher_config.dart` خط ۴: نام محصول `New Life UK`. خط ۵ تا ۲۵: نام حقوقی، نشانی، ایمیل‌ها، شمارهٔ شرکت، ICO، و نشانی‌های عمومی هنوز `[PLACEHOLDER: …]` هستند. خط ۴۰ تا ۴۲: `placeholdersRemaining` تا پر شدن این فیلدها درست است. از نام حساب گیت‌هاب هویت ناشر ساخته نشد.

متن‌های درون‌برنامه، تاریخ ۵ نوامبر ۲۰۲۶، مسیر `/legal`: حریم خط ۲۷، شرایط خط ۹۱، کودکان خط ۱۵۰، درباره خط ۱۷۹ در `app/lib/features/legal/legal_screen.dart`. هنوز همان جای‌خالی‌ها را نشان می‌دهند.

## داده و صدا — رفتار کد

- حساب و سرور یادگیرنده نیست. Hive جعبهٔ `progress` (`progress_store.dart` خط ۶۲–۷۲). وب بدون رمز IndexedDB. اندروید AES با کلید دستگاهی `nluk_progress_aes_v1` (خط ۳۹–۵۱). کلید اینجا چاپ نشد.
- پروفایل بزرگسال/کودک محلی است (`learner_profile.dart` خط ۳–۲۰). تعویض پروفایل قفل والد نیست (legal خط ۱۵۷–۱۵۸). مسیرهای کودک‌مخفی خط ۷۴–۸۵. در درخت `51d67f6d` جملهٔ مطلق «دادهٔ کودک جمع نمی‌شود» در `profiles_screen.dart` با پیش‌نویس حریم (ذخیرهٔ محلی و تماس دانلود) یکی نبود. آن جمله در بخش «اعلان پروفایل کودک» همین سند اصلاح شد. پیش‌نویس `legal_screen` دست نخورد و برای فروشگاه همان پیش‌نویس نویسنده ملاک است.
- خروجی: JSON در کلیپ‌بورد (legal خط ۳۳۵–۳۴۸). حذف: پاک‌کردن جعبهٔ محلی پس از تأیید (خط ۳۵۲–۳۸۲). کش صدا ممکن است بماند (خط ۵۰).
- گفت‌وگو آفلاین و فیلمنامه‌ای است (`dialogue_brain.dart` خط ۴۳–۵۸)، نه چت آزاد.
- TTS زمان اجرا فقط کلیپ ازپیش‌ساخته است. مربی تلفظ Azure Pronunciation Assessment ندارد (`coach_screen.dart` خط ۱۳–۱۴).
- وب: Web Speech API ممکن است صدا را به سرویس مرورگر (گوگل/اپل) بفرستد (`speech_web.dart` خط ۱۳–۲۲). اندروید: `sttSupported` و `recordSupported` هر دو false (`speech_io.dart` خط ۲۵–۲۶). جملهٔ «یا سرویس سیستم‌عامل» در حریم خط ۶۵ از این کد اندروید گسترده‌تر است.
- مانیفست فقط `INTERNET` می‌خواهد (`AndroidManifest.xml` خط ۲–۳). مجوزهای ادغام‌شدهٔ پلاگین UNKNOWN است.
- پرداخت خاموش: `betaFree = true` (`premium.dart` خط ۶). `Billing.available` بدون سه شرط روشن نمی‌شود (`billing.dart` خط ۲۱–۲۲). Sentry بدون DSN هیچ ارسالی ندارد (`sentry_gate.dart` خط ۹–۱۵) و بستهٔ `sentry_flutter` وصل نیست. تبلیغ و آمار در `pubspec.yaml` نیست. فونت زمان اجرا خاموش است (`main.dart` خط ۲۸–۲۹).
- میزبان واقعی صدا در اندروید: `https://mmhaidari2-hash.github.io/the-toms/assets/` (`speech_io.dart` خط ۲۱–۲۲). دعوت همان سایت است (`share.dart` خط ۱۳). CSP وب `fonts.gstatic.com` و Sentry را اجازه می‌دهد (`web/index.html` خط ۸) ولی کد پیش‌فرض به آن‌ها وصل نمی‌شود.

## زبان و مخاطب

فارسی آماده است. جدول تولیدشده فقط `hi`، `ur`، `ar`، `ps` را تمام‌شده می‌داند (`coverage.g.dart` خط ۲۲). رومانیایی و لهستانی beta هستند نه ready. بقیهٔ فهرست `strings.dart` خط ۱۶–۳۵ پوشش ۰ دارند یا در `hold.json` مانده‌اند. بازیابی لهستانیِ قبلاً مسدودشده باز نشد.

سن محصول UNKNOWN است (Q15). متن کودکان «زیر ۱۳ با والد» دارد (legal خط ۱۷۲–۱۷۴) و می‌گوید برچسب ۱۳+ ارزیابی نیست. این مشاهدهٔ متن بریتانیایی است، نه انطباق UK GDPR یا GDPR اتحادیه.

## مانع‌ها و مرحلهٔ بعدی کد

1. جای‌خالی ناشر تا ثبت شرکت.
2. کلید امضای تولید داخل مخزن نیست (`build.gradle.kts` خط ۱۰–۱۳). هویت امضای تازه ساخته نشود.
3. کلیپ‌های غایب، تا اثبات F0.
4. مجموعهٔ تاریخی سبز نیست.
5. Q15، Q17، Q16، Q06، Q09، Q13 باز هستند.
6. آزمون خرید واقعی، Data safety، و گوشی اندروید انجام نشده. پرداخت باید خاموش بماند.
7. پیش‌نمایش و سایت زنده دست نخورند.

مرحلهٔ بعدی امن و مستقل از متن فروشگاه: یک اصلاح کوتاه انگلیسی+فارسی تا راهنمای میکروفون، تشخیص گفتار سیستم را برای اندروید وعده ندهد؛ مطابق `speech_io.dart` خط ۲۵–۲۶. پیش‌نویس حقوقی نویسنده دست نخورد. APK ساخته نشود. صوت تازه ساخته نشود. مجموعهٔ کامل تکرار نشود.

English: The mic-help correction below is that next stage. Leave the writer’s legal drafts, audio generation, signing, and the full suite alone.

## مرحلهٔ کد — راهنمای میکروفون، ۱۰ نوامبر ۲۰۲۶

Azure تازه، جدا از ۶ نوامبر: والد در ۱۰ نوامبر ۲۰۲۶ ساعت ۲۲:۴۳:۳۸ اروپا/لندن یک `subscription_list` زندهٔ مجاز را خواند و دوباره `401` / `CredentialUnavailableException` / `ChainedTokenCredential` گرفت. ورود `az login` لازم است. منبع، اشتراک، SKU، F0، نقطهٔ پایانی و ظرفیت رایگان نوامبر اثبات نشد. این مرحله همان را دوباره نپرسید، کلید نخواند و کلیپ نساخت. فایل اعلام‌شده `newlife-f0-check-20261110/f0-check-evidence.txt` در این محیط نبود؛ این بند نقل همان خواندن والد است، نه یک بررسی تازهٔ Azure. این مدرک جایگزینِ تکیهٔ تنها بر `401` ششم نوامبر است و اجازهٔ ساخت صدا نیست.

اصلاح: وقتی وب نیست و `sttSupported` و `recordSupported` هر دو false هستند (همان `speech_io.dart`)، متن راهنما دیگر مرورگر، ضبط، دیکتهٔ صفحه‌کلید، یا تشخیص گفتار اندروید را وعده نمی‌دهد. مسیر وب همان تشخیص اختیاری مرورگر (گوگل/اپل) و در صورت نبودن API، میکروفون کیبورد یا تایپ را می‌گوید. پیش‌نویس `/legal` دست نخورد. زبان‌های helper و جدول پوشش عوض نشد. مسیر، اثر، متن درس و پیشرفت عوض نشد. SDK گفتار تازه اضافه نشد.

فایل‌ها:

- `app/lib/features/speaking/speaking_widgets.dart`
- `app/lib/features/conversation/conversation_screen.dart`
- `app/lib/features/coach/coach_screen.dart`
- `app/lib/features/messages/thread_screen.dart`
- `app/test/speaking_test.dart`
- `app/test/priya_shop_layout_test.dart` فقط راهنمای tooltip میکروفون، چون در آزمون VM دیگر «Speak with the keyboard mic» نیست

آزمون، بدون مجموعهٔ کامل: `cd app && flutter test -j 1 test/speaking_test.dart` با Flutter 3.47.7. نتیجه: `+12`، همه قبول، حدود ۶ ثانیه بعد از بارگذاری. لاگ: `speaking-mic-2026-11-10.log`. مجموعهٔ `+259 ~2 -4` روی `9daa52a98` تاریخی ماند. APK و مرورگر ساخته نشد.

مانع‌های بعدی که این مرحله باز نکرد:

1. جای‌خالی ناشر تا ثبت شرکت (Q03 پرسیده نشود).
2. کلیپ‌های arrival و audit، تا اثبات F0. مدرک ۱۰ نوامبر هنوز `401` است.
3. مجوزهای ادغام‌شدهٔ APK هنوز UNKNOWN. بسته ساخته نشود.
4. پیش‌نویس حقوقی منتظر نویسنده است.
5. امضای تولید داخل مخزن نیست.
6. آمادهٔ Play نیست و تأیید حقوقی کامل نیست.

English: Parent’s 10 Nov 2026 22:43:38 Europe/London Azure read was again 401 CredentialUnavailable / ChainedTokenCredential. No F0 proof and no new audio. The installed-app mic help now says it cannot transcribe or record; web copy still names browser speech. Focused `speaking_test.dart` was +12. Not Play-ready.

## مرحلهٔ کد — اعلان پروفایل کودک، ۱۰ نوامبر ۲۰۲۶

جملهٔ مطلق جعبهٔ `profiles-privacy` برداشته شد. متن جدید، انگلیسی و فارسی، این‌ها را جدا می‌گوید: پروفایل کودک نام و پیشرفت را روی همین دستگاه نگه می‌دارد؛ حساب یادگیرنده ساخته نمی‌شود و این برنامه آن پروفایل را به سرور ما نمی‌فرستد؛ دانلود صدای درس هنوز می‌تواند به میزبان صدا وصل شود؛ عوض کردن پروفایل قفل والد یا سرپرست نیست. وعدهٔ مطلق «هیچ داده‌ای جمع نمی‌شود»، «فقط روی دستگاه»، یا «هیچ شخص ثالثی» داده نشد. دکمهٔ سیاست حریم، مسیر `/legal`، مخفی‌بودن مسیرهای بزرگسال برای کودک، جعبهٔ پیشرفت، و جریان داده عوض نشد. `legal_screen.dart` دست نخورد. زبان‌های helper و جدول پوشش عوض نشد.

سورس این اصلاح `082600210fa5a5346786216851b57ca99d8ad226`، والد `8bf230814b76975d95e460b0cb2e7f0aecfcdeee`. آزمون `+21` روی همان درخت Dart اجرا شد؛ این بند SHA فقط سند را به آن کامیت وصل می‌کند.

فایل‌های این مرحله:

- `app/lib/features/profiles/profiles_screen.dart`
- `app/test/profiles_test.dart`

آزمون سریال، بدون مجموعهٔ کامل، بعد از اصلاح یک یابنده. یابندهٔ اول «does not create» می‌خواست و جمله «We do not create» است؛ همان اجرا `+20 -1` شد و فقط همان رشتهٔ آزمون عوض شد. اجرای ثبت‌شده:

`cd app && flutter test -j 1 test/speaking_test.dart test/profiles_test.dart test/messages_flow_test.dart test/priya_shop_layout_test.dart`

Flutter 3.47.7، Dart 3.13.5. نتیجه: `+21`، همه قبول. لاگ: `profiles-notice-focused-2026-11-10.log`. فایل‌ها: `speaking_test.dart` (۱۲، شامل متن مربی)، `profiles_test.dart` (۶، شامل اعلان دوزبانه و آزمون‌های قفل مسیر و پیشرفت)، `messages_flow_test.dart` (۱، محل `msg-mic-note`)، `priya_shop_layout_test.dart` (۲، شامل tooltip «Type your reply» از کامیت `8bf230814`). `messages_test.dart` آزمون محتوا و فهرست صوت است و اجرا نشد تا شکاف کلیپ‌های شناخته‌شده این مرحله را نشکند. مجموعهٔ `+259 ~2 -4` روی `9daa52a98` تاریخی ماند.

مجوزها — ادغام release ساخته نشد. مانع دقیق: `ANDROID_HOME` و `ANDROID_SDK_ROOT` خالی‌اند، SDK اندروید روی این ماشین نیست، و `/home/box/keys/key.properties` نیست. `processReleaseManifest` اجرا نشد. `ALLOW_DEBUG_SIGNED_RELEASE` ست نشد. نگهبان `build.gradle.kts` خط ۷۵–۸۰ عوض نشد. هیچ APK یا AAB ساخته یا باز نشد. پس مجوزهای مانیفست ادغام‌شدهٔ release همین الان UNKNOWN است.

آنچه از سورس خود اپ خوانده شد، و ادغام نیست:

- `src/main`: یک گره `android.permission.INTERNET` (خط ۳). نظر خط ۲ که «تنها مجوز» است فقط نظر سورس است.
- `src/debug` و `src/profile`: هر کدام همان `INTERNET` را برای ابزار توسعه تکرار می‌کنند. واریانت release پوشهٔ `src/release` ندارد، پس از سمت سورس اپ فقط main وارد release می‌شود. پلاگین‌ها جدا ادغام می‌شوند و این جمله آن ادغام را ثابت نمی‌کند.

مانیفست کتابخانهٔ کش‌شده در pub-cache (فهرست `.flutter-plugins-dependencies` تاریخ ۲۰۲۶-۱۱-۱۰ ۲۲:۵۰، Flutter 3.47.7) فقط به‌عنوان سهم احتمالی خوانده شد، نه اثبات ادغام. در `android/src/main` این‌ها گره `uses-permission` ندارند: `audioplayers_android` 5.3.0، `flutter_secure_storage` 9.2.4 (فقط `uses-sdk tools:overrideLibrary="androidx.security"`)، `jni` 1.1.0، `jni_flutter` 1.0.4+1، `purchases_flutter` 11.0.1، `share_plus` 12.0.2 (FileProvider و receiver با `exported=false`)، `url_launcher_android` 6.3.33 (فعالیت WebView با `exported=false`). `path_provider_android` 2.3.1 در این کش پوشهٔ کتابخانهٔ اندروید و مانیفست کتابخانه ندارد (پیاده‌سازی Dart/JNI است)؛ مانیفست example آن سهم اپ ما نیست. AAR وابستگی `com.revenuecat.purchases:purchases-hybrid-common:20.3.0` دانلود نشده و مانیفستش UNKNOWN است. مانیفست example پلاگین‌ها (از جمله INTERNET یا WAKE_LOCK نمونهٔ audioplayers) مانیفست این اپ نیست.

Azure ۱۰ نوامبر ۲۲:۴۳:۳۸ اروپا/لندن همچنان `401` / `CredentialUnavailableException` / `ChainedTokenCredential` است. این مرحله دوباره نپرسید و کلیپ نساخت. Q03 پرسیده نشد.

مانع‌های بعدی که فقط مالک باز می‌کند:

1. جای‌خالی ناشر تا ثبت شرکت. Q03 پرسیده نشود.
2. کلیپ‌های arrival و audit، تا اثبات F0. مدرک تازه همان `401` است.
3. مانیفست ادغام‌شدهٔ release هنوز UNKNOWN، تا وقتی SDK باشد و امضا یا نگهبان فعلی عوض نشود.
4. پیش‌نویس حقوقی هنوز مال نویسنده است. این مرحله آن را وارد محصول نکرد.
5. کلید امضای تولید نیست و ساخته نشود.
6. Q15 و Q17 بازند.
7. آمادهٔ Play نیست و تأیید حقوقی کامل نیست.

English: The profiles privacy box now says a child profile keeps a name and progress on the device, that there is no learner account and no upload of that profile to our server, that lesson-audio download can still contact the audio host, and that switching profiles is not a parent lock. It does not say no data is collected, only-on-device, or no third party. Legal drafts were not edited. Serial focused tests were +21. The merged release manifest was not generated: no Android SDK and no upload key. Merged permissions stay UNKNOWN. Cached plugin library manifests are not that proof. The 10 Nov 22:43:38 London Azure read is still 401. Not Play-ready.

## مرحلهٔ منبع — فهرست تصویر و مرور Q13، ۱۰ نوامبر ۲۰۲۶

پایه `5077252e2c3c303ba2aa345a21d143291b829c96`. کامیت این فهرست `15a92267f9feed524bc98e0b9af52d644125ca57`. والد محصول اعلان پروفایل `082600210fa5a5346786216851b57ca99d8ad226`. این مرحله کد محصول، پیش‌نویس `legal_screen`، آثار، صدا، و ساخت را عوض نکرد. آزمون این مرحله NOT-RUN. `+21` روی `082600210` و `+259 ~2 -4` روی `9daa52a988fd7abda121a759ff2a683d02694b2b` جدا ماندند. Azure ۱۰ نوامبر ۲۲:۴۳:۳۸ اروپا/لندن همچنان `401` است.

Q09: فهرست ساخته شد چون در سؤال‌های باز نوشته شده بود که فهرست منشأ ۱۸۳ تصویر هنوز نیست. جدول `docs/compliance/image_inventory_2026-11-10.tsv`، توضیح `docs/compliance/image_inventory_2026-11-10.md`. SHA-256 جدول `dba891018f5b352164055912b9327fe3e895b465134544482709a1efef281a85`. ۳۴۵ فایل ردیابی‌شده. ۱۸۳ = `places` ۹۷ + `portraits` ۵۵ + `spots` ۳۱. منشأ و مجوز هر فایل UNKNOWN. هیچ سربرگی حق‌نشر یا نام Grok نداشت. پاسخ مالک «Grok» و بعد «Grok Bot» برای یک فایل اثبات نشد. تأیید کتبی xAI در مخزن نیست. فونت‌ها در `docs/compliance/font_provenance.md` ماندند و دوباره کشف نشدند.

Q13: متن محصول میز ویزا، مسیر اقامت، و نقطهٔ نقشه از قبل «IAA (formerly OISC)» و ارجاع GOV.UK است و مشاورهٔ پرونده را از خود برمی‌دارد. گفت‌وگوی داستانی درس‌ها جدا از این ادعاهای محصول است و بازنویسی نشد. اصلاح تازه‌ای در کد لازم نبود. Q13 بسته نشد.

عبارت‌های مانده برای ادغام بعدی، نه برای این مرحله:

- `app/lib/features/legal/legal_screen.dart` خط ۶۰ و ۶۵: «or the OS service» و ماندن ضبط Shadowing روی دستگاه. در `speech_io.dart` هر دو `sttSupported` و `recordSupported` برای اپ نصب‌شده false است.
- همان فایل خط ۱۹۱–۱۹۳: «Created with Grok»، در حالی که پاسخ تکمیلی مالک Grok Bot است.
- `docs/compliance/compliance_report.md` خط ۱۳، ۹۴، ۹۸ و ۱۸۸ هنوز OISC را منبع جاری می‌نامد و خط ۹۸ به نشانی قدیمی `office-of-the-immigration-services-commissioner` لینک می‌دهد. دادهٔ محصول به `https://www.gov.uk/government/organisations/immigration-advice-authority` اشاره می‌کند.

تصمیم‌هایی که از همین رکوردها بسته نمی‌شوند: تأیید کتبی استفادهٔ تجاری Grok Bot، نوع حساب و تاریخ ساخت، بازبینی تصویری شباهت و لوگو، و پذیرش خود Q13. آمادهٔ Play نیست و تأیید حقوقی کامل نیست.

English: The inventory lists 345 tracked images and leaves every file's source and licence UNKNOWN. It does not clear Q09. The Q13 product strings already signpost IAA and say the app does not give immigration advice, so no product text was changed. Tests were not run. Legal drafts were not edited. Not Play-ready.

## مخاطب ۱۸+ — رابط پروفایل، ۱۰ نوامبر ۲۰۲۶، ۲۳:۱۴ لندن

مالک مخاطب نسخهٔ اول را فقط ۱۸+ اعلام کرد. رابط پروفایل: دکمه و دعوت ساخت پروفایل کودک برداشته شد؛ پروفایل تازه فقط بزرگسال است؛ متن می‌گوید این صفحه سن را بررسی نمی‌کند و تعویض پروفایل تأیید سن یا قفل والد نیست. پروفایل کودکِ موجود در فهرست می‌ماند، قابل انتخاب است، kind عوض نمی‌شود، پیشرفت جدا می‌ماند، و `kidBlocks` همان است. درس‌های خانواده و مهد دست نخورد. `legal_screen` دست نخورد.

آزمون: `cd app && flutter test -j 1 test/profiles_test.dart`. Flutter 3.47.7. نتیجه `+7`، همه قبول. لاگ: `profiles-18-2026-11-10.log`. `+21` روی `082600210` و `+259 ~2 -4` روی `9daa52a98` جدا ماندند. Q17 و DPIA بسته نشدند. مجوز ادغام‌شدهٔ release همچنان UNKNOWN است. Azure ۱۰ نوامبر ۲۲:۴۳:۳۸ لندن همچنان `401` است.

English: The owner set the first version's intended audience to 18+ only. The profile screen no longer creates a child profile and does not claim to verify age. Existing child profiles, their progress, and kid-mode route blocks remain. Q17 and the DPIA stay open. Focused profiles tests were +7. Not Play-ready.
