# Missing audio — counted manifest

Tree counted: `68d49ff94a28cdb705d59be6d6f95659bbdee91d` on `fix/offline-audio-content`. No clip was rendered. Azure was not called. `tool/az_tts.py` was used only for `ssml()`, the same function the generator uses to build the request and the billable length.

## What was counted

A clip id is `md5(speaker + '|' + authored text)[:16]`, the key `tool/render_voices.py` and `Voice` use. The spoken string is `clean(text)` from that script (neutral `{you}`, the two pronunciation respellings, stage directions, spaced dashes, emoji). The file name is `assets/audio/<id>.mp3`.

`render_voices.py --dry-run` collected **44436** ids. **22446** come from the authored JSON the script walks even when `build/voice_lines.json` is absent. **21990** exist only because that gitignored dump is present. `audit_test.dart` writes the dump from `spoken()`: chapter variants, ghost hints, the fixed “No worries” line, five sample recasts per node, and word prompts. The generator reads the dump when the file exists.

Missing means the id is not a file in `app/assets/audio/<id>.mp3` and not in the live host index. The host index was fetched, not assumed:

- `GET https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/index.json` → 200, **22235** ids.
- `GET https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/ver.json` → 200, `{"v":"8e3903c12d"}`.
- `GET https://mmhaidari2-hash.github.io/the-toms/assets/audio/index.json` → 404.
- GitHub Pages for this repo, from the API: branch `main`, path `/`. This branch is not that source. Each listed id was not downloaded.

Local `app/assets/audio/ver.json` is `{"v":"da11c1351d"}`. Local hex mp3 files: **22407**. Local `index.json`: **22313** ids. `bundled.json`: **419** ids.

## Billable length

`billable_chars` is the integer `az_tts.ssml()` returns: the number of Python characters inside `<voice>`, including `<prosody>` or `<mstts:express-as>` when the generator emits them. That is what `synth()` adds to `BILLED`. `text_chars` is `len(clean(text))`. No counted character is outside the Basic Multilingual Plane. The generator does not double any character.

Each JSONL row has `text`, `ssml_escaped` (`xml.sax.saxutils.escape` of that text), and the full `ssml` document.

## Languages

The player does not build a clip id from fa, hi, ur, ar, ps, ro, or bn. `render_voices.py` reads English fields only. The zeros below are empty sets, not a sample of translation files. PL was not read and is not in the manifest.

| Language | Missing clips | Text characters | Billable characters (SSML inside voice) |
|---|---:|---:|---:|
| en | 22030 | 884473 | 1705254 |
| fa | 0 | 0 | 0 |
| hi | 0 | 0 | 0 |
| ur | 0 | 0 | 0 |
| ar | 0 | 0 | 0 |
| ps | 0 | 0 | 0 |
| **In-scope total** | **22030** | **884473** | **1705254** |

Held, not in the in-scope total:

| Language | Missing clips | Text characters | Billable characters |
|---|---:|---:|---:|
| ro | 0 | 0 | 0 |
| bn | 0 | 0 | 0 |

`bn` is listed in `app/tool/i18n/hold.json`. `ro` is not in `helperComplete`. Neither has an audio generator in this tree.

## Split of the 22030 English rows

These two rows add up to the grand total.

| Origin | Clips | Text characters | Billable characters |
|---|---:|---:|---:|
| Authored content (`origin=content`) | 40 | 3050 | 4350 |
| Computed dump only (`origin=computed`) | 21990 | 881423 | 1700904 |

Authored content is 7 arrival clips (414 text / 724 billable) and 33 global clips (2636 text / 3626 billable). No authored scene line is missing from both the local mp3 set and the host index.

Scope on a row is `lesson`, `arrival`, and/or `global`. Six rows carry two scopes, so the scope clip counts are not a partition: lesson 21972, global 57, arrival 7.

399 of the 22030 ids are named in `bundled.json` and still have no mp3. `tool/build_android.sh` copies a bundled mp3 only when the file exists.

172 expected ids have a local mp3 and are absent from the live host index. They are not in this manifest. One host id and one local mp3 are outside the expected set.

Manifest: `docs/audio/missing-audio-manifest.jsonl`, 22030 lines, 14147547 bytes, SHA-256 `b6455c12ff77c7f00751bf3bd134ee17c4eac171be7e86534b37f1a9d8cd11fe`.

## How the generator is run

Paths are based on the script file, not the shell’s current directory.

```
python3 app/tool/render_voices.py
```

`--dry-run` prints the local-file inventory and exits before `az_tts` is imported. This count used that path, then applied the host index itself.

Environment variables the script reads:

