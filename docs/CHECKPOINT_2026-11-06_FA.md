# نقطهٔ ثبت — ۶ نوامبر ۲۰۲۶، بعدازظهر

این رکورد ادامه است. از همین فایل و از نوک `origin/fix/offline-audio-content` شروع کنید. کار تمام‌شدهٔ زیر را دوباره نسازید، ادغام نکنید و cherry-pick نکنید.

English: Start here and from the latest `origin/fix/offline-audio-content`. Do not reapply the finished commits below.

ادامهٔ همان روز، گزارش چرخش درس پریا، در بخش «درس پریا — چرخش و بنر صدا» پایین همین فایل است. آن بخش تمام است. بعد از آن، بخش «جواب خارج از متن و وضعیت صدا» را بخوانید. t236u دیگر باز نیست.

English: The Priya shop rotation section is done. The later alternate-reply and audio-status section is the next record. Do not rediscover either.

ورود از [سند تحویل](HANDOVER_FA.md). سؤال‌های باز حقوقی همچنان در [OPEN_QUESTIONS_FA.md](compliance/OPEN_QUESTIONS_FA.md) است. این نقطه آن دفتر را نمی‌بندد و تأیید حقوقی، تأیید کامل آزمون، یا آمادگی Play نیست.

## شاخه و قانون

- مخزن: https://github.com/mmhaidari2-hash/the-toms
- تنها شاخهٔ مجاز نوشتن: `fix/offline-audio-content`
- `main`، `source`، سایت زنده، و مخزن/سایت `the-toms-preview` تغییر داده نشدند و نباید تغییر کنند.
- چهار کامیت زیر در ساعت ۱۵:۴۹ روی همین شاخه زنده بودند و هنگام این ثبت هم نیای نوک بودند. ادغام تازه‌ای لازم نبود.

English: Those four commits were already ancestors. No merge, squash, rebase, or force-push was done for them.

## چهار اصلاح ثبت‌شده

### ۱. تاریخ B2 و نام IAA

