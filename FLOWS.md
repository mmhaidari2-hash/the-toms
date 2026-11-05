# Regression flows

Scope: repair the existing app, not redesign it. Preserve artwork, curriculum,
saved progress and public routes. Do not deploy to production or merge main/source.

## Current upgrade pass

Baseline re-opened at the first conversation before editing. Existing lesson reply
and navigation semantics were present. The previous repair commit has since been
pushed only to `fix/offline-audio-content`; the earlier delivery notes below
describe the first pass, not the current remote state.

- Shared audio: missing recording and failed playback return false, stop play-all
  loops and show a dismissible explanation without substituting device TTS.
- A newer audio request or Stop must not let an older failure overwrite its state.
- Speed controls must preserve pitch; real recordings are not retuned in bulk.
- App menu: English/Persian search filters every section, supports clearing, shows
  a useful no-results state and still navigates to the actual destination.
- Library: highlighting stops when actual speech finishes; a long estimated
  karaoke duration must not add artificial pauses.
- Arrival pack: incomplete/cancelled downloads never display a complete-ready
  banner, and unexpected errors let the user retry.
- Natural voice replacements: original service credentials and a reviewed sample
  are required before replacing characters. No unsupported “all voices fixed”
  claim, no bulk paid calls without explicit scope approval.
- Regression: desktop/mobile onboarding, map, menu, course/lesson/conversation,
  library, grammar, radio/cinema and arrival navigation; list exclusions honestly.

## Observed baseline
- Onboarding: Persian helper language, optional name, skip tutorial, select A0–A1.
- Town: map, Home, locked later tiers and Continue card are visible.
- Lesson: Continue opens “Hello! I'm Nicola”; objectives, word chips and Start the story render.

## Browser regression checks
- Fresh desktop and 375px mobile: app boots, onboarding finishes and map loads.
- My path / Town / Leitner: each bottom tab opens without an exception.
- Lesson: open first lesson, play a word, start story, choose a suggested reply.
- Menu: open progress/settings and return to town without losing navigation.
- Nursery: lesson data includes the interview and all four N7 stories.
- Reload: previously selected language and progress remain available.
- Offline: after worker installation, reload with network disabled; map and first lesson render.
- Audio: cache a clip, request a suffix and an out-of-bounds range while offline.
- Renderer: no external CanvasKit request; local renderer is cached.
- Reset: only this app's worker/scope caches are removed; neighbor data survives.
- Failed update: rejected required download does not activate a new worker or remove old caches.

## Test layers
- Full Flutter analyzer and test suite, plus repository/bundle parity regression.
- Node tests of the generated worker and HTML reset code with browser-like APIs.
- Python generator/content tests.
- Real-browser smoke and offline checks where supported; explicitly report untested flows.

## Executed against final release build

- Release completed with `--no-web-resources-cdn --base-href /the-toms/`.
- Fresh desktop context, 1280×900: onboarding → skip tutorial → beginner level →
  map → My path → Leitner → Town → menu → first lesson → story →
  type `Hi, I'm Alex.` → receive the next age question. No page errors.
- Mobile, 375×812: final worker activated with shell `ea4d0eff5ca4`. Its font
  manifest includes Inter, Fraunces and Vazirmatn. Persian text was visually
  inspected in the lesson and fixed start-story button.
- With HTTP cache cleared and networking disabled, reload rendered the map;
  Continue opened the first lesson. A screenshot records the final offline lesson,
  not just the HTML loading shell.
- Cached audio offline: `bytes=-8` returned 206, eight bytes and correct
  Content-Range; an out-of-bounds range returned 416.
- Progress storage/schema is unchanged. Mobile reload retained onboarded state;
  this is not a full multi-profile migration audit.
- Every-route return-to-map test completed successfully in the broad run.
- Library and grammar mobile flows passed Flutter widget tests; these were not
  additionally replayed in the final browser context.

## Test boundaries and unresolved blockers

- Worker/reset/build checks: 30 passed. Python generator and safe voice dry-run
  checks: six passed. Existing voice-identity QA unit tests: nine passed.
- Focused repaired Flutter paths: 36 passed. Analyzer: no issues.
- Three exhaustive widget overflow traversals were not completed. They were not
  deleted, shortened or reported as passing.
- The broad run originally had a school-test click outside the viewport. After
  aligning the actual target and requiring hit-testability, it passed in the
  focused suite; a final bounded suite checks the non-exhaustive tests again.
