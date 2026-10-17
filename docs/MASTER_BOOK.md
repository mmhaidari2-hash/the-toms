# 📘 MASTER BOOK — British Life Immersion

> **نوع سند:** Product Requirements + Technical Design (PRD/TDD)
> **وضعیت:** v2.0 — نهایی، یکپارچه، تأییدشده برای شروع فاز ۱
> **تاریخ:** ۳ اکتبر ۲۰۲۶

> ⚠️ توجه: بخش میانی سند (حدود ۱۲٬۴۷۱ نویسه، از بخش ۴ تا اواسط بخش ۱۵) در نسخه‌ای که به دستیار رسید حذف/کوتاه شده بود. لطفاً متن کامل را دوباره بفرستید تا جایگزین شود.

## ۰. خلاصهٔ یک‌خطی (TL;DR)
> اپی موبایلی که به‌جای «حفظ لغت»، کاربر را **داخل زندگی یک خانوادهٔ واقعی بریتانیایی** (خانوادهٔ تام) می‌اندازد؛ کاربر از سطح یک بچهٔ یک‌ساله شروع می‌کند، با شخصیت‌ها حرف می‌زند، نقش‌ها را سوییچ می‌کند، و **خانواده را جلوی چشمش بزرگ می‌کند**.

## ۳.۱ یک خانواده، یک جهان زنده
| شخصیت | نقش | سن روایی | کاربرد آموزشی |
|---|---|---|---|
| Tom | رانندهٔ اتوبوس (پدر) | ۴۲ | زبان کار، روزمرهٔ مردانه، شوخی، اصطلاحات خیابان |
| Leslie | معلم (مادر) | ۳۹ | زبان دقیق، گرامر، صبر، آموزش کودکانه |
| William | پسر کوچک (پیش‌دبستانی ← آمادگی/کلاس اول) | ۳ ← ~۶ | جمله‌های کوتاه و ساده (حداکثر ۶–۸ کلمه)، «چرا؟»، اتوبوس، بازی، غذا |
| Nicola | کودک | ~۵–۶ | بازی، کارتون، پارک، احساسات ساده |
| Ryan | نوجوان | ۱۵ ← ۱۸ | سال ۱۰–۱۱ و امتحانات GCSE، رانندگی در ۱۷، دانشگاه در ۱۸؛ دوست‌ها، گیم، اسلنگ نوجوانانه |
| Nana Maggie (Margaret) | پرستار بچه | — | زبان مراقبت، دستورالعمل، صمیمیت |

## ۳.۳ متد یادگیری
> «یادگیری زبان = جعبهٔ لایتنر + محیط واقعی + هدفِ محاوره.»

## ۱۸. گام بعدی (Next Step)
ساخت اسکریپت خودکار که کل ساختار پوشه + فایل‌های فاز ۱ را بسازد:
- مدل‌ها (Character با age/growthStage، Milestone، DialogueNode با cultureNote، UserProgress با growthMap/accentPassport)
- JSON خانوادهٔ تام + `nicola_growth.json` (M0–M2) + صحنهٔ `nicola_birthday`
- `GrowthEngine` که از Trust + Leitner درصد رشد را حساب کند
- pubspec، main.dart، HomeScreen

## Growth & Monetisation Strategy (added 2026-10-16)
### Revenue
- Freemium: A0–A2 + Tom's home free; B1+ via subscription (~£7.99/mo, £49/yr).
- Themed packs: IELTS / Life in the UK prep, NHS workplace English, job interview, banking & housing.
- B2B: colleges, local councils, refugee charities, employers of overseas workers (care, warehouse).
- Live tutor add-on: 15-min calls with British tutors, revenue share.
### Global growth
- AI voice conversation with characters (British accents, pronunciation feedback) — key differentiator vs Duolingo.
- Weekly serialised episodes of Tom's family life (retention).
- Regional accents: London, Manchester, Scotland, Wales, Liverpool.
- Same engine/brand, new families: US, Australia, Canada.
- Real culture: queuing, weather talk, "sorry", pub quiz, Bonfire Night.
- Viral share cards ("William started Reception today!") + referral invites.
- Targeted TikTok/Instagram in Farsi, Arabic, Urdu, Polish with short character clips.
### Roadmap
1. Free version tested on iPhone (PWA). 2. AI voice chat + subscription payments. 3. App Store / Play Store release.

