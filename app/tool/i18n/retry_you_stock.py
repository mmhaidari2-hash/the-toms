"""Third chance (t307) for two kinds of lines build_tables.py drops to English:
1. {you} lost: NLLB rewrites the learner-name placeholder as "you"/"آپ". The English source is translated with the
   placeholder masked as the name "Sam"; the output is accepted only if the name appears exactly as many times as
   {you} (as a whole word, in the target script's usual spelling), and it is then put back as {you}.
2. Stock hallucinations: one output reused for >= 5 unrelated sources (same rule as build_tables.py). Those lines
   are re-decoded with the strict decoder, one at a time.
Every new output must pass the same checks as translate.py (script, Latin, length) and loops.py; otherwise the line
keeps falling back to English. Offline NLLB only. Never manual lines, never frozen languages (tool/i18n/frozen.json).
Usage: python3 tool/i18n/retry_you_stock.py ur ro ..."""
import json, os, re, sys
from collections import defaultdict
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
codes, sys.argv = sys.argv[1:], sys.argv[:1]
import translate as T
from loops import looped
FROZEN = json.load(open(os.path.join(HERE, 'frozen.json'))) if os.path.exists(os.path.join(HERE, 'frozen.json')) else {}
NAME = {'Latn': ['Sam'], 'Arab': ['سام', 'سم'], 'Deva': ['सैम', 'सम'], 'Beng': ['স্যাম'], 'Guru': ['ਸੈਮ'], 'Cyrl': ['Сэм', 'Сем']}
src = T.src
def stock_of(done, code):
    uses = defaultdict(list)
    for k, v in done.items():
        if k in src and isinstance(v, str) and v and not v.startswith('\u0000'): uses[v].append(src[k].get('en') or k)
    st = {v for v, ens in uses.items() if len(ens) >= 5 and len(set(e.lower() for e in ens)) >= 5 and sum(len(e) for e in ens) / len(ens) > 9
          and not set.intersection(*[set(re.findall(r'[a-z]+', e.lower())) for e in ens])}
    return {k for k, v in done.items() if v in st and k in src}
for code in codes:
    if code in FROZEN: print('frozen, skipped:', code); continue
    path = os.path.join(HERE, 'mt', code + '.json'); done = json.load(open(path))
    manp = os.path.join(HERE, 'manual', code + '.json'); man = json.load(open(manp)) if os.path.exists(manp) else {}
    tgt = T.NLLB[code]; sc = tgt.split('_')[1]
    def good(k, o, a): return o and T.ok(o, a, code) and not looped(o, src[k].get('en'), code) and (len(a) < 16 or len(o) >= 0.45 * len(a))
    you = [k for k in src if k in done and k not in man and '{you}' in k and isinstance(done[k], str) and '{you}' not in done[k]
           and src[k].get('en') and '{you}' in src[k]['en']]
    fy = 0
    for i in range(0, len(you), 32):
        ch = you[i:i + 32]; ins = [src[k]['en'].replace('{you}', 'Sam') for k in ch]
        for strict in (False, True):
            left = [j for j, k in enumerate(ch) if '{you}' not in str(done[k])]
            if not left: break
            for j, o in zip(left, T.run([ins[j] for j in left], 'eng_Latn', tgt, strict)):
                k = ch[j]; o = T.fix(o, code); n = src[k]['en'].count('{you}')
                for nm in NAME.get(sc, []):
                    pat = r'(?<![^\W\d_])' + re.escape(nm) + r'(?![^\W\d_])'
                    if len(re.findall(pat, o)) == n:
                        o2 = re.sub(pat, '{you}', o)
                        if good(k, o2, src[k]['en']): done[k] = o2; fy += 1
                        break
    T.save(done, path); print(code, '{you} fixed', fy, 'of', len(you), flush=True)
    st = sorted(k for k in stock_of(done, code) if k not in man); fs = 0
    for k in st:
        for a, L in ((src[k].get('en'), 'eng_Latn'), (k, 'pes_Arab')):
            if not a: continue
            o = T.fix(T.run([a], L, tgt, strict=True)[0], code)
            if good(k, o, a) and ('{you}' not in k or '{you}' in o): done[k] = o; fs += 1; break
        else: done[k] = '\u0000' + str(done[k]).lstrip('\u0000')  # still the stock garbage: keep it marked as failed
    T.save(done, path); print(code, 'stock re-decoded', fs, 'of', len(st), 'left', len(stock_of(done, code)), flush=True)
