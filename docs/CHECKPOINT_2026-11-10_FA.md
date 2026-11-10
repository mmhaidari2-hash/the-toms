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
- پروفایل بزرگسال/کودک محلی است (`learner_profile.dart` خط ۳–۲۰). تعویض پروفایل قفل والد نیست (legal خط ۱۵۷–۱۵۸). مسیرهای کودک‌مخفی خط ۷۴–۸۵. جملهٔ مطلق «دادهٔ کودک جمع نمی‌شود» در `profiles_screen.dart` خط ۱۸۲ با پیش‌نویس حریم (ذخیرهٔ محلی و تماس دانلود) یکی نیست؛ برای فروشگاه پیش‌نویس حریم ملاک است.
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