---

## Monetisation — 20 ideas

1. **Visa & citizenship exam tracks** — Life in the UK test prep, IELTS Life Skills A1/B1, plus NHS, job-interview and Universal Credit English.
2. **B2B licences** — councils, refugee charities, FE colleges, NHS trusts.
3. **Family plan** — one subscription for the whole household.
4. **Premium AI voice tutor** — open conversation with the family characters.
5. **Paid story chapters** — new seasons with the Toms.
6. **Official level certificates** — CEFR-aligned and shareable.
7. **Employer partnerships** — care, warehouse and hospitality onboarding English.
8. **20 helper languages** — reach every big migrant community.
9. **Pre-arrival edition** — learn before you move to the UK.
10. **Global British-English fans** — learners who love British culture but don't live here.
11. **TikTok/Reels** — short clips of the family's funny moments.
12. **Immigrant influencer affiliates** — creators get revenue share.
13. **Live small-group classes** — with British tutors.
14. **Books & merch** — e.g. Nicola's teddy, Mr Buttons.
15. **Kids edition.**
16. **Schools EAL edition** — with a teacher panel.
17. **Government grants** — Home Office integration funds, Innovate UK.
18. **Referral** — a free month for each friend.
19. **Social layer** — challenges, leaderboards and a shareable "trust card".
20. **Local pricing** — plus weekly micro-passes.

**Top 3:** exam tracks, B2B licences, family plan.

### App shell (2026-10-17)
- **Home = painted roadmap map** (`assets/places/map.webp`, `lib/features/map/map_home.dart`): Home (L1) → Neighbourhood (L2) → High Street (L3) → Town centre (L4) → The city (L5), plus Vida's Nursery (Career Pack). Tap a region to open that level's units, or the pack. Locked regions show "Needs Level N" and suggest the placement test. One big **Continue** button. Everything else (course path, family/stories/stats, packs, diary, placement test, how it works) is in the ☰ menu. The old home is at `/family`.
- **Placement test** (`/placement`, `tool/make_placement.py` → `assets/data/placement.json`): adaptive, Level 1 upwards. Each level has 2 listening items (real voiced lines; choose the meaning) and 1 choice item; pass 2 of 3 to climb, and the first failed level stops the test. Then an optional speaking item. Sets the start level. Skippable.
- **Onboarding:** language → 4 "How it works" pages with Tom and Nicola (tap people/objects, reply, X-Ray, role swap) → placement test or pick a level. Can be replayed from the menu (`/howto`).

