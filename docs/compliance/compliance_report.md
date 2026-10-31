# New Life UK — Self-serve compliance & security report

**Live deploy hash:** `thetoms-bd4f5aebf18c` (main `f5f58fa6`, source `c4415bec`) — Europe/London 31 Oct 2026 ~15:08

**Date:** 31 October 2026 (Europe/London)  
**Scope:** Android / Google Play + PWA (GitHub Pages), UK publisher, global users  
**Important:** This is a **self-review by the product team / automation**, **not legal advice**. It does not create a solicitor–client relationship. For paid launch, have a qualified UK solicitor (and, for immigration wording, someone who understands OISC boundaries) review the live texts and Play Console answers.

Publisher fields still use `[PLACEHOLDER: …]` in `lib/core/legal/publisher_config.dart` — fill before store submission.

---

## Decision: Play target audience

| Option | Verdict |
|---|---|
| Designed for Families / under-13 primary | **Rejected** for this product |
| **13+ with parental kid mode** | **Chosen** |

**Justification:** Core curriculum includes visa, settlement, forms and driving (adult bureaucracy). Kid-friendly mode is a high-privacy parental control with **local-only** child progress (Children’s Code aligned), not a child-directed Play Families app. This is the safest compliant route under current Play Families data rules while still protecting children who share a device.

---

## 1. UK GDPR / DPA 2018 / Data (Use and Access) Act 2025

