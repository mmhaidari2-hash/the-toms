# سند تحویل کار — New Life UK (The Toms)

تاریخ نخستین این سند: ۶ نوامبر ۲۰۲۶، صبح (کامیت `4e2046e69`).
مخزن: https://github.com/mmhaidari2-hash/the-toms
شاخهٔ کار: `fix/offline-audio-content` — **همیشه روی همین شاخه کار کنید.**

## از اینجا ادامه دهید — ۶ نوامبر ۲۰۲۶، بعد از جواب پریا و وضعیت صدا

رکورد معتبر ادامه این است، نه جست‌وجوی دوبارهٔ کار تمام‌شده:

- [نقطهٔ ثبت ۶ نوامبر ۲۰۲۶](CHECKPOINT_2026-11-06_FA.md) — چهار اصلاح قبلی، چرخش درس پریا (تمام)، و بخش «جواب خارج از متن و وضعیت صدا». t236u در سورس بسته شده است. چرخش را دوباره نسازید.
- نوک مجاز همان `origin/fix/offline-audio-content` است. کامیت‌های `51754c98b`، `f65208064`، `42ac8ee96`، `8cfbe9e89`، `555884785` و `171a75cdc` از قبل نیا هستند. دوباره ادغام، cherry-pick، squash یا اعمال نکنید.
- SHA سورس را از `.last_build_id` پیش‌نمایش حدس نزنید. پیش‌نمایش ساعت ۱۳:۲۱ با HEAD فعلی یکی نیست و در این مرحله منتشر نشد.
- بخش‌های «کارهای در حال اجرا» و «انجام‌شده تا صبح ۶ نوامبر» پایین همین فایل، عکس لحظهٔ صبح‌اند و وضعیت فعلی را ثابت نمی‌کنند.
- مجموعهٔ کامل روی `9daa52a988fd7abda121a759ff2a683d02694b2b`: `+259 ~2 -4`، خروج ۱. چهار شکست کلیپ غایب‌اند (arrival و سه آزمون audit). `+242 ~2 -10` و `+220 ~2 -16` نتیجه‌های قدیمی‌ترند، نه این SHA. این عدد تاریخی است و پذیرش مرورگر پایین آن را سبز یا آمادهٔ Play نمی‌کند.
- بررسی زندهٔ Azure در ۶ نوامبر ۱۸:۲۵ لندن به ورود حساب نرسید (`401` / `CredentialUnavailableException`). تا وقتی مالک `az login` نکند، SKU و سهمیهٔ F0 اثبات نشده و کلیپ تازه ساخته نمی‌شود. جزئیات در نقطهٔ ثبت است.
- پذیرش یک‌بارهٔ مرورگر محلی، بخش «پذیرش مرورگر محلی — سه مسئلهٔ پریا» در نقطهٔ ثبت: ساخت تازهٔ `--release --csp --no-web-resources-cdn --no-wasm-dry-run` بدون dart-define، از درخت `c2a81fa6d` (Dart برابر `9daa52a98`)، فقط روی `http://127.0.0.1:7358/#/chat/l1_u43_1`. آب‌نبات، کمک، زعفران، و نپریدن صفحه در چرخش PASS. املای نزدیک و پیش‌نویسِ نفرستاده NOT-RUN. بنر خطای صدا دیده نشد و عمداً ساخته نشد. پیش‌نمایش منتشر نشد.
- ۱۰ نوامبر ۲۰۲۶: واقعیت‌های حریم، فروشگاه و مانع‌ها در [نقطهٔ ثبت ۱۰ نوامبر](CHECKPOINT_2026-11-10_FA.md) است. از درخت `51d67f6d` خوانده شد. Q03 دوباره پرسیده نشد. `+259 ~2 -4` هنوز تاریخی است.
- همان شب، مرحلهٔ کد راهنمای میکروفون: اپ نصب‌شده دیگر تشخیص گفتار یا ضبط اندروید را وعده نمی‌دهد؛ متن وب جدا ماند. پیش‌نویس حقوقی عوض نشد. آزمون `flutter test -j 1 test/speaking_test.dart` نتیجهٔ `+12`. Azure والد در ۲۲:۴۳:۳۸ لندن دوباره `401` بود و کلیپ ساخته نشد.
- همان شب، اعلان غیرحقوقی پروفایل کودک در `profiles_screen.dart` دیگر نمی‌گوید داده جمع نمی‌شود. کامیت سورس `082600210fa5a5346786216851b57ca99d8ad226`، والد `8bf230814b76975d95e460b0cb2e7f0aecfcdeee`. ذخیرهٔ محلی نام و پیشرفت، نبودن حساب یادگیرنده و نفرستادن پروفایل به سرور خودمان، تماس ممکن با میزبان صدا، و این‌که تعویض پروفایل قفل والد نیست، جدا نوشته شد. پیش‌نویس `legal_screen` دست نخورد. آزمون سریال `cd app && flutter test -j 1 test/speaking_test.dart test/profiles_test.dart test/messages_flow_test.dart test/priya_shop_layout_test.dart` نتیجهٔ `+21`. مجموعهٔ `+259` تکرار نشد. مانیفست ادغام‌شدهٔ release ساخته نشد: `ANDROID_HOME` خالی است و کلید امضا نیست. وضعیت مجوز ادغام‌شده UNKNOWN ماند. جزئیات در نقطهٔ ثبت ۱۰ نوامبر است.

