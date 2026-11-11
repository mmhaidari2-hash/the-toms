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

کامیت `af6e61ec6549934121fc48777328f753df792a22`. مالک مخاطب نسخهٔ اول را فقط ۱۸+ اعلام کرد. رابط پروفایل: دکمه و دعوت ساخت پروفایل کودک برداشته شد؛ پروفایل تازه فقط بزرگسال است؛ متن می‌گوید این صفحه سن را بررسی نمی‌کند و تعویض پروفایل تأیید سن یا قفل والد نیست. پروفایل کودکِ موجود در فهرست می‌ماند، قابل انتخاب است، kind عوض نمی‌شود، پیشرفت جدا می‌ماند، و `kidBlocks` همان است. درس‌های خانواده و مهد دست نخورد. `legal_screen` دست نخورد.

آزمون: `cd app && flutter test -j 1 test/profiles_test.dart`. Flutter 3.47.7. نتیجه `+7`، همه قبول. لاگ: `profiles-18-2026-11-10.log`. `+21` روی `082600210` و `+259 ~2 -4` روی `9daa52a98` جدا ماندند. Q17 و DPIA بسته نشدند. مجوز ادغام‌شدهٔ release همچنان UNKNOWN است. Azure ۱۰ نوامبر ۲۲:۴۳:۳۸ لندن همچنان `401` است.

English: The owner set the first version's intended audience to 18+ only. The profile screen no longer creates a child profile and does not claim to verify age. Existing child profiles, their progress, and kid-mode route blocks remain. Q17 and the DPIA stay open. Focused profiles tests were +7. Not Play-ready.

## اصلاح واقع‌بینانهٔ متن موجود legal_screen

`legal_screen.dart` فقط در جمله‌های ناسازگار با کد عوض شد. اپ نصب‌شده گفتار را رونویسی یا ضبط نمی‌کند و تشخیص سیستم‌عامل ندارد. گفتار به متن فقط در مرورگر و در صورت وجود همان مرورگر اختیاری است. مخاطب نسخه ۱۸+ است، سن بررسی نمی‌شود، پروفایل تازه بزرگسال است، و پروفایل کودک موجود با محدودیت می‌ماند. جملهٔ «Created with Grok» و ادعای مالکیت یا اصالت هر تصویر برداشته شد. جای‌خالی ناشر ماند. تأیید حقوقی، DPIA، Q17 و Q09 بسته نشد. پیش‌نویس چت فروشگاه وارد محصول نشد.

`docs/compliance/compliance_report.md` فقط نام و پیوند قدیمی OISC را به IAA (formerly OISC) و نشانی `immigration-advice-authority` عوض کرد. برچسب تاریخی «done» ترخیص تازه نیست.

آزمون: `cd app && flutter test -j 1 test/legal_test.dart`. نتیجه `+3`. لاگ: `legal-accuracy-2026-11-10.log`. `+7` روی `af6e61ec6` و `+21` روی `082600210` جدا ماندند.

English: The existing legal screen now matches installed-app speech limits, the 18+ intended audience, adult-only new profiles, and retained child-profile limits. It no longer gives a blanket Grok or ownership line. Focused legal tests were +3. Not legal approval.

## مانیفست ادغام‌شدهٔ release

SDK رسمی رایگان نصب شد: Android SDK 36، build-tools 36.0.0، platform-tools 37.0.1، cmdline-tools. `ANDROID_HOME=$HOME/android-sdk`. کلید امضا ساخته نشد و `ALLOW_DEBUG_SIGNED_RELEASE` ست نشد. نگهبان `build.gradle.kts` عوض نشد.

دستور: از `app/android` با Gradle 9.3.1 همان `gradle-wrapper.properties`: `:app:processReleaseManifest`. نتیجه: `BUILD SUCCESSFUL`. این assemble یا bundle نیست، پس نگهبان امضا این وظیفه را نگرفت. APK/AAB ساخته نشد. `versionCode`/`versionName` در این خروجی `1`/`1.0` است چون Gradle مستقیم اجرا شد؛ نسخهٔ pubspec `1.1.0+5` است و این اعداد نسخهٔ فروشگاه نیستند.

گره‌های `uses-permission` در `app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`، واریانت release:

- `android.permission.INTERNET` از `src/main` خط ۳. همان نام در `purchases:11.0.1` و `transport-backend-cct:3.1.8` هم بود و ادغام شد.
- `android.permission.ACCESS_NETWORK_STATE` از `com.revenuecat.purchases:purchases:11.0.1`.
- `com.android.vending.BILLING` از `com.android.billingclient:billing:9.1.0`.
- `app.thetoms.newlifeuk.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` از `androidx.core:core:1.17.0`، همراه یک گره `permission` همان کتابخانه.

پرداخت در کد هنوز خاموش است؛ مجوز BILLING به‌خاطر وابستگی کتابخانه داخل مانیفست release آمده است. این بند وضعیت پیش از حذف همان مجوز است. بخش بعدی را ببینید. این باینری فروشگاه نیست.

English: The release merged manifest was produced by processReleaseManifest. It is not a signed APK. INTERNET comes from the app source. ACCESS_NETWORK_STATE, BILLING, and the AndroidX exported-receiver permission come from libraries. The upload key is still absent.

## مجموعهٔ سریال روی درخت legal

دستور: `cd app && flutter test -j 1`. درخت Dart `8785e94c4ec634fb49ded445101e4d7812caef82` (سند مانیفست `c365676e5` فقط سند است). نتیجه: `+261 ~2 -4`، خروج ۱، زمان آزمون ۳۸:۰۳. لاگ: `full-suite-2026-11-10.log`.

چهار شکست همان کمبود صداست، نه رگرسیون متن: arrival کلیدهای `087cc7d72afdb4af`، `30d6184f7e89755f`، `356cbff6b133709e`، `41f7ba1b5bec01ca`، `aff7622e07e6c48a`، `d8460a4b3cebf583`، `da6a5e64cdb062a6`؛ و سه آزمون audit از جمله شمار کلیپ `22209` که از ۳۰۰۰۰ بیشتر نیست. آزمون‌ها ضعیف نشدند و کلیپ ساخته نشد. این سبز نیست. `+259 ~2 -4` روی `9daa52a98`، `+21` روی `082600210` و `+7` روی `af6e61ec6` تاریخی و جدا هستند.

English: The full serial suite on 8785e94c4 was +261 ~2 -4, exit 1. The four failures are the known missing clips. Not a green suite and not Play-ready.

## حذف BILLING از ساخت رایگان

`Billing.available` فقط وقتی روشن است که `PremiumConfig.betaFree` نادرست باشد، `RC_GOOGLE_KEY` پر باشد و پلتفرم اندروید باشد. پیش‌فرض بتا `betaFree = true` و کلید خالی است، پس `Billing.init` به RevenueCat وصل نمی‌شود. وابستگی `purchases_flutter` ماند.

در `app/android/app/src/main/AndroidManifest.xml` یک گره `uses-permission` برای `com.android.vending.BILLING` با `tools:node="remove"` اضافه شد. نگهبان امضا عوض نشد.

