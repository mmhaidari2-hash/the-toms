# DPIA — Children’s use of New Life UK (kid-friendly mode)

> Review correction, 5 November 2026: DRAFT, NOT APPROVED. The earlier
> "accepted for beta" wording is not a current approval. This draft omits a full
> hosting/speech transfer assessment, age assurance, shared-device controls and
> documented review against all Children's Code standards. Owner/controller and
> qualified privacy review are pending; see `OPEN_QUESTIONS_FA.md`.

**Date:** 31 October 2026 (Europe/London)  
**Status:** Internal self-assessment (not legal advice)  
**Controller:** `[PLACEHOLDER: BUSINESS LEGAL NAME]`  
**Contact:** `[PLACEHOLDER: PRIVACY CONTACT EMAIL]`

## Initial screening — 11 November 2026

DRAFT. Not an approved DPIA, not a controller sign-off, and not an acceptance of residual risk. No user count, lawful basis, processor contract, consent, or ICO consultation is decided here. Q03 stays deferred.

غربال اولیه. DPIA تأییدشده نیست، امضای کنترل‌کننده نیست، و ریسک باقی‌مانده پذیرفته نشده است. تعداد کاربر، مبنای قانونی، قرارداد پردازشگر، رضایت، و مشورت با ICO اینجا تصمیم نشده است.

### Evidence for this free Android build

| Fact | Where it shows |
|---|---|
| Intended audience is 18+. The app does not check age. | Profile screen and in-app children notice, decision of 10 November 2026. |
| A new profile is adult. A child profile already on the device stays selectable, with the same route limits. Switching profiles is not a parent lock. | `learner_profile.dart`; `profiles_screen.dart`. |
| Name, progress, diary and certificate name stay in the on-device progress box. Export copies that box to the clipboard. Delete clears the box and writes a default adult profile. It does not delete the encryption key, cached lesson files, or a host log. | `progress_store.dart`; legal export/delete. |
| A lesson download can send a request to `https://mmhaidari2-hash.github.io/the-toms/assets/`. GitHub’s Pages doc says a visitor IP is logged. Retention, the publisher’s role, and any location category are undecided. | `speech_io.dart`; Data safety draft. |
| Installed Android does not transcribe and does not record. | `speech_io.dart`: `sttSupported` and `recordSupported` are false. |
| `purchases_flutter` 11.0.1 is packaged and `Purchases.configure` is not called. Before that call, plugin registration and `CurrentActivityTrackerInitializer` show no network call in the bytecode. Traffic was not captured. | Data safety draft, commit `0cd43cf5`. |

مخاطب مورد نظر ۱۸+ است و سن بررسی نمی‌شود. پروفایل تازه بزرگسال است و پروفایل کودک موجود می‌ماند. تعویض پروفایل قفل والد نیست. خروجی محلی است. حذف، لاگ میزبان را پاک نمی‌کند. دانلود درس می‌تواند IP را به میزبان برساند. اپ اندروید ضبط و رونویسی ندارد. کتابخانهٔ خرید پیکربندی نمی‌شود و ترافیکش ضبط نشده است.

### Two questions this screening does not decide

**Likely access by under-18s.** The ICO says the Children’s Code applies to information society services likely to be accessed by children in the UK. A child is a person under 18. The code is not limited to services aimed at children. “Likely” means more probable than not, judged from the nature of the service and from measures that actually prevent access. An adult-only label is not itself that finding. This app does not check age, so access is not prevented. Whether children are more likely than not to use it is not decided. No market research or user count is invented here. ([Services covered by this code](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/services-covered-by-this-code/))

احتمال دسترسی زیر ۱۸ سال تصمیم نشده است. برچسب ۱۸+ به‌تنهایی معافیت نیست، چون سن بررسی نمی‌شود.

**Whether a DPIA is required.** UK GDPR Article 35 requires a DPIA where processing is likely to result in a high risk. The ICO’s screening list includes offering online services directly to children. Children are vulnerable data subjects. If the controller is in doubt, the ICO recommends doing a DPIA. This version does not offer creation of a new child profile. It can still process a name and progress already stored for a legacy child profile, and a lesson download can leave the device. This draft does not decide that the processing is, or is not, likely to be high risk, and it does not treat the ICO recommendation as a signature. ([When do we need to do a DPIA?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/accountability-and-governance/data-protection-impact-assessments-dpias/when-do-we-need-to-do-a-dpia/))

لزوم DPIA تصمیم نشده است. توصیهٔ ICO در حالت تردید، امضای این پیش‌نویس نیست.

### Controls already in this build

These are code facts, not a claim that risk is closed. Kid-mode still hides visa, forms, settlement, driving, premium and invite. Share stays hidden for a child profile. An unsent chat line is cleared when the active profile changes, and that clear does not send it. There is no Android speech recognition or recording to leave on for a child profile.

این‌ها واقعیت کدند، نه بسته‌شدن ریسک.

### Residual unknowns

Left open, and not accepted: whether under-18s are likely users; whether a DPIA is required; who the controller is; lawful basis; scale; any contract with the download host; how a person asks for deletion of a host log; consultation. Q17 is not closed. On this Android build, speech recognition and recording are off for every profile, including a legacy child profile. That is not a parent lock, and it says nothing about a browser build.

باقی‌مانده پذیرفته نشده است: احتمال کاربر زیر ۱۸ سال، لزوم DPIA، کنترل‌کننده، مبنای قانونی، مقیاس، قرارداد میزبان، و درخواست حذف لاگ. Q17 بسته نیست.

## Earlier draft body — 31 October 2026

The sections below are the older draft. They are not this screening where they say a parent can create a child profile, that data does not leave the device, that a lawful basis has been chosen, or that residual risk is accepted for beta.

بخش‌های پایین پیش‌نویس قدیمی‌اند. جایی که ساخت پروفایل کودک، نرفتن داده از دستگاه، انتخاب مبنای قانونی، یا پذیرش ریسک برای بتا را می‌گویند، غربال امروز نیستند.

## Processing description
Parents may create a local “child” profile on a shared device. Progress (lessons, XP, streak) is stored only on that device in the app sandbox (encrypted on Android/iOS). No child account, no server database, no ads, no tracking, no public leagues, no geolocation.

## Necessity & proportionality
Processing is limited to what the child actively does in the learning UI. Kid mode hides adult bureaucracy routes (visa, forms, settlement, driving, premium).

## Risks & mitigates
| Risk | Mitigation |
|---|---|
| Data leaving the device | No server sync for profiles; buddy codes do not transmit child XP |
| Parental sharing of device | Separate profiles; delete profile / delete-all controls |
| Nudges / dark patterns | No leagues; calm streaks only; no privacy-weakening prompts |
| Identification of child | Display name optional/local; no email collection |

## Lawful basis
Local storage as steps necessary to provide the service the parent requested (contract / legitimate interests for adult controller context). No consent-to-ads.

## Children’s Code standards mapped
Best interests, DPIA (this doc), transparency (Children tab), high privacy defaults, minimisation, no sharing, geolocation off, no profiling for ads, no privacy nudges, on-device tools (export/delete).

## Residual risk
Browser PWA storage is not hardware-encrypted; shared-computer risk remains with the parent. Accepted for beta; Android/iOS preferred for child use.