English: Continue from [the 6 Nov 2026 checkpoint](CHECKPOINT_2026-11-06_FA.md) and then [the 10 Nov facts record](CHECKPOINT_2026-11-10_FA.md). The Priya rotation work and the candy-reply fix are already recorded. Do not reapply those commits. The preview was not republished. The sections below are the morning snapshot. Old full-suite counts are not a new pass. The local browser check is in the 6 Nov checkpoint: candy, help, saffron, and rotation passed on a fresh unreleased web build; the typo and an unsent draft were not run; no audio-failure notice was seen or forced. The 10 Nov record has the facts audit, the microphone-copy correction, and the later child-profile notice correction. Those corrections are not a new full-suite pass. The merged release manifest is still UNKNOWN.

## قوانین مهم مالک
- **هرگز** شاخه‌های `main` و `source` و نسخهٔ زندهٔ سایت را تغییر ندهید و چیزی منتشر نکنید.
- **بعد از هر مرحله** commit و push کنید تا کار از بین نرود.
- نام و ایمیل git: `mmhaidari2-hash <317994101+mmhaidari2-hash@users.noreply.github.com>`
- همهٔ متن‌های رو‌به‌کاربر باید فارسی + انگلیسی باشند.
- پاسخ‌های کاربر را به فارسی بنویسید و تصمیم‌ها را یکی‌یکی بپرسید.
- صداها فقط با سهمیهٔ **رایگان ماهانهٔ Azure (F0)** ساخته شوند؛ استفاده از کلید پولی S1 ممنوع است مگر با اجازهٔ صریح مالک.
- ترجمه‌ها فقط با ابزار آفلاین رایگان (NLLB)، نه سرویس پولی.
- آثار هنری، ساختار درس‌ها، پیشرفت ذخیره‌شده و مسیرهای فعلی حفظ شوند.
- من وکیل نیستم؛ در پرونده‌های حقوقی هرگز «تأیید کامل» اعلام نکنید.

## ساختار پروژه
- اپ Flutter در `app/` (وب + اندروید). SDK فلاتر: نسخهٔ 3.47.7.
- داده‌ها در `app/assets/data/*.json` و تولیدکننده‌هایشان در `app/tool/**`.
- آزمون‌ها: `cd app && flutter test -j 1` (به‌خاطر حافظهٔ کم، موازی نکنید).
- ساخت وب از یک کپی rsync بدون فایل‌های `*.tmp` و `*.az.mp3` انجام می‌شود.
- ساخت بازبینی (همهٔ درس‌ها باز): `--dart-define=PREVIEW_UNLOCK=true`؛ پخش صدا از گیت‌هاب: `--dart-define=PREVIEW_AUDIO_BASE=https://raw.githubusercontent.com/mmhaidari2-hash/the-toms/fix/offline-audio-content/app/assets/audio/`. هر دو فقط برای بازبینی‌اند و در نسخهٔ واقعی خالی‌اند.

## کارهای در حال اجرا (پس‌زمینه) — عکس لحظهٔ صبح ۶ نوامبر، تأییدنشده

