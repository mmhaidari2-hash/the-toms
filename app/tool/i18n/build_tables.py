"""Build the helper-language tables the app loads: assets/i18n/<code>.json = {Persian source: translation}, plus
assets/i18n/en.json (Persian -> English, the fallback for beta languages), and lib/core/i18n/coverage.g.dart
(share of strings translated per language; a finished run with >= 85% kept and passing the quality bar in quality.json shows as ready,
anything less as beta, nothing as coming soon).
Safe to run while translate.py is still writing: a table that does not parse yet is skipped this time.
Usage: python3 tool/i18n/build_tables.py"""
import json, os
H = os.path.dirname(os.path.abspath(__file__)); APP = os.path.join(H, '..', '..')
OUT = os.path.join(APP, 'assets', 'i18n'); os.makedirs(OUT, exist_ok=True)
src = json.load(open(os.path.join(H, 'sources.json')))
REWRITES = json.load(open(os.path.join(H, 'fa_rewrites.json'))) if os.path.exists(os.path.join(H, 'fa_rewrites.json')) else {}
RENAMES = json.load(open(os.path.join(H, 'brand_renames.json'))) if os.path.exists(os.path.join(H, 'brand_renames.json')) else []
FLAGS = json.load(open(os.path.join(H, 'prompt_flags.json'))) if os.path.exists(os.path.join(H, 'prompt_flags.json')) else {}
QUALITY = json.load(open(os.path.join(H, 'quality.json'))) if os.path.exists(os.path.join(H, 'quality.json')) else {}
CODES = ['hi', 'ur', 'zh', 'ar', 'uk', 'prs', 'ps', 'bn', 'pa', 'ro', 'pl', 'ti', 'ckb', 'tr', 'es', 'pt', 'zh-Hant']
import re
def looped(out, en, code=''):
    """Machine-translation loops ("before retirement already one before retirement"): a phrase repeated that the
    English does not repeat, or an output far longer than its source. Those fall back to English."""
    w = re.findall(r'[^\W\d_]+', out.lower())
    grams = [' '.join(w[i:i + 3]) for i in range(len(w) - 2)]
    ew = re.findall(r'[^\W\d_]+', (en or '').lower())
    egrams = [' '.join(ew[i:i + 3]) for i in range(len(ew) - 2)]
    if en and len(grams) != len(set(grams)) and len(egrams) == len(set(egrams)): return True
    # No English source (Persian-only lines): only a phrase repeated three times or more is a loop.
    if not en and grams and max(grams.count(g) for g in set(grams)) >= 3: return True
    if '{you}' in (en or '') and '{you}' not in out: return True  # the learner's name placeholder must survive
    if en and len(en) > 25 and len(out) < (0.12 if code.startswith('zh') else 0.3) * len(en): return True  # a long sentence collapsed to a fragment
    return bool(en) and len(out) > 3 * len(en) + 25
def dump(name, d):
    json.dump(d, open(os.path.join(OUT, name + '.json'), 'w'), ensure_ascii=False, separators=(',', ':'), sort_keys=True)
