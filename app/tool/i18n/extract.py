"""Collect every Persian string the app can show (assets/data/*.json + Dart literals) with its English source when known.
Writes tool/i18n/sources.json: {persian: {"en": english|None, "kind": "word"|"text"}}. Keys are exactly what hl() looks up at runtime."""
import json, glob, re, os
os.chdir(os.path.join(os.path.dirname(__file__), '..', '..'))
FA = re.compile('[\u0600-\u06FF]')
LAT = re.compile('[A-Za-z]')
SEP = re.compile(r'\s*(?:·|•|\n|\||—)\s*')
RUN = re.compile(r'[\u0600-\u06FF\u200c][\u0600-\u06FF\u200c\s،؛؟!.:()«»0-9۰-۹\-/]*')
out = {}
UI = set()
def add(fa, en=None, kind='text', ui=False):
    fa = fa.strip()
    if ui and FA.search(fa): UI.add(fa)
    if not FA.search(fa): return
    # Not display text: punctuation alone ("،"), regular expressions over the Persian range, half-split interpolations.
    if not re.search('[\u0621-\u063A\u0641-\u064A\u0671-\u06D3\u06FA-\u06FF]', fa): return
    if re.search(r'\\[usdwSWDb]', fa): return
    if '${' in fa:  # an interpolation with quotes inside that LIT cut in half: keep only the text before it
        return add(fa.split('${')[0], en if en and '${' not in en else None, kind, ui)
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
# lib/core/i18n/strings.dart holds per-language UI maps ('en': {'storyDone': 'Story finished'}, 'fa': {...}). The
# literal before a value there is the map KEY, not English: pair each value with the English value of the same key.
STR_DART = os.path.join('lib', 'core', 'i18n', 'strings.dart')
def _ui_maps(path):
    maps, cur = {}, None
    for line in open(path, encoding='utf-8'):
        m = re.match(r"^  '([a-zA-Z-]+)': \{\s*$", line)
        if m: cur = maps.setdefault(m.group(1), {}); continue
        if re.match(r'^  \},?\s*$', line): cur = None; continue
        m = re.match(r"^\s+'([A-Za-z0-9_]+)': '((?:[^'\\]|\\.)*)',?\s*$", line)
        if cur is not None and m: cur[m.group(1)] = m.group(2).replace("\\'", "'").replace('\\n', '\n')
    return maps
if os.path.exists(STR_DART):
    _m = _ui_maps(STR_DART); _enm = _m.get('en', {})
    for _lang, _tab in _m.items():
        if _lang == 'en': continue
        for _k, _v in _tab.items():
            if FA.search(_v): add(_v, _enm.get(_k), ui=True)
# A Latin literal directly followed by ':' is a map key ('title': 'متن'), never the English of the next literal.
KEYLIT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LIT = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")
INTERP = re.compile(r'\$\{[^}]*\}|\$\w+')
for f in sorted(glob.glob('lib/**/*.dart', recursive=True)):
    if os.path.normpath(f) == os.path.normpath(STR_DART): continue
    carry = None  # English literal that ended the previous line as a tuple/list element: ('English…',\n 'فارسی…')
    for line in open(f, encoding='utf-8'):
        ms = list(LIT.finditer(line))
        lits = [(m.group(1) if m.group(1) is not None else m.group(2)) for m in ms]
        keyish = [bool(KEYLIT.match(x or '')) and line[m.end():].lstrip().startswith(':') for x, m in zip(lits, ms)]
        prev = carry if ms and line[:ms[0].start()].strip() == '' else None
        carry = None
        if ms and line[ms[-1].end():].strip() == ',':
            last = lits[-1].replace("\\'", "'").replace('\\"', '"')
            if LAT.search(last) and not FA.search(last) and not INTERP.search(last) and ' ' in last.strip(): carry = last
        for s, isk in zip(lits, keyish):
            s2 = s.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
            if FA.search(s2):
                parts = INTERP.split(s2)
                if len(parts) == 1: add(s2, prev, ui=True)
                else:
                    for p in parts: add(p, ui=True)
            elif LAT.search(s2): prev = None if isk else s2
for k in out: out[k]['ui'] = k in UI
# Keep the English a line had in the previous sources.json when the code that paired it moved (the English fallback
# must stay real English), unless that English was a map key leaked by the old pairing.
_old = os.path.join('tool', 'i18n', 'sources.json')
if os.path.exists(_old):
    for k, v in json.load(open(_old)).items():
        e = v.get('en') if isinstance(v, dict) else None
        if k in out and out[k]['en'] is None and e and not KEYLIT.match(e.strip()) and ' ' in e.strip():
            out[k]['en'] = e
json.dump(out, open('tool/i18n/sources.json', 'w'), ensure_ascii=False, indent=0, sort_keys=True)
n = len(out); e = sum(1 for v in out.values() if v['en'])
print(f'{n} Persian strings, {e} with English source, {sum(len(k) for k in out)} chars')