دوباره `:app:processReleaseManifest` با Gradle 9.3.1: `BUILD SUCCESSFUL`. APK/AAB ساخته نشد. در مانیفست ادغام‌شدهٔ release این سه `uses-permission` ماندند: `INTERNET`، `ACCESS_NETWORK_STATE`، `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. رشتهٔ `com.android.vending.BILLING` در فایل ادغام‌شده نیست. گزارش ادغام: همان مجوز از `billing:9.1.0` با برچسب `REJECTED` رد شد، چون `tools:node` از مانیفست اپ آمد. لاگ: `billing-manifest-2026-11-11.log`.

پیش از ساخت پولی این خط حذف شود، و `betaFree` نادرست و کلید عمومی RevenueCat گذاشته شود. مجموعهٔ `+261 ~2 -4` همچنان مال درخت `8785e94c4` است و اینجا تکرار نشد.

English: The free build strips only the Play Billing permission. The purchase scaffold stays. Delete the remove-node before a paid build. The historical suite result stays on 8785e94c4.

## دادهٔ محلی — ۱۱ نوامبر ۲۰۲۶

این مرحله Azure، امضا، ناشر و بازنویسی حقوقی را باز نکرد. وابستگی‌ها بررسی نشدند.

بازتولید روی پوشهٔ موقت، قبل از اصلاح: جعبهٔ رمزشده با کلید دیگر و `crashRecovery` پیش‌فرض Hive باز شد، پیام `Recovering corrupted box.` آمد، فایل از ۱۲۹ بایت به ۰ رسید و کلید `p:child_legacy` نبود. با `crashRecovery: false` همان باز کردن `HiveError: Wrong checksum` داد و طول فایل ماند.

اصلاح: `HiveProgressStore.openAt` همیشه `crashRecovery: false` است. کلید نادرست یا کلید گم‌شده فایل را عوض نمی‌کند و کلید تازه نوشته نمی‌شود. جعبهٔ بدون رمز قدیمی اول در `.hive.kept` کپی می‌شود، بعد به جعبهٔ رمزشده با همان نام کلید `nluk_progress_aes_v1` منتقل می‌شود، و فقط بعد از خواندن دوبارهٔ مقدارها نسخهٔ موقت پاک می‌شود. اگر انتقال شکست بخورد، نسخهٔ موقت برمی‌گردد. اگر فایل رمزشده باشد و کلید خوانده نشود، `ProgressStoreLocked` پرتاب می‌شود و `ProgressLockedScreen` متن انگلیسی و فارسی نشان می‌دهد که چیزی پاک نشده است. دکمهٔ پاک کردن ندارد.

پشتیبان: در AOSP برچسب `android-15.0.0_r36`، `BackupEligibilityRules` تغییر `IGNORE_ALLOW_BACKUP_IN_D2D` (۱۸۳۱۴۷۲۴۹) را از targetSdk ۳۱ برای اپ غیرسیستمی روشن می‌داند. این اپ targetSdk ۳۶ است (`FlutterExtension` مقدار ۳۶). پس `allowBackup="false"` پشتیبان ابری را می‌بندد و برای ساخت غیراشکال‌زدایی، `adb backup` را هم می‌بندد، اما انتقال دستگاه را نه. `FullBackup.java` بدون قاعده «همه چیز را کپی می‌کند». قاعدهٔ جدید هر دامنه را در `cloud-backup` و `device-transfer` مستثنی می‌کند. مطابقت AOSP روی مسیر پوشهٔ دامنه است و فرزندان را صف نمی‌کند. این انتقال واقعی روی گوشی اجرا نشد.

آزمون: `cd app && flutter test -j 1 test/progress_at_rest_test.dart`. نتیجه: `+7`، همه قبول. کلید نادرست، کلید گم‌شده، انتقال جعبهٔ قدیمی، برگرداندن `.kept`، جعبهٔ رمزشدهٔ خالی روی نسخهٔ موقت، قاعدهٔ XML، و متن دوزبانه. لاگ این اجرا در مخزن ذخیره نشد.

`:app:processReleaseManifest` با Gradle 9.3.1 و SDK موجود: `BUILD SUCCESSFUL`. APK/AAB ساخته نشد. `ALLOW_DEBUG_SIGNED_RELEASE` ست نشد. مانیفست ادغام‌شده `android:allowBackup="false"` و `android:dataExtractionRules="@xml/data_extraction_rules"` دارد. `com.android.vending.BILLING` در همان فایل نیست. مجموعهٔ `+261 ~2 -4` مال `8785e94c4` است و تکرار نشد.

مانع‌هایی که این مرحله باز نکرد: ورود Azure و کلیپ‌های غایب، کلید امضای اصلی، جای‌خالی ناشر، Q09 و Q17 و DPIA، IndexedDB بدون رمز در وب، و بازنشانی عمدی داده وقتی کلید دستگاه واقعاً از بین رفته باشد. برای آن حالت دکمهٔ پاک کردن اضافه نشد.

English: A wrong Hive key used to truncate the progress file under Hive's default crash recovery. The open path now refuses to truncate or replace the key, migrates a readable plaintext box, and shows a bilingual notice when an encrypted file cannot be unlocked. Device-to-device transfer is excluded because allowBackup=false does not apply to it on targetSdk 36. Focused test +7 on 7fb47b4ab. processReleaseManifest succeeded. The historical full suite stays +261 ~2 -4 on 8785e94c4. No Azure work and no clearance.

## دنبالهٔ همان مرحله — قطع مهاجرت

روی کد `7fb47b4ab`، قبل از این اصلاح، فیکسچر جدا این حالت را ساخت: `.hive.kept` شامل `ADULT_MARKER` و `CHILD_PROGRESS_MARKER`، و جعبهٔ رمزشده فقط `p:adult`. `openAt` جعبه را غیرخالی دید، `.kept` را پاک کرد، و `readOf('child_legacy')` برابر `null` بود. این شکستِ آزمون بود، نه یک استثنای گرفته‌شده داخل انتقال.

اصلاح: اگر `.kept` هست، مقدارهای غیرخالی‌اش با جعبهٔ بازشده مقایسه می‌شود. مقدار خالی شمرده نمی‌شود، چون نویسندهٔ انتقال هم آن را نمی‌نویسد. اگر یکی کم باشد، جعبهٔ ناتمام پاک می‌شود، نسخهٔ کامل برمی‌گردد، و با همان کلید از نو نوشته می‌شود. کلید تازه ساخته نمی‌شود. اگر همه باشند، فقط `.kept` پاک می‌شود.

`keys.readKey()` اگر به‌جای `null` استثنا بدهد، از جمله `PlatformException`، همان‌جا `ProgressStoreLocked` می‌شود. `main` فقط همین نوع را به صفحهٔ دوزبانه می‌برد. پیش از این، استثنا از `await` رد می‌شد. در این مسیر هیچ فایلی کپی یا پاک نمی‌شود و `writeKey` صدا نمی‌شود.

حد: اگر خودِ فایل رمزشده چک‌سام را رد کند و باز نشود، از `.kept` جایگزین نمی‌شود. هر دو فایل می‌مانند و صفحهٔ قفل می‌آید. این گم شدنِ بی‌صدا نیست. انتقال واقعیِ گوشی و مجموعهٔ کامل تکرار نشد.

آزمون: `cd app && flutter test -j 1 test/progress_at_rest_test.dart`. نتیجهٔ بعد از اصلاح: `+10`، خروج ۰. `+7` همان نتیجهٔ `7fb47b4ab` است و این عدد جای آن را نمی‌گیرد. لاگ: `progress-at-rest-interruption.log`.

English: On 7fb47b4ab a nonempty partial encrypted box deleted the complete .kept copy and the missing child entry was null. The open path now restores that copy unless every non-empty kept entry is already present, and it does not rotate the key. A platform exception from readKey becomes ProgressStoreLocked before any file change, so the bilingual screen can catch it. A checksum-invalid hive file is not replaced from .kept. New focused result +10. The earlier +7 stays on 7fb47b4ab.

## وابستگی زمان اجرا — ۱۱ نوامبر ۲۰۲۶

نقطهٔ شروع `ecb0860afbd05d22e683a9bbb63c6106b06529ee`. مرحلهٔ دادهٔ محلی دوباره باز نشد.

روش: `app/pubspec.lock` (۱۰۷ بسته؛ ۵ تای SDK با نسخهٔ `0.0.0` جدا). بستار اجرا از `dart pub deps --json`، بدون `flutter_lints`/`lints` که فقط dev هستند. Android: `gradle :app:dependencies --configuration releaseRuntimeClasspath` آفلاین، ۸۲ مختصاتِ حل‌شده، هر کدام یک نسخه. پرسش دسته‌ای `POST https://api.osv.dev/v1/querybatch` برای نسخهٔ قفل‌شده و جدا برای «هر توصیهٔ تاریخی این نام». کنترل: PyPI `jinja2` 2.4.1 و Maven `log4j-core` 2.14.1 هر دو توصیه برگرداندند، پس خالی بودن نتیجه خطای API نیست. موتور Flutter با commit `deb287481e3ce9468f3434937ced4240a70539ca` هم خالی بود. فهرست GitHub برای `dart-lang/sdk` جدا خوانده شد چون OSV اکوسیستم Pub خودِ SDK را با نسخهٔ 3.13.5 پوشش نمی‌دهد.

