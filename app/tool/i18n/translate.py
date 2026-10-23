"""Machine-translate tool/i18n/sources.json into each helper language with NLLB-200 (1.3B, CTranslate2, offline).
English source when known, else the Persian. Every output is QA-checked (script, repetition, length); failures are retried
with the other source and a stricter decoder. Resumable: results accumulate in tool/i18n/mt/<code>.json.
Usage: python3 translate.py ar uk ps ...   (model dir: $NLLB, default /workspace/mt/onmt13)"""
import json, os, re, sys, time
import ctranslate2, sentencepiece as spm
HERE = os.path.dirname(os.path.abspath(__file__))
NLLB = {'hi': 'hin_Deva', 'bn': 'ben_Beng', 'pa': 'pan_Guru', 'zh': 'zho_Hans', 'zh-Hant': 'zho_Hant', 'ar': 'arb_Arab', 'uk': 'ukr_Cyrl', 'ps': 'pbt_Arab', 'ur': 'urd_Arab', 'ckb': 'ckb_Arab', 'tr': 'tur_Latn', 'es': 'spa_Latn',
        'prs': 'prs_Arab', 'pl': 'pol_Latn', 'ro': 'ron_Latn', 'pt': 'por_Latn', 'so': 'som_Latn', 'kmr': 'kmr_Latn', 'sq': 'als_Latn', 'ti': 'tir_Ethi'}
SCRIPT = {'Arab': '\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\u200c\u200d', 'Cyrl': '\u0400-\u04FF', 'Latn': 'A-Za-z\u00C0-\u024F', 'Ethi': '\u1200-\u139F', 'Deva': '\u0900-\u097F\u200c\u200d', 'Beng': '\u0980-\u09FF', 'Guru': '\u0A00-\u0A7F', 'Hans': '\u3000-\u303F\u4E00-\u9FFF\uFF00-\uFFEF', 'Hant': '\u3000-\u303F\u4E00-\u9FFF\uFF00-\uFFEF'}
MODEL = os.environ.get('NLLB', '/workspace/mt/onmt13')
sp = spm.SentencePieceProcessor(model_file='/workspace/mt/nllb13/sentencepiece.bpe.model')
tr = ctranslate2.Translator(MODEL, device='cpu', compute_type='int8', inter_threads=2, intra_threads=int(os.environ.get('MT_THREADS','2')))
src = json.load(open(os.path.join(HERE, 'sources.json')))
FA_DIG = str.maketrans('۰۱۲۳۴۵۶۷۸۹', '0123456789')
def ok(out, srctext, code):
    sc = NLLB[code].split('_')[1]
    letters = re.findall(r'[^\W\d_]', out)
    if not letters: return not re.search(r'[^\W\d_]', srctext)
    native = re.findall('[' + SCRIPT[sc] + ']', out)
    foreign = [c for c in letters if not re.match('[' + SCRIPT[sc] + 'A-Za-z]', c)]
    alien = '[\u0900-\u0DFF\u0E00-\u0FFF\u3040-\u9FFF\uAC00-\uD7AF\u0590-\u05FF\u10A0-\u10FF\u0530-\u058F]'
    if foreign or re.search(alien, re.sub('[' + SCRIPT[sc] + ']', '', out)): return False
    if sc in ('Hans', 'Hant'): return len(native) >= 0.5 * len(letters)
    if len(native) < 0.6 * len(letters): return False
    if sc == 'Latn' and re.search('[\u0600-\u06FF\u0400-\u04FF]', out): return False
    # Latin in a non-Latin target only for names/English words that were in the source.
    for w in re.findall('[A-Za-z]{3,}', out):
        if w.lower() not in srctext.lower(): return False
    if re.search(r'(\b\w+\b)(?:\W+\1\b){3,}', out): return False
    r = len(out) / max(1, len(srctext))
    return 0.25 < r < 3.5 or len(srctext) < 12
