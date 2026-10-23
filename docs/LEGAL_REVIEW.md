# New Life UK (formerly "The Toms: British Life Immersion"): UK legal and compliance review

> **App renamed to "New Life UK" (2026-10-23).** The family in the stories is still "the Toms". Quick clearance check done (see below); **a solicitor / trade mark attorney must confirm the name before monetising.**

*Prepared 17 October 2026. Research summary only. Personal and situation-specific details were removed before publishing (18 Oct 2026).*

> **This is not legal advice.** It is a research-based checklist from public sources, put together to help plan the work and to brief a professional. Laws, platform rules and dates change. Before you take payments, launch to children, or license DVSA content, get a UK solicitor (and an accountant for tax) to check the points marked **⚖️ Solicitor**.

**Scope:** The Flutter PWA (the live web app on GitHub Pages), the planned iOS/Android apps, Persian-speaking users, the planned paid subscription (£4.99/month, £34.99/year, 7-day trial) and paid Career Packs (£9.99), for a UK-based business.

**Repo check:** I reviewed the project files directly. I scanned `app/lib`, `app/assets/data`, `app/tool` (lesson sources, voice renderer, nursery pack), `app/web`, the docs, and a contact sheet of all 40 scene paintings plus the map. Concrete findings are marked **🔎 Repo**.

---

## 0. Risk dashboard

| # | Area | Risk now | Risk at paid launch | Top action |
|---|------|----------|---------------------|------------|
| 6 | AI voices (edge-tts) | **High** | **High** | Re-render every clip with a licensed paid TTS (e.g. Azure AI Speech paid tier) before charging money |
| 7 | Microphone, privacy, children | **High** | **High** | Fix the "nothing is sent anywhere" claim, publish a privacy policy, do a DPIA, apply the Children's Code before Family Mode |
| 1 | Driving theory test | Med (planned) | **High** if DVSA questions or clips are used | Use only the OGL Highway Code, OGL sign images and your own questions, or get a DVSA licence |
| 8 | Payments and subscriptions | Low (beta, no charge) | **High** | Store billing, CCR cancellation and waiver flow, DMCCA subscription rules from **Jan 2027** |
| 11 | Required documents and store claims | Med | **High** | Privacy policy, terms, accessibility statement; no "Duolingo" or "IELTS" in store metadata |
| 5 | Career Packs and certificates | Med | Med | Disclaimers; certificate wording "not an accredited qualification"; check safeguarding facts |
| 2 | Life in the UK prep | Med (planned) | Med | Don't copy the handbook; your own questions; "not affiliated with the Home Office" |
| 4 | Brand names | Low | Low–Med | Plain-text mentions only; no logos, roundel or NHS lozenge; no endorsement |
| 3 | London Tour | Low | Low | Original paintings; check facts; no royal or Parliament emblems |
| 9 | Practice-league bots and streaks | Low (already disclosed) | Med | Keep the bot disclosure; no fake "real users"; no guilt-tripping or paid streak repair pressure on children |
| 10 | Accents | Low | Low | Respectful, authentic framing; get native-speaker review |
| 12 | Business set-up | Med | Med | ICO fee (£52), UKIPO trade mark search and filing, sole trader → Ltd before scaling |

---

## 1. UK Driving Theory Test prep: risk MEDIUM now, HIGH if done wrong

**The law and rules**
- DVSA: *"It's a criminal offence to use DVSA theory test questions or hazard perception clips in a product without a licence."* Making a product with revision questions or practice hazard perception clips needs a **DVSA Crown copyright licence**. It is free to apply, lasts 3 years, needs artwork approval and a Crown copyright acknowledgement, and you pay **quarterly royalties**. There is a separate **Translation** licence for non-English products, which matters for a Persian version. Source: https://www.gov.uk/guidance/make-and-sell-driving-theory-test-revision-products
- **The Highway Code and traffic sign images do not need a DVSA licence.** They are Crown copyright under the **Open Government Licence (OGL v3)**. You must reproduce signs accurately, not use them in a misleading context, and include a Crown copyright or OGL attribution. Sources: https://www.gov.uk/guidance/traffic-sign-images · https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/ · https://dvsadigital.blog.gov.uk/2017/01/20/one-million-appy-users/
- "Official DVSA" products are a separate DVSA and TSO line. DVSA says it does not endorse licensees' products (https://www.whatdotheyknow.com/request/a_full_list_of_all_dvsa_crown_co).

**What's fine**
- Teaching driving-lesson English (mirror, signal, manoeuvre; roundabouts) through Ryan's story, written by you.
- Quoting or paraphrasing Highway Code rules with OGL attribution, and using the GOV.UK sign image files.
- Explaining how the hazard perception test works, in your own words.
- Original multiple-choice questions you wrote from the Highway Code (not reworded DVSA bank items).