بستهٔ قفل‌شده داخل بازهٔ آسیب‌دیده نبود. تنها توصیهٔ Pub روی نام `http` است: GHSA-4rgh-jx4f-qfcq / CVE-2020-35669، اصلاح در `0.13.3`؛ قفل `1.6.0` است. Maven تاریخی و خارج از نسخهٔ حل‌شده: `play-services-basement` GHSA-cm6r-892j-jv2g تا قبل از `18.0.2` (حل‌شده `18.9.0`)، `gson` GHSA-4jrv-ppp4-jm57 تا قبل از `2.8.9` (حل‌شده `2.10.1`)، `kotlin-stdlib` GHSA-2qp4-g3q3-f92w و GHSA-cqj8-47ch-rvvq تا قبل از `1.6.0` و `1.4.21` (حل‌شده `2.4.0`).

`dart pub outdated --json`: ۳۵ بسته latest جدیدتر دارند. این به‌تنهایی آسیب‌پذیری نیست و ارتقای عمده انجام نشد. از جمله `flutter_secure_storage` 9.2.4 در برابر 11.2.0.

مورد تأییدشده: [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp). Dart پایدار قبل از `3.13.7` و Flutter پایدار قبل از `3.47.8`. شدت high. `dart:io` روی Android و Windows و لینوکسِ بدون بستهٔ به‌روز CA، به CA میانی لو رفتهٔ eMudhra اعتماد می‌کند. وب و iOS و macOS در خودِ توصیه خارج‌اند. این درخت Flutter 3.47.7 / Dart 3.13.5 بود. اصلاح کمینه: کف `pubspec.yaml` برابر `^3.13.7`. Flutter 3.47.8 همان Dart 3.13.7 را دارد (`releases_linux.json`). 3.47.9 هم همان Dart را دارد و انتخاب نشد. APK ساخته نشد؛ باینری نصب‌شده تا بازسازی با این SDK همان آسیب را دارد.

