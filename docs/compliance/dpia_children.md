# DPIA — Children’s use of New Life UK (kid-friendly mode)

**Date:** 31 October 2026 (Europe/London)  
**Status:** Internal self-assessment (not legal advice)  
**Controller:** `[PLACEHOLDER: BUSINESS LEGAL NAME]`  
**Contact:** `[PLACEHOLDER: PRIVACY CONTACT EMAIL]`

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
