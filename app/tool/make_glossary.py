#!/usr/bin/env python3
"""Leitner glossary -> assets/data/glossary.json {word: [persian, example sentence, example speaker]}.
Collects every authored word/phrase with a Persian meaning (conversation newWords, library glosses, driving,
seasons, grammar, theory words) and the first authored line that uses it, so a word added from anywhere
gets its meaning, a real example and (where recorded) British audio. Run after editing content."""
import json, os, re, glob
A = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'data')
J = lambda p: json.load(open(os.path.join(A, p)))
g, lines, near = {}, [], {}
def add(w, fa, ex=None, sp=None):
    w = (w or '').strip(); fa = (fa or '').strip()
    if not w or not fa or len(w) > 60: return
    k = w.lower()
    if k not in g: g[k] = [w, fa, ex or '', sp or '']
    elif ex and not g[k][2]: g[k][2], g[k][3] = ex, sp or ''
for s in J('scenes_bundle.json').values():
    for n in s['nodes'].values():
        t = n.get('text', ''); sp = n.get('speaker', '')
        if t: lines.append((t, sp))
        for w in n.get('newWords', []) or []: add(w.get('word') or w.get('w'), w.get('fa') or w.get('meaningFa')); near.setdefault((w.get('word') or w.get('w') or '').strip().lower(), (t, sp))
for b in J('library.json')['books']:
    for k, v in (b.get('gloss') or {}).items(): add(k, v)
    for ch in b.get('chapters', []) or []:
        for s in ch.get('sentences', []) or []:
            if s.get('en'): lines.append((s['en'], s.get('voice', 'narrator')))
def walk(o):
    if isinstance(o, dict):
        w = o.get('w') or o.get('word') or o.get('en_word'); fa = o.get('fa') or o.get('wordFa')
        if isinstance(w, str) and isinstance(fa, str) and len(w.split()) <= 6: add(w, fa)
        if isinstance(o.get('en'), str) and isinstance(o.get('sp'), str): lines.append((o['en'], o['sp']))
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
for f in ['driving.json', 'seasons.json', 'grammar.json', 'theory.json', 'lifeuk.json', 'missions.json', 'estate.json']:
    if os.path.exists(os.path.join(A, f)): walk(J(f))
for k, v in g.items():
    if v[2]: continue
    rx = re.compile(r'\b' + re.escape(v[0]) + r'\b', re.I)
    hit = next(((t, sp) for t, sp in lines if rx.search(t)), None)
    hit = hit or near.get(k)
    if hit: v[2], v[3] = hit
out = {k: v for k, v in sorted(g.items())}
json.dump(out, open(os.path.join(A, 'glossary.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(out), 'glossary entries;', sum(1 for v in out.values() if v[2]), 'with an example')
