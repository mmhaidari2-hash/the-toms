# The Toms: British Life Immersion: Phase‑1 audit

I wrote this audit against the requirements in the task brief and the revised Master Book notes. Only an abridged MASTER_BOOK.md (3.5 KB) is on the box, so I could not check the full text line by line.

**Status key:** ✅ done · 🟡 partial · ⏳ later phase / needs assets

| # | Requirement | Status | Where |
|---|---|---|---|
| UI | Painting is the hero. No floating buttons, raw percentages or text boxes over the painting | ✅ | `features/place/place_screen.dart` (`_PolyHit`), `features/conversation/conversation_screen.dart` (painting background + `_sheet`) |
| UI | Invisible polygon hitboxes locked to each character. They shimmer once on arrival and when tapped | ✅ | `places.json` `shape` polygons; `Hotspot.shape`; `_PolyHit` uses ClipPath hit-testing |
| UI | Kitchen props: teapot, sourdough board, jam jars, butter. A tap gives the word, a British phrase and a mini-dialogue | ✅ | `places.json` `prop`; `Prop` model; prop sheet in `_ambientCard` |
| UI | Storybook sheet (about ⅓ of the screen): dark glass with wood grain and gold edge. Shows only the active line, plus mic and a feedback card | ✅ | `_sheet`, `_WoodGrain`, `_feedback`; the painting pans to the active speaker (`_focusX`) |
| Recast | Implicit Recasting Engine: no red X. The character recasts the line, and a green tip appears | ✅ | `core/engine/recast_engine.dart` (global rule table + per-line `recasts` in scene JSON) |
| X‑Ray | Connected Speech X‑Ray on every line: written vs connected form, IPA, native/slowed playback | ✅ | `core/engine/connected_speech.dart`. Key episode lines are authored (`xray`); all other lines are rule-generated |
| Polite | Politeness score: warm words add trust; blunt lines earn 0 trust and a cooler reply (`coolReply`) | ✅ | `core/engine/politeness_engine.dart`, `OfflineBrain` |
| Polite | Private family stories unlock at high trust | ✅ | `private_tom_dad`, `private_leslie_letters` (`requiresTrust: 60`); gate in `canPlay` |
| SRS | Narrative SRS: learned and recast phrases are queued with the character who will bring them back. The next day that character opens with "Remember yesterday when…?" | ✅ | `core/engine/narrative_srs.dart`, `UserProgress.srsQueue`, `Scene.memory`, `_open()` |
| SRS | Wrong words come back the next day. Box‑5 words appear in the next milestone dialogue | ✅ | Recast and ghost lines are queued; `pendingMilestoneWords` is spoken at the start of gated scenes |
| Matrix | Character linguistic matrix: Nicola A1–A2, Leslie A2–B1, Ryan B1–B2, Tom B2–C1, William non-verbal | ✅ | `core/engine/level_profile.dart` `VoiceProfile.matrix`; the test enforces budgets and Ryan's slang |
| Matrix | William surprise events (he spills the jam) that the learner must react to | ✅ | `DialogueNode.event`; event banner in the sheet; `ep1/k3` |
| Ep | Chapter 1: Morning Table · Muddy Hallway (rain words) · High Street Bakery & Butcher · Evening Tea + plumber call (voice-only Dave) | ✅ | `scenes/ep1..ep4*.json`; places `kitchen`, `hallway`, `bakery`, `eveningtea`; `ChapterStrip` on home |
| AI | Offline now, but a FastAPI/LLM layer can plug in, returning `{npc_reply, recast_tip, connected_speech_xray, trust_delta}` | ✅ | `core/ai/dialogue_brain.dart` (`DialogueBrain` interface, `BrainReply.fromJson`, `OfflineBrain`) |
| 3.2 | Character switching: play Mehdi (guest), Ryan, Tom or Leslie, with role-specific scenes | 🟡 | `RolePicker`, `UserProgress.role`, `roles.json`, `{you}` token. There is one role scene per role (A1/A2/B1), not one per level yet |
| 6 | Nicola milestones M0–M5 (birthday, school, Mia, race, opinion); William M0–M3; Ryan and Tom growth lines | ✅ | `*_growth.json`, `growth_index.json`, scenes `nicola_*`, `william_*`, `ryan_report`, `ryan_driving` |
| 6 | Soft cap on trust; streak as a small accelerator (≤ +14%); growth visible | ✅ | `GrowthEngine.softTrust/streakBoost`; growth bar on the family cards (home only, never over paintings) |
| 6 | Set-pieces: birthday, first school day, Weda illness, end-of-year report, driving lesson | ✅ | `moments.json` + `GrowingUpStrip`. Existing paintings are reused as covers; `ryan_driving` falls back to the storybook view |
| 7.2 | Daily mission (e.g. "supermarket with no mistakes"), with tracking | ✅ | `core/engine/mission.dart`, `missionsDone`, home mission card |
| 7.4 | Three speeds per line: Slow / Medium / Normal (`audioBySpeed` first, otherwise TTS) | ✅ | `LevelProfile`, `_speak` |
| 7.5 | Summary: sentences said, spot-on, recasts, trust per character | ✅ | `_summary` |
| 7.6 | In-story Ghost Hint ("You mean… …?") | ✅ | `RecastEngine.ghostHint`; the character says it, and suggestion chips appear after the 2nd miss |
| 7.7 | The learner writes the diary in English and characters react | ✅ | `DiaryComposer`, `core/engine/diary_coach.dart` |
| 7.11 | Replay + milestone archive; shadowing (record/playback) | ✅ | `ArchiveEntry`, `_Archive`; `core/platform/speech_web.dart` (MediaRecorder, no extra package) |
| 7.12 | Culture notes everywhere (queuing, weather, sorry, love, tea, rounds) | ✅ | `CultureCorner` on home, per-line notes, prop phrases |
| Pass | Accent Passport stamps per milestone | ✅ | `Stamp`, `PassportCard` |
| Lvl | Speed and line length per level | ✅ | `LevelProfile.all`; a test enforces `maxChars` for every line |
| i18n | Complete PL/UR/AR/RO/ES/PT UI strings, RTL for UR/AR | 🟡 | `core/i18n/strings.dart` (65 keys × 8 languages; a test checks completeness). Helper strings render RTL per string, but the app chrome is not mirrored. Dialogue translations exist only in Persian (other languages fall back to Persian) |
| 9 | Models: Character mood/growthStage; DialogueNode audioBySpeed; UserProgress replayArchive | ✅ | `core/models/*` |
| 8.1 | Folder structure: `app/ core/{models,engine,data,ai,platform,i18n} features/*` | ✅ | `lib/` |
| 10 | Content pipeline: JSON scenes, Python authoring helpers, integrity tests | ✅ | `assets/data/*`, `test/engine_test.dart` (20 tests) |
| STT | Optional speech-to-text via the Web Speech API (en-GB) | ✅ | `SpeechInput.listen`; the mic button only appears where the browser supports it |
| Title | App renamed to "The Toms: British Life Immersion" | ✅ | `app.dart`, `web/index.html`, `manifest.json` |
| — | Pre-recorded native audio per speed | ⏳ | The `audioBySpeed` hook exists; no audio files yet |
| — | Server LLM brain | ⏳ | Interface is ready; nothing is deployed (offline by design) |