حد: OSV ممکن است دیر به‌روز شود. classpath اندروید حضور در APK بعد از R8 نیست. SDK در مخزن vendored نیست. تأیید کامل نیست.

English: Locked Pub and resolved Android runtime versions were not inside OSV affected ranges. The one confirmed issue is GHSA-frr6-h895-5pxp in Dart 3.13.5 / Flutter 3.47.7. The pubspec floor is now Dart ^3.13.7, which Flutter 3.47.8 provides. Newer package versions were not treated as vulnerabilities. No release binary was built.

## پیش‌نویس HTML حریم — ۱۱ نوامبر ۲۰۲۶

جست‌وجو: تنها HTML مخزن `app/web/index.html` است و پوستهٔ اپ است، نه سیاست حریم. عوض نشد. `privacy-store-facts-2026-11-10.md` یادداشت واقعیت است و بخش‌هایی از آن (جملهٔ پروفایل، مانیفست UNKNOWN، رمز قبل از اصلاح قطع مهاجرت) کهنه است. متن داخل `legal_screen.dart` و شرایط استفاده بازنویسی نشد.

فایل تازه: `docs/compliance/privacy-android-18-draft.html`. برچسب انگلیسی و فارسی «برای انتشار نیست». دامنه فقط ساخت اندروید ۱۸+ رایگان است. مرورگر بیرون از اطلاعیه است. جای‌خالی نام، نشانی، ایمیل، ICO و نشانی عمومی دیده می‌شود. سن بررسی نمی‌شود؛ پروفایل تازه بزرگسال است و پروفایل کودک موجود می‌ماند. رمز و استثنای پشتیبان گواهی امنیت کامل نیست. اپ اندروید رونویسی و ضبط ندارد. پرداخت در این ساخت گرفته نمی‌شود و `Purchases.configure` با پرچم رایگان و کلید خالی صدا نمی‌شود؛ پیش‌نویس نمی‌گوید کتابخانهٔ بسته‌شده هرگز داده نمی‌فرستد. حذف جعبهٔ پیشرفت را پاک می‌کند و کلید رمز و کش درس را پاک نمی‌کند. مهلت پاسخ و صندوق تماس وعده نشده است.

این فایل تأیید حقوقی، آمادگی Play، یا نشانی عمومی نیست. Q03، میزبان عمومی، Q09، Q13، Q17 و DPIA، امضا، کلیپ‌های غایب، و بازسازی باینری با Flutter 3.47.8+ باز ماندند.

English: No privacy HTML existed. The new file is a marked draft for the intended free Android 18+ build. In-app terms were not overwritten. It does not claim legal clearance or a public URL.