dump('en', {k: v['en'] for k, v in src.items() if v.get('en')})
cov = {}
complete = set()  # every source line went through the translator (rejected ones fall back to English)
# Languages whose machine-translation run has not passed its gate yet (tool/i18n/hold.json): kept at 'coming soon'
# and their table removed, even if a half-finished mt/<code>.json already clears the 85% key bar. Remove a code from
# hold.json once its run has passed (e.g. /workspace/run31/robust_mt.passed) and its QA has been reviewed.
BETA_HOLD = json.load(open(os.path.join(H, 'beta_hold.json'))) if os.path.exists(os.path.join(H, 'beta_hold.json')) else {}
HOLD = set(json.load(open(os.path.join(H, 'hold.json')))) if os.path.exists(os.path.join(H, 'hold.json')) else set()
for c in CODES:
    if c in HOLD:
        cov[c] = 0.0; print('hold (not shipped):', c)
        if os.path.exists(os.path.join(OUT, c + '.json')): os.remove(os.path.join(OUT, c + '.json'))
        continue
    p = os.path.join(H, 'mt', c + '.json')
    if not os.path.exists(p): cov[c] = 0.0; continue
    try: mt = json.load(open(p))
    except Exception: print('skip (still writing):', c); old = os.path.join(OUT, c + '.json'); cov[c] = None; continue
    # Skip incomplete or high-NUL MT so mid-run langs are not shipped.
    _nul = sum(1 for v in mt.values() if isinstance(v, str) and v.startswith('\u0000'))
    if len(mt) < 0.85 * len(src) or _nul > 0.12 * max(1, len(mt)):
        print('skip (incomplete or dirty):', c, f'keys={len(mt)}/{len(src)} nul={_nul}'); cov[c] = 0.0; continue
    mt = {k: v.replace(' \u2047 ', ' — ').replace('\u2047', '—') if isinstance(v, str) else v for k, v in mt.items()}
    # Persian prompts rewritten to match their English answer (tool/i18n/fa_rewrites.json): the new Persian key keeps the
    # translation of the old one when that translation was made from the same English sentence.
    for new, r in REWRITES.items():
        if new in mt or r['old'] not in mt or not isinstance(mt[r['old']], str): continue
        if r.get('rename'):  # a real brand renamed (tool/i18n/brand_renames.json): same rename in the translation
            v = mt[r['old']]
            for x, y in RENAMES: v = v.replace(x, y)
            mt[new] = v
        elif r.get('en') and src.get(new, {}).get('en') == r['en']: mt[new] = mt[r['old']]
    t = {k: v for k, v in mt.items() if k in src and isinstance(v, str) and v and not v.startswith('\u0000') and not looped(v, src[k].get('en'), c)}
    print(c, 'rejected as loops:', sum(1 for k, v in mt.items() if k in src and isinstance(v, str) and v and not v.startswith('\u0000') and looped(v, src[k].get('en'), c)))
    # One output reused for many unrelated, longer sources is a stock hallucination ("हयात" for "Theory test",
    # "Vocabulary", "My mistakes"...): drop it everywhere so those lines fall back to English.
    from collections import defaultdict
    uses = defaultdict(list)
    for k, v in t.items(): uses[v].append((src[k].get('en') or k))
    stock = {v for v, ens in uses.items() if len(ens) >= 5 and len(set(e.lower() for e in ens)) >= 5 and sum(len(e) for e in ens) / len(ens) > 9
             and not set.intersection(*[set(re.findall(r'[a-z]+', e.lower())) for e in ens])}
    stock |= {v for v in uses if v.strip(' .') in ('हयात',)}
    t = {k: v for k, v in t.items() if v not in stock}
    print(c, 'stock outputs dropped:', len(stock))
    # Lines whose machine translation carries non-words / foreign-language garbage (tool/i18n/drop/<code>.json, made by a
    # lexicon check such as /workspace/run31/pl_lexcheck.py): dropped so they fall back to English.
    dp = os.path.join(H, 'drop', c + '.json')
    if os.path.exists(dp):
        _drop = set(json.load(open(dp))); t = {k: v for k, v in t.items() if k not in _drop}; print(c, 'dropped (lexicon garbage):', len(_drop))
    man = os.path.join(H, 'manual', c + '.json')  # hand-checked lines win over the machine translation
    if os.path.exists(man): t.update({k: v for k, v in json.load(open(man)).items() if k in src})
    # Practice prompts whose translation does not carry the whole answer (tool/qa/qa_translate.py): dropped, so the
    # exercise plays the sentence instead of showing a partial translation.
    for k in FLAGS.get(c, []): t.pop(k, None)
    for k, v in list(t.items()):
        if isinstance(v, str):
            for x, y in RENAMES: v = v.replace(x, y)
            t[k] = v
            if re.search(r'Twix|FIFA', v): t.pop(k)  # brand left in a machine translation: use the fallback instead
    dump(c, t); cov[c] = round(len(t) / len(src), 4)
    # Ready needs the whole run finished AND quality from the QA (tool/qa/qa_translate.py -> quality.json): at most 10%
    # of practice prompts dropped as unreliable and at most 10% of sampled back-translations missing the answer.
    # Anything else stays beta (English fallback for the lines that failed).
    q = QUALITY.get(c)
    # Human spot-check veto (tool/i18n/beta_hold.json, code -> reason): a language whose sampled sentence-builder items
    # are often unfaithful stays beta even when the automatic metrics pass.
    if all(k in mt for k in src) and q and q['flag_share'] <= 0.10 and q['bt_mismatch_rate'] <= 0.10 and c not in BETA_HOLD: complete.add(c)
    if q: print(c, 'quality: prompts flagged', q['flag_share'], 'back-translation mismatch', q['bt_mismatch_rate'], 'ready-eligible' if c in complete else 'beta')
# A language skipped this run keeps the coverage from the last build.
prev = {}; prevc = set()
g = os.path.join(APP, 'lib', 'core', 'i18n', 'coverage.g.dart')
if os.path.exists(g):
    for line in open(g):
        if line.strip().startswith("const helperComplete"): prevc = set(re.findall(r"'([a-zA-Z-]+)'", line))
        elif line.strip().startswith("'"): k, v = line.strip().rstrip(',').split(': '); prev[k.strip("'")] = float(v)
for c in CODES:
    if c in HOLD: continue
    if cov[c] is None:
        cov[c] = prev.get(c, 0.0)
        if c in prevc: complete.add(c)
with open(g, 'w') as f:
    f.write('// GENERATED by tool/i18n/build_tables.py: share of helper strings translated per language.\n')
    f.write('const helperCoverage = <String, double>{\n')
    for c in CODES: f.write(f"  '{c}': {cov[c]},\n")
    f.write('};\n')
    f.write('// Languages whose whole translation run has finished.\n')
    f.write('const helperComplete = <String>{' + ', '.join(f"'{c}'" for c in CODES if c in complete) + '};\n')
print({c: cov[c] for c in CODES if cov[c]}, 'complete:', sorted(complete))
