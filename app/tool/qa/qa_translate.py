"""Translation fidelity of practice prompts. A "Build the sentence" / "Fill the gap" prompt must carry the whole meaning
of its English answer. Each helper-language prompt is back-translated to English (NLLB, cached) and scored against the
answer: content-word coverage, length ratio, names and numbers kept.
- Persian (the source language): a flagged prompt is BLOCKING until rewritten or reviewed (tool/qa/fa_reviewed.json).
- Other helper languages: flagged prompts go to tool/i18n/prompt_flags.json; tool/i18n/build_tables.py drops them, so
  the exercise falls back to the audio prompt instead of showing a wrong translation."""
import os, re, json, glob, random, time
H = os.path.dirname(os.path.abspath(__file__)); APP = os.path.abspath(os.path.join(H, '..', '..'))
CACHE = os.path.join(H, 'cache'); os.makedirs(CACHE, exist_ok=True)
STOP = set("""a an the i you he she it we they me him her us them my your his its our their mine yours is am are was were be been being do does did
to of in on at for with and or but so if then than that this these those there here not no yes oh ah um er well just very really too also
can could will would shall should may might must have has had get got go going gonna let s t ll ve re d m ok okay please thanks thank right
what which who whom whose when where why how all any some one ones as by from up down out off about into over again now hello hi""".split())
CONTR = [("n't", " not"), ("'m", " am"), ("'re", " are"), ("'ll", " will"), ("'ve", " have"), ("'d", " would"), ("'s", " is")]
SYN = {'mum': 'mother', 'mummy': 'mother', 'dad': 'father', 'daddy': 'father', 'kid': 'child', 'kids': 'child', 'children': 'child', 'telly': 'tv',
       'television': 'tv', 'quid': 'pound', 'flat': 'apartment', 'loo': 'toilet', 'lovely': 'beautiful', 'brilliant': 'great', 'cuppa': 'tea',
       'film': 'movie', 'rubbish': 'garbage', 'queue': 'line', 'holiday': 'vacation', 'biscuit': 'cookie', 'nan': 'grandmother', 'nana': 'grandmother',
       'granny': 'grandmother', 'grandad': 'grandfather', 'grandpa': 'grandfather', 'yeah': 'yes', 'yep': 'yes', 'mate': 'friend', 'cheers': 'thank',
       'shop': 'store', 'little': 'small', 'tiny': 'small', 'big': 'large', 'huge': 'large', 'scared': 'afraid', 'frightened': 'afraid',
       'poorly': 'sick', 'ill': 'sick', 'unwell': 'sick', 'nappy': 'diaper', 'pram': 'stroller', 'sweets': 'candy', 'chips': 'fries', 'jumper': 'sweater',
       'lift': 'elevator', 'trousers': 'pants', 'autumn': 'fall', 'fancy': 'want', 'reckon': 'think', 'bloke': 'man', 'lad': 'boy', 'lass': 'girl',
       'brolly': 'umbrella', 'motorway': 'highway', 'pavement': 'sidewalk', 'car park': 'parking', 'bin': 'trash', 'post': 'mail', 'postcode': 'zip',
       'surname': 'name', 'doctor': 'doctor', 'gp': 'doctor', 'surgery': 'clinic', 'chemist': 'pharmacy', 'nursery': 'kindergarten', 'tidy': 'clean',
       'glad': 'happy', 'pleased': 'happy', 'wonderful': 'great', 'fantastic': 'great', 'amazing': 'great', 'awesome': 'great', 'excellent': 'great',
       'perfect': 'great', 'nice': 'good', 'fine': 'good', 'tasty': 'delicious', 'yummy': 'delicious', 'hungry': 'hungry', 'tired': 'tired', 'sleepy': 'tired'}
NUMW = {'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10', 'eleven': '11',
        'twelve': '12', 'twenty': '20', 'thirty': '30', 'forty': '40', 'fifty': '50', 'hundred': '100', 'first': '1', 'second': '2', 'third': '3', 'half': '1/2'}
def words(t):
    t = t.lower().replace('’', "'").replace('{you}', ' sam ')
    for a, b in CONTR: t = t.replace(a, b)
    return re.findall(r"[a-z0-9]+", t)
def stem(w):
    w = SYN.get(w, w); w = NUMW.get(w, w)
    for suf in ('ies', 'ing', 'ed', 'es', 's', 'ly', 'er', 'est'):
        if len(w) > 4 and w.endswith(suf): return w[:-len(suf)]
    return w
CHAR = set()
for c in json.load(open(os.path.join(APP, 'assets', 'data', 'characters.json'))):
    CHAR |= {w.lower() for w in c['name'].split()} - {'nana', 'grandad', 'mrs', 'mr', 'dr', 'auntie', 'uncle', 'baby'}