[51754c98b4a7701eb10bf3bb82ca55e57558ed3b](https://github.com/mmhaidari2-hash/the-toms/commit/51754c98b4a7701eb10bf3bb82ca55e57558ed3b)

بازنویسی سؤال‌های خانوادگی (Q12) شناسه و گزینه‌ها را نگه داشته بود، اما توضیح values و پاسخ `values_13` را به جملهٔ «فقط B1» برگردانده بود. این کامیت متن انگلیسی و فارسی را به این واقعیت برگرداند: شهروندی B1؛ اقامت در بسیاری از مسیرها پیش از ۲۶ مارس ۲۰۲۷ سطح B1 و از آن تاریخ B2. ساقهٔ خانوادگی سؤال حفظ شد. کلیپ معلم برای متنِ برگشته موجود نبود، پس `ms` همان توضیح ۰ است. کلیپ جملهٔ نادرست حذف نشد و TTS اجرا نشد.

در میز ویزا، سلب مسئولیت اقامت، و نقطهٔ ویزای نقشه، نام کاربرپسند شد: IAA (formerly OISC) / سازمان مشاورهٔ مهاجرت. این Q13 را نمی‌بندد. `docs/compliance/compliance_report.md` هنوز ممکن است OISC قدیمی بگوید.

English: Restores the settlement B2 date and names the IAA in the visa signposts. The restored values explanation is still unvoiced.

### ۲. قفل مالک و پرچم پیش‌نمایش

[f65208064dc96ef08936f13ba17629b870a632dc](https://github.com/mmhaidari2-hash/the-toms/commit/f65208064dc96ef08936f13ba17629b870a632dc)

قفل مالک با کد ساختگی آزمون شد: درس قفل و منطقهٔ نقشه باز می‌شود، `unlockAll` خاموش می‌ماند، همان ذخیره بعد از ظرف جدید باز می‌ماند، پروفایل کودک بسته می‌ماند، و پنج تلاش غلط قفل زمانی می‌سازد. کد واقعی در مخزن نیست و اینجا هم نوشته نشده است. آزمون‌هایی که به کد واقعی نیاز دارند رد شده می‌مانند.

`PREVIEW_UNLOCK` و `PREVIEW_AUDIO_BASE` پیش‌فرض خالی‌اند و در `app/lib/core/platform/preview_flags.dart` جمع شده‌اند. اسکریپت انتشار اندروید، استقرار Cloudflare، و `.github/workflows/ci.yml` این defineها را نمی‌دهند. `check_public_release.py` خودش جلوی `PREVIEW_UNLOCK` را نمی‌گیرد؛ توضیح قدیمی که خلاف این را می‌گفت برداشته شد.

English: Synthetic owner unlock opens lessons and persists; a child profile stays gated. Preview flags default off. The real owner code is not recorded here.

### ۳. بنر صدای گم‌شده

[42ac8ee9647cb41fe734c1e7c779a1f3b4165890](https://github.com/mmhaidari2-hash/the-toms/commit/42ac8ee9647cb41fe734c1e7c779a1f3b4165890)

جملهٔ «No recording for this line yet / صدای این جمله هنوز آماده نیست» می‌ماند، اما بالای صفحه است و خود متن ضربه را نمی‌گیرد. فقط دکمه‌های بستن و تلاش دوباره هدف ضربه‌اند. آزمون پیام (`messages_flow_test`) بعد از این تغییر گذشت.

English: The bilingual missing-audio notice stays visible and no longer covers the reply.

### ۴. تایمر بنر

[8cfbe9e89fc4aa6c7d523b380826f5845f56ae00](https://github.com/mmhaidari2-hash/the-toms/commit/8cfbe9e89fc4aa6c7d523b380826f5845f56ae00)

چند گزارش در یک فریم فقط یک تایمر پنهان‌سازی می‌سازند و با بستن صفحه همان تایمر لغو می‌شود. این کامیت نوک ثبت است مگر پوش بعدی کسی دیگر نوک را جلو ببرد.

English: Stale missing-audio timers are cancelled. This commit was the tip when the record was written.

## آزمون

Flutter 3.47.7. فرمان: `cd app && flutter test -j 1`.

- مجموعهٔ سریال روی `42ac8ee96` تمام شد: `+242 ~2 -10`. این اجرای کامل روی کد نهایی `8cfbe9e89` تکرار نشد.
- بعد از `8cfbe9e89` این پنج فایل با هم گذشتند (`+17`): `test/voice_feedback_test.dart`، `test/messages_flow_test.dart`، `test/park_flow_test.dart`، `test/roleplay_test.dart`، `test/seasons_flow_test.dart`.
- شکست‌های دیده‌شده در مجموعهٔ `42ac8ee96` که با اصلاح تایمر دوباره اجرا نشدند: هفت کلید arrival در `arrival_pack_test`؛ سه آزمون audit صوت؛ رادیو و سینما چون `playClip` بیرون از اندروید فوراً false است (سه خط اول `r_a1_weather` در ایندکس بودند)؛ `profiles-privacy` در نمای اول ۸۴۴ پیکسل پیدا نشد.
- این فهرست «همهٔ ایرادهای محصول» نیست.

English: Full serial result was `+242 ~2 -10` on `42ac8ee96` only. Five files passed after `8cfbe9e89`. No full-QA claim.

## پیش‌نمایش — فقط خواندنی

سایت: https://mmhaidari2-hash.github.io/the-toms-preview/

خروجی مخزن پیش‌نمایش: [fd32df7992eea53ae09db3425aa885d77908094f](https://github.com/mmhaidari2-hash/the-toms-preview/commit/fd32df7992eea53ae09db3425aa885d77908094f). این کامیت سایت ساخته‌شده است، نه SHA سورس اپ. `version.json`: `british_life` `1.1.0` build `5`. `.last_build_id` برابر `4a4309525698ef581ca5bf3181bee22b` است و SHA گیت نیست؛ از آن کامیت سورس نسازید. Last-Modified صفحه ۱۳:۲۱ UTC در ۶ نوامبر بود. SHA دقیق سورس معلوم نیست. محتوا با HEAD فعلی یکی نیست: `lifeuk.json` / ویزا / اقامت با blobهای ثابت از `68b3a8a88` تا `4e2046e69` می‌خوانند، نه با `51754c98b` به بعد.

صوت استریم در JS به `fix/offline-audio-content` روی raw.githubusercontent.com اشاره دارد. نوار PREVIEW در گوشه دیده شد. مسیر بدون `#` روی GitHub Pages فایل نیست و 404 می‌دهد.

جریان‌های دیده‌شده:

- `#/lifeskills` — ۸ درس باز؛ هشدار ۲۶ مارس ۲۰۲۷ و سقف B1 روی صفحه بود.
- `#/mistakes` — ۱۰ درس باز بود.
- `#/visa` — هنوز OISC بود، نه IAA.
- `#/lifeuk/values` — جملهٔ روی صفحه هنوز «B1 level or above» برای اقامت و شهروندی با هم بود.
- `#/messages/t_a1_milk` — ضربه به Milk و سپس «Yes, no problem! x» به «Delivered» و «Done · تمام» رسید. بنر «No recording» در این نخ دیده نشد، چون خط آغاز صوت داشت. این مشاهده ثابت نمی‌کند بنر قدیمی هرگز چیزی را نمی‌پوشاند.

عکس‌ها از همان مشاهده‌اند و دوباره ساخته نشده‌اند:

- [Life Skills](checkpoint/2026-11-06/preview-lifeskills.png)
- [اشتباهات](checkpoint/2026-11-06/preview-mistakes.png)
- [ویزا، هنوز OISC](checkpoint/2026-11-06/preview-visa.png)
- [values، جملهٔ قدیمی](checkpoint/2026-11-06/preview-lifeuk-values.png)
- [نخ پیام](checkpoint/2026-11-06/preview-message-thread.png)
- [پاسخ Delivered](checkpoint/2026-11-06/preview-message-reply.png)

English: Preview output commit `fd32df7992`, app version `1.1.0+5`. Exact source SHA is unknown. Do not infer it from `.last_build_id`. The deployed preview is not current HEAD.

## ساخت خصوصی اندروید — فقط فراداده

این دودویی‌ها فقط روی ماشین ابری همان اجرا بودند. به مخزن، Release، LFS، یا پیوست والد منتقل نشده‌اند و اینجا هم نیستند. دوباره ساخته یا امضا نشده‌اند.

- کامیت تولید پس از بازسازی روی `8cfbe9e89`: `app.thetoms.newlifeuk`، versionName `1.1.0`، versionCode `5`، compileSdk `36`
- APK: SHA-256 `1c6704c00f1d3c81ea921519f7eda55b02651be26446e2c539abb1d371aa71f5` ، ۳۶۳۱۶۱۷۴۲ بایت
- AAB: SHA-256 `06c4c3ef919ac3593b39f3df296bcd8956c2bcc07a12b2bf9ea509fc24f038f3` ، ۳۴۲۱۹۵۸۰۶ بایت
- امضا: گواهی اشکال‌زدایی `CN=Android Debug`. SHA-256 گواهی `05933c3216df8d826c998d13fe5f57cd0f2a8794aad5fb04f3a019e93439da85`
- ویژگی `android:debuggable` در مانیفست نبود
- فایل کلید انتشار حاضر نبود. کلید تازه ساخته نشد و هیچ رمزی اینجا نیست
- این بسته Play-ready نیست

English: Debug-signed `1.1.0+5` metadata only. The binaries were not exported and are not Play-ready.

## مانع‌های باز که در همین اجرا دیده شد

این فهرست جامع همهٔ محصول نیست.

- مادهٔ امضای آپلود تولید حاضر نبود
- هفت ارجاع صوتی arrival: `087cc7d72afdb4af`، `30d6184f7e89755f`، `356cbff6b133709e`، `41f7ba1b5bec01ca`، `aff7622e07e6c48a`، `d8460a4b3cebf583`، `da6a5e64cdb062a6`
- کلیپ توضیح values پس از برگرداندن متن ۲۰۲۷ هنوز ساخته نشده (`ms` = ۰)
- سوییپ IAA در همهٔ داده‌ها و گزارش انطباق تمام نیست
- مجموعهٔ کامل روی کد نهایی تکرار نشد؛ شکست‌های بالا سر جایشان‌اند
- زبان‌هایی که قبلاً نگه داشته شده‌اند (از جمله لهستانی، رومانیایی، بنگالی) ارتقا داده نشدند. وصلهٔ مسدود لهستانی بازیابی نشد

English: These are the verified gaps from this run, not a claim that nothing else is open.

## درس پریا — چرخش و بنر صدا، ۱۶:۳۵ تا ۱۶:۳۷ لندن

همان درس. مسیر واقعی `/chat/l1_u43_1`. شناسهٔ صحنه `l1_u43_1`. عنوان «Excuse me, can you help me?» / «ببخشید، می‌توانید کمکم کنید؟». تنظیم «Asking for help · Level 1»، سطح A1، گوینده Priya. این شناسه از فایل صحنه است، نه یک مسیر ساخته‌شده.

نوک والد پیش از این اصلاح `5558847851ccf9fb4acc464e4f33c30aac74fde2` بود. پیش‌نمایش ساعت ۱۳:۲۱ تغییر داده نشد.

### t237u — صفحهٔ خاکستری بعد از چرخش

گزارش: همان درس، بعد از حالت عمودی که کاربر «yes please can i have candy» نوشته بود و پریا «Of course! What are you looking for?» گفته بود، گوشی ۹۰ درجه چرخید. والد یک صفحهٔ خاکستری/خالی دید که فقط روبان PREVIEW داشت. فایل اصلی آن عکس دیگر در دسترس نیست؛ این مشاهده است، نه یک آزمون ساختگی.

علت، روی کد قبل از این اصلاح: بعد از بیش از دو خط گفتگو ارتفاع نقاشی این بود:

`(width * .5).clamp(128.0, height * .24)`

ستون اپ حداکثر ۵۲۰ عرض دارد. در افقی با ارتفاع ۳۹۰، سقف `height * .24` حدود ۹۳٫۶ است و از کف ۱۲۸ کمتر است. `num.clamp` در این حالت `ArgumentError` می‌دهد و مسیر درس با صفحهٔ خطا عوض می‌شود. روبان PREVIEW بیرون از آن مسیر است (`app.dart`) و می‌ماند. در حالت آزمون ویجت، صفحهٔ خطا قرمز است؛ در ساخت release همان خطا صفحهٔ خاکستری است. تا وقتی گفتگو هنوز «اوایل» است (حداکثر دو خط) سقف `height * .42` است و روی ارتفاع ۳۹۰ پرتاب نمی‌کند. گزارش بعد از جواب پریا بوده، پس با این شرط می‌خواند.

با اجرای همان مسیر روی کدِ قبل از اصلاح، بعد از همان جواب و چرخش به ۸۴۴×۳۹۰، خروجی آزمون این بود: `ArgumentError Invalid argument(s): 128.0`.

اصلاح: اگر سقف از ۱۲۸ کوتاه‌تر باشد، همان سقف استفاده می‌شود و استثنا پرتاب نمی‌شود. روی صفحهٔ کوتاه، اگر بنر صدا روشن باشد درس از زیر بنرِ بالای صفحه شروع می‌شود تا ردیف نقش زیر آن نرود. ارتفاع نقاشی روی صفحهٔ کوتاه انیمیشن جمع‌شدن ندارد، چون ارتفاع میانیِ عمودی ستون را سرریز می‌کرد.

English: Rotating this lesson after the chat had grown threw `ArgumentError` from an inverted `clamp` and replaced the route with the error page. The fix keeps a legal painting height. The 390×844 and 844×390 sizes are test viewports, not a measured handset.

### t238u — بنر روی «YOUR LINE AS PRIYA»

عکس پیوست‌شده عمودی است، نه عکس چرخش: نقش Priya انتخاب شده، Newcomer می‌گوید «Do you sell saffron?»، و بنر دوزبانهٔ «No recording for this line yet» روی کارت خط یادگیرنده نشسته است. این هندسه بنرِ پایینِ قدیمی است. کامیت `42ac8ee96` بنر را در همین شاخه به بالای صفحه برده بود. پیش‌نمایش ۱۳:۲۱ قبل از آن ساخته شده و اینجا دوباره منتشر نشد. اگر علامت روی شاخهٔ فعلی دیگر دیده نشود، وضعیت «در شاخه درست شده، روی پیش‌نمایشِ ۱۳:۲۱ نه» است. این مرحله علاوه بر آن، در افقیِ کوتاه و با صفحه‌کلید باز، ردیف نقش و خط و دکمه‌ها را زیر همان بنرِ بالا نمی‌گذارد. متن بنر همان انگلیسی و فارسی است و برای خاموش کردن خطا مخفی نشده است.

جابه‌جا کردن بنر صوت گم‌شده را درست نمی‌کند. کلیدها با `md5(speaker|text)` شانزده‌رقمی، روی ایندکس و فایل‌های همین شاخه:

- `learner|Do you sell saffron?` = `2baed0e7dbf8c870` — در ایندکس نیست و فایل ندارد.
- `me|Do you sell saffron?` = `7f6d6c589b18837c` — در ایندکس هست، ۴۱۲۴ بایت. `Voice._find` برای گویندهٔ `learner` کلید `me` را هم می‌گردد، پس همین جملهٔ Newcomer روی این شاخه، اگر ایندکس بار شده باشد، کلیپ گم‌شده نیست.
- `priya|Do you sell saffron?` = `2ef642b86cdfef76` — نیست. پریا این جمله را نمی‌گوید.
- خط خود پریا در همین نوبت، `priya|We do! Spices are in aisle six. But saffron is behind the till. It's very expensive!` = `8db96d4723b8e439` — هست، ۲۰۹۰۰ بایت.
- `priya|Of course! What are you looking for?` = `9289f78efa9292f6` — هست، ۸۳۰۰ بایت.
- `priya|Hi there! You look a bit lost. Can I help you with anything?` = `b5a1fd4a8c2b34ed` — هست، ۱۳۹۸۸ بایت.
- جملهٔ تایپ‌شدهٔ کاربر کلیپ ندارد: `me` = `b922edc0347e152d` و `learner` = `f42e529f09e12a54`.

پس بنر «No recording» در آن عکس با غایب بودنِ خودِ «Do you sell saffron?» توضیح داده نمی‌شود، مگر ایندکس هنوز بار نشده باشد، متن دقیق خط چیز دیگری بوده باشد، یا ساخت پیش‌نمایش مسیر دیگری داشته باشد. این مرحله کلیپی اضافه نکرد.

English: The covering notice matches the old bottom banner. On this branch the notice stays at the top and the short layout keeps the line and controls clear of it. The Newcomer saffron line resolves through the existing `learner` → `me` clip. Missing audio is not solved by moving the notice.

### t236u — در بخش بعدی بسته شد

قبل از اصلاح، «yes please can i have candy» به‌خاطر واژهٔ `can` به شاخهٔ اول می‌رفت و پریا می‌گفت «Of course! What are you looking for?». همان رفتار در آزمونِ قبل از اصلاح دوباره دیده شد. اصلاح و آزمونش در بخش «جواب خارج از متن و وضعیت صدا» است، نه اینجا. عکس عمودیِ قدیمیِ «جواب تایپ‌شده» هنوز همان جواب نادرست را نشان می‌دهد و سندِ قبل از اصلاح است.

English: The candy mismatch was real. The fix is in the next section. The older portrait screenshot still shows the wrong reply.

### آزمون این مرحله

Flutter 3.47.7. فرمان:

`cd app && flutter test -j 1 test/priya_shop_layout_test.dart test/voice_feedback_test.dart test/messages_flow_test.dart test/play_as_test.dart test/chat_bubbles_test.dart test/roleplay_test.dart`

نتیجه: `+19` و `All tests passed`. مجموعهٔ کامل دوباره اجرا نشد. نتیجهٔ تاریخی `+242 ~2 -10` روی `42ac8ee96` و `+17` روی `8cfbe9e89` سر جایش است. شکست‌های arrival، audit، رادیو، سینما و `profiles-privacy` حل‌شده علامت نخوردند. نماهای ۳۹۰×۸۴۴ و ۸۴۴×۳۹۰ اندازهٔ دستگاه مالک نیستند. آزمون لینوکس mp3 پخش نمی‌کند.

عکس‌ها از همان آزمون ویجت‌اند. عکس «قبل» صفحهٔ خطای حالت آزمون است (قرمز)، نه قاب release خاکستری؛ استثنا همان `ArgumentError` بود.

- [افقی، قبل از اصلاح، صفحهٔ خطا](checkpoint/2026-11-06/roleplay-before-landscape-error.png)
- [عمودی، جواب تایپ‌شده مانده](checkpoint/2026-11-06/roleplay-after-portrait-typed.png)
- [افقی، گفتگو مانده](checkpoint/2026-11-06/roleplay-after-landscape.png)
- [عمودی، خط پریا پیدا است](checkpoint/2026-11-06/roleplay-after-portrait-line.png)
- [افقی، خط پریا زیر بنر نرفته](checkpoint/2026-11-06/roleplay-after-landscape-notice.png)
- [افقی با صفحه‌کلید، نقش و ارسال پیدا است](checkpoint/2026-11-06/roleplay-after-landscape-keyboard.png)

English: Focused serial result `+19` on `171a75cdc`. Not a full suite and not a Play-ready claim.

## جواب خارج از متن و وضعیت صدا

این بخش بعد از `171a75cdc` است. چرخش و جای بنر دوباره ساخته نشد.

### جواب فروشگاه پریا

`ConversationEngine.match` دیگر با `can` / `please` / `yes` به‌تنهایی جمله‌ای را قبول نمی‌کند که واژهٔ محتواییِ خارج از درس داشته باشد. جملهٔ دقیقِ نوشته‌شده در درس همچنان شاخهٔ خودش را می‌برد. یک حرفِ جاافتاده در واژهٔ بلند (saffron / safron، please / pleas) و علامت‌ها هنوز قبول‌اند. نفی (`don't` / `no` / `not`) شاخهٔ مثبت را جلو نمی‌برد، مگر خودِ پیشنهادِ درس همان جملهٔ منفی باشد.

اگر همان جمله از قبل به سؤال بعدی جواب داده باشد، داستان یک قدم به خطِ نوشته‌شدهٔ بعد می‌رود. «Do you sell saffron?» و «I'm looking for saffron» از گرهٔ کمک به توضیح راهرو می‌رسند، نه به «دنبال چه می‌گردید؟». «Excuse me, can you help me?» و «yes please» هنوز همان سؤال را می‌آورند. «candy» و «yes pleas can i have candy» شاخه نمی‌گیرند، اعتماد و شمارش موفقیت اضافه نمی‌کنند، و راهنمای دوزبانهٔ همان درس («You mean…» به‌علاوهٔ فارسیِ پیشنهاد) می‌ماند. قیمت و موجودی ساخته نمی‌شود. بازنویسیِ ادب، اگر واژهٔ درس را نزده باشد، دیگر خودش داستان را جلو نمی‌برد. گراف درس و هدف‌ها عوض نشدند. نقش عوض‌شده و چرخش در `priya_shop_layout_test` ماندند؛ انتظارِ قدیمیِ «Of course» بعد از آب‌نبات برداشته شد، نه پوششِ چرخش.

آزمون قبل از اصلاح، روی همین فایل و کدِ قبلی، چهار انتظار را رد کرد: آب‌نبات شاخه می‌گرفت، زعفران روی `n2` می‌ماند، «I don't want saffron» قبول می‌شد، و `successMap` از ۰ به ۱ می‌رفت. بعد از اصلاح همان آزمون‌ها گذشتند.

English: Weak words no longer accept an unnamed item. A supported item continues to the authored answer. An unsupported request gets the existing bilingual hint and no success. The lesson graph was not rewritten around one sentence.

### صدا — چه چیزی «No recording» می‌سازد

روی این شاخه و روی ایندکسِ پیش‌نمایشِ ۱۳:۲۱ (خواندنی، ۴۴۶۲۸۰ بایت، Last-Modified همان ساعت)، این کلیدها هستند: `7f6d6c589b18837c` و `8db96d4723b8e439` و `9289f78efa9292f6` و `b5a1fd4a8c2b34ed`. کلیدهای آب‌نبات نیستند. هر خطِ نوشته‌شدهٔ `l1_u43_1` با ایندکسِ شاخه پیدا می‌شود (learner به me). پس خودِ «Do you sell saffron?» وقتی ایندکس بار شده باشد کلیپِ گم‌شده نیست.

GET خواندنیِ همان کلید از `raw.githubusercontent.com/.../fix/offline-audio-content/app/assets/audio/7f6d6c589b18837c.mp3` برابر فایل شاخه است: ۴۱۲۴ بایت، SHA-256 `caf0a85b044f5434a03a3e5cd8badd13e3f3202559cc86408f0207bb8571376c`. `main.dart.js` پیش‌نمایش همین پایه را برای mp3 می‌گذارد. پخش در مرورگر انجام نشد. فایلِ همان کلید روی سایتِ `the-toms` (نه پیش‌نمایش) ۴۵۵۶ بایت و SHA-256 دیگری است (`c135025ae657786e…`). آن سایت تغییر داده نشد و این تفاوت با یک نام مستعار در ایندکس حل نشد.

در سورس، «No recording» فقط وقتی است که ایندکس آماده است و کلیدِ یک خطِ درسی نیست. سه وضعیت جدا شد:

- ایندکس هنوز بار نشده یا بارگذاری‌اش شکست خورده: «The audio list is not ready yet / فهرست صدا هنوز آماده نیست» و تلاش دوباره همان بارگذاری را تکرار می‌کند. این دیگر جملهٔ «صدای این جمله نیست» نیست.
- کلید هست و پخش false برمی‌گرداند: «Audio could not play». روی لینوکس `playClip` فوراً false است؛ آزمون همان را برای خط زعفران ثبت کرد، نه missing.
- جملهٔ خودِ یادگیرنده که کلیپ ندارد، و جملهٔ راهنمای Ghost، دیگر بنرِ «این خط ضبط نشده» نمی‌سازند و به‌جای یک کلیپ دیگر پخش نمی‌شوند. تمرین ادامه دارد. خطِ درسیِ بی‌کلیپ هنوز همان بنرِ صادق را دارد و تلاش دوباره برای missing همچنان false است.

این مرحله کلیپ، کلید ایندکس، یا mp3 خالی اضافه نکرد.

English: Supported shop lines resolve when the index is loaded. The branch clip matches the raw URL byte for byte. An unloaded index, a failed play, and the learner's own unrecorded words are three different statuses. No clip was invented. The preview page was not driven, and the live site was not changed.

### آزمون این بخش

Flutter 3.47.7. قبل از اصلاح: `test/priya_shop_reply_test.dart` چهار شکست (خروجی در لاگِ قبل). بعد از اصلاح، همین فایل به‌همراه `voice_feedback_test` و `engine_test` و `conversation_suggestions_test`: `+42` و `All tests passed`. سپس `priya_shop_layout_test` و `messages_flow_test` و `play_as_test` و `chat_bubbles_test` و `roleplay_test`: `+9` و `All tests passed`. مجموعهٔ کامل روی این SHA در همین بخش، تا وقتی عدد دقیق نوشته شود، اجرا نشده است.

English: Focused tests passed after the fix. The four reply failures above are the before evidence. This paragraph does not claim a new full-suite pass.

## Azure — ورود حساب در ۱۸:۲۵ لندن بسته بود

بررسی فقط‌خواندنی در `2026-11-06 18:25:53 Europe/London`. اتصال ابزار Azure برقرار بود، اما هر سه خواندن (`subscription_list`، پرس‌وجوی Speech، و ساخت دستور منبع) با `401 CredentialUnavailableException` / `ChainedTokenCredential` برگشت: `az login` لازم است. نام منبع Speech، شناسه، SKU (F0 یا S1)، منطقه، سهمیهٔ مانده، و اتصال کلید خوانده نشد. کلیدی خوانده نشد و کلیپی ساخته نشد. سقف ۴۸۰٬۰۰۰ نویسه در ماه فقط سیاست برنامه است، نه اندازه‌گیری زنده. تا ورود خود مالک، ساخت کلیپ تازه مجاز نیست. این مانع تعمیر سورس و آزمون همین مرحله نیست.

English: A live read-only Azure check at 18:25 London found the connector up and the credential chain unsigned-in. No Speech resource, SKU, region, remaining quota, or key binding was proven. No login, no TTS, and no resource change was made. New clips stay blocked. Source and test repairs are not.

## مجموعهٔ سریال روی `104f7500d` — تمام شد، سبز نیست

فرمان: `cd app && flutter test -j 1`. SHA درخت در شروع اجرا: `104f7500d92dd629074bd94aa5c86040fd0d0c27`. زمان آزمون حدود ۲۵:۲۷. نتیجه: `+220 ~2 -16` و `EXIT:1`. این عدد مجموعهٔ کاملِ همین SHA است و با `+242 ~2 -10` یکی نیست.

شکست‌های واقعی همین اجرا:

- `arrival_pack_test`: هفت کلید arrival هنوز کلیپ ندارند. کلیپ ساخته نشد.
- `widget_test` در هر سه اندازه: باز کردن چت و رفتن به مسیر بعد، `ListenableBuilder` را وسط ساخت درخت کثیف می‌کرد (`markNeedsBuild` وقتی درخت قفل است). صفحهٔ خاکستریِ چرخش نیست؛ همان بنر صداست.
- `radio_flow_test`: بعد از پخش، `radio-stop` نبود. روی لینوکس `playClip` فوراً false است و برنامه همان را «قطع توسط کلیپ دیگر» می‌گرفت و متوقف می‌شد.
- سه آزمون `audit_test`: خط‌های بدون mp3، از جمله راهنمای Ghost، بازتاب‌های سراسری، واژه‌های راوی، و خط‌های شغلی مثل خوشامد Vida. آستانهٔ `n > 30000` هم به‌خاطر همین غیبت‌ها رد شد. آزمون حذف یا شل نشد. کلیپ جعلی اضافه نشد.
- `profiles_test`: یادداشت حریم کودک زیر اولین صفحهٔ فهرست بود و پیدا نمی‌شد.

هفت بارگذاریِ بعدی (`voice_feedback`، `park_flow`، `driving_flow`، `cinema_flow`، `roleplay`، `onb_lang`، `speaking`) خطای کامپایل `instanceOrNull` بودند، چون وسط همان اجرا فایل صوت عوض شده بود. آن ویرایش برگردانده شد و آن هفت نتیجهٔ محصول نیستند. بعد از برگشت، بقیهٔ مجموعه روی کدِ کامیت ادامه یافت. آن هفت فایل بعداً جدا پاس شدند؛ این پاس‌ها جای عددِ `+220 ~2 -16` را نمی‌گیرد.

English: Full serial on `104f7500d` was `+220 ~2 -16`, exit 1. Arrival clips, audit gaps, the locked audio notice, radio stop, and the profiles note are real. Seven later load failures were a compile break from an edit during that run, not product failures. They were re-run afterwards and are not a new full-suite total.

## ادامهٔ همان شب — بنر، رادیو، سینما، پروفایل

اعلام وضعیت صدا اگر وسط ساخت درخت باشد به فریم بعد موکول می‌شود تا بستن چت درخت را قفل نکند. اگر پخش false بدهد و کلیپِ دیگری جایش را نگرفته باشد، رادیو و سینما سرعت نوشته‌شدهٔ خط را نگه می‌دارند و بنرِ «پخش نشد» سر جایش می‌ماند؛ صدای موفق جعل نمی‌شود. آزمون پروفایل تا یادداشت حریم کودک می‌لغزد و همان جملهٔ انگلیسی و فارسی را می‌خواهد. آزمون کوتاه `chat_notice_dispose_test` ورود و خروج `/chat/nicola_park` را بدون استثنا می‌سنجد.

این اصلاح‌ها در SHA مجموعهٔ `104f7500d` نیستند. مجموعهٔ کاملِ SHA بعدی، وقتی تمام شود، در همین فایل با همان عدد ثبت می‌شود. تا آن ثبت، ادعای سبزِ جدید نیست.

English: The notice no longer marks the tree dirty during dispose. Radio and cinema keep their written pace when playback returns false without being replaced, and the failure notice stays. The profiles test scrolls to the child-privacy note and still requires its wording. The full suite of the following commit is not claimed until its own log is written here.