def run(texts, srclang, tgt, strict=False):
    toks = [[srclang] + sp.encode(t, out_type=str) + ['</s>'] for t in texts]
    res = tr.translate_batch(toks, target_prefix=[[tgt]] * len(texts), beam_size=5 if strict else 2, max_batch_size=48, batch_type='examples',
                             max_decoding_length=min(400, 40 + 3 * max(len(t) for t in toks)), repetition_penalty=1.15 if strict else 1.0,
                             no_repeat_ngram_size=4 if strict else 0)
    return [sp.decode(r.hypotheses[0][1:]) for r in res]
def fix(out, code):
    out = out.strip()
    out = re.sub(r'\s*\.\.+$', '', out) if not out.endswith('…') else out
    if NLLB[code].endswith('Latn') or NLLB[code].endswith('Cyrl'): out = out.translate(FA_DIG)
    return out
def save(done, path):
    json.dump(done, open(path + '.tmp', 'w'), ensure_ascii=False, indent=0, sort_keys=True); os.replace(path + '.tmp', path)
for code in sys.argv[1:]:
    path = os.path.join(HERE, 'mt', code + '.json'); os.makedirs(os.path.dirname(path), exist_ok=True)
    done = json.load(open(path)) if os.path.exists(path) else {}
    # Resumable: a key is done once it has an output. Outputs that failed QA are kept with a leading NUL (build_tables
    # skips them); MT_RETRY_BAD=1 gives those one more try.
    retry = os.environ.get('MT_RETRY_BAD') == '1'
    todo = [k for k in src if k not in done or (retry and str(done[k]).startswith('\u0000'))]
    todo.sort(key=lambda k: (not src[k].get('ui'), len(src[k]['en'] or k)))
    t0 = time.time(); tgt = NLLB[code]; bad = 0
    for i in range(0, len(todo), 96):
        chunk = todo[i:i + 96]
        texts = [(src[k]['en'] or k) for k in chunk]
        langs = ['eng_Latn' if (src[k]['en'] and t == src[k]['en']) else 'pes_Arab' for k, t in zip(chunk, texts)]
        outs = [None] * len(chunk)
        for L in ('eng_Latn', 'pes_Arab'):
            idx = [j for j in range(len(chunk)) if langs[j] == L]
            if idx:
                for j, o in zip(idx, run([texts[j] for j in idx], L, tgt)): outs[j] = fix(o, code)
        failed = [j for j in range(len(chunk)) if not ok(outs[j], texts[j], code)]
        for strict in (False, True):
            for which in (1, 0):
                for L in ('eng_Latn', 'pes_Arab'):
                    idx, ins = [], []
                    for j in failed:
                        k = chunk[j]
                        alts = [(k, 'pes_Arab'), (src[k]['en'], 'eng_Latn')] if langs[j] == 'eng_Latn' else [(src[k]['en'], 'eng_Latn'), (k, 'pes_Arab')]
                        a, AL = alts[1 - which] if not strict else alts[which]
                        if a and AL == L: idx.append(j); ins.append(a)
                    if not idx: continue
                    for j, a, o in zip(idx, ins, run(ins, L, tgt, strict)):
                        o = fix(o, code)
                        if ok(o, a, code): outs[j] = o
                    failed = [j for j in failed if not ok(outs[j], texts[j], code) and outs[j] is not None and not getattr(outs, 'x', 0)]
                    failed = [j for j in failed if j not in [jj for jj, a2 in zip(idx, ins) if ok(outs[jj], a2, code)]]
        for j in failed: bad += 1; outs[j] = '\u0000' + outs[j]
        for j, k in enumerate(chunk): done[k] = outs[j]
        save(done, path)  # checkpoint after every chunk (atomic), so an interruption loses at most 96 lines
        if (i // 96) % 5 == 0 or i + 96 >= len(todo):
            el = time.time() - t0; n = i + len(chunk)
            print(f'{code} {n}/{len(todo)} {n / el:.1f}/s bad={bad} eta {int((len(todo) - n) / max(.1, n / el) / 60)}m', flush=True)
    save(done, path)
    print(code, 'DONE', flush=True)
