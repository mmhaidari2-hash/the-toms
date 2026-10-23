# Quality audit report (Oct 2026)

## 1. Text ↔ audio
- **Whole-corpus duration check** (`tool/audit_audio_len.py`): checks 19,424 clips against the word count of their text.
  - It found **104 near-empty clips** (~0.4 s, failed TTS) and re-rendered them. It now flags 0.
- **Whisper STT spot-check** (`tool/audit_audio.py`, faster-whisper small.en): random sample of 447 clips.
  - Mean WER is 0.095 and 38 clips were over 0.35.
  - On recheck, 2 were genuinely truncated ("She knitted you a scarf?", "Yes, you'll be fine.") and were re-rendered. The rest were STT artefacts: digits, compounds, spelled words, Persian names.
- **Names/places check**: 48 clips containing Hackney, Thompson, Mare Street, Dalston, Homerton, Leyton, Okafor, Tehran, Nowruz, ghormeh sabzi, Tahdig, Esteghlal, Simorgh, setar and the learner.
  - All English place names sound correct. Whisper's different spellings ("Mayor Street", "Leighton") are homophones.
  - "setar" was read as "set-ar" and "Simorgh" was mangled, so a TTS respelling map (`PRON` in render_voices.py) was added and the clips were re-rendered.
- **British spelling lint** (`tool/check_british.py`): clean across all authored lines. It is enforced by a test in map_spots_test.dart.

## 2. Progression
- **Bug fixed:** after placement every unit of the starting level was open at once.
  - Now only the first unit of the start level is open. Later units open in sequence, by passing the unit test (≥70) or finishing all its lessons.
  - Units already played in never re-lock.
- **New test/progression_test.dart** (11 tests):
  - level order and a fresh learner
  - walking 40 lessons in order
  - practice/story gating and the unit-test unlock
  - placement levels 1–5 (units and map regions)
  - Continue target and null when everything is done
  - save/reload
  - Career Packs never used as Continue targets
  - demo mode

## 3. Visual consistency
- Contact sheets are in `/workspace/british-life/audit/contact/`: paintings.png, portraits.png, avatars_and_map_icons.png and map_icons_painted.png.
- **Outlier fixed:** map spot icons were platform emoji. They are now painted circular crops of each spot's place painting (`tool/make_spot_icons.py` → `assets/spots/`, `SpotIcon` widget, greyscale when locked). A test checks every spot has an icon.
- **Remaining outliers:** see IMAGE_PROMPTS.md (Sara portrait; museum/cinema; driving/bigsupermarket).
