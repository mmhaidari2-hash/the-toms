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
- Themed packs: English-for-exams / Life in the UK prep (original questions; not affiliated with the Home Office), NHS workplace English, job interview, banking & housing.
- B2B: colleges, local councils, refugee charities, employers of overseas workers (care, warehouse).
- Live tutor add-on: 15-min calls with British tutors, revenue share.
### Global growth
- AI voice conversation with characters (British accents, pronunciation feedback) — a key differentiator (British, not American, English).
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

1. **Visa & citizenship exam tracks** — Life in the UK test prep (original questions, not affiliated with the Home Office), English for speaking-and-listening exams at A1/B1 (no exam trade marks in store text), plus NHS, job-interview and Universal Credit English.
2. **B2B licences** — councils, refugee charities, FE colleges, NHS trusts.
3. **Family plan** — one subscription for the whole household.
4. **Premium AI voice tutor** — open conversation with the family characters.
5. **Paid story chapters** — new seasons with the Toms.
6. **Level completion certificates** — aligned to CEFR descriptors, shareable, clearly labelled "Not an accredited qualification. CEFR level is an indication only."
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

**Core differentiator.** Most of the big apps teach American English, or a neutral English that leans American. The Toms teaches British English all the way through: the vocabulary, the spelling, the accents (Received Pronunciation plus friendly regional voices), and real daily life in a British family home.

### Content rules (non-negotiable)
- Always use British spelling: colour, favourite, mum, organise, centre, programme, cosy, pyjamas, grey, tyre.
- Always use British words: flat, queue, chemist, biscuit, crisps, chips, jumper, trousers, trainers, mobile, rubbish/bin, lift, loo, post, holiday, garden, car park, motorway, GP, A&E, term, maths.
- Every voice is British (edge-tts en-GB). Never use an en-US voice.
- Put **British vs American** mini-notes (`C:` culture notes) in roughly 1 in 3 lessons. Practice includes a "Which is British?" item type.
- Pairs to cover in Level 1–2: queue/line, flat/apartment, chemist/pharmacy, biscuit/cookie, crisps/chips, chips/fries, jumper/sweater, trousers/pants, trainers/sneakers, mobile/cell phone, bin/trash can, lift/elevator, holiday/vacation, garden/yard, loo/restroom, autumn/fall, post/mail, mum/mom, car park/parking lot, rubber/eraser, film/movie, football/soccer.

