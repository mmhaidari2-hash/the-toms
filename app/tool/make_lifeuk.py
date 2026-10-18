#!/usr/bin/env python3
"""Life in the UK test prep: tool/lifeuk/lifeuk.txt -> assets/data/lifeuk.json.

ORIGINAL questions only (never copied from official or commercial question banks). Each chapter lists the
public sources its facts were checked against. Explanations are voiced by 'tutor' (tool/render_voices.py);
run that after editing, then this again to fill in clip lengths.
The build fails on missing Persian, duplicate questions, bad options or a chapter with too few questions.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
def key(sp, t): return hashlib.md5(f'{sp}|{t}'.encode()).hexdigest()[:16]
def ms(t):
    f = os.path.join(A, 'audio', key('tutor', t) + '.mp3')
    if not os.path.exists(f): return 0
    out = subprocess.run(['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(out or 0) * 1000)
bad, chs, ch = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'lifeuk', 'lifeuk.txt')), 1):
    line = raw.strip()
    if not line or (line.startswith('#') and not line.startswith('## ')): continue
    if line.startswith('## '):
        p = [x.strip() for x in line[3:].split('|')]
        ch = {'id': p[0], 'title': p[1], 'titleFa': p[2], 'src': [], 'expl': [], 'cards': [], 'qs': []}; chs.append(ch); continue
    k, _, v = line.partition(': ')
    p = [x.strip() for x in v.split('|')]
    if k == 'src': ch['src'].append(v.strip())
    elif k == 'expl':
        if len(p) != 2 or not all(p): bad.append(f'{n}: expl needs English | Persian'); continue
        ch['expl'].append({'en': p[0], 'fa': p[1], 'ms': ms(p[0])})
    elif k == 'card':
        if len(p) != 3 or not all(p): bad.append(f'{n}: card needs front | back | backFa'); continue
        ch['cards'].append({'front': p[0], 'back': p[1], 'fa': p[2]})
    elif k == 'Q':
        if len(p) != 5 or not all(p): bad.append(f'{n}: Q needs 5 parts'); continue
        opts = [o.strip() for o in p[2].split(';')]
        tf = set(opts) == {'TRUE', 'FALSE'}
        if not (tf and len(opts) == 2 or len(opts) == 4 and len(set(opts)) == 4): bad.append(f'{n}: options must be 4 distinct or TRUE ; FALSE')
        if not tf and not p[0].endswith(('?', '...')): bad.append(f'{n}: question should end with ?')
        ch['qs'].append({'id': f"{ch['id']}_{len(ch['qs']) + 1:02d}", 'q': p[0], 'fa': p[1], 'options': opts, 'answer': 0, 'tf': tf, 'why': p[3], 'whyFa': p[4]})
    else: bad.append(f'{n}: unknown line {k}')
seen = set()
for c in chs:
    if len(c['qs']) < 15: bad.append(f"{c['id']}: needs 15+ questions")
    if len(c['expl']) < 3 or len(c['cards']) < 8 or not c['src']: bad.append(f"{c['id']}: needs 3+ explanations, 8+ cards and sources")
    for q in c['qs']:
        if q['q'].lower() in seen: bad.append(f"duplicate question: {q['q']}")
        seen.add(q['q'].lower())
if bad: print('\n'.join(bad)); sys.exit(1)
json.dump({'chapters': chs, 'mock': {'questions': 24, 'minutes': 45, 'pass': 75}}, open(os.path.join(A, 'data', 'lifeuk.json'), 'w'), ensure_ascii=False, indent=1)
print(len(chs), 'chapters,', sum(len(c['qs']) for c in chs), 'questions,', sum(len(c['cards']) for c in chs), 'cards,', sum(len(c['expl']) for c in chs), 'explanations;', sum(1 for c in chs for e in c['expl'] if e['ms']), 'voiced')