def score(en, bt):
    ew = words(en); bw = words(bt); cont = [w for w in ew if w not in STOP]
    bset = {stem(w) for w in bw}
    def has(w):
        s = stem(w)
        return s in bset or any(len(s) >= 4 and (b.startswith(s[:4]) or s.startswith(b[:4]) and len(b) >= 4) for b in bset)
    miss = [w for w in cont if not has(w)]
    names = [w for w in re.findall(r"\b[A-Z][a-z]+", en) if w.lower() in CHAR]
    mname = [n for n in names if not any(b.startswith(n.lower()[:3]) for b in bw)]
    ratio = len(bw) / max(1, len(ew)); cov = 1 - len(miss) / max(1, len(cont))
    bad = (len(cont) >= 2 and cov < 0.5) or (len(cont) >= 4 and len(miss) >= 3) or (len(ew) >= 4 and ratio < 0.5) or bool(mname)
    return {'bad': bad, 'cov': round(cov, 2), 'ratio': round(ratio, 2), 'miss': miss, 'mname': mname}
def best(en, samples):
    rs = [score(en, s) for s in samples]
    return min(rs, key=lambda r: (r['bad'], -r['cov'])) if rs else None

GARB = re.compile(r'[^\x00-\x7F’‘“”—–…éèàçñ£€]|_Latn|_Arab')
def garbage(t): return (not t.strip()) or bool(GARB.search(t)) or bool(re.search(r'(\b\w+\b)(\W+\1\b){2,}', t))
_tr = None
def mt(texts, src, tries=6, split=True, samples=1):
    """Back-translate to English. CTranslate2 on this box sometimes returns garbage (non-deterministic), so outputs are
    checked and retried; returns {text: [outputs]}."""
    global _tr, _sp
    import ctranslate2, sentencepiece as spm
    if _tr is None:
        _sp = spm.SentencePieceProcessor(model_file='/workspace/mt/nllb13/sentencepiece.bpe.model')
        _tr = ctranslate2.Translator(os.environ.get('NLLB', '/workspace/mt/onmt13'), device='cpu', compute_type='int8', intra_threads=2)
    # NLLB drops whole sentences from multi-sentence input ("Yes, my neighbours. They're like family." -> "Yeah, my
    # neighbors."), so each sentence is translated on its own and the parts joined.
    if split:
        segs = {t: [x for x in re.split(r'(?<=[.!?؟…!])\s+', t.strip()) if x.strip()] for t in texts}
        flat = sorted({x for v in segs.values() for x in v})
        got = mt(flat, src, tries, split=False, samples=samples)
        res = {}
        for t, v in segs.items():
            res[t] = []
            for k in range(samples):
                parts = [got[x][k % len(got[x])] if got[x] else None for x in v]
                if all(parts): res[t].append(' '.join(parts))
        return res
    out = {t: [] for t in texts}; todo = list(texts)
    for _ in range(tries):
        if not todo: break
        for i in range(0, len(todo), 32):
            ch = todo[i:i + 32]
            toks = [[src] + _sp.encode(t.replace('{you}', 'Sam'), out_type=str) + ['</s>'] for t in ch]
            res = _tr.translate_batch(toks, target_prefix=[['eng_Latn']] * len(ch), beam_size=2, max_batch_size=32, max_decoding_length=min(160, 20 + 3 * max(map(len, toks))))
            for t, r in zip(ch, res):
                o = _sp.decode(r.hypotheses[0][1:])
                if not garbage(o): out[t].append(o)
        todo = [t for t in todo if len(out[t]) < samples]
    return out

def pairs():
    """(scene, node, branch, english, persian) for every suggestion a practice item can be built from."""
    out = []
    for f in sorted(glob.glob(os.path.join(APP, 'assets', 'data', 'scenes', '*.json'))):
        d = json.load(open(f))
        for nid, n in d['nodes'].items():
            for i, b in enumerate(n.get('branches', [])):
                if b.get('suggestion') and b.get('suggestionFa'): out.append((os.path.basename(f)[:-5], nid, i, b['suggestion'], b['suggestionFa']))
    return out
