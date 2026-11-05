# Natural voice review

This is a limited review of seven existing clips, not certification of the whole
library. No production audio, speaker assignment, pitch, rate or text was changed.
The synthetic origin of the audio should remain disclosed.

## Sample review

Automated listening was used for triage. Naturalness is subjective; a native
English listener should approve an A/B sample before any bulk regeneration.

| Speaker | Existing clip key | Sample-level finding | Next action |
| --- | --- | --- | --- |
| Tom | `09877c969180121a` | “builder's — strong” sounds disjointed | A/B a more connected delivery, preserving wording and voice identity |
| Leslie | `01fffcc2e0698b22` | Relatively natural and clear in this sample | Retain as comparison reference |
| Nicola | `309735d693f32b6d` | High/exclamatory “Wheee!” delivery sounds artificial | Prioritize a reviewed child-voice A/B; do not just raise pitch |
| Learner | `563770d7291b16ca` | Clear but somewhat word-by-word rhythm | Test connected speech without sacrificing beginner intelligibility |
| Weda | `357979d49bfd2cc9` | Possible abrupt phrase transition; subjective | Have a native listener compare before changing pronunciation |
| Narrator | `008d0dbc8c293f19` | Relatively natural, clear and measured | Retain as comparison reference |
| William | `021e8e1dcc33f95a` | Listening review flagged mechanical rhythm/intonation | Include in child-voice A/B; do not certify from file-existence tests |

The seven source MP3s were concatenated for comparison without pitch, rate or
loudness processing. One second of silence was added after each original clip.
This comparison file is not a replacement asset.

## Signal checks are separate

The project's `qa_audio.analyse(key)` was also run on these seven originals.
It reported `cut=false` and `clip=false` for every sample, with approximately
0.28–0.30 seconds of tail and speech loudness between -21.3 and -21.7 dBFS.
Thus a perceptual impression of an abrupt ending is not evidence of digital
clipping or a file truncated at its final sample. These checks do not measure
natural intonation.

## Release gate for future generation

- Start with a handful of full-sentence A/B samples, including questions,
  contractions, names, child exclamations and connected dialogue.
- Keep the current character identities unless the owner approves replacements.
- Review intelligibility, UK pronunciation, conversational rhythm and consistent
  emotional tone, not just voice-model labels or average pitch.
- Obtain explicit approval of the chosen samples and paid generation scope before
  running the speech API in bulk. No paid API was invoked for this review.
- Preserve old clips for rollback. Automatic pruning is now opt-in with
  `RENDER_PRUNE_OBSOLETE=1`; inventory without generation is available through
  `python3 tool/render_voices.py --dry-run`.
- Re-run content/audio coverage, identity, signal and offline playback tests after
  regeneration. A correct speaker manifest does not prove natural-sounding speech.
