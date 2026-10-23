#!/usr/bin/env python3
"""Real-life missions: tool/missions/missions.txt -> assets/data/missions.json.

Each mission: prep phrases you say (voice 'me') + what you might hear (a role voice) + a tip
(+ an optional safety note). The build fails on an unknown spot or role, missing Persian, a phrase too long
for its level, fewer than 3 phrases, or no "you might hear" line. Run tool/render_voices.py after adding
lines (it reads missions.json), then this again to add clip lengths.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
SPOTS = {s['id'] for s in json.load(open(os.path.join(A, 'data', 'spots.json')))}
# role -> (voice id, label): real-life strangers doing their job, voiced by the town's voices
ROLES = {'barista': ('callum', 'Barista'), 'driver': ('dave', 'Bus driver'), 'neighbour': ('doris', 'Neighbour'),
         'staff': ('maya', 'Staff'), 'pharmacist': ('dawson', 'Pharmacist'), 'librarian': ('bennett', 'Librarian'),
         'assistant': ('jade', 'Shop assistant'), 'clerk': ('receptionist', 'Post office clerk'), 'waiter': ('sophie', 'Waiter'), 'agent': ('agent', 'Letting agent')}
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']
MAXW = {'A1': 9, 'A2': 13, 'B1': 20, 'B2': 28, 'C1': 28}
bad, out, m = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'missions', 'missions.txt')), 1):
    line = raw.rstrip('\n')
    if not line.strip() or (line.startswith('#') and not re.match(r'^# [a-z0-9_]+ \|', line)):
        continue
    if line.startswith('# '):
        t = [x.strip() for x in line[2:].split('|')]
        if len(t) != 7: bad.append(f'{n}: mission header needs 7 fields'); continue
        m = dict(zip(['id', 'level', 'spot', 'title', 'titleFa', 'goal', 'goalFa'], t), say=[], hear=[], tip=None, safe=None)
        out.append(m); continue
    k = re.match(r'^(say|hear [a-z]+|tip|safe): (.+?) \| (.+)$', line)
    if not k: bad.append(f'{n}: cannot parse: {line}'); continue
    kind, en, fa = k.group(1), k.group(2).strip(), k.group(3).strip()
    if kind == 'say':
        if len(en.split()) > MAXW[m['level']]: bad.append(f"{n}: {len(en.split())} words is too long for {m['level']}")
        m['say'].append(dict(sp='me', spn='You', en=en, fa=fa))
    elif kind.startswith('hear '):
        role = kind[5:]
        if role not in ROLES: bad.append(f'{n}: unknown role {role}'); continue
        if len(en.split()) > MAXW[m['level']] + 4: bad.append(f"{n}: too long for {m['level']}")
        m['hear'].append(dict(sp=ROLES[role][0], spn=ROLES[role][1], en=en, fa=fa))
    else:
        m[kind] = dict(en=en, fa=fa)

def ms(sp, en):
    f = os.path.join(A, 'audio', hashlib.md5(f'{sp}|{en}'.encode()).hexdigest()[:16] + '.mp3')
    if not os.path.exists(f): return 0
    o = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(o.strip() or 0) * 1000)

ids, missing = set(), 0
for x in out:
    if x['id'] in ids: bad.append(f"duplicate id {x['id']}")
    ids.add(x['id'])
    if x['level'] not in LEVELS: bad.append(f"{x['id']}: bad level")
    if x['spot'] not in SPOTS: bad.append(f"{x['id']}: unknown map spot {x['spot']}")
    if len(x['say']) < 3: bad.append(f"{x['id']}: needs 3+ phrases")
    if not x['hear']: bad.append(f"{x['id']}: needs a 'hear' line")
    if not x['tip']: bad.append(f"{x['id']}: needs a tip")
    for l in x['say'] + x['hear']:
        if l['sp'] not in VOICES: bad.append(f"{x['id']}: no voice {l['sp']}")
        l['ms'] = ms(l['sp'], l['en']); missing += l['ms'] == 0
if bad:
    print('\n'.join(bad)); sys.exit(1)
json.dump({'missions': out}, open(os.path.join(A, 'data', 'missions.json'), 'w'), ensure_ascii=False, indent=0)
for x in out: print(x['level'], x['id'], len(x['say']), 'phrases', len(x['hear']), 'hear')
if missing: print(f'WARNING: {missing} lines have no clip yet: run tool/render_voices.py, then this again')
