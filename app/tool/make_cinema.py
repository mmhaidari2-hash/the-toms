#!/usr/bin/env python3
"""Cinema & dubbing scenes: tool/cinema/scenes.txt -> assets/data/cinema.json.

DSL (see the header of scenes.txt):
  # id | level | title | titleFa | still | blurb | blurbFa | default dub role
  speaker: English | Persian          speaker = a voice id from tool/render_voices.py
  Q: question | correct ; wrong ; wrong

Every scene is original (no film clips or quotes). The build fails on an unknown voice, a missing
still, missing Persian, a dub role with fewer than two lines, or a bad quiz.
Each line gets 'ms', the length of its rendered clip (ffprobe), which the dub mode uses as the
"in time" window. Run tool/render_voices.py after adding lines, then run this again.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
CAST = {c['id']: c['name'] for c in json.load(open(os.path.join(A, 'data', 'characters.json')))}
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']
bad, scenes, sc = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'cinema', 'scenes.txt')), 1):
    line = raw.rstrip('\n')
    if not line.strip() or (line.startswith('#') and not re.match(r'^# [a-z0-9_]+ \|', line)):
        continue  # blank or comment
    if line.startswith('# '):
        t = [x.strip() for x in line[2:].split('|')]
        if len(t) != 8: bad.append(f'{n}: scene header needs 8 fields'); continue
        sc = dict(id=t[0], level=t[1], title=t[2], titleFa=t[3], still=t[4], blurb=t[5], blurbFa=t[6], dub=t[7], lines=[], quiz=[])
        scenes.append(sc); continue
    if line.startswith('Q:'):
        q, opts = [x.strip() for x in line[2:].split('|')]
        o = [x.strip() for x in opts.split(';')]
        if len(o) != 3 or len(set(o)) != 3: bad.append(f'{n}: quiz needs 3 different options')
        sc['quiz'].append(dict(q=q, options=o, answer=0)); continue
    m = re.match(r'^([a-z]+): (.+?) \| (.+)$', line)
    if not m: bad.append(f'{n}: cannot parse: {line}'); continue
    sp, en, fa = m.groups()
    if sp not in VOICES: bad.append(f'{n}: unknown voice {sp}')
    if sp not in CAST: bad.append(f'{n}: {sp} is not in characters.json')
    sc['lines'].append(dict(sp=sp, spn=CAST.get(sp, sp), en=en.strip(), fa=fa.strip()))

def ms(sp, en):
    f = os.path.join(A, 'audio', hashlib.md5(f'{sp}|{en}'.encode()).hexdigest()[:16] + '.mp3')
    if not os.path.exists(f): return 0
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(out.strip() or 0) * 1000)

ids, missing = set(), 0
for s in scenes:
    if s['id'] in ids: bad.append(f"duplicate id {s['id']}")
    ids.add(s['id'])
    if s['level'] not in LEVELS: bad.append(f"{s['id']}: bad level")
    if not os.path.exists(os.path.join(A, 'places', s['still'] + '.webp')): bad.append(f"{s['id']}: no still {s['still']}")
    if sum(1 for l in s['lines'] if l['sp'] == s['dub']) < 2: bad.append(f"{s['id']}: dub role {s['dub']} needs 2+ lines")
    if len({l['sp'] for l in s['lines']}) < 2 or len(s['lines']) < 6: bad.append(f"{s['id']}: needs 6+ lines and 2+ characters")
    if len(s['quiz']) < 3: bad.append(f"{s['id']}: needs 3 questions")
    for l in s['lines']:
        if not l['fa']: bad.append(f"{s['id']}: no Persian for {l['en']}")
        l['ms'] = ms(l['sp'], l['en']); missing += l['ms'] == 0
if bad:
    print('\n'.join(bad)); sys.exit(1)
json.dump({'scenes': scenes}, open(os.path.join(A, 'data', 'cinema.json'), 'w'), ensure_ascii=False, indent=0)
for s in scenes:
    print(s['level'], s['id'], len(s['lines']), 'lines', f"{sum(l['ms'] for l in s['lines'])/1000:.0f}s")
if missing: print(f'WARNING: {missing} lines have no clip yet: run tool/render_voices.py, then this again')
