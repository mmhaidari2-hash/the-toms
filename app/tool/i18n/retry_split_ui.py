"""UI lines whose machine translation silently dropped a sentence (NLLB drops whole sentences from multi-sentence
input: a disclaimer "General information only. ... use GOV.UK and an IAA-regulated adviser." came back as its middle
sentence only). For UI strings whose English has 2+ sentences and whose translation has fewer, the English is
re-translated sentence by sentence (offline NLLB, same decoder as translate.py) and joined. The new output replaces
the old one ONLY if it passes translate.py's checks and loops.py and is longer than the old one; otherwise the old
output stays. Never manual lines, never frozen languages (tool/i18n/frozen.json). MT stays unreviewed by a person.
Usage: python3 tool/i18n/retry_split_ui.py ps ur ..."""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
codes, sys.argv = sys.argv[1:], sys.argv[:1]
import translate as T
from loops import looped
FROZEN = json.load(open(os.path.join(HERE, 'frozen.json'))) if os.path.exists(os.path.join(HERE, 'frozen.json')) else {}
SPLIT = r'(?<=[.!?؟۔।])\s+'
def sents(t): return [x for x in re.split(SPLIT, t.strip()) if re.search(r'\w', x)]
src = T.src
for code in codes:
    if code in FROZEN: print('frozen, skipped:', code); continue
    path = os.path.join(HERE, 'mt', code + '.json'); done = json.load(open(path))
    manp = os.path.join(HERE, 'manual', code + '.json'); man = json.load(open(manp)) if os.path.exists(manp) else {}
    todo = [k for k, v in done.items() if k in src and k not in man and src[k].get('ui') and src[k].get('en') and isinstance(v, str)
            and v and not v.startswith('\u0000') and len(sents(src[k]['en'])) >= 2 and len(sents(v)) < len(sents(src[k]['en']))]
    tgt = T.NLLB[code]; fixed = 0
    for k in todo:
        en = src[k]['en']; segs = sents(en)
        o = T.fix(' '.join(T.fix(x, code) for x in T.run(segs, 'eng_Latn', tgt)), code)
        if (T.ok(o, en, code) and not looped(o, en, code) and len(o) > len(done[k]) and ('{you}' not in k or '{you}' in o)):
            done[k] = o; fixed += 1
    T.save(done, path); print(code, 'split-retranslated', fixed, 'of', len(todo), flush=True)