### Store listing / ASO
- **Title:** The Toms: British English Life
- **Subtitle (30 chars):** Speak real British English
- **Keywords:** british english, uk english, learn english uk, british accent, english for uk, english for exams, life in the uk test practice, move to uk, english farsi, persian english, british pronunciation, english conversation, esol  *(no "ielts", "duolingo", "official", "certified" or other brands' names in store metadata — Apple 2.3.7; see docs/LEGAL_REVIEW.md §11)*
- **First screenshot caption:** "Not American. Not textbook. Real British English, at home with the Toms."
- Localised listings for Farsi, Arabic, Urdu, Ukrainian, Polish and Turkish speakers moving to the UK.

### Tagline ideas
- "Learn English the way Britain speaks it."
- "Cuppa, queue, cheers — English, the British way."
- "Your British family, in your pocket."
- "Move to the UK sounding like you already live here."
- "Other apps say 'cookie'. Nana says 'biscuit'." (no competitor names in ads or store text)

### Marketing
- Short videos: "British vs American in 10 seconds" (queue/line…), Nana's tea rules, "Words Americans get wrong in the UK".
- Partner with relocation services, UK universities' international offices, ESOL colleges, NHS international-recruitment teams, and exam / Life in the UK prep providers.
- Find the communities where people talk about moving to the UK (Farsi, Arabic and Ukrainian Telegram and Instagram groups).
- In-app share card: "I'm learning British English with the Toms".
- B2B pitch: "Onboard staff into British workplace English."

### Monetisation (prep done 2026-10-17)
- **Premium screen** (`/premium`, menu "Premium (free in beta)"): Yearly £34.99 (save 42%, 7-day trial), Monthly £4.99, Career Pack one-off £9.99. Prices are config in `lib/core/data/premium.dart` (`PremiumConfig`).
- **Beta-free state:** `PremiumConfig.betaFree = true`. Every pack is open, prices are shown struck through as "FREE in beta", and no payment is ever taken. When the flag is false the screen says "Coming soon".
- **Career Pack preview lock:** after the beta, lesson 1 of each pack is free. Later lessons open with Premium (`pref:premium`), a one-off buy (`pack:<id>`) or demo mode. Locked stones and direct `/lesson/<id>` links show the paywall. The main course is never paywalled.
- **Certificates** (`/certificate/1..5`, menu "Certificates"): one per level, earned when every unit of the level is finished. Shows a printable certificate with the learner's name; locked levels show % progress.
- **Real payments and native store builds:** GitHub issue #50 (RevenueCat for iOS/Android, Stripe or RevenueCat Web for the PWA, legal/VAT, store builds, per-level audio downloads).

### Motivation (2026-10-17)
- XP (practice 5–15, stories 10), a daily goal picker (10/20/30/50 XP), and a streak with freezes (start with 1, earn one per 7-day streak, max 2; a freeze covers one missed day).
- A weekly league with 9 friendly bots (Bronze to Diamond; top 3 move up, bottom 2 move down). Real online leagues need a backend (see the AI tutor and backend issue).
- 14 badges and an end-of-lesson celebration screen.
- Daily reminders: a PWA notification nudge after the chosen time when the app is opened, plus an "Add to calendar" .ics file (daily repeat with alert) that is the reliable option on iPhone. True scheduled push needs a push server (Web Push / FCM) and will come with the native apps.

### Speaking (2026-10-17)
- Web Speech API (`SpeechRecognition` / `webkitSpeechRecognition`, en-GB, 3 alternatives, live partial text). Works in Chrome (Android/desktop) and Safari on iPhone (iOS 14.5+; needs Dictation on, otherwise the error is "service-not-allowed"). Audio is processed by the browser/OS speech service; the app stores nothing.
- Per-word pronunciation scoring (`lib/core/engine/pronunciation.dart`): word alignment against the target; contractions, numbers, British/American spellings and homophones count as clear; similar-sounding words count as "nearly". Score = clear + half of nearly; pass at 70%.
- Speak-the-reply mode in chats (the mic in the composer; saved per learner). The reply options are the targets: the best match is scored and coloured word by word (green/amber/red), auto-sent when it passes, otherwise Retry / Listen / Send anyway. Free speech that matches no option is sent as typed text.
- Graceful fallback: no recognition → help sheet + typing + Record-and-compare; mic denied → step-by-step permission help for iPhone and Android; no-speech / network errors → a short inline note.
- Limits: browser STT recognises words, not phonemes, so scoring reflects intelligibility. Phoneme-level scoring (e.g. Azure Pronunciation Assessment or Speechace) is planned with the backend proxy.

### Library — graded readers (run 1, 2026-10-17)
- Reached from the **library spot** on the town map ("Browse the shelves") and the menu (**Library · graded readers**). Route `/library`, reader `/read/<book>?ch=<n>`.
- Painted wooden shelves, one per CEFR level (A1 → C1). Covers are crops of existing scene paintings (no generated art yet; real covers listed in IMAGE_PROMPTS).
- **Content:** `app/tool/library/<level>.txt` (DSL: `# book`, `## chapter`, `English | Persian`, `Q:` quiz with the correct option first, `W:` glossary) → `tool/make_library.py` → `assets/data/library.json`. The build **fails if any word has no Persian gloss** (book W: > base function-word dictionary > names > course words, with simple lemmatising), so tap-to-translate never comes up empty.
- **Run 1:** 8 A1 books (83–113 words, 2 chapters, present simple / have got / can) and 8 A2 books (152–194 words, past simple, going to, comparatives). Original stories about the Thompsons, Mrs Patel's cat Biscuit, Priya's corner shop, Nana Maggie, Brighton, Christmas, a London fox and Ryan's first driving lesson.
- **Reader:** narrator (en-GB-SoniaNeural, -8%) reads aloud sentence by sentence with highlighting and auto-scroll; long-press a sentence to start there; speed 0.75×–1.15×; Persian translation toggle; tap any word (or phrase like "bus stop") for Persian + **Save to my words** (Leitner box). Chapter quiz (2 questions, shuffled) → Celebration with XP (10, 15 for 100%, 3 for a retry); passing every chapter marks the book **Finished** (green tick on the cover) and earns the **Finished!** / **Bookworm** (5 books) badges.
- Tests: `test/library_test.dart` (8+ books per shelf, glossary coverage, narrator clip for every sentence, A1/A2 length limits, British spelling, XP/finish logic, full shelf→reader→quiz→finished flow at 375×667).
- ~~Next runs: B1, B2, C1 shelves~~ → done in run 2. Still open: audio-synced word highlighting, a Library section in Progress, more books per upper shelf.

### Library — run 2: shelves B1, B2, C1 + shelf lock (2026-10-17)
- **14 new books** (2 chapters, 2 quiz questions each, 214–339 words, avg sentence 12–18 words):
  - **B1 (5):** The Flood Upstairs (Mrs Khan's leak, Dave the plumber), Quiz Night at the Red Lion (Big Dave, Alastair), Ryan's Saturday Job (Gareth's bakery), Grandad's Giant Marrow, The Wrong Train (Dover).
  - **B2 (4):** The Interview (Leslie's head-of-year panel, Ms Clarke as a governor), A Night in A&E (triage, William's wrist), Old Friends (Alastair, made redundant after 20 years in the City, becomes a lecturer in urban transport — matches canon; their student flat was in Glasgow), The Phone Call (Nana Maggie vs a bank scam, Siân at the real bank).
  - **C1 (5):** The Best Man (Tom at Alastair's wedding to Imogen), The Inspection (Acorns nursery: Jo, Mr Harris, Vida, Oscar), Letters from 1962 (George, Mr Bennett and a first love called Margaret), The Motion (Ryan's debate, Mr Patel: phones in school), Last Orders at the Post Office (Doris, Arthur).
  - Grammar per shelf follows the Grammar School classes (B1: present perfect, futures, 1st conditional, modals; B2: 2nd/3rd conditionals, passive, reported speech, used to; C1: inversion, mixed conditionals, wish, cleft, causative).
- **Voices per character:** a DSL line `speaker> "Quoted line" | Persian` voices *only the quote* with that character's edge-tts voice (voice ids from `render_voices.py`; an unknown id fails the build) and the reader shows the name in small red capitals above the line (`spk-<i>`). Narration stays with the narrator. A1/A2 books are still narrator-only.
- **Level glossaries:** `tool/library/gloss_<level>.txt` (`word=fa ; phrase=fa`) are merged under each book's own `W:` lines; common B1+ words (would, could, I'll, hadn't…) were added to the base dictionary; place names are glossed without the "اسم:" prefix; the tokenizer now keeps accented letters (café, Siân), and "A&E" is glossed as a phrase.
- **Shelf lock = Grammar School rule** (`library_gate.dart`): A1 always open; a higher shelf opens when the course reaches its level (A2=2 … C1=5), when the previous Grammar class is passed, when the previous shelf is finished, or when a book on it was already started (nobody loses a book mid-read). Locked shelves: grey badge with a padlock, "Locked · قفل", dimmed covers; tapping one explains why (EN + FA). The reader enforces the same lock on deep links (`book-locked`). Note: A2 is now locked for brand-new learners until any of the above.
- Canon fix: grammar examples in B1/C1 had Biscuit as "he" — Biscuit is a **she** (cat). Shelf header no longer overflows at 375 px with long level names.
- Tests: `library_test.dart` (B1/B2/C1 counts, per-character voices are known and pure quotes, clip per sentence using its own voice, shelf-gate unit chain to C1, B1+ length limits) and `library_lock_test.dart` (locked deep link, locked-cover snack, unlocked B1 reader shows the speaker label).

### Cinema & dubbing — run 1 (2026-10-18)
- **Where:** cinema spot on the town map ("Now showing · watch & dub scenes"; the Cinema, Library and Grammar School markers are never shown locked, since each has A1 content) and the menu (**Cinema & dubbing**). Routes `/cinema` (foyer, "The Picture House") and `/cinema/<scene>`.
- **Content:** `app/tool/cinema/scenes.txt` (DSL: `# id | level | title | titleFa | still | blurb | blurbFa | dub role`, `speaker: English | Persian`, `Q: question | correct ; wrong ; wrong`) → `tool/make_cinema.py` → `assets/data/cinema.json`. The build fails on an unknown voice, a non-canon speaker, a missing still or Persian, a dub role with fewer than 2 lines, or a bad quiz. After `render_voices.py`, run make_cinema again: each line gets `ms`, its real clip length (ffprobe).
- **10 original scenes** (no film clips, titles or quotes), stills are existing scene paintings with a slow pan, every line in its character's voice: A1 Toast or Cereal?, The Number 38 (Tom drives, Nana Maggie, William, Doris); A2 Three Pounds Twenty (Ryan, Priya), Who Ate the Cake?; B1 Have You Seen My Keys?, Ringing the Surgery (Tracy); B2 A Small Favour (Mrs Khan, polite British requests), On the House (Sophie at The Copper Kettle); C1 The Form (Ryan & Grandad George: sixth form or apprenticeship; inversion, cleft, wish), Parents' Evening (Leslie & Mr Patel).
- **Watch:** subtitles on the screen (speaker in gold), optional Persian subtitles, the script below (tap any line to hear it).
- **Dub:** pick a role (default per scene). The scene plays; on your lines a red "YOUR LINE" cue appears and the words light up at the original pace while you speak. Speech recognition → `Pronunciation.score` (per-word good/close/missed colours). "In time" = finished within the original clip length + 1.2 s; a late line is docked 20%. Results: overall %, lines in time, XP (15 at 90%+, 10 at 70%+, else 3), best kept in `cine:dub:<id>`. No microphone support → the usual mic help sheet.
- **Questions:** 3 per scene, shuffled; 2 of 3 passes (`cine:<id>`), XP like the Library; a watched scene gets a green tick, a dub score shows on its poster.
- **Level gate = Library/Grammar rule** (`CinemaGate`): A1 always; a level opens at its course level, when the previous Grammar class is passed, when every scene of the previous level is passed, or when a scene on it was already started. Locked posters explain why; deep links show a locked page.
- Tests: `cinema_test.dart` (content, voices, timings, British usage, gate + XP), `cinema_flow_test.dart` (foyer lock, locked deep link, watch, dub with a stubbed microphone: perfect → 100% / 3 of 3 in time, mumbled → low with word marks, best kept; questions → watched). `nav_test` covers `/cinema` routes.

### Library — A1/A2 voices + canon fixes (2026-10-18)
- 49 A1/A2 dialogue lines are now pure quotes voiced by their character (`speaker> "…"`), like B1–C1; split where a line mixed narration and speech. Mrs Patel (A1 *The Lost Cat*) and the old man (A2 *The Lost Wallet*) got their own voices on 2026-10-18 (`mrspatel`, `oldman`: minor characters with a voice and no portrait, named in make_library's CAST).
- Canon fixes: Biscuit is **Mrs Patel's cat, a she** (course: "she's too lazy"); A1 "Mr Patel's Shop" → **The Corner Shop**, run by **Priya** (Mr Patel is Ryan's maths form tutor); Tom and Alastair's student flat was in **Glasgow** and Alastair becomes a **lecturer in urban transport** (canon); Leslie keeps her **Year 4** class; "Letters from 1962" are from **Frank, George's childhood best friend** (Nana Maggie is Margaret, George's wife); the Cinema's George drove the 38 for 31 years, and Ryan (Year 10) is choosing sixth form vs an apprenticeship, not university.

### Radio — Hackney Hum, run 1 (2026-10-18)
- **Hackney Hum** is an invented local station (we checked it isn't a real London station). It has a rooftop studio on the glass office block (spot `radio`, 0.55/0.235, 📻, linked to 5 weather/news lessons), with a sheet button "On air", a menu item, and the routes `/radio` and `/radio/:id`.
- **Presenters** (station voices, not in characters.json): Bex (host, Libby), Malcolm (news, Ryan −10Hz), Grace (travel, en-NG Ezinne), Owen (weather, Thomas). Callers and guests are canon: Doris and George (grumbles), Mrs Khan and Ryan (car-free Mare Street), Mr Bennett (library vote), Maya (conductor), Gareth and Sal (adverts), Tom (the parrot on the 38).
- **Content:** `app/tool/radio/segments.txt` (`# id | level | kind | slot | title | titleFa | blurb | blurbFa`, then `speaker: English | Persian` and `Q:` lines) → `tool/make_radio.py` → `assets/data/radio.json`. There are 10 programmes, 2 per level, covering every kind: news, weather, travel, phone-in and advert. The build checks voices, speakers, Persian, words per line (A1 9 / A2 13 / B1 20 / B2–C1 28) and 3 questions per programme. It also bans transport-operator branding (TfL, Tube, Overground, Oyster); travel news uses generic terms (the trains, rail replacement buses, road names).
- **Listening first:** the transcript is hidden every time a programme opens. There is an "ON AIR" radio set with the speaker's name, an equaliser, play/stop, progress and a "Slower" toggle. "Show transcript" and then "فارسی" are optional. The Questions button turns red once you've listened all the way through. Progress is stored in `radio:<id>` (best score; 60% passes; XP 15/10/3).
- **Level gate = Library/Cinema/Grammar rule** (`RadioGate`). Locked programmes explain why, and deep links show a locked page.

### Feature queue (approved by the user, 2026-10-17) — each a map spot/section, uncluttered, short runs
1. **Grammar School** (school spot + menu): classrooms "Class A1 · مبتدی" … C1, Mrs Ellis (canon name) explains with a British voice + Persian, Thompson-family examples, gap-fill / reorder / choose / transform, mini test per topic, XP, unlocks in order, links to related lessons. — **Run 1 shipped 2026-10-17: Class A1 + A2. Run 2: Class B1 + B2. Run 3: Class C1 + strict lock — all five classes live.**
2. **Cinema**: short scenes with bilingual subtitles, tap-to-translate, "dub it" mode with a speech score (paintings + audio now; real video later). — **Run 1 shipped 2026-10-18: 10 scenes A1–C1, watch / dub / questions.**
3. **Radio**: a short daily podcast by the characters (Tom's local news, George's grumbles), transcript + Persian. — **Run 1 shipped 2026-10-18: Hackney Hum, 10 programmes A1–C1 (news, weather, travel, phone-in, adverts), listening first, questions.**
4. **Real-life missions**: weekly real-world tasks, tick off, XP/badges.
5. **Family voice messages**: daily voice notes from Nicola/Leslie/Tom, reply by voice, tied to the reminder.
6. **Park games**: matching, find-the-object in a painting, speed rounds.
7. **Life in the UK test prep** (in the Library; premium pack candidate; **not affiliated with or endorsed by the Home Office**; original summaries and questions only, no copying or translating handbook text; point users to the official handbook and GOV.UK booking).
8. **Seasonal events**: Christmas, Halloween, Bonfire Night, Nowruz, Easter — themed town + special lessons.
9. **Driving School** (premium candidate; **not affiliated with or endorsed by DVSA**; original questions only, each logged against a Highway Code rule; OGL attribution for the Highway Code and sign images; no DVSA questions, hazard clips, logos or "official" claims without a DVSA licence; call it "hazard awareness practice"): instructor English (mirror-signal-manoeuvre, roundabouts, test day) tied to Ryan at 17; Theory Test prep with Highway Code vocabulary, road signs, **original** practice questions (never DVSA's bank), mock tests, Hazard Perception explainer.
10. **London Tour** (red sightseeing-bus spot): Big Ben/Elizabeth Tower, Parliament, Westminster Abbey, Buckingham Palace, Tower of London, Tower Bridge, London Bridge, St Paul's, London Eye, British Museum, Trafalgar Square, Camden, Greenwich…; guide narration with web-verified history, Persian, saveable words, quiz, XP; the family tags along; A2–B2 versions.
11. **UK accents** (Cockney, Scouse, Geordie, Scottish, Welsh, Brummie…) listening with comprehension.
12. **Phone-call simulator** (GP, bank, energy, school), audio only, hint button — phone box spot.
13. **Job interview practice** with feedback, linked to Career Packs — job centre spot.
14. **Forms & letters**: UK-style forms (GP registration, job application, school) and formal emails/letters — post office/council spot.
15. **What Brits really mean**: hidden meanings, small talk, humour, queueing/apologies — pub spot.
16. **Family mode**: parents + kids learn together (kids play Nicola/William), parent progress view — home.
17. **AI coach "My mistakes"** notebook generating personal practice — home.
Then Parts 3–5: AI tutor scaffold, Android build, payments scaffold.

### Legal fixes (2026-10-17, from docs/LEGAL_REVIEW.md)
- Mic wording corrected (EN+FA): speech-to-text is done by the browser's service (Google in Chrome, Apple in Safari), which may process audio on its servers; The Toms never stores or sends recordings itself.
- Certificates: "Awarded to … for completing The Toms course content", "aligned to CEFR descriptors", and "Not an accredited qualification. CEFR level is an indication only." on the certificate itself.
- Career Packs: a "Please note" disclaimer on every pack page (language practice only, not training or a qualification; follow your workplace's policies); the nursery pack adds the England-only EYFS context, the ratio caveat (1:8 for 3–5s, 1:13 with a qualified teacher; check your setting) and "does not replace safeguarding / paediatric first aid / Level 2–3 training". The u02 ratio culture note now says the same.
- New **Privacy, terms & about** screen (`/legal`, menu item): draft Privacy Policy and Terms of Use in EN+FA with placeholders [BUSINESS NAME], [POSTAL ADDRESS], [CONTACT EMAIL]; accurate about local-only storage, no accounts/analytics/ads, speech via the browser, GitHub Pages logs, synthetic voices, trade-mark and non-affiliation lines. Needs a solicitor's review and a public URL before store submission.
- IMAGE_PROMPTS: "roundel" removed; no-logos rule added. Store keywords and taglines: no Duolingo/IELTS/official.
- Still open (not code): licensed TTS re-render before charging (edge-tts is personal-use only), ICO fee, DPIA before Family Mode/AI chat, trade-mark search for "The Toms".

## Grammar School — run 1 (2026-10-17)
- **Where:** school spot on the town map + menu item "Grammar School" → `/school` → `/school/:level` → `/grammar/:id`.
- **Classrooms:** A1 · مبتدی, A2 · مقدماتی open now; B1–C1 show "coming soon". A1 is always open; a class opens when the previous one is passed or the course reaches that level.
- **Class A1 (6):** be (am/is/are), have got / has got, a/an/the, plurals, present simple, can/can't.
- **Class A2 (5):** past simple regular, past simple irregular, present continuous, present simple vs continuous, comparatives & superlatives.
- **Each topic:** Mrs Ellis teaches on a chalkboard (British TTS voice "ellis" + Persian), examples from the Thompsons' life, links to up to 3 related course lessons, 6 practice items (gap / choose / reorder / transform, instant feedback with the right answer), then a 5-question mini test. Pass mark 60%; 10 XP (15 for 100%), 3 XP for a try. Topics unlock in order.
- **Content pipeline:** `tool/grammar/a1.txt`, `a2.txt` (DSL) → `tool/make_grammar.py` → `assets/data/grammar.json` (validated; related lessons auto-linked by grammar tag). `render_voices.py` walks grammar.json.
- **Tests:** `test/grammar_test.dart` (content rules, British spelling, audio for every line, answer checking, unlock order, full flow at 375×667).
- **Run 2 (2026-10-17): Class B1 (5)** present perfect (ever/never/just/already/yet), present perfect vs past simple, future forms (will / going to / present continuous), first conditional (+ unless), modals (have to / must / mustn't / should / might). **Class B2 (5)** second conditional (If I were you…), third conditional + should have, the passive, reported speech (say/tell, asked if), used to / would / be used to. Same format: 6 practice + 5 test, Mrs Ellis voice, related lessons only at or below the class level. B1 opens when A2 is passed (or the course reaches Level 3); B2 after B1 (or Level 4).
- **Screenshot tooling:** `/workspace/stage/lib_shots.py` now takes `preset=@file.json` (writes a UserProgress JSON into the Hive IndexedDB box `progress`/`box` key `v1`, then reloads on `#/`) so shots skip onboarding; plus `hscroll=` (pan the town map), `type=`, `dumpdb=`. `preset_new.json` = a fresh, onboarded learner; `screenshot_preset_a2done.json` = A1+A2 passed. Copies live in `app/tool/`. Map: `hscroll=-700 wait=4000` brings St Mary's School + Library into view (wheel pans ~0.4 px per unit; wait for it to settle before tapping).
- **Run 3 (2026-10-18): Class C1 (5)** inversion (Never have I… / Not only… / No sooner…), mixed conditionals, wish / if only / it's (high) time, cleft sentences (What I need is… / It was… who…), causative and advanced passive (have it done / is said to / is thought to have…). C1 opens when B2 is passed (or the course reaches Level 5).
- **Strict lock:** the topic page itself checks `GrammarGate.topicOpen`; a deep link to a locked topic shows `TopicLocked` (why it's locked in EN + FA, a button to the topic that opens it when the class is open, otherwise back to the school). Tested in `test/grammar_lock_test.dart` (own file: a second app pump in one file hangs on cached asset futures).
- **Next runs:** Library shelves B1–C1; then Cinema.
