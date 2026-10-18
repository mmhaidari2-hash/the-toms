#!/usr/bin/env python3
"""Hackney Hum (an invented local radio station): tool/radio/segments.txt -> assets/data/radio.json.

DSL (see the header of segments.txt):
  # id | level | kind | slot | title | titleFa | blurb | blurbFa
  speaker: English | Persian          speaker = a voice id from tool/render_voices.py
  Q: question | correct ; wrong ; wrong

Speakers are the station's presenters (STATION below) or characters from characters.json (callers, guests).
The build fails on an unknown voice, a bad kind/level, missing Persian, a line too long for its level,
fewer than 5 lines, or fewer than 3 questions. Each line gets 'ms' (its clip length, via ffprobe).
Run tool/render_voices.py after adding lines, then run this again.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
STATION = {'bex': 'Bex', 'malcolm': 'Malcolm', 'grace': 'Grace', 'owen': 'Owen'}  # presenters, newsreader, travel, weather
CAST = {**{c['id']: c['name'] for c in json.load(open(os.path.join(A, 'data', 'characters.json')))}, **STATION}
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']
KINDS = ['news', 'weather', 'travel', 'phonein', 'advert']
MAXW = {'A1': 9, 'A2': 13, 'B1': 20, 'B2': 28, 'C1': 28}
bad, segs, sg = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'radio', 'segments.txt')), 1):
    line = raw.rstrip('\n')
    if not line.strip() or (line.startswith('#') and not re.match(r'^# [a-z0-9_]+ \|', line)):
        continue
    if line.startswith('# '):
        t = [x.strip() for x in line[2:].split('|')]
        if len(t) != 8: bad.append(f'{n}: segment header needs 8 fields'); continue
        sg = dict(zip(['id', 'level', 'kind', 'slot', 'title', 'titleFa', 'blurb', 'blurbFa'], t), lines=[], quiz=[])
        segs.append(sg); continue
    if line.startswith('Q:'):
        q, opts = [x.strip() for x in line[2:].split('|')]
        o = [x.strip() for x in opts.split(';')]
        if len(o) != 3 or len(set(o)) != 3: bad.append(f'{n}: quiz needs 3 different options')
        sg['quiz'].append(dict(q=q, options=o, answer=0)); continue
    m = re.match(r'^([a-z]+): (.+?) \| (.+)$', line)
    if not m: bad.append(f'{n}: cannot parse: {line}'); continue
    sp, en, fa = m.groups()
    if sp not in VOICES: bad.append(f'{n}: unknown voice {sp}')
    if sp not in CAST: bad.append(f'{n}: {sp} is neither a presenter nor in characters.json')
    if len(en.split()) > MAXW[sg['level']]: bad.append(f"{n}: {len(en.split())} words is too long for {sg['level']}")
    if re.search(r'\bTfL\b|Transport for London|\bTube\b|Overground|Oyster', en): bad.append(f'{n}: no transport-operator branding')
    sg['lines'].append(dict(sp=sp, spn=CAST.get(sp, sp), en=en.strip(), fa=fa.strip()))

def ms(sp, en):
    f = os.path.join(A, 'audio', hashlib.md5(f'{sp}|{en}'.encode()).hexdigest()[:16] + '.mp3')
    if not os.path.exists(f): return 0
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(out.strip() or 0) * 1000)

ids, missing = set(), 0
for s in segs:
    if s['id'] in ids: bad.append(f"duplicate id {s['id']}")
    ids.add(s['id'])
    if s['level'] not in LEVELS: bad.append(f"{s['id']}: bad level")
    if s['kind'] not in KINDS: bad.append(f"{s['id']}: bad kind {s['kind']}")
    if not re.match(r'^\d\d:\d\d$', s['slot']): bad.append(f"{s['id']}: slot must be HH:MM")
    if len(s['lines']) < 5: bad.append(f"{s['id']}: needs 5+ lines")
    if len(s['quiz']) < 3: bad.append(f"{s['id']}: needs 3 questions")
    for l in s['lines']:
        if not l['fa']: bad.append(f"{s['id']}: no Persian for {l['en']}")
        l['ms'] = ms(l['sp'], l['en']); missing += l['ms'] == 0
if bad:
    print('\n'.join(bad)); sys.exit(1)
json.dump({'station': 'Hackney Hum', 'segments': segs}, open(os.path.join(A, 'data', 'radio.json'), 'w'), ensure_ascii=False, indent=0)
for s in segs:
    print(s['level'], s['kind'].ljust(8), s['id'], len(s['lines']), 'lines', f"{sum(l['ms'] for l in s['lines'])/1000:.0f}s")
if missing: print(f'WARNING: {missing} lines have no clip yet: run tool/render_voices.py, then this again')