- `AZURE_SPEECH_KEY_1` — sent as `Ocp-Apim-Subscription-Key` when set. If it is unset, `synth()` posts with curl and does not add that header. The region is not an environment variable. `tool/az_tts.py` sets `REGION = 'uksouth'` and posts to `https://uksouth.tts.speech.microsoft.com/cognitiveservices/v1`.
- `RENDER_THREADS` — default 8.
- `RENDER_CHAR_CAP` — default 0, meaning no cap. With a cap, the ledger is `app/tool/audit/tts_month.json`. The cap check uses `len(text) + 400` before the call. The ledger stores `BILLED`, which is the inner SSML length.
- `RENDER_FRESH_SINCE`, `RENDER_OLDER_THAN`, `RENDER_LIMIT`, `RENDER_LIST_ONLY`, `RENDER_PRUNE_OBSOLETE` — optional. Prune runs only when `RENDER_PRUNE_OBSOLETE=1`.

The handover’s recorded command is `RENDER_THREADS=1 RENDER_CHAR_CAP=480000 RENDER_FRESH_SINCE=<epoch>` with the F0 key in `AZURE_SPEECH_KEY_1`. That cap is the script’s optional stop, not a figure from this count.

Outputs of a real run:

- `app/assets/audio/<id>.az.mp3`, replaced by `app/assets/audio/<id>.mp3` after `compress_audio` and `tighten_audio`
- `app/assets/audio/index.json` rewritten from the hex mp3 names in that directory
- `app/tool/audit/voice_texts.json`, `voice_manifest.json`, `voice_engine.json`, `tts_month.json`, and `you_neutral_v1.done`

The Android client requests `https://mmhaidari2-hash.github.io/the-toms/assets/` plus `assets/audio/<id>.mp3?v=<version>`. The version it prefers is the live `ver.json` above. Putting a new mp3 on this branch does not put it on that host. Pages is `main` at `/`. The workflow `.github/workflows/ci.yml` builds web on `source` and has no Pages upload step. No publish command is invented here.

## فارسی

این شمارش از درخت `68d49ff94` است. صدایی ساخته نشد و Azure صدا زده نشد.

کلید هر کلیپ `md5(گوینده|متن اصلی)` شانزده‌نویسه است. متن صورتحساب، متنِ `clean` است به‌اضافهٔ نشانه‌های داخل `<voice>`، همان عددی که `az_tts.ssml` برمی‌گرداند.

میزبان زنده، ایندکس `https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/index.json` است: ۲۰۰، ۲۲۲۳۵ شناسه، نسخهٔ `8e3903c12d`. مسیر بدون `assets/` اضافه ۴۰۴ بود. Pages از شاخهٔ `main` سرو می‌شود، نه از این شاخه. هر فایل mp3 جداگانه دانلود نشد.

غایب یعنی نه فایل محلی `app/assets/audio/<id>.mp3` هست و نه شناسه در ایندکس میزبان.

| زبان | کلیپ غایب | نویسهٔ متن | نویسهٔ قابل‌صورتحساب |
|---|---:|---:|---:|
| en | 22030 | 884473 | 1705254 |
| fa، hi، ur، ar، ps | هر کدام ۰ | ۰ | ۰ |
| جمع همین دامنه‌ها | 22030 | 884473 | 1705254 |
| ro و bn، جدا و معوق | هر کدام ۰ | ۰ | ۰ |

PL خوانده نشد و در فهرست نیست. برای fa و بقیه کلیپ ساخته نمی‌شود چون پخش‌کننده فقط متن انگلیسی را کلید می‌کند.

از ۲۲۰۳۰ ردیف انگلیسی، ۴۰ ردیف متنِ authored است (ورود ۷ کلیپ، ۴۱۴ / ۷۲۴؛ سراسری ۳۳ کلیپ، ۲۶۳۶ / ۳۶۲۶). ۲۱۹۹۰ ردیف فقط از `build/voice_lines.json` می‌آید (۸۸۱۴۲۳ / ۱۷۰۰۹۰۴): راهنمای شبح، پنج بازخوانی نمونه در هر گره، و واژه‌ها. بدون آن فایل، مولد همان ۲۱۹۹۰ را در صف نمی‌گذارد. هیچ خط authored صحنه هم‌زمان از فایل محلی و ایندکس میزبان غایب نیست.

۱۷۲ کلیپِ مورد انتظار فایل محلی دارند و در ایندکس زنده نیستند؛ در این مانیفست نیستند. ۳۹۹ شناسه در `bundled.json` نام دارند ولی mp3 ندارند.

SHA-256 مانیفست: `b6455c12ff77c7f00751bf3bd134ee17c4eac171be7e86534b37f1a9d8cd11fe`.
