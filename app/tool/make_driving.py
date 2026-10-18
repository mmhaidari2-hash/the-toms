#!/usr/bin/env python3
"""Driving School dialogues: tool/driving/lessons.txt -> assets/data/driving.json.

English for learning to drive in Britain: instructor lessons, petrol station, MOT, provisional licence, test day.
Each scene has British voices, Persian, vocab and a 3-question quiz; facts checked against GOV.UK (src:).
The build fails on an unknown speaker, missing Persian, a line too long for its level or a bad quiz.
Run tool/render_voices.py after adding lines, then this again to fill in clip lengths.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
CAST = {c['id']: c for c in json.load(open(os.path.join(A, 'data', 'characters.json')))}
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']
MAXW = {'A1': 9, 'A2': 13, 'B1': 20, 'B2': 28, 'C1': 28}
FX = ['engine', 'indicator', 'brake']
SCENES = {'car', 'road', 'petrol', 'garage', 'home'}
# Scene art follows the same rule as conversations (tool/match_scene_art.py): a painting only if it shows the setting
# and no main character who isn't speaking; otherwise a people-free stage (drawn road, or blurred setting + symbol).
MAIN = {'tom', 'leslie', 'william', 'nicola', 'ryan', 'weda', 'george', 'mehdi'}
PLACES = {p['id']: p for t in json.load(open(os.path.join(A, 'data', 'places.json'))) for p in t['places'] if p.get('image')}
ART = {'petrol': ('petrol', 'garage'), 'garage': (None, 'garage'), 'home': ('kitchen', 'home'), 'car': (None, 'garage'), 'road': (None, 'garage')}
# Speakers who are not in characters.json (no portrait yet: the app shows an icon).
EXTRA = {'instructor': 'Bev (instructor)', 'examiner': 'The examiner'}
def ms(sp, en):
    f = os.path.join(A, 'audio', hashlib.md5(f'{sp}|{en}'.encode()).hexdigest()[:16] + '.mp3')
    if not os.path.exists(f): return 0
    o = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(o.strip() or 0) * 1000)
bad, out, ev = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'driving', 'lessons.txt')), 1):
    line = raw.strip()
    if not line or (line.startswith('#') and not re.match(r'^# [a-z0-9]+ \|', line)): continue
    if line.startswith('# '):
        p = [x.strip() for x in line[2:].split('|')]
        if len(p) != 4: bad.append(f'{n}: header needs 4 fields'); continue
        ev = dict(id=p[0], level=p[1], title=p[2], titleFa=p[3], scene='', video=None, note='', noteFa='', lines=[], words=[], qs=[], src=[]); fx = None
        out.append(ev); continue
    k, _, v = line.partition(': ')
    if k == 'src': ev['src'].append(v.strip()); continue
    if k == 'scene':
        if v.strip() not in SCENES: bad.append(f'{n}: scene must be one of {sorted(SCENES)}')
        ev['scene'] = v.strip(); continue
    if k == 'video': ev['video'] = v.strip(); continue
    if k == 'fx':
        if v.strip() not in FX: bad.append(f'{n}: fx must be one of {FX}')
        fx = v.strip(); continue
    if k == 'note':
        p = [x.strip() for x in v.split('|')]
        if len(p) != 2 or not all(p): bad.append(f'{n}: {k} needs English | Persian'); continue
        ev[k], ev[k + 'Fa'] = p; continue
    if k == 'word':
        m = re.match(r'^(.+?) = (.+?) \| (.+)$', v)
        if not m: bad.append(f'{n}: word needs "word = meaning | Persian"'); continue
        ev['words'].append(dict(w=m.group(1).strip(), en=m.group(2).strip(), fa=m.group(3).strip())); continue
    if k == 'Q':
        p = [x.strip() for x in v.split('|')]
        o = [x.strip() for x in p[1].split(';')] if len(p) == 2 else []
        if len(o) != 3 or len(set(o)) != 3 or not p[0].endswith(('?', '...')): bad.append(f'{n}: Q needs "question? | right ; wrong ; wrong"'); continue
        ev['qs'].append(dict(q=p[0], options=o, answer=0)); continue
    if k == 'me' or k in CAST or k in EXTRA:
        p = [x.strip() for x in v.split('|')]
        if len(p) != 2 or not all(p): bad.append(f'{n}: line needs English | Persian'); continue
        if k not in VOICES: bad.append(f'{n}: no voice for {k}')
        if len(p[0].split()) > MAXW.get(ev['level'], 0): bad.append(f"{n}: {len(p[0].split())} words is too long for {ev['level']}")
        c = CAST.get(k, {})
        ev['lines'].append(dict(sp=k, name=c.get('name', EXTRA.get(k, 'You')), avatar=c.get('avatar', ''), en=p[0], fa=p[1], ms=ms(k, p[0]), fx=fx)); fx = None; continue
    bad.append(f'{n}: unknown line {k}')
ids, missing = set(), 0
for e in out:
    if e['id'] in ids: bad.append(f"duplicate id {e['id']}")
    ids.add(e['id'])
    if e['level'] not in LEVELS: bad.append(f"{e['id']}: bad level")
    if e['video'] and not os.path.exists(os.path.join(A, '..', e['video'])): bad.append(f"{e['id']}: video {e['video']} not found")
    pid, icon = ART.get(e['scene'], (None, 'home'))
    sp = {l['sp'] for l in e['lines']}
    ok = pid in PLACES and {h['characterId'] for h in PLACES[pid]['hotspots']} & MAIN <= sp
    e['img'] = PLACES[pid]['image'] if ok else None
    e['bg'] = f'assets/places/blur/{pid}.webp' if pid in PLACES and not ok else None
    if e['scene'] == 'garage': e['bg'] = 'assets/places/blur/petrol.webp'  # Mick's Motors shares the forecourt
    e['icon'] = icon
    if not e['scene']: bad.append(f"{e['id']}: needs scene:")
    if not e['note']: bad.append(f"{e['id']}: needs note:")
    if len(e['lines']) < 5 or len(e['words']) < 4 or len(e['qs']) != 3: bad.append(f"{e['id']}: needs 5+ lines, 4+ words and 3 questions")
    missing += sum(1 for l in e['lines'] if not l['ms'])
for lv in LEVELS:
    if sum(e['level'] == lv for e in out) < 2: bad.append(f'needs 2+ dialogues at {lv}')
if bad: print('\n'.join(bad)); sys.exit(1)
json.dump({'lessons': out}, open(os.path.join(A, 'data', 'driving.json'), 'w'), ensure_ascii=False, indent=0)
for e in out: print(e['level'], e['id'], len(e['lines']), 'lines')
if missing: print(f'WARNING: {missing} lines have no clip yet: run tool/render_voices.py, then this again')