## پیش‌نویس نفرستاده و املای نزدیک — ۱۱ نوامبر ۲۰۲۶

NOT-RUN پذیرش مرورگر ۶ نوامبر («yes pleas» و پیش‌نویس در فیلد) نقص ثبت‌شده نبود. این مرحله همان دو رفتار را از کد فعلی سنجید و آب‌نبات، کمک، چرخش، و چیدمان را تکرار نکرد.

املا: `_near` در `conversation_engine.dart` برای واژهٔ پنج‌حرفی به بالا یک ویرایش را می‌پذیرد. «yes pleas» مثل «yes please» شاخهٔ n2 فروشگاه است. «yes ples» چهار حرف است و قبول نمی‌شود. در ویجت، فرستادن «yes pleas» از همان `TextField` خط کاربر را نگه می‌دارد و پریا می‌گوید «Of course! What are you looking for?»، نه راهنمای «You mean».

پیش‌نویس: متن تا ارسال فقط در `TextEditingController` همان چت است. اینسِت صفحه‌کلید در آزمون، تعویض نقش، و `push` به چت دیگر آن را حباب نمی‌کند و در پیشرفت هیچ پروفایلی نمی‌نویسد. برگشت به همان چت متن را در فیلد نگه می‌دارد. `go` به خانه ویجت را می‌بندد؛ پیش‌نویس ذخیره نمی‌شود و جملهٔ فرستاده‌شده هم ساخته نمی‌شود.

نقص: چت زیر صفحهٔ پروفایل زنده می‌ماند. تعویض به پروفایل کودک، متن بزرگسال را در فیلد می‌گذاشت. ارسال بعدی همان متن را برای پروفایل فعال می‌فرستاد. اصلاح: با عوض شدن `activeId` فیلد پاک می‌شود و `_send` صدا نمی‌شود. تاریخچهٔ همان صحنه دست نخورده است. پروفایل کودک موجود حذف نشد.

آزمون: `cd app && flutter test -j 1 test/priya_shop_reply_test.dart test/chat_draft_typing_test.dart` با Flutter 3.47.8 و Dart 3.13.7. نتیجهٔ بعد از اصلاح: `+7`. این ویجتِ بدون مرورگر است. مرورگر واقعی، صفحه‌کلید فیزیکی، و گوشی NOT-RUN ماندند. لاگ: `chat-draft-typing-2026-11-11.log`.

English: The unsent shop line stayed in the composer across a profile switch and the next send would belong to the profile then active. The composer now clears when the active profile id changes, and that clear does not send. Role swap and another character's chat do not send it. “yes pleas” continues the lesson; “yes ples” does not. The check is a headless widget test, not a browser or a device.

## پیش‌نویس Data safety — ۱۱ نوامبر ۲۰۲۶

جست‌وجو: فایل `data_safety` در مخزن و در `/workspace/play_listing/` نبود. ردیف گزارش انطباق که آن مسیر گم‌شده را «انجام‌شده» می‌گفت به `docs/compliance/play-data-safety-draft.md` اشاره می‌کند و دیگر انجام‌شده نیست. HTML حریم `7a5982c0`، شرایط استفاده، و متن فروشگاه بازنویسی نشد.

نقشه ده ردیف است، نه فرم کامل. تعریف جمع‌آوری و اشتراک از صفحهٔ رسمی Play است. گیت‌هاب در صفحهٔ Pages می‌گوید IP بازدیدکننده برای امنیت ثبت و ذخیره می‌شود؛ بیانیهٔ حریم (تاریخ اجرا ۲۷ آوریل ۲۰۲۶) مدت ثابت این لاگ و قرارداد پردازشگرِ این ناشر را نمی‌دهد. `purchases_flutter` 11.0.1 داخل اپ است و `Purchases.configure` در این ساخت صدا نمی‌شود. صفحهٔ RevenueCat برای SDKِ در حال استفاده است و به این ساختِ پیکربندی‌نشده چسبانده نشد. ضبط بسته انجام نشد. Q03 و نشانی سیاست و DPIA باز ماندند. کنسول Play باز نشد.

English: No Data safety file existed. The new map is a ten-row draft for the free Android 18+ build and is not for submission. Local progress is not “no data collected”, and a source reading is not a packet capture.
