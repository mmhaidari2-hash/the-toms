# Free-marketing launch kit — New Life UK

Prepared for the owner. **Nothing in this folder has been published or posted.** Fill the placeholders, get the owner's approval, and only then post or print.

Placeholders used throughout:

- `[PLAY_LINK]` — public Google Play listing URL (not live yet)
- `[TESTER_SIGNUP_LINK]` — closed-test opt-in / Play testing link (not open yet)
- `[SUPPORT_EMAIL]` — public support address (create before Play)
- `[YOUR_NAME]` — the name the owner wants to sign as
- QR on the poster currently points at the **test-release page**  
  `https://github.com/mmhaidari2-hash/the-toms-preview/releases`  
  Replace it with `[PLAY_LINK]` before any public print run.

## Contents

| File | What it is |
| --- | --- |
| [LAUNCH_ROADMAP_FA.md](LAUNCH_ROADMAP_FA.md) | Stages from owner prep to post-launch (Persian) |
| [POSTS.md](POSTS.md) | Ready-to-copy EN+FA drafts (groups, Reddit, X, LinkedIn, testers, Product Hunt, AlternativeTo) |
| [SHORT_VIDEOS.md](SHORT_VIDEOS.md) | Ten short-video ideas (TikTok / Reels / Shorts) |
| [poster_qr_EN_FA.png](poster_qr_EN_FA.png) / [poster_qr_EN_FA.pdf](poster_qr_EN_FA.pdf) | A4 poster for libraries, ESOL classes and community centres |
| [store/](store/) | Play feature graphic (1024×500) and captioned phone screenshots |
| [REVIEWS_AND_OUTREACH_FA.md](REVIEWS_AND_OUTREACH_FA.md) | Asking for ratings, plus a local outreach checklist and email/visit template |

Play store text already delivered lives outside this folder (`title` / `short` / `full` / X interest). Reuse it; do not contradict it. Do not claim full offline, general AI, official visa or exam guarantees, or that a closed test is already open.

## Regenerating graphics

From `app/`:

```bash
STORE_SHOTS=1 flutter test test/store_screenshots_test.dart
```

Then, with fonts and the 3D icon in the repo:

```bash
python3 app/tool/make_launch_kit.py --repo .
```

The screenshot test is skipped in the normal suite unless `STORE_SHOTS=1`. Do not run the full test suite just to refresh these images. Headless Material icons are loaded in the test harness so toolbar icons are not squares.

`sdk: ^3.13.7` stays in `pubspec.yaml`. No Azure spend. Do not publish the live site or merge to `main` from this kit.