def fa_words(s): return len([w for w in re.split(r'[\s\u200c]+', re.sub(r'[^\w\s\u200c]', ' ', s)) if w])
def clauses(s): return len([x for x in re.split(r'[.!?؟,،;؛…:—–۔।]+', s) if x.strip()])
_FILL = r'(I think|I guess|I suppose|then|too|please|actually|obviously|definitely|maybe|really|roughly|nearly|exactly|originally|either|though|sadly|to be honest|honestly|of course|mind)'
_VOC = r'(Mrs |Mr |Dr |Miss )?([A-Z][a-z]+|\{you\}|doctor|love|dear|mate|sweetheart|everybody|everyone|sir|boss|chef|teacher|girls|boys)'
def clauses_en(s):
    """Clauses in the English answer, not counting vocatives (", Nicola") and fillers (", I think"), which Persian
    attaches without a comma."""
    s = re.sub(r',\s*' + _FILL + r'\b', '', s, flags=re.I); s = re.sub(r'(^|[.!?]\s*)' + _FILL + r',', r'\1', s, flags=re.I)
    s = re.sub(r',\s*' + _VOC + r'(?=[.!?,]|$)', '', s); s = re.sub(r'(^|[.!?]\s*)' + _VOC + r',', r'\1', s)
    s = re.sub(r'^(In|On|At|From|Next|First|Yesterday|Secretly|Now|Gently|Like)( [^,]+)?,', '', s)
    return clauses(s)
SCRIPT = {'ar': '\u0600-\u06ff\u0750-\u077f\ufb50-\ufdff\ufe70-\ufeff', 'hi': '\u0900-\u097f', 'bn': '\u0980-\u09ff', 'pa': '\u0a00-\u0a7f',
          'zh': '\u3400-\u9fff\uf900-\ufaff', 'uk': '\u0400-\u04ff', 'ti': '\u1200-\u139f\u2d80-\u2ddf'}
for _c in ('ps', 'ur', 'ckb', 'prs'): SCRIPT[_c] = SCRIPT['ar']
SCRIPT['zh-Hant'] = SCRIPT['zh']
def wrong_script(t, code):
    """Machine-translation garbage in a helper table: other scripts mixed in, NLLB language tags, or a word looping."""
    if not t.strip() or re.search(r'_[A-Z][a-z]{3}\b|\bzho_|\barb_', t) or re.search(r'(\b\w+\b)(\W+\1\b){3,}', t): return True
    if code not in SCRIPT: return bool(re.search(r'[^\x00-\u024f\u2000-\u206f\u20a0-\u20cf«»…–—]', t))
    letters = [ch for ch in t if ch.isalpha()]
    if not letters: return False
    own = sum(1 for ch in letters if re.match('[' + SCRIPT[code] + ']', ch))
    latin = sum(1 for ch in letters if ch.isascii())
    return own + latin < len(letters) or own < 0.6 * len(letters)
def build_eligible(en): return 3 <= len(en.split(' ')) <= 7

NLLB = {'hi': 'hin_Deva', 'bn': 'ben_Beng', 'pa': 'pan_Guru', 'zh': 'zho_Hans', 'zh-Hant': 'zho_Hant', 'ar': 'arb_Arab', 'uk': 'ukr_Cyrl', 'ps': 'pbt_Arab',
        'ur': 'urd_Arab', 'ckb': 'ckb_Arab', 'tr': 'tur_Latn', 'es': 'spa_Latn', 'prs': 'prs_Arab', 'pl': 'pol_Latn', 'ro': 'ron_Latn', 'pt': 'por_Latn', 'ti': 'tir_Ethi'}