| Requirement | Source | Status | Note |
|---|---|---|---|
| Privacy notice completeness | [ICO right to be informed](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/right-to-be-informed/) | **done** | Privacy tab: controller placeholders, purposes, bases, recipients (GitHub/Azure/browser STT), retention, rights, ICO |
| Lawful bases documented | [ICO lawful basis](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/a-guide-to-lawful-basis/) | **done** | Contract / LI / consent for permissions |
| DUAA children duty | [ICO DUAA](https://ico.org.uk/about-the-ico/what-we-do/legislation-we-cover/data-use-and-access-act-2025/the-data-use-and-access-act-2025-what-does-it-mean-for-organisations) | **done** | Children’s notice + DPIA |
| DUAA complaints | same | **done** | Privacy: complain to us; 30-day ack |
| Retention | UK GDPR Art 5(1)(e) | **done** | Until user deletes / clears storage; no server DB |
| Access / erase / portability | UK GDPR Arts 15–20 | **done** | In-app Export + Delete all local data |
| International transfers | UK GDPR Ch V | **done** | Disclosed: GitHub Pages (US host logs); Azure used at build for TTS assets; browser STT may leave device |
| ICO fee / registration | [ICO register](https://ico.org.uk/for-organisations/data-protection-fee/) | **needs user** | Confirm if fee/registration required for your entity; placeholder in PublisherConfig |

## 2. ICO Children’s Code (AADC)

| Standard | Source | Status | Note |
|---|---|---|---|
| Best interests / high privacy default | [ICO code standards](https://ico.org.uk/designstandards) | **done** | Kid mode; no ads/tracking/leagues |
| DPIA | same | **done** | `/workspace/legal/dpia_children.md` |
| Geolocation off | same | **done** | Not used; Permissions-Policy geolocation=() |
| No privacy nudges | same | **done** | Calm retention only |
| Transparency for children | same | **done** | Children tab EN+FA |

## 3. PECR (cookies / storage)

| Requirement | Source | Status | Note |
|---|---|---|---|
| Consent for non-essential cookies | [ICO PECR](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guide-to-pecr/cookies-and-similar-technologies/) | **done** / **risk accepted** | Only essential local storage + SW cache; no analytics cookies → no banner. Revisit if analytics added. |

## 4. Google Play

| Requirement | Source | Status | Note |
|---|---|---|---|
| Data safety accuracy | [User Data](https://support.google.com/googleplay/android-developer/answer/10144311) | **done** | `/workspace/play_listing/data_safety.md` |
| Families / audience | [Families](https://support.google.com/googleplay/android-developer/answer/9893335) | **done** | Declare **13+**; not Designed for Families |
| Account deletion | [Account deletion](https://support.google.com/googleplay/android-developer/answer/13327111) | **done** (N/A account) | No accounts; still provide in-app delete-all + future web URL placeholder |
| AI-generated content | Play AI/gen policies | **done** | TTS + coach labelled in-app / About / listing |
| Subscriptions | Play + DMCC | **done** (scaffold) | Premium screen: example prices; cooling-off copy; beta free |

## 5. Consumer law (CRA 2015, DMCC 2024)

| Requirement | Source | Status | Note |
|---|---|---|---|
| Clear pricing | CRA / DMCC | **done** | Example prices labelled; no charge in beta |
| 14-day cooling-off / digital waiver | [DMCC cooling-off](https://www.legislation.gov.uk/ukpga/2024/13/part/4/chapter/2/crossheading/coolingoff-rights) | **done** (wording) | Terms + Premium; wire into real checkout when billing ships |
| Easy cancel online | DMCC s.260 | **needs user** | Implement store cancel path when RevenueCat/Play Billing live |
| ASA/CAP marketing | [CAP](https://www.asa.org.uk/codes-and-rulings/advertising-codes/non-broadcast-code.html) | **done** | Listing avoids “official”, competitor names, guaranteed outcomes |

## 6. Accessibility (WCAG 2.2 AA basics)

| Item | Status | Note |
|---|---|---|
| Text resize / system fonts | **risk accepted** | Flutter text scales with system; further audit recommended |
| Contrast on cream/ink | **done** (design system) | Spot-check legal screens |
| Tap targets | **partial** | Legal segmented control compact — monitor |
| Screen reader labels | **partial** | Icons generally have text labels; full TalkBack pass **needs user** on a device |

## 7. EU AI Act transparency (Art. 50)

| Item | Source | Status | Note |
|---|---|---|---|
| Label AI voices | [Art. 50 FAQ](https://digital-strategy.ec.europa.eu/en/faqs/transparency-obligations-under-article-50-ai-act) | **done** | Map note + About + listing |
| Label AI coach | same | **done** | Coach screen AI aid banner |

## 8. Immigration content / OISC

| Item | Source | Status | Note |
|---|---|---|---|
| Not immigration advice | [OISC](https://www.gov.uk/government/organisations/office-of-the-immigration-services-commissioner) | **done** | Visa + Settlement disclaimers + Terms; GOV.UK links |
| No casework advice | same | **done** / monitor | Content is signposting only — keep reviews when editing visa JSON |

## 9. IP / likeness / trademarks

| Item | Status | Note |
|---|---|---|
| Prior brand audit | **done** | `tool/audit/name_audit.md` (Oct 23) + this pass |
| Renames this pass | **done** | Fennick & Rowe → **Hartley & Wren Homes**; Little Acorns / Vida’s Nursery → **Primrose Lane Nursery**; St Mary’s → **Maple Grove Primary** |
| Companies House | **done** | No CH hits for Fennick & Rowe / Vida Nursery / St Marys School Hackney search strings used |
| Web likeness | **done** | Fennick≈Fenn Wright / Hyde & Rowe risk → renamed; Little Acorns common Ofsted name → renamed |
| UKIPO “New Life UK” | **needs user** | Search UI: [UKIPO](https://trademarks.ipo.gov.uk/ipo-tmtext). Found live mark **NEWLIFE** (UK00004239664) Bamford Bus Co — Class 12/37 vehicles (different goods). No identical Class 9/41 “New Life UK” confirmed in this self-search; **solicitor TM opinion recommended before brand spend** |
| Azure TTS terms | **done** | Pre-rendered clips; disclosure in About |
| Fonts | **done** | SIL OFL (Fraunces, Inter, Vazirmatn) |
| No Mahdi rule | **done** | Test name → Alex |
| Characters fictional notice | **done** | About tab |
| Audio re-render | **done** | 10 clips / 987 billed chars |

## 10. Legal pages & in-app links

| Doc | Status |
|---|---|
| Privacy (EN+FA) | **done** |
| Terms (EN+FA) | **done** |
| Children’s notice (EN+FA) | **done** |
| About / licences + fictional notice | **done** |
| Export / delete controls | **done** |
| Publisher placeholders | **needs user** |

---

## A) Likeness & IP audit (this pass)

Screenshots: `/workspace/legal/shots/legal_{privacy,terms,children,about}.png` (About includes fictional-characters notice).

See §9. Map/pack/character bios/scenes/i18n updated consistently; 10 TTS lines re-rendered with same Azure voice map.

## B) Security hardening

| Control | Status | Note |
|---|---|---|
| CSP + security meta | **done** | Meta CSP allows self + Flutter CanvasKit (`https://www.gstatic.com`); `frame-ancestors` only in `_headers` (meta ignores it). GH Pages ignores `_headers`. |
| Dependency advisories | **done** | `flutter pub outdated` reviewed; Dependabot config written; GH vulnerability alerts enabled (API 204) |
| Secret scan | **done** | `/workspace/legal/secret_scan.txt` — **0** pattern hits in trees; rotate if any key ever leaked via chat/logs (**needs user** operational hygiene). Azure key only in env, not source |
| Android cleartext off / allowBackup false / R8 | **done** | Manifest + network_security_config + minify |
| Exported components | **done** | Only MAIN/LAUNCHER activity exported |
| Play Integrity | **needs user** | Wire when Play Cloud project ready |
| Hive encryption | **done** | Mobile: AES + `flutter_secure_storage`; Web/PWA: unencrypted IndexedDB (documented residual risk) |
| Buddy code validation | **done** | Strict alphabet/length |
| Branch protection main+source | **done** | API 200; force-push disabled; 1 review |
| Dependabot | **done** | `.github/dependabot.yml` (source tree) |
| Secret scanning alerts API | **done** | HTTP 200 on public repo |
| CodeQL default setup API | **needs user** | API 200 `state: not-configured` — enable in Settings → Code security (languages detected: JS/TS) |
| SECURITY.md + security.txt | **done** | App root + `web/.well-known/security.txt` |

### OWASP MASVS-L1 checklist (summary)

| MASVS-L1 theme | Status |
|---|---|
| Architecture / threat notes | **partial** — this report |
| Data storage (encrypted sensitive) | **done** (Android/iOS AES); PWA unencrypted IndexedDB **risk accepted** |
| Crypto | **done** (platform secure storage + AES) |
| Auth | **N/A** (no accounts) |
| Network (TLS, no cleartext) | **done** |
| Platform (backup, exports) | **done** |
| Code quality / obfuscation | **done** (R8 release) |
| Resilience | **partial** — Play Integrity **needs user** |

---



### Dependency audit detail (31 Oct 2026)

`flutter pub outdated` saved at `docs/compliance/pub_outdated.txt`. Direct deps: crypto/go_router/flutter_svg/web have patch upgrades available; `flutter_secure_storage` 9.2.4 → 11.x is a major (defer until after launch). No known Critical advisories in-tree from this scan; Dependabot will flag CVEs. Discontinued: `flutter_secure_storage_macos` / `js` (transitive).
## Things only the user must do before launch

1. Fill every `[PLACEHOLDER: …]` in `PublisherConfig` (legal name, UK address, emails, ICO/Companies House, public privacy/deletion URLs).
2. Confirm ICO data-protection fee / registration for your entity.
3. Paste Data safety + 13+ audience answers into Play Console from `play_listing/data_safety.md`.
4. Set Play external data-deletion URL once the public page exists.
5. Complete real billing (Play Billing) with DMCC cancel + cooling-off UI before charging.
6. Optional: solicitor review of Privacy/Terms + UKIPO filing strategy for “New Life UK”.
7. Enable CodeQL in GitHub Settings (API default-setup 404’d).
8. Device TalkBack/VoiceOver pass; Play Integrity when Cloud project ready.
9. Keep Azure/speech keys in secret store only; rotate if ever pasted into chat.

## Real legal risks (honest)

1. **Trademark:** “New Life UK” / “NEWLIFE” adjacent marks exist in other classes; education/app class clearance not formally opined — brand risk if you invest heavily without a TM search opinion.  
2. **OISC boundary:** Any future visa content that tips into case-specific advice would be unlawful without regulation — process needed for content edits.  
3. **PWA storage:** Not as strong as mobile encrypted Hive; prefer Android for child profiles.  
4. **Self-review limit:** Without a solicitor, residual regulatory risk remains — acceptable for beta, not a guarantee for paid scale.