## Paintings
**Delivered and used:**
- kitchen, hallway, bakery, eveningtea
- the six milestone set-pieces: firstday, playdate, sportsday, poorly, parentsevening (4 people, revised), driving (front view, right-hand drive, revised)
- the 24 earlier paintings

The six set-pieces are now their own places with polygon hitboxes, checked by drawing the outlines onto each painting. Each place opens at the matching milestone, and the "Growing up" cards use these paintings as covers. Props: teddy and school sign; dolls' house and biscuits; egg and spoon; night light and cot; report and name plate; L-plate and wing mirror. New NPCs: Mrs Ellis and Mr Grant.

**Still optional:** Tom's garden bench at dusk (`private_tom_dad`) and the attic with letters (`private_leslie_letters`).

**Parents' evening:** the painting is now Nicola's end-of-year report (`nicola_report`, unlocked at Nicola M4). Ryan's report (`ryan_report`) stays as a text-only scene in "Growing up".

## iPhone Safari PWA polish
| Item | Status | Where |
|---|---|---|
| Safe areas | ✅ | `viewport-fit=cover`; Flutter is hosted in `#app`, which is inset by `env(safe-area-inset-*)` (`web/index.html`, `web/flutter_bootstrap.js`) |
| Portrait and landscape fit; tap areas reachable | ✅ | `place_screen.dart` `_painted`: portrait pans sideways, landscape fits the height and never overflows vertically |
| Offline service worker | ✅ | `tool/make_sw.py` writes `build/web/sw.js` after each build. It precaches all 179 built files and uses cache-first with stale-cache cleanup. Verified: the app reloads with the network off |
| No CDN | ✅ | `--no-web-resources-cdn` (CanvasKit is local); fonts are bundled in `assets/google_fonts` (OFL) with runtime fetching off |
| Root URL | ✅ | `flutter build web --release --base-href / --no-web-resources-cdn && python3 tool/make_sw.py` |
| Remaining | 🟡 | Flutter may still fetch Noto fallback glyphs (emoji) from fonts.gstatic.com on first use; offline, those glyphs fall back to the system font |