این فهرست وضعیت صوت و ترجمه را در زمان سند صبح ثبت کرده است. ادامهٔ کار نباید آن را گزارش فعلی بداند و نباید کار ثبت‌شده در نقطهٔ ثبت را دوباره بسازد.
1. **ساخت صدا (TTS):** `app/tool/render_voices.py` با متغیرهای `RENDER_THREADS=1 RENDER_CHAR_CAP=480000 RENDER_FRESH_SINCE=<epoch>` و کلید F0. دفتر حساب: `app/tool/audit/tts_month.json` (سقف ۴۸۰ هزار نویسه در ماه). حدود ۳۳ هزار کلیپ مانده؛ با سهمیهٔ رایگان حدود ۳ ماه طول می‌کشد. کلیپ‌های تازه (اشتباهات رایج و Life Skills) اولویت دارند. خطاها در اجرای بعدی دوباره ساخته می‌شوند. `autosave_audio.sh` هر چند دقیقه کلیپ‌های تازه را commit می‌کند.
2. **ترجمه:** `app/tool/i18n/translate.py <lang>` با مدل آفلاین NLLB (`/workspace/mt/onmt13` و `sentencepiece.bpe.model`). صف: prs (تا ۳۰٬۰۰۰ از ۳۲٬۵۶۴ ذخیره شده)، uk (در جریان)، ckb، pa، tr، bn، es، pt، zh، zh-Hant، ti. بعد از اتمام هر زبان: حذف از `tool/i18n/hold.json`، اجرای `build_tables.py`، کنترل کیفیت `tool/qa/qa_translate.py`، آزمون `test/lang_test.dart` و `test/onb_lang_test.dart`، سپس commit فقط فایل‌های i18n.

## انجام‌شده تا صبح ۶ نوامبر (عکس لحظه؛ همه روی شاخه)

این فهرست تا کامیت `4e2046e69` است. اصلاح‌های بعدازظهر در [نقطهٔ ثبت](CHECKPOINT_2026-11-06_FA.md) آمده‌اند و اینجا تکرار نمی‌شوند.
- اشتباهات رایج فارسی‌زبان‌ها: `assets/data/mistakes.json`، مسیر `/mistakes` (commit 7de88729).
- آمادگی IELTS Life Skills: `assets/data/lifeskills.json`، مسیر `/lifeskills`، هشدار قانون B2 از ۲۶ مارس ۲۰۲۷ (commit c6975835).
- اشتراک گواهی به‌صورت تصویر + دعوت از دوست (بدون ردیابی، پنهان در پروفایل کودک، توضیح در سیاست حریم خصوصی): `lib/features/shared/share.dart` (commit 4cfb64a9).
- مرور ترکیبی هر کلاس گرامر: `lib/features/grammar/review_screen.dart` (commit 21af01e2).
- Q10: منشأ فونت‌ها در `docs/compliance/font_provenance.md` (commit 1a66ce8b).
- Q11: مدرک Azure TTS در `docs/compliance/azure_tts_evidence.md` — حساب شخصی مالک (commit ba9e2da4).
- Q12: بازنویسی هر ۱۵۱ سؤال رانندگی و Life in the UK در قالب صحنه‌های خانواده (واقعیت‌ها، گزینه‌ها، شناسه‌ها و صداها دست‌نخورده) (commit 68b3a8a8).
- سند سؤال‌های باز: `docs/compliance/OPEN_QUESTIONS_FA.md` (Q43/Q44/Q45/Q46 ثبت شد).

## نکات برای ادامهٔ کار روی ماشین دیگر
- **کلید Azure F0** در یک credential store محلی ذخیره است و قابل انتقال نیست؛ مالک باید خودش کلید را به ابزار بعدی بدهد.
- **مدل NLLB** (`/workspace/mt/onmt13`) فایل محلی است و باید روی ماشین جدید دانلود شود.
- فرایندهای پس‌زمینه (render، translate) روی ماشین فعلی‌اند؛ روی ماشین جدید باید دوباره اجرا شوند. هر دو از محل توقف ادامه می‌دهند (checkpoint دارند).
- نسخهٔ بازبینی: https://mmhaidari2-hash.github.io/the-toms-preview/ (مخزن `the-toms-preview`). مشاهدهٔ ۶ نوامبر بعدازظهر در نقطهٔ ثبت است: خروجی سایت کامیت `fd32df7992` است و SHA سورسش معلوم نیست. این نشانی مجوز تغییر آن مخزن یا سایت نیست.
