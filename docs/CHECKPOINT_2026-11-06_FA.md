# نقطهٔ ثبت — ۶ نوامبر ۲۰۲۶، بعدازظهر

این رکورد ادامه است. از همین فایل و از نوک `origin/fix/offline-audio-content` شروع کنید. کار تمام‌شدهٔ زیر را دوباره نسازید، ادغام نکنید و cherry-pick نکنید.

English: Start here and from the latest `origin/fix/offline-audio-content`. Do not reapply the finished commits below.

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