### Career Packs (added 2026-10-17) — first: Vida's Nursery
Profession-specific English tracks led by a family member who does that job, built on the same lesson engine (story, reply choices, recasts, culture notes, Persian, rendered audio).
- **Model:** each pack is a one-off purchase (~£9.99–£14.99) or included in the subscription; a "Premium" badge shows in the app. **Every pack is unlocked during the beta** (`Pack.unlocked == true`); turning on the paywall later is a one-line change plus a payments step.
- **Pack 1 — Vida's Nursery** (`tool/career/nursery/`): 24 lessons in 6 units, A1–B2. It covers routines and instructions to children, toileting, lunch, nap, outdoor play, circle time, behaviour and praise, drop-off/pick-up, daily reports, accident forms, medicine, sickness policy, team huddles, key person, EYFS observations, settling-in, safeguarding, first aid (choking), the Ofsted visit and difficult conversations with parents. Lead: Vida (Leslie's younger sister, 33). With: Jo (room leader/DSL), Oscar (3), Dan (Oscar's dad), Mr Harris (Ofsted), plus William, Leslie and Nicola.
- **Art needed:** a dedicated nursery painting (pre-school room, Little Acorns). The pack uses the existing firstday/playdate/park paintings for now.
- **Next packs (ideas):** care worker / NHS healthcare assistant, warehouse & delivery, hospitality & barista, retail, construction (CSCS), taxi/rideshare, cleaning, teaching assistant (EAL), office admin.
- **B2B angle:** sell packs to employers and agencies (nurseries, care homes, logistics) as staff onboarding.
- **Pipeline:** `tool/career/<pack>/pack.json` + `u*.txt` (unit header field 7 = CEFR) → `gen.py` writes `course.json.packs`. The app shows a Career Packs entry on the home screen and a chip in the course screen, which opens `/pack/<id>`.

---

## Technical Architecture, Quality & Security

**Modular layers.**
- **Content:** story, lesson and place data in JSON/DSL files, separate from code.
- **Conversation engine:** keyword matching, recasts, politeness, X-Ray, SRS — `lib/core/engine`, behind the `DialogueBrain` interface.
- **Audio:** pre-rendered neural voices, content-addressed mp3s; there is no robotic fallback.
- **Progress:** a local store (Hive) via the `ProgressStore` abstraction.
- **UI:** the feature folders.

**Content as data.** Writers edit `tool/level1/u*.txt` and the JSON files. Generators compile them to the assets and render the voices (`tool/render_voices.py`).

**Automated tests per conversation:**
- every conversation always reaches an end;
- there are no dead or unreachable nodes;
- every suggested reply picks its own branch;
- every spoken line has an mp3;
- there is no layout overflow at 375×667, 390×844 or landscape;
- line-length and character-voice budgets are respected.

**CI gate before deploy.** A GitHub Actions workflow runs `flutter analyze` and `flutter test`. A deploy only happens from a green build.

**Anonymous crash reporting** (planned): opt-in, with no personal data.

**Offline-first, local-only data now.** No account and no server, and progress never leaves the device.

**Future backend:**
- encryption in transit and at rest;
- API keys held server-side only (never in the app);
- official in-app purchase / Stripe;
- rate limiting and abuse protection;
- UK GDPR compliance and the ICO Children's Code (age-appropriate design: high privacy by default for under-18s, no nudge techniques, no profiling of children).

---

## Positioning: the only truly British English app

**Core differentiator.** Duolingo and most of the big apps teach American English, or a neutral English that leans American. The Toms teaches British English all the way through: the vocabulary, the spelling, the accents (Received Pronunciation plus friendly regional voices), and real daily life in a British family home.

### Content rules (non-negotiable)
- Always use British spelling: colour, favourite, mum, organise, centre, programme, cosy, pyjamas, grey, tyre.
- Always use British words: flat, queue, chemist, biscuit, crisps, chips, jumper, trousers, trainers, mobile, rubbish/bin, lift, loo, post, holiday, garden, car park, motorway, GP, A&E, term, maths.
- Every voice is British (edge-tts en-GB). Never use an en-US voice.
- Put **British vs American** mini-notes (`C:` culture notes) in roughly 1 in 3 lessons. Practice includes a "Which is British?" item type.
- Pairs to cover in Level 1–2: queue/line, flat/apartment, chemist/pharmacy, biscuit/cookie, crisps/chips, chips/fries, jumper/sweater, trousers/pants, trainers/sneakers, mobile/cell phone, bin/trash can, lift/elevator, holiday/vacation, garden/yard, loo/restroom, autumn/fall, post/mail, mum/mom, car park/parking lot, rubber/eraser, film/movie, football/soccer.

### Store listing / ASO
- **Title:** The Toms: British English Life
- **Subtitle (30 chars):** Speak real British English
- **Keywords:** british english, uk english, learn english uk, british accent, english for uk, ielts, life in the uk, move to uk, english farsi, persian english, british pronunciation, english conversation, esol
- **First screenshot caption:** "Not American. Not textbook. Real British English, at home with the Toms."
- Localised listings for Farsi, Arabic, Urdu, Ukrainian, Polish and Turkish speakers moving to the UK.

### Tagline ideas
- "Learn English the way Britain speaks it."
- "Cuppa, queue, cheers — English, the British way."
- "Your British family, in your pocket."
- "Move to the UK sounding like you already live here."
- "Duolingo says 'cookie'. Nana says 'biscuit'."

### Marketing
- Short videos: "British vs American in 10 seconds" (queue/line…), Nana's tea rules, "Words Americans get wrong in the UK".
- Partner with relocation services, UK universities' international offices, ESOL colleges, NHS international-recruitment teams, and IELTS/Life in the UK prep.
- Find the communities where people talk about moving to the UK (Farsi, Arabic and Ukrainian Telegram and Instagram groups).
- In-app share card: "I'm learning British English with the Toms".
- B2B pitch: "Onboard staff into British workplace English."