**What to change or avoid**
- Don't use DVSA revision questions, "knowledge and understanding" text or hazard perception clips, or close copies of them, unless you hold a licence.
- Don't make your own fake "hazard perception clips" that copy DVSA's format or scoring closely and call them "practice tests". Call it "hazard awareness practice".
- No "official", "DVSA approved", "real test questions", "pass guaranteed" or DVSA/GOV.UK logos. The crown and the GOV.UK logo are not covered by OGL.

**Actions**
1. Write the question bank yourself and keep a source log (Highway Code rule number for each question).
2. Add the attribution: "Contains public sector information licensed under the Open Government Licence v3.0. Traffic sign images © Crown copyright."
3. Add the disclaimer: "Not affiliated with or endorsed by DVSA. Practice questions are original and are not the questions used in the real test."
4. If real DVSA questions or clips (the strongest sales feature) are wanted later, apply for the Standard licence and the Translation licence for Persian, and budget for royalties. **⚖️ Solicitor** to review the licence agreement.

🔎 **Repo:** no DVSA or Highway Code material yet (the "driving" scene is only a lesson setting). Nothing to fix yet.

---

## 2. Life in the UK test prep: risk MEDIUM

**The law and rules**
- The official handbook, *Life in the United Kingdom: A Guide for New Residents* (3rd ed., TSO), is Crown copyright and **sold commercially by TSO**. Prep-app operators generally treat it as **not freely reusable under OGL**. Don't assume OGL covers it. Sources: https://www.tsoshop.co.uk/Society/Life-in-the-UK · https://iknowtheuk.com/sources (example of how a prep site handles this) · OGL scope: https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/open-government-licence/
- Some sites say they reuse it "with the permission of The National Archives under OGL" (https://law.stackexchange.com/questions/46378). Licensing status is **unclear**, so get written confirmation from The National Archives (psi@nationalarchives.gov.uk) or TSO before copying any text.
- Facts themselves (dates, history) aren't copyright. The handbook's wording, selection and structure are.
- Official test info: https://www.gov.uk/life-in-the-uk-test

**What's fine:** Original summaries, original questions, citing facts from several sources, saying "covers the topics in the official handbook".

**What to change or avoid:** Copying or translating handbook chapters word for word; using the Home Office, crown or GOV.UK logos; "official practice test"; "pass guaranteed".

**Actions:** Write original content. Add "Not affiliated with or endorsed by the Home Office. Buy the official handbook from TSO." Link to GOV.UK for booking. **⚖️ Solicitor** (or written TNA/TSO confirmation) before reusing any handbook text. The Persian translation of handbook text counts as an adaptation and has the same issue.

🔎 **Repo:** only a planned lesson ("U228 · Life in the UK test") and marketing keywords in `MASTER_BOOK.md`. Nothing copied.

---

## 3. London Tour (landmarks): risk LOW

**The law and rules**
- **Freedom of panorama:** CDPA 1988 **s.62** allows paintings, drawings, photos and film of **buildings** and of sculptures or works of artistic craftsmanship permanently in public places. https://www.legislation.gov.uk/ukpga/1988/48/section/62
- **Photos** taken by other people are their copyright. Don't scrape Google Images. Use your own photos, **original AI paintings** (as the app does now), or properly licensed or CC images with attribution.
- Commercial filming or photography *on* the Parliamentary Estate, in the Royal Parks or at Historic Royal Palaces sites needs permission. Using a painting *of* the view from public land does not. https://www.parliament.uk/visiting/access/photography-filming-and-mobile-phone-use/ · https://www.royalparks.org.uk/ · https://www.hrp.org.uk/
- **Emblems:** the Royal Arms, royal cyphers, Parliament's crowned portcullis and the HRP and Royal Parks logos are protected. Don't show them as badges or imply royal or Parliament approval. Landmark *names* (Big Ben, Tower Bridge, Buckingham Palace) are fine to use descriptively. Don't use them as your product or pack *brand name* without a trade mark check. Background: https://www.citma.org.uk/resources/how-are-landmarks-protected-by-intellectual-property-rights-blog.html

**Actions:** Use original paintings. Check every date and fact against primary sources (UK Parliament, HRP, the Royal Collection Trust, British Museum sites) and keep a source list. For example, "Big Ben" is the bell; the tower was renamed Elizabeth Tower in 2012. Avoid statements about living royals. Add a "Tour facts last checked: <date>" line.

🔎 **Repo:** the map painting has a Westminster-like skyline. No emblems seen. Fine.

---

## 4. Brand names in lessons: risk LOW (MEDIUM if logos are used)

**The law and rules**
- Naming real brands in **plain text** to describe real life ("I'll pop into Tesco", "top up your Oyster") is generally allowed as descriptive or referential use, as long as it is honest, doesn't suggest a commercial connection and doesn't harm the brand. See Trade Marks Act 1994 s.11 (limits on infringement): https://www.legislation.gov.uk/ukpga/1994/26/section/11
- **NHS:** commercial organisations must **not** use the NHS logo (the blue lozenge), and must not suggest NHS endorsement. Plain-text references are fine. https://www.england.nhs.uk/nhsidentity/identity-guidelines/who-can-use-the-nhs-identity/
- **TfL:** the roundel, the Oyster logo and card design, "Underground" and line diagrams are TfL trade marks or copyright. Third parties need TfL's written licence to use them in apps or images. https://tfl.gov.uk/info-for/business-and-advertisers/using-tfl-brand-ip · https://content.tfl.gov.uk/tfl-ip-guidance.pdf · https://tfl.gov.uk/info-for/open-data-users/design-and-branding
- **Ofsted / EYFS:** names are fine as descriptions. The Ofsted logo and the crown/GOV.UK marks are not. The EYFS framework text is OGL (attribute it). https://www.gov.uk/government/publications/early-years-foundation-stage-framework--2
- **Clubcard, Freedom Pass, Royal Mail, Boots, Greggs, Pret, Barclays, Arsenal, BBC, Netflix, Uber** and so on: the same principle applies. Use them in text only, keep the portrayal neutral or positive, and say nothing false or defamatory (e.g. "Tesco overcharged me" written as a fact about the real company).

🔎 **Repo:** brand mentions in lesson data, counted case-insensitively and including some false hits: NHS ~179, Oyster ~42, TfL ~32, Ofsted ~42, EYFS ~26, Freedom Pass ~27, Clubcard 7, Tesco 4, Royal Mail 9, Barclays 8, Arsenal ~61. All are **text only**. `IMAGE_PROMPTS.md` already says "no real brand logos", and I saw **no logos, roundel or NHS lozenge** in the 40 scene paintings or the map at thumbnail scale. One prompt asks for a **"roundel sign"** at a Tube station (IMAGE_PROMPTS.md, map and tube prompts). Don't render a TfL roundel in future art.

**Actions:**
- Add an "About trade marks" line to the terms or credits: "Brand and place names are used for realistic, descriptive purposes. The Toms is not affiliated with or endorsed by any of them."
- Never put real logos in art or icons. Remove "roundel" from the image prompts.
- Keep the portrayal of real companies factual.

---

## 5. Career Packs (nursery/EYFS, and planned nurse, police, care): risk MEDIUM

**Issues:** People may rely on the content at work, especially safeguarding, first aid, ratios and allergies. A paid "career" product and a "certificate" could be read as job training or a qualification.

🔎 **Repo:**
- The nursery pack covers safeguarding, first aid, allergies, ratios and Ofsted (`tool/career/nursery/u01–u06`). The ratio note (*"For ages 3–5 in England it's usually 1 adult to 8 children"*) is broadly right, but EYFS allows 1:13 where a qualifying teacher works directly with the children, and it is England-only. Add "check your setting's policy". EYFS ratios: https://www.gov.uk/government/publications/early-years-foundation-stage-framework--2
- `certificate_screen.dart` says "Certificate of Completion… This is to certify that… has completed Level X · <CEFR>". It has **no "not accredited" line**, and it states a CEFR level.
- `MASTER_BOOK.md` plans **"Official level certificates — CEFR-aligned"**. "Official" must go.

**Actions:**
1. Pack disclaimer, shown at pack start and in the store listing: "English-language practice only. Not professional training or an accredited qualification. It does not replace your employer's induction, safeguarding, paediatric first aid or Level 2/3 training. Always follow your setting's policies and the current EYFS framework (England)."
2. Add to the certificate: "Certificate of completion of The Toms course content. Not an accredited qualification and not a CEFR, IELTS, Ofqual-regulated or Home Office-approved English test." Write "aligned to CEFR descriptors" rather than "Level B1". Never say "official".
3. Have someone with real experience in the sector review the safeguarding and first-aid content. Add a "last reviewed" date and cite the source (EYFS, Working Together to Safeguard Children, NHS first aid pages).
4. For the police and nurse packs, avoid procedural advice that could be wrong (e.g. clinical doses, legal powers). Keep it to communication.

---

## 6. AI voices and images: risk HIGH (voices)

**Voices: the most urgent legal and business issue**
🔎 **Repo:** `app/tool/render_voices.py` makes **every** spoken line with **`edge-tts`** (`en-GB-RyanNeural`, `SoniaNeural`, `MaisieNeural`, `LibbyNeural`, `ThomasNeural`, and en-IE/en-IN/en-AU/en-KE voices). The MP3s ship in `assets/audio`.
- `edge-tts` is an unofficial client for the **Microsoft Edge "Read Aloud"** consumer endpoint. Microsoft's general terms limit services to **personal, non-commercial use**. Microsoft moderators say redistributing Read Aloud audio is unsupported and point to **Azure AI Speech** for publishing or monetising. The edge-tts maintainer says the library "is meant for personal use" and is unreliable for business. Sources: https://learn.microsoft.com/en-us/answers/questions/5730260/inquiry-about-using-read-aloud · https://www.microsoft.com/en-us/legal/terms-of-use · https://github.com/rany2/edge-tts/discussions/261 · https://learn.microsoft.com/en-us/answers/questions/5925556/commercial-use-of-edge-read-aloud-voices-via-edge
- **Azure AI Speech, paid tier (S0):** the output of prebuilt neural voices may be used commercially, subject to the Azure Acceptable Use Policy and the TTS code of conduct, including disclosure that voices are synthetic. The free F0 tier is reportedly not for commercial use. https://learn.microsoft.com/en-us/answers/questions/5987029/can-audio-generated-with-azure-text-to-speech-be-p · https://learn.microsoft.com/en-us/answers/questions/5805156/ · https://learn.microsoft.com/en-us/legal/cognitive-services/speech-service/text-to-speech/code-of-conduct
- **Status (23 Oct 2026, run 23): done.** Every clip is re-rendered through the Azure Speech REST API on the owner's paid S0 resource (uksouth); the edge-tts audio is kept only as an offline backup outside the app, and the app says "Voices are AI-generated (text-to-speech), not real people" in the menu and in About.
- **Original action:** move `render_voices.py` to the official Azure Speech SDK on a paid subscription, keeping the same voice names so it sounds the same, and **re-render all clips**. Alternatives are Google Cloud TTS, Amazon Polly or ElevenLabs on a commercial plan. Keep the invoices or terms as proof of licence. Add a credit: "Voices are synthetic (text-to-speech)." Rough cost: Azure neural TTS is priced per million characters, so check current pricing. **⚖️ Solicitor** only if you want to keep the existing edge-tts audio.

**Images**
- **Ownership:** UK CDPA **s.9(3)** still protects "computer-generated" works, with the author being the person who made the arrangements. The government's March 2026 report proposes **removing** this, which is not yet law. So your rights in the AI paintings may be **thin or uncertain**, and competitors might copy them. Also check the image tool's terms (commercial use allowed? ownership assigned?). https://www.gov.uk/government/publications/report-and-impact-assessment-on-copyright-and-artificial-intelligence/report-on-copyright-and-artificial-intelligence
- **Likeness:** don't prompt for real people (celebrities, royals, real teachers) or "in the style of" living artists or named illustrators. Characters are fictional, which is fine. Don't use real people's names in content. The audio uses a default name for the learner placeholder `{you}`. Before selling the app, make sure it is a neutral, fictional name.
- **Action:** keep a log of the prompts and tool terms for each asset. Where the art is a core brand asset, consider human retouching to strengthen copyright.

---

## 7. Microphone, voice data, children: risk HIGH

**The law and rules**
- **UK GDPR and DPA 2018:** you need a lawful basis, transparency (a privacy notice), data minimisation, security and data subject rights. https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/
- **Children's Code (Age Appropriate Design Code):** applies to apps **likely to be accessed by under-18s**, not only apps aimed at children. A family story with child characters, a nursery setting and a planned Family Mode will very likely count. It has 15 standards: best interests, **DPIA**, age-appropriate application, transparency, no detrimental use, policies, **high-privacy defaults**, data minimisation, data sharing, geolocation off, parental controls, **profiling off**, **no nudge techniques**, connected devices, and online tools. https://ico.org.uk/designstandards · https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/services-covered-by-this-code/
- **UK GDPR Art. 8:** where you rely on consent for an online service offered to a child, the UK age is **13**. Below that, you need parental consent.
- **Speech recognition:** in **Chrome**, the Web Speech API sends microphone audio to **Google's servers**. Safari on iOS uses Apple's speech service (sometimes on-device). https://web.archive.org/web/20230320152006/https://www.google.com/chrome/privacy/whitepaper.html · https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API/Using_the_Web_Speech_API
- **Voice data:** voice is personal data. If it is used to identify someone, it becomes biometric special-category data. Avoid that.

🔎 **Repo:**
- **Inaccurate privacy statement (fix now):** `lib/features/speaking/speaking_widgets.dart` says *"The Toms only listens while the microphone is red, and nothing is recorded or sent anywhere."* `lib/core/platform/speech_web.dart` says "Everything stays on the device." That's true for The Toms' own servers (there are none), but **Chrome and Safari send the audio to Google or Apple to transcribe it**. Suggested wording: "Speech is turned into text by your browser's speech service (Google in Chrome, Apple in Safari), which may process your voice on its servers. The Toms doesn't store or receive your recordings. 'Record' clips stay on your device." Where supported, use on-device recognition (`processLocally`).
- Good: no analytics, no ads SDK, no accounts. Progress is stored locally (Hive). `GoogleFonts.config.allowRuntimeFetching = false`, so no calls to Google Fonts. The GitHub Pages host logs IP addresses, so mention GitHub in the privacy policy.
- No privacy policy or terms anywhere in the app (grep for "privacy" or "terms" found nothing).
- The certificate stores a user-entered name locally. Fine, but disclose it.

**Actions:**
1. Fix the microphone wording (above). Make the microphone opt-in, with a clear first-use explanation.
2. Publish a privacy notice in English and Persian. Cover the controller (you, with contact details), what is processed (local progress, certificate name, microphone audio through Google or Apple, GitHub hosting logs, later payments through Apple, Google or Stripe), lawful bases, retention, rights, the ICO complaint route and international transfers.
3. Do a **DPIA** before launching Family Mode or any account, cloud sync, AI conversation or analytics. The ICO template is at https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/accountability-and-governance/data-protection-impact-assessments-dpias/
4. **Family Mode / under-13s:** default to the highest privacy settings. No cloud speech for child profiles unless a parent turns it on. No profiling or behavioural nudges, no public leaderboards, no social features, no ads, and no third-party analytics. Put a parental gate in front of purchases and links. Consider an age gate at onboarding.
5. **AI conversation (planned):** if typed or spoken input goes to an LLM or STT provider, sign a data processing agreement, turn off training on user data, minimise what is sent, and say so in the privacy notice. This needs a DPIA. **⚖️ Solicitor or privacy consultant** before launching AI chat to children.
6. If analytics are added later, use privacy-friendly, cookieless or first-party tools. See PECR (below).

---

## 8. Payments and subscriptions: risk LOW now (beta), HIGH at launch

🔎 **Repo:** `lib/core/data/premium.dart` has `betaFree = true`, and the screen says "No payment is taken… Prices are examples." That's fine for the beta. Before switching it on:

**App stores**
- **Apple 3.1.1 / 3.1.2:** digital content and subscriptions in the iOS app must use **In-App Purchase**. Auto-renewing subscriptions must give ongoing value and last at least 7 days. Free trials must be clear, with no bait-and-switch. Show the price, period, renewal terms, and links to Terms (EULA) and Privacy on the paywall. Include **Restore Purchases**. https://developer.apple.com/app-store/review/guidelines/
- **Google Play:** use Play Billing for digital goods (UK alternative or user-choice billing options exist, so check), and follow the subscriptions policy on clear trial terms and easy cancellation. https://support.google.com/googleplay/android-developer/answer/140504 · https://support.google.com/googleplay/android-developer/answer/9900533
- The CMA has designated Apple and Google with **strategic market status** in mobile platforms (Oct 2025), so steering and billing rules in the UK may change. Check them when you launch. https://www.gov.uk/cma-cases/mobile-platforms-sms-investigations
- Commission: apply for the **Apple App Store Small Business Program** (15%). Google charges 15% on subscriptions.

**UK consumer law**
- **Consumer Contracts Regulations 2013:** pre-contract information and a 14-day cancellation right. For **digital content** (Career Packs), the right is lost only if the consumer **expressly consents** to immediate supply **and acknowledges** losing it (reg. 37). For **services** (subscriptions), the consumer pays proportionately if they asked for the service to start in the cancellation period. Build this consent step into web or Stripe checkout. Apple and Google handle it in-store. https://www.legislation.gov.uk/uksi/2013/3134/regulation/37
- **Consumer Rights Act 2015:** digital content must be of satisfactory quality and as described. Remedies apply. Don't exclude them in your terms.
- **DMCCA 2024 subscription contracts regime: now due January 2027.** It was brought forward from spring 2027, and the secondary legislation and guidance were still pending at the time of writing. It requires clear pre-contract information, **reminders before a free or discounted trial ends** and before 12-month+ renewals, **easy online cancellation** (exit as easy as joining), and a **new 14-day cooling-off period after a trial ends and after annual renewal**. Your £34.99/year plan with a 7-day trial falls squarely in scope. Sources: https://www.tlt.com/insights-and-events/insight/dmcc-act-subscription-contracts-regime-brought-forward-by-the-pm-what-do-businesses-need-to-know · https://www.gov.uk/government/news/consumers-to-save-around-400-million-every-year-from-government-crackdown-on-costly-subscription-traps · https://connectontech.bakermckenzie.com/uk-government-accelerates-dmcca-subscription-reforms-to-january-2027/
- **Price display (DMCCA unfair commercial practices, in force since 6 April 2025):** show the **total price including VAT** up front, with no drip pricing. "Save X%" claims must be accurate (the code works it out, which is good) and the comparison must be fair. https://www.gov.uk/government/publications/unfair-commercial-practices-cma207/unfair-commercial-practices

**VAT and tax**
- Through **Apple and Google**, the store is the deemed supplier or merchant of record and accounts for VAT on consumer sales. You get the proceeds net of VAT and commission.
- For **direct web sales (Stripe)**: UK VAT applies once your UK taxable turnover goes over **£90,000**. Sales of digital services to **EU consumers** carry EU VAT **from the first sale** (no threshold for non-EU sellers), handled through the **non-Union OSS**. A **merchant of record** like Paddle or Lemon Squeezy avoids this. https://www.gov.uk/guidance/the-vat-rules-if-you-supply-digital-services-to-private-consumers · https://www.gov.uk/vat-registration/when-to-register
- Register for Self Assessment (sole trader) or Corporation Tax (Ltd). **⚖️ Accountant.**

**Sanctions (Persian-speaking market)**
- Some countries where the target audience lives are under UK, US or EU sanctions, and major app stores and payment providers don't serve users there. Free access to educational content is generally lower-risk. Don't take payments through intermediaries in sanctioned jurisdictions. Guidance: https://www.gov.uk/government/collections/uk-sanctions-regimes · **⚖️ Solicitor** before planning any payment route for users in a sanctioned jurisdiction.

**Actions:** use store billing on mobile and a merchant of record on the web. Write a paywall checklist: total price incl. VAT, renewal period, trial end date, how to cancel, links to terms and privacy, restore purchases. Add trial-end and renewal reminders, one-tap cancellation, and the CCR waiver checkbox for packs. Plan for the DMCCA by Jan 2027.

---

## 9. Practice-league bots and streaks: risk LOW (well handled), MEDIUM if changed

🔎 **Repo:** `progress_screen.dart` shows the league with *"Practice league with friendly bots while online leagues are being built."* That's good disclosure.
- Under the DMCCA (Part 4, Ch.1), it would be a **misleading action or omission** to present bots as real people (fake names and photos, "you beat 30 learners") or to invent social proof ("10,000 learners this week"). The CMA can now fine directly, up to 10% of global turnover. https://competitionandmarkets.blog.gov.uk/2025/03/10/our-new-consumer-enforcement-regime/
- **Streak dark patterns:** see the CMA's paper on harmful online choice architecture (confirmshaming, false urgency, pressure to pay). https://www.gov.uk/government/publications/online-choice-architecture-how-digital-design-can-harm-competition-and-consumers · Children's Code standard 13 (no nudge techniques).

**Actions:** keep the bot disclosure next to the board, and label bot rows (e.g. a 🤖 icon). Never tie paid upsells to streak loss ("Pay £1.99 or lose your 30-day streak"), and don't use guilt messages. For child profiles, turn off the league, streak pressure and notifications by default. Keep the "streak freeze" free or earned.

---

## 10. Accents feature: risk LOW

- The Equality Act 2010 covers race, which includes nationality and ethnic or national origins, so accent mockery can feed discrimination. In an app the main risks are **reputational** and **store content policy** (Apple 1.1 objectionable content). https://www.legislation.gov.uk/ukpga/2010/15/section/9
- 🔎 **Repo:** characters use en-IN, en-IE, en-KE and en-AU neural voices for some roles (e.g. Priya/Patel/Khan en-IN, Zara en-KE, Bilal en-IN). That's fine, but make sure these characters aren't stereotyped (only in service jobs, or the butt of jokes). Synthetic voices for Cockney, Scouse, Geordie, Scottish and Welsh **don't exist** as real regional TTS, and "fake" accents made by pitch-shifting would be inaccurate and could come across as mockery.

**Actions:** present accents as "how real people speak", with respect, and include RP alongside the regional accents. Use **licensed recordings of real speakers** (with consent and a contract) or properly licensed corpora, not pitch-shifted TTS. Avoid class and intelligence clichés. Get native speakers from each region to review.

---

## 11. Required documents and store listing claims: risk MEDIUM → HIGH at launch

| Document | Needed? | Notes |
|---|---|---|
| **Privacy policy** | **Yes**, now. Both Apple and Google require a URL | English + Persian; see §7 |
| **Terms of use / EULA** | Yes, before payments | Licence to use, subscriptions, refunds per CRA/CCR, acceptable use, disclaimers (career, driving, LITUK, not legal or medical advice), governing law (England & Wales). Apple's standard EULA can be used on iOS |
| **Cookie / storage notice** | Light-touch | PECR: storage that is *strictly necessary* for a feature the user asks for (progress in IndexedDB or Hive, the service worker cache) needs no consent, but explain it. Any analytics or ads need consent (the Data (Use and Access) Act 2025 relaxes some analytics cases, so check the ICO's updated guidance). https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guide-to-pecr/cookies-and-similar-technologies/ |
| **Accessibility statement** | Best practice (legal duty for public bodies only) | Aim for WCAG 2.2 AA: captions or transcripts (you have text), contrast, screen-reader labels. Equality Act duties for service providers apply. https://www.w3.org/TR/WCAG22/ |
| **Age rating** | Yes | Apple and Google questionnaires. Medical or safeguarding topics and mild peril probably mean 4+/9+ (PEGI 3/7). **Don't** enter the Apple Kids Category unless you meet guideline 1.3 (no third-party analytics or ads, parental gate) |
| **Credits / attributions** | Yes | OGL lines, TTS provider, fonts (Google Fonts are OFL), open-source licences (Flutter `LicenseRegistry`), image tool |
| **Imprint / trader details** | Yes for paid | CCR requires trader identity, geographic address and contact email |

**Store claims**
- 🔎 **Repo:** `MASTER_BOOK.md` plans store **keywords including "ielts" and "life in the uk"**, the tagline *"Duolingo says 'cookie'. Nana says 'biscuit'."* and "key differentiator vs Duolingo".
- Apple **2.3.7** bans other apps' names and trade marks in the name, subtitle and keywords. "Duolingo" in store metadata is likely to be **rejected** and is a trade mark risk. "IELTS" is a registered trade mark of the IELTS partners (British Council, IDP, Cambridge), so keep it out of keywords and use phrases like "English for exams" instead. https://developer.apple.com/app-store/review/guidelines/
- **Comparative advertising** (CPRs 2008 now in the DMCCA, the Business Protection from Misleading Marketing Regulations 2008, and the CAP Code s.3.33–3.44) is allowed only if it is **objective, verifiable, not misleading** and doesn't denigrate. "Better than Duolingo" is not verifiable. Avoid it. "Teaches British, not American, English" about your *own* app is fine. A factual comparison ("Duolingo uses 'cookie'") must be true now and evidenced. Safer to drop it. https://www.asa.org.uk/type/non_broadcast/code_section/03.html · https://www.legislation.gov.uk/uksi/2008/1276/contents
- Don't use "official", "approved", "certified", "guaranteed pass" or "NHS/DVSA/Home Office" in store text.

---

## 12. Business: risk MEDIUM

- **Sole trader vs Ltd:** a sole trader is simplest, but has **unlimited personal liability**, which matters with paid subscriptions, children's data and IP claims. A **Ltd** costs **£100** online at Companies House (since 1 Feb 2026), and you need annual accounts and a confirmation statement. It ring-fences liability, and app stores show the company as the seller. Many founders incorporate before the paid launch. https://www.gov.uk/government/news/companies-house-fees-are-changing-from-1-february-2026 · https://www.gov.uk/limited-company-formation · **⚖️ Accountant.** Consider product and professional indemnity and cyber insurance.
- **Trade mark "The Toms":** search the UKIPO register (https://www.gov.uk/search-for-trademark) in **classes 9** (apps), **41** (education) and 16, and check EUIPO/WIPO if you sell abroad. "TOMS" is a well-known registered footwear and apparel brand. Its classes are different, but a reputation-based objection is possible, so the name may be **weak or contested**. "THE TOMS BRITISH LIFE IMMERSION" (or a distinctive logo) is stronger. UK filing costs £170 online for one class plus £50 per extra class. https://www.gov.uk/how-to-register-a-trade-mark · **⚖️ Trade mark attorney** for a clearance search (around a few hundred pounds) **before** spending on branding.
- **ICO data protection fee:** most organisations processing personal data must pay unless exempt. Tier 1 is **£52/year** (£47 by direct debit) since Feb 2025. Even a sole trader app that only stores data locally will be processing data once it has payments, support email or analytics. Use the ICO self-assessment. https://ico.org.uk/for-organisations/data-protection-fee/data-protection-fee/
- **Domain / GitHub:** host the privacy policy at a stable URL, not just inside the app. Consider moving off `github.io` to your own domain.
- **Open-source licences:** Flutter packages are BSD/MIT. Keep the licence page. The edge-tts library is GPL-3 but only used as a build tool, so that's fine. The problem is the *service terms* (§6).

---

## Top 10 prioritised actions

1. **Replace edge-tts audio** with a commercially licensed TTS (Azure AI Speech paid tier or similar) and re-render every clip before charging or submitting to the stores. (§6)
2. **Fix the microphone privacy text.** "Nothing is sent anywhere" is inaccurate in Chrome and Safari. (§7)
3. **Publish a privacy policy and terms of use** (EN + FA), with trader details. They are required by Apple and Google and by CCR and UK GDPR. (§7, §11)
4. **Pay the ICO fee (£52)** and do a **DPIA**, especially before Family Mode, AI chat or analytics. Apply Children's Code defaults. (§7, §12)
5. **Certificate and pack wording:** add "not an accredited qualification", remove "official" from the plans, add career-pack disclaimers, and get expert review of the safeguarding and first-aid content. (§5)
6. **Driving and Life in the UK:** original questions only, OGL attribution for the Highway Code and signs, a "not affiliated with DVSA / Home Office" disclaimer, no DVSA questions or clips without a licence. (§1, §2)
7. **Payments:** store billing on mobile, a merchant of record (or OSS) on the web, a compliant paywall, the CCR waiver for packs, and DMCCA subscription compliance by **Jan 2027** (trial reminders, easy cancel, cooling-off). (§8)
8. **Store metadata:** no "Duolingo", "IELTS", "official" or unverifiable "better than" claims. Keep comparisons factual and evidenced. (§11)
9. **Trade mark:** do a UKIPO/EUIPO clearance search for "The Toms" (watch out for TOMS footwear) and file in classes 9 and 41. Decide sole trader vs Ltd before the paid launch. (§12)
10. **Brands and art hygiene:** text-only brand mentions, no logos, roundel, NHS lozenge or royal or Parliament emblems in art (remove "roundel" from the prompts), a trade mark disclaimer, keep the bot label on the league, and no paid streak pressure. (§3, §4, §9)

## Where a solicitor or professional is needed
- Reviewing the **DVSA licence** agreement, if you take one.
- Any reuse of **Life in the UK handbook** text (or written TNA/TSO confirmation).
- Whether the **existing edge-tts audio** can be kept, if you don't re-render.
- **Terms of use, subscription terms and DMCCA** compliance before the paid launch.
- **Children's data and AI chat**, including the DPIA (privacy solicitor or consultant).
- **Trade mark clearance** for "The Toms" (trade mark attorney).
- **VAT, structure and tax** (accountant).
- Any payment route that touches **sanctioned jurisdictions**.

*Sources were checked on 17 Oct 2026. Re-check the DMCCA subscription commencement, the AI copyright reform and platform rules before launch.*


## New Life UK: quick name clearance (2026-10-23, not legal advice)
- **UK IPO / EUIPO official search:** the UK IPO search page returned a captcha to automated access, so it was **not** run directly. It must be done by hand at https://www.gov.uk/search-for-trademark (classes 9, 41, 16) and EUIPO eSearch. Third-party register mirrors were checked instead.
- **Registered marks found (mirrors):** NEWLIFE (UK00004239664, Bamford Bus Company, figurative, classes 12/37); NEW LIFE (EUTM 018656961, TAPMARK, figurative, classes 25/35); MY NEW LIFE THE LOVEVERY PODCAST (UK00801546580, class 41, podcasts on early childhood development); NewLife NUTRITION (class 29). An older EU word mark NEW LIFE (005173612, class 9 among others) expired in 2017. **No "NEW LIFE" or "NEW LIFE UK" mark covering apps or education in classes 9/41 was found.**
- **Apps with similar names:** "New Life in UK Tests" (Ruby Technologies, iOS, Education, Life in the UK test practice). This is the **closest conflict**: same audience, overlapping words, though it is unregistered as far as we found. Others are unrelated: "New Life" Chinese takeaway (Gravesend, Play/App Store), New Life Teeth (dental community), New Life Eng Boarding School (school ERP), Newlife charity login app.
- **Assessment:** no serious registered conflict found. Risks: (1) confusion or passing-off with "New Life in UK Tests"; (2) "New Life UK" is fairly descriptive, so it may be **hard to register** as a word mark (a distinctive logo or a longer form helps). **⚖️ A solicitor or trade mark attorney must confirm before monetising.**
