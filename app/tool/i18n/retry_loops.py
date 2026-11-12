"""Second chance for machine translations build_tables.py rejects as loops/garbage (tool/i18n/loops.py): re-decode
with the strict decoder (beam 5, repetition penalty, no repeated 4-grams), English source first, then Persian, then
sentence by sentence. A new output replaces the old one in mt/<code>.json ONLY if it passes the same checks as
translate.py (script, Latin, length) AND loops.py; otherwise the line keeps falling back to English.
Offline NLLB only (same model as translate.py). UI strings first. Never for frozen languages (tool/i18n/frozen.json).
Usage: python3 tool/i18n/retry_loops.py ps ar ...   (MT_RETRY_LIMIT=n caps lines per language)"""
import json, os, re, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
codes, sys.argv = sys.argv[1:], sys.argv[:1]
import translate as T  # loads the model; its CLI loop runs on no codes
from loops import looped
FROZEN = json.load(open(os.path.join(HERE, 'frozen.json'))) if os.path.exists(os.path.join(HERE, 'frozen.json')) else {}
LIMIT = int(os.environ.get('MT_RETRY_LIMIT', '0')) or None
src = T.src
for code in codes:
    if code in FROZEN: print('frozen, skipped:', code); continue
    path = os.path.join(HERE, 'mt', code + '.json'); done = json.load(open(path))
    manp = os.path.join(HERE, 'manual', code + '.json'); man = json.load(open(manp)) if os.path.exists(manp) else {}
    def bad(k, v): return (not isinstance(v, str) or not v or v.startswith('\u0000') or looped(v, src[k].get('en'), code)
                           or ('{you}' in k and '{you}' not in v))
    todo = [k for k in src if k in done and k not in man and bad(k, done[k])]
    todo.sort(key=lambda k: (not src[k].get('ui'), len(src[k].get('en') or k)))
    todo = todo[:LIMIT]
    tgt = T.NLLB[code]; fixed = 0; t0 = time.time()
    # A retry must not trade a loop for a fragment: at least 45% of the source length (short labels excepted).
    def good(k, o, a): return o and T.ok(o, a, code) and not bad(k, o) and (len(a) < 16 or len(o) >= 0.45 * len(a))
    for i in range(0, len(todo), 32):
        chunk = todo[i:i + 32]; left = list(chunk)
        for L in ('eng_Latn', 'pes_Arab'):
            ins = [(k, src[k]['en'] if L == 'eng_Latn' else k) for k in left]
            ins = [(k, a) for k, a in ins if a]
            if not ins: continue
            for (k, a), o in zip(ins, T.run([a for _, a in ins], L, tgt, strict=True)):
                o = T.fix(o, code)
                if good(k, o, a): done[k] = o; left.remove(k); fixed += 1
        for k in list(left):
            for a, L in ((src[k].get('en'), 'eng_Latn'), (k, 'pes_Arab')):
                if not a: continue
                segs = [x for x in re.split(r'(?<=[.!?؟؛;,،])\s+', a) if x.strip()]
                if len(segs) < 2: continue
                o = T.fix(' '.join(T.fix(x, code) for x in T.run(segs, L, tgt, strict=True)), code)
                if good(k, o, a): done[k] = o; left.remove(k); fixed += 1; break
        T.save(done, path)
        n = i + len(chunk); el = time.time() - t0
        print(f'{code} {n}/{len(todo)} fixed={fixed} {n / el:.2f}/s eta {int((len(todo) - n) / max(.01, n / el) / 60)}m', flush=True)
    print(code, 'DONE fixed', fixed, 'of', len(todo), flush=True)
