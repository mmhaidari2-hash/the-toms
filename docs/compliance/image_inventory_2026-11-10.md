# فهرست تصاویر ردیابی‌شده — ۱۰ نوامبر ۲۰۲۶ (Q09)

این فهرست مالکیت، اجازهٔ تجاری، یا پاک‌بودن تصویری را ثابت نمی‌کند. هر فایل جداگانه منشأ و مجوز `UNKNOWN` دارد. بازبینی شباهت چهره، لوگو و آثار شناخته‌شده انجام نشد.

English: Tracked-image inventory for owner review. It is not ownership, a commercial licence, or a likeness clearance. Per-file source and licence are UNKNOWN. No visual review was done.

درخت: `5077252e2c3c303ba2aa345a21d143291b829c96` روی `fix/offline-audio-content`. فایل جدول: `docs/compliance/image_inventory_2026-11-10.tsv`. SHA-256 خود جدول: `dba891018f5b352164055912b9327fe3e895b465134544482709a1efef281a85`. ۳۴۵ سطر. ستون‌ها: path، bytes، sha256، group، per_file_source، per_file_licence. دو ستون آخر برای هر سطر `UNKNOWN` است.

## شمارش

| group | count | what it is |
|---|---:|---|
| product-place | 97 | `app/assets/places/*.webp` |
| product-portrait | 55 | `app/assets/portraits/*.webp` |
| product-spot | 31 | `app/assets/spots/*.webp` |
| product-avatar | 51 | `app/assets/avatars/*.svg` |
| source-new-art | 37 | `new_art/*.jpg` |
| source-spot-jpg | 1 | `app/tool/spot_src/homes.jpg` |
| brand-file | 2 | `app/tool/brand/icon_glass_src.jpg`, `icon_1024.png` |
| launcher-or-web-icon | 56 | Android mipmap, iOS AppIcon/LaunchImage, `app/web` icons |
| audit-sheet | 2 | `app/tool/audit/portraits.png`, `map_icons_painted.png` |
| qa-screenshot | 12 | `docs/checkpoint/2026-11-06/*.png` |
| docs-image | 1 | `docs/motion/morning_table_still.png` |

۹۷ + ۵۵ + ۳۱ = ۱۸۳. این همان شمار «۱۸۳ تصویر» در Q09 است، به اضافهٔ بقیهٔ فایل‌های تصویری ردیابی‌شده تا چیزی جا نیفتد.

## آنچه مخزن واقعاً نشان می‌دهد

- در سربرگ هیچ‌کدام از ۳۴۵ فایل متن حق‌نشر، مجوز، یا نام Grok پیدا نشد.
- پاسخ مالک در `docs/compliance/OPEN_QUESTIONS_FA.md` (۵ نوامبر ۲۰۲۶، Q09): تصاویر با Grok ساخته شده‌اند؛ پاسخ تکمیلی: Grok Bot. این جمله برای کل مجموعه است، نه اثبات بایت‌های یک فایل. نوع حساب و تاریخ ساخت هر فایل در مخزن نیست.
- صفحهٔ درباره در `app/lib/features/legal/legal_screen.dart` خط ۱۹۱–۱۹۳ می‌گوید «Created with Grok». این متن محصول است، نه مدرک هر فایل، و در این مرحله عوض نشد.
- `IMAGE_PROMPTS.md` و `app/tool/audit/IMAGE_PROMPTS.md` پرامپت‌اند. Q09 می‌گوید وجود پرامپت به‌تنهایی مدرک مالکیت نیست. هر ۳۷ نام در `new_art/` با یک `app/assets/places/<همان نام>.webp` هم‌نام است. هم‌نامی، اثبات تبدیل همان بایت‌ها نیست.
- `app/tool/audit/IMAGE_PROMPTS.md` در اکتبر ۲۰۲۶ نوشته `sara.webp` آن زمان یک نقاشی تخت PIL بوده است. این فهرست نمی‌گوید فایل فعلی با همان SHA هنوز همان نقاشی است.
- `docs/LEGAL_REVIEW.md` یک مرور تاریخی است و خودش می‌گوید ترخیص نیست. نگاه آن به حدود ۴۰ نقاشی در اندازهٔ کوچک بوده، نه به این ۳۴۵ هش.
- فونت‌ها جدا هستند: `docs/compliance/font_provenance.md` (Q10). اینجا تکرار نشدند.
- `docs/MASTER_BOOK.md` خط ۴۱۲ می‌گوید `icon_glass_src.jpg` یک‌بار ساخته شده و به آیکون‌ها رسیده است. اسکریپت آن ساخت داخل مخزن نیست. هش آیکون‌های فعلی با آن jpg یکی نیست، پس اشتقاق بایت‌ها اثبات نشد.
- هفت گروه هش تکراری فقط بین آیکون‌ها و تصویر راه‌انداز است (مثلاً سه مقیاس LaunchImage iOS یک SHA دارند). منشأ همان بایت‌ها همچنان UNKNOWN است.
- تأیید کتبی legal@x.ai در مخزن نیست.

آثار عوض نشدند. این سند Q09 را نمی‌بندد.
