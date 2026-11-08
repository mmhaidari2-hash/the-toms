# New Life UK (formerly "The Toms: British Life Immersion")

Flutter web/PWA for learning British English by living with a painted British family.

- `app/` Flutter app (content as data in `app/assets/data`, lesson DSL in `app/tool/level1`, voices via `app/tool/render_voices.py`)
- `docs/` the only copy of the Master Book, curriculum plan, gaps list and audits (`AUDIT.md` phase 1, `AUDIT_10X_FA.md` Nov 2026), plus the handover and checkpoints (`HANDOVER_FA.md`, `CHECKPOINT_*_FA.md`)
- `new_art/` source paintings
- Branches: `main` = deployed site (GitHub Pages, never push), `source` = this code, `fix/offline-audio-content` = work from 6 Nov 2026, `improve/newlife-10x` = improvements from the 10x audit. CI runs analyze + tests + build on pushes to `source` and `improve/**`.
