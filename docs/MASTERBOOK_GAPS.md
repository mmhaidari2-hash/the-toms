# Master Book — requirements still not (fully) implemented

Source note: this box only has an abridged `MASTER_BOOK.md`; the full v2.0 text and the Qwen blueprint live in the parent conversation, which this agent cannot read. This list combines the abridged book, every steering message so far, and an audit of the code. Items marked ⚠ need the full text to confirm wording.

## Big gaps
1. **Character growth over time (ageing/progression)** — only milestone stages (M0–M5) with text/stamps exist. Missing: characters visibly ageing (new portraits/avatars per stage), their language level rising (Nicola A1 → A2 → B1 lines as she grows), season/year timeline, dialogue variants that depend on age stage, "years pass" chapter breaks.
2. **Full role switching** — only 3 role-locked scenes (play as Ryan/Tom/Leslie). Missing: play as ANY family member in ANY scene (speaker swap: the user's role's lines become choices, the guest Mehdi becomes an NPC), role-specific openings, per-role trust, role picker per scene.
3. **Full curriculum depth** — Level 1 in progress (Unit 1 done); Levels 2–5 not built; many everyday locations missing (see CURRICULUM_PLAN.md).
4. **AI conversation layer** — interface exists (`DialogueBrain`), offline rule engine only; no FastAPI/LLM backend (intentionally deferred).
5. **Speech recognition on iOS** — Web Speech STT is not available in iOS Safari; mic only works in Chrome/Android. Needs a server STT later.
6. **Cinematic/motion layer** — ambient motion & short clips (approved direction) not yet built.

## Smaller gaps
7. Dynamic lines are silent (SRS callbacks, "practising your words", rule-based recasts on unusual input) — need server TTS or templated pre-renders.
8. Pronunciation scoring for shadowing (record & compare) — playback exists, no scoring.
9. Accent passport covers RP/general only ⚠ (regional accents need new voices/recordings).
10. Driving painting shows left-hand drive (replacement pending) — fixed per later art? verify.
11. Notifications/reminders for streaks (PWA push) not implemented.
12. Parent/teacher dashboard, family plan, certificates, exam tracks — business features (see Monetisation chapter).
13. Analytics/crash reporting (anonymous) not implemented.
14. Accessibility: semantics labels on painting hotspots partially (strip fallback exists); full VoiceOver pass pending.
15. Content translations beyond Persian for dialogue lines (UI strings exist for 9 languages; dialogue translations only fa).
