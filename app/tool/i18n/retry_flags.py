"""Second chance for practice prompts tool/qa/qa_translate.py flagged (tool/i18n/prompt_flags.json, dropped at build
so the exercise plays audio instead). Only machine-translated lines (never a line in manual/<code>.json, never a frozen
language). Each flagged prompt is re-translated from its English answer with the strict decoder, sentence by sentence,
and accepted ONLY if it passes every deterministic check qa_translate.py applies (script, clause count, length vs the
language's median ratio), translate.py's QA, loops.py, AND a fresh back-translation (NLLB, offline) that covers the
English answer (qa_translate.score not bad). Accepted prompts replace mt/<code>.json and leave the flag list; the rest
stay flagged. Machine translation remains unreviewed by a person.
Usage: python3 tool/i18n/retry_flags.py ur ro"""
import json, os, re, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); APP = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(APP, 'tool', 'qa'))
codes, sys.argv = sys.argv[1:], sys.argv[:1]
import translate as T
import qa_translate as Q
from loops import looped
FROZEN = json.load(open(os.path.join(HERE, 'frozen.json'))) if os.path.exists(os.path.join(HERE, 'frozen.json')) else {}
flags_p = os.path.join(HERE, 'prompt_flags.json'); flags = json.load(open(flags_p))
en_of = {}
for p in Q.pairs():
    if Q.build_eligible(p[3]): en_of.setdefault(p[4], p[3])
for code in codes:
    if code in FROZEN: print('frozen, skipped:', code); continue
    path = os.path.join(HERE, 'mt', code + '.json'); done = json.load(open(path))
    manp = os.path.join(HERE, 'manual', code + '.json'); man = json.load(open(manp)) if os.path.exists(manp) else {}
    tab = json.load(open(os.path.join(APP, 'assets', 'i18n', code + '.json')))
    have = [fa for fa in en_of if fa in tab]
    rat = sorted(len(tab[fa]) / max(1, len(en_of[fa])) for fa in have) or [1]; med = rat[len(rat) // 2]
    fl = set(flags.get(code, []))
    todo = sorted(fa for fa in fl if fa in en_of and fa not in man and fa in T.src)
    tgt = T.NLLB[code]; ok_n = 0; t0 = time.time()
    for i in range(0, len(todo), 48):
        chunk = todo[i:i + 48]; cand = {}
        for fa in chunk:
            segs = [x for x in re.split(r'(?<=[.!?])\s+', en_of[fa].strip()) if x.strip()]
            cand[fa] = segs
        flat = sorted({s for v in cand.values() for s in v})
        out = dict(zip(flat, T.run(flat, 'eng_Latn', tgt, strict=True)))
        new = {}
        for fa, segs in cand.items():
            o = T.fix(' '.join(T.fix(out[s], code) for s in segs), code); en = en_of[fa]
            q = len(o) / max(1, len(en)) / med
            if (not o or not T.ok(o, en, code) or looped(o, T.src[fa].get('en'), code) or Q.wrong_script(o, code)
                    or Q.clauses(o) < Q.clauses_en(en) or q < 0.62 or q > 2.1 or ('{you}' in fa and '{you}' not in o)): continue
            new[fa] = o
        if new:
            bt = Q.mt(list(set(new.values())), tgt)
            for fa, o in new.items():
                r = Q.best(en_of[fa], bt.get(o, []))
                if r and not r['bad']: done[fa] = o; fl.discard(fa); ok_n += 1
        T.save(done, path); flags[code] = sorted(fl)
        json.dump(flags, open(flags_p + '.tmp', 'w'), ensure_ascii=False, indent=0, sort_keys=True); os.replace(flags_p + '.tmp', flags_p)
        n = i + len(chunk); el = time.time() - t0
        print(f'{code} {n}/{len(todo)} accepted={ok_n} {n / el:.2f}/s eta {int((len(todo) - n) / max(.01, n / el) / 60)}m', flush=True)
    print(code, 'DONE accepted', ok_n, 'of', len(todo), flush=True)