def run(log=print, allow_mt=True, per_lang=int(os.environ.get('QA_MT_PER_LANG', '40'))):
    issues, stats = [], {}
    P = pairs(); stats['practice prompt pairs (en ↔ fa)'] = len(P)
    stats['build-the-sentence eligible'] = sum(build_eligible(p[3]) for p in P)
    # ---- Persian
    cp = os.path.join(CACHE, 'bt_fa.json'); bt = json.load(open(cp)) if os.path.exists(cp) else {}
    new = sorted({p[4] for p in P if p[4] not in bt})
    if new and allow_mt:
        log(f'translation: back-translating {len(new)} new Persian prompts'); bt.update(mt(new, 'pes_Arab')); json.dump(bt, open(cp, 'w'), ensure_ascii=False)
    rev = json.load(open(os.path.join(H, 'fa_reviewed.json'))) if os.path.exists(os.path.join(H, 'fa_reviewed.json')) else {}
    flagged = []
    for sc, nid, i, en, fa in P:
        r = best(en, bt.get(fa, []))
        if r is None: issues.append(('warn', 'Persian prompt not back-translated yet', f'{sc}/{nid}#{i}', f'{en} ↔ {fa}')); continue
        # Back-translation alone is noisy (NLLB paraphrases and drops sentences), so a Persian prompt BLOCKS only when two
        # independent signals agree, or when it has fewer clauses than the answer (a dropped "go on" / "We do!"):
        # everything else is a warning. Prompts a person has checked are listed in tool/qa/fa_reviewed.json.
        short = fa_words(fa) / max(1, len(re.findall(r"[A-Za-z0-9']+", en))) < 0.72
        fewer = clauses(fa) < clauses_en(en)
        if (r['bad'] or fewer) and rev.get(fa) != en:
            hard = build_eligible(en) and ((r['bad'] and short) or fewer)
            flagged.append((sc, nid, i, en, fa, r))
            why = 'fewer clauses than the answer' if fewer else f"missing {', '.join(r['miss'] + r['mname'])}"
            issues.append(('block' if hard else 'warn', 'Persian prompt does not match the answer', f'{sc}/{nid}#{i}',
                           f"{en} ↔ {fa} (back: “{(bt.get(fa) or [''])[0]}”; {why})"))
    stats['Persian prompts flagged'] = len(flagged)
    json.dump([dict(scene=a, node=b, i=c, en=d, fa=e, **r) for a, b, c, d, e, r in flagged], open(os.path.join(H, 'cache', 'fa_flagged.json'), 'w'), ensure_ascii=False, indent=0)
    # ---- other helper languages: sample, back-translate, flag
    flags_p = os.path.join(APP, 'tool', 'i18n', 'prompt_flags.json')
    flags = json.load(open(flags_p)) if os.path.exists(flags_p) else {}
    en_of = {}; quality = {}
    for p in P:
        if build_eligible(p[3]): en_of.setdefault(p[4], p[3])
    for code, src in NLLB.items():
        tp = os.path.join(APP, 'assets', 'i18n', code + '.json')
        if not os.path.exists(tp): continue
        tab = json.load(open(tp))
        have = [fa for fa in en_of if fa in tab]
        stats[f'{code}: build prompts translated'] = f'{len(have)}/{len(en_of)}'
        cpl = os.path.join(CACHE, f'bt_{code}.json'); c = json.load(open(cpl)) if os.path.exists(cpl) else {}
        todo = [fa for fa in have if f'{fa}\u0001{tab[fa]}' not in c]
        random.Random(len(todo)).shuffle(todo); todo = todo[:per_lang]
        if todo and allow_mt:
            got = mt([tab[fa] for fa in todo], src)
            for fa in todo: c[f'{fa}\u0001{tab[fa]}'] = got.get(tab[fa], [])
            json.dump(c, open(cpl, 'w'), ensure_ascii=False)
        fl = set(flags.get(code, [])); checked = 0; btbad = 0
        for fa in have:
            outs = c.get(f'{fa}\u0001{tab[fa]}')
            if not outs: continue
            checked += 1; r = best(en_of[fa], outs)
            if r and r['bad'] and fa not in fl:
                btbad += 1; issues.append(('warn', f'{code}: back-translation does not cover the answer (sampled)', fa, f"{en_of[fa]} ↔ {tab[fa]} (back: “{outs[0]}”)"))
        # Deterministic checks on every build prompt: machine-translation garbage, or a length far from this language's
        # usual ratio to English (a dropped or repeated clause). Those prompts are dropped from the table at build time,
        # so the exercise plays the sentence instead.
        rat = sorted(len(tab[fa]) / max(1, len(en_of[fa])) for fa in have) or [1]
        med = rat[len(rat) // 2]
        for fa in have:
            t = tab[fa]; q = len(t) / max(1, len(en_of[fa])) / med
            bad = wrong_script(t, code)
            few = clauses(t) < clauses_en(en_of[fa])
            if (bad or few or q < 0.62 or q > 2.1) and fa not in fl:
                fl.add(fa); issues.append(('fixed', f'{code}: prompt translation unreliable → audio prompt instead', fa, f"{en_of[fa]} ↔ {t} ({'garbage' if bad else 'fewer clauses' if few else f'length ×{q:.2f}'})"))
        flags[code] = sorted(fl)
        quality[code] = {'prompts': len(en_of), 'flagged': len(fl), 'flag_share': round(len(fl) / max(1, len(en_of)), 4),
                         'bt_checked': checked, 'bt_mismatch': btbad, 'bt_mismatch_rate': round(btbad / max(1, checked), 4)}
        stats[f'{code}: prompts back-translated (sampled, total) / flagged'] = f'{checked} / {len(fl)}'
    json.dump(flags, open(flags_p, 'w'), ensure_ascii=False, indent=0, sort_keys=True)
    # Per-language quality, read by tool/i18n/build_tables.py to decide ready vs beta.
    json.dump(quality, open(os.path.join(APP, 'tool', 'i18n', 'quality.json'), 'w'), indent=1, sort_keys=True)
    return {'issues': issues, 'stats': stats}
