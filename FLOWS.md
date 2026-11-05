# Regression flows

Scope: repair the existing app, not redesign it. Preserve artwork, curriculum,
saved progress and public routes. Do not deploy to production or merge main/source.

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

No push, PR, merge or production deployment has been made. Private preview
deployment was attempted twice, but the tool incorrectly reported that the
verified index.html did not exist; the failure was recorded. Browser checks above
use the local final build. A hosted preview is not available.