- Four audio coverage checks remain blocked by missing clips. The original
  >30,000 spoken-line requirement was not lowered.
- Final bounded Flutter run completed in 3:06: 217 passed, four audio checks
  failed, two optional secret-dependent tests skipped. It excluded the three
  exhaustive overflow traversals and the already-completed every-route
  return-to-map test. The full suite is therefore not green.
- Two optional real-owner-code tests skip with a reason when the untracked
  production secret is unavailable; negative verifier tests still run.

## Natural voice review

Seven original clips were sampled: Tom, Leslie, Nicola, learner, Weda, narrator
and William. No pitch, tempo or loudness modification was applied. Automated
listening found naturalness concerns, especially Nicola's high/exclamatory
delivery and some learner/child pacing. These are sample-level subjective
assessments, not a score or a guarantee about the full library. Local signal
checks are separate from perceptual judgments. Voice-identity tests alone do not
establish that speech sounds natural.

No voice was replaced and no paid speech API was called. Completing and
re-voicing requires approved access to the original speech service and review of
a sample before bulk generation. `render_voices.py --dry-run` does not change
voice manifests or import the paid API client.

## Delivery boundary

The first repair pass was pushed as `83faff53` to `fix/offline-audio-content`.
No merge or production deployment has been made. Private preview
deployment was attempted twice, but the tool incorrectly reported that the
verified index.html did not exist; the failure was recorded. Browser checks above
use the local final build. A hosted preview is not available.

## Second-pass QA inventory and open decisions

Current central register: `docs/compliance/OPEN_QUESTIONS_FA.md`, Q01–Q40.
An implementation or an automated test is not legal approval or user acceptance.
The public-release evidence check deliberately fails while identity and reviews
are incomplete. Its integration currently covers the Cloudflare script only.

| Change / claim | Required check | Current scope |
|---|---|---|
| Missing/failed audio is not reported as success | Missing, false, exception, retry, superseded request, stop, bounded rate | Unit tests |
| Shared audio feedback | Visible at 375px, dismiss, missing has no futile retry | Widget test; browser visual check pending |
| Search all sections | English/Persian, Arabic keyboard variants, no results, clear, child filtering retained | Normalization test; mobile browser check pending |
| Reader timing | Actual completion stops estimated highlight timer; next clip not held by text estimate | Implementation + library regression; real playback review pending |
| Arrival downloads | Complete only, partial, thrown error, cancel, HTTP/MP3 validation | Three injected-result widget cases; seven actual clips still absent |
| Native offline playback | Same cache path for warmer and player, airplane mode | OPEN: existing cache-path mismatch, Q29 |
| Privacy / terms | No false completed DPIA or blanket local-storage exemption | Legal text regression; controller/professional approval pending |
| Font notices | Full OFL bundled, registered with licence UI | Source check; provenance matching remains Q10 |
| Public-release check | Missing identities/evidence and rubber-stamp approvals fail | Three Python tests; gate intentionally blocked |
| Responsive regression | 375px search/keyboard/no-results and legal page; desktop return | Browser check pending |

Second-pass evidence, 5 November 2026:
- Release web build passed; analyzer reported no issues.
- Final focused Flutter run: 23 passed, 1 failed on seven absent arrival clips.
  Full suite and exhaustive overflow traversals were not rerun to completion.
- Worker/reset/built-output Node checks: 34 passed. Generator/safe dry-run Python
  checks: 6 passed. Public-release gate unit checks: 3 passed.
- Browser 375×812: Persian filtering and no-results view inspected; missing
  `hiya` recording correctly surfaced; notice dismissed. Final isolated-context
  runtime error list was empty after worker-registration error handling.
- Retry success is widget-tested. Forced playback-failure browser scenario
  did not run to completion because the chosen word itself had no recording;
  do not count that scenario as browser playback-failure signoff.
- Full clear-search restore, real keyboard, child mode, Safari/native playback
  and the native cache-path mismatch remain open in the central register.
- Isolated QA context closed, network interception removed; server and other
  contexts retained for continuation.
- User chose to change the product name, then deferred choosing a replacement.
  Do not rebrand or rename the story family without that later decision.

Off-happy-path browser checks: search with no matches and return to all sections;
force audio playback failure in an isolated local test context and dismiss it.
Do not treat this focused inventory as exhaustive app signoff or natural-voice
approval. Do not clear the user's real saved data for QA.
