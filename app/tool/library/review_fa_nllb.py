"""Compare hand-written FA of newer library books with offline NLLB (eng_Latn -> pes_Arab).
Resumable: tool/library/_fa_review_mt.json. No paid services. Never sent off-box.
Usage: python3 review_fa_nllb.py
"""
import json, os, re, time
import ctranslate2, sentencepiece as spm

HERE = os.path.dirname(os.path.abspath(__file__))
NEWER = [
    'classics_a2.txt', 'classics_b1.txt', 'classics_b2.txt', 'classics_c1.txt',
    'nonfiction_a2.txt', 'nonfiction_b1.txt', 'poetry.txt',
]
MODEL = os.environ.get('NLLB', '/workspace/mt/onmt13')
SPM = '/workspace/mt/nllb13/sentencepiece.bpe.model'
OUT = os.path.join(HERE, '_fa_review_mt.json')
REPORT = os.path.join(HERE, '_fa_review_report.json')
DIG_FA = str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789')
PUNCT = re.compile(r'[\s\u200c\u200d،؛؟!.…,;:?\"\'«»()\[\]{}،\-–—/\\]+')
SPK = re.compile(r'^([a-z]+)> (.*)$')

def extract():
    rows = []
    for fn in NEWER:
        path = os.path.join(HERE, fn)
        bid = ch = kind = None
        for i, raw in enumerate(open(path, encoding='utf-8'), 1):
            ln = raw.rstrip('\n').strip()
            if not ln or ln.startswith('Q:') or ln.startswith('W:') or ln.startswith('@'):
                continue
            if ln.startswith('# '):
                t = [x.strip() for x in ln[2:].split('|')]
                bid = t[0]
                rows.append(dict(file=fn, line=i, book=bid, kind='title', en=t[2], fa=t[3]))
                if len(t) > 6:
                    rows.append(dict(file=fn, line=i, book=bid, kind='blurb', en=t[5], fa=t[6]))
                continue
            if ln.startswith('## '):
                t = [x.strip() for x in ln[3:].split('|')]
                ch = t[0]
                rows.append(dict(file=fn, line=i, book=bid, kind='chapter', en=t[0], fa=t[1], chapter=ch))
                continue
            if '|' not in ln:
                continue
            if SPK.match(ln):
                ln = SPK.match(ln).group(2)
            en, fa = [x.strip() for x in ln.split('|', 1)]
            rows.append(dict(file=fn, line=i, book=bid, kind='sentence', en=en, fa=fa, chapter=ch or ''))
    return rows

def run(texts):
    toks = [['eng_Latn'] + sp.encode(t, out_type=str) + ['</s>'] for t in texts]
    res = tr.translate_batch(
        toks, target_prefix=[['pes_Arab']] * len(texts),
        beam_size=2, max_batch_size=32, batch_type='examples',
        max_decoding_length=min(400, 40 + 3 * max(len(t) for t in toks)),
        repetition_penalty=1.0,
    )
    return [sp.decode(r.hypotheses[0][1:]).strip() for r in res]

def norm(s):
    s = (s or '').translate(DIG_FA).replace('ي', 'ی').replace('ك', 'ک').replace('ة', 'ه')
    return PUNCT.sub(' ', s).strip()

def tokens(s):
    return [t for t in norm(s).split() if t]

def jaccard(a, b):
    A, B = set(tokens(a)), set(tokens(b))
    if not A or not B:
        return 0.0
    return len(A & B) / len(A | B)

def numbers(s):
    return re.findall(r'\d+(?:[.,]\d+)?', (s or '').translate(DIG_FA))

def flag(row, mt):
    reasons = []
    en, fa = row['en'], row['fa']
    jac = jaccard(fa, mt)
    fa_n, mt_n, en_n = len(norm(fa)), len(norm(mt)), len(norm(en))
    en_nums, fa_nums = numbers(en), numbers(fa)
    missing_nums = [n for n in en_nums if n not in fa_nums]
    if missing_nums:
        reasons.append('number_missing:' + ','.join(missing_nums))
    # NLLB much longer than hand FA: possible omission
    if mt_n >= 24 and fa_n < 0.55 * mt_n:
        reasons.append('fa_shorter_than_mt')
    if en_n >= 40 and fa_n < 0.45 * en_n:
        reasons.append('fa_short_vs_en')
    # very low lexical overlap with NLLB (meaning may diverge)
    if jac < 0.22 and min(fa_n, mt_n) >= 12:
        reasons.append('low_overlap')
    # extra numbers in FA not in EN (wrong fact)
    extra = [n for n in fa_nums if n not in en_nums]
    if extra:
        reasons.append('number_extra:' + ','.join(extra))
    return reasons, round(jac, 3), fa_n, mt_n

if __name__ == '__main__':
    rows = extract()
    done = json.load(open(OUT, encoding='utf-8')) if os.path.exists(OUT) else {}
    todo = []
    for r in rows:
        key = f"{r['file']}:{r['line']}:{r['kind']}:{r['en']}"
        r['key'] = key
        if key not in done:
            todo.append(r)
    print(f'lines {len(rows)} todo {len(todo)}', flush=True)
    if todo:
        sp = spm.SentencePieceProcessor(model_file=SPM)
        tr = ctranslate2.Translator(MODEL, device='cpu', compute_type='int8', inter_threads=2, intra_threads=2)
        t0 = time.time()
        for i in range(0, len(todo), 32):
            chunk = todo[i:i+32]
            outs = run([r['en'] for r in chunk])
            for r, o in zip(chunk, outs):
                done[r['key']] = o
            tmp = OUT + '.tmp'
            json.dump(done, open(tmp, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
            os.replace(tmp, OUT)
            n = i + len(chunk)
            el = time.time() - t0
            print(f'mt {n}/{len(todo)} {n/max(el,.1):.1f}/s eta {int((len(todo)-n)/max(.1,n/el)/60)}m', flush=True)
    flagged = []
    for r in rows:
        mt = done.get(r['key'], '')
        reasons, jac, fa_n, mt_n = flag(r, mt)
        item = dict(file=r['file'], line=r['line'], book=r['book'], kind=r['kind'],
                    chapter=r.get('chapter',''), en=r['en'], fa=r['fa'], mt=mt,
                    jaccard=jac, fa_len=fa_n, mt_len=mt_n, reasons=reasons)
        if reasons:
            flagged.append(item)
    json.dump({'total': len(rows), 'flagged': len(flagged), 'items': flagged},
              open(REPORT, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    from collections import Counter
    c = Counter(r for it in flagged for r in it['reasons'])
    bybook = Counter(it['book'] for it in flagged)
    print('TOTAL', len(rows), 'FLAGGED', len(flagged), 'reasons', dict(c), 'bybook', dict(bybook), flush=True)
