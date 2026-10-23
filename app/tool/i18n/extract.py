"""Collect every Persian string the app can show (assets/data/*.json + Dart literals) with its English source when known.
Writes tool/i18n/sources.json: {persian: {"en": english|None, "kind": "word"|"text"}}. Keys are exactly what hl() looks up at runtime."""
import json, glob, re, os
os.chdir(os.path.join(os.path.dirname(__file__), '..', '..'))
FA = re.compile('[\u0600-\u06FF]')
LAT = re.compile('[A-Za-z]')
SEP = re.compile(r'\s*(?:·|•|\n|\||—)\s*')
RUN = re.compile(r'[\u0600-\u06FF\u200c][\u0600-\u06FF\u200c\s،؛؟!.:()«»0-9۰-۹\-/]*')
out = {}
def add(fa, en=None, kind='text'):
    fa = fa.strip()
    if not FA.search(fa): return
    if en is not None and (not isinstance(en, str) or not LAT.search(en) or FA.search(en)): en = None
    parts = SEP.split(fa)
    if len(parts) > 1:
        # "English · Persian" labels and multi-part lines: runtime hl() translates each part, so store parts.
        enp = SEP.split(en) if en else []
        fparts = [q for q in parts if FA.search(q)]
        if len(fparts) < len(parts) or len(fparts) > 1:
            for i, q in enumerate(parts):
                if FA.search(q):
                    pe = enp[i] if len(enp) == len(parts) else (q if False else None)
                    if pe is None and len(fparts) == 1 and len(parts) == 2: pe = next((x for x in parts if not FA.search(x)), None)
                    add(q, pe, kind)
            if len(fparts) < len(parts): return
    cur = out.get(fa)
    if cur is None or (cur['en'] is None and en):
        out[fa] = {'en': en.strip() if en else None, 'kind': kind}
def walk(x, parent=None):
    if isinstance(x, dict):
        for k, v in x.items():
            if isinstance(v, str) and FA.search(v):
                en = None
                if parent is not None and isinstance(parent, dict):
                    pass
                if k in ('fa', 'meaning_fa', 'gloss_fa'):
                    en = x.get('en') or x.get('word') or x.get('text') or x.get('meaning') or x.get('gloss')
                elif k.endswith('Fa'): en = x.get(k[:-2])
                elif k.endswith('_fa'): en = x.get(k[:-3])
                if isinstance(en, list): en = None
                if en is None and k == 'fa' and parent is not None: en = parent.get('text') if isinstance(parent, dict) else None
                add(v, en if isinstance(en, str) else None, 'word' if 'word' in x and not ' ' in str(x.get('word', '')).strip() else 'text')
            elif isinstance(v, dict) and k == 'translations': walk(v, x)
            else: walk(v, x)
    elif isinstance(x, list):
        for v in x:
            if isinstance(v, str) and FA.search(v): add(v)
            else: walk(v, None)
for f in sorted(glob.glob('assets/data/*.json')): walk(json.load(open(f)))
LIT = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")
INTERP = re.compile(r'\$\{[^}]*\}|\$\w+')
for f in sorted(glob.glob('lib/**/*.dart', recursive=True)):
    for line in open(f, encoding='utf-8'):
        lits = [(m.group(1) if m.group(1) is not None else m.group(2)) for m in LIT.finditer(line)]
        prev = None
        for s in lits:
            s2 = s.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
            if FA.search(s2):
                parts = INTERP.split(s2)
                if len(parts) == 1: add(s2, prev)
                else:
                    for p in parts: add(p)
            elif LAT.search(s2): prev = s2
json.dump(out, open('tool/i18n/sources.json', 'w'), ensure_ascii=False, indent=0, sort_keys=True)
n = len(out); e = sum(1 for v in out.values() if v['en'])
print(f'{n} Persian strings, {e} with English source, {sum(len(k) for k in out)} chars')
