#!/usr/bin/env python3
"""Role-play missions per building: tool/roleplay/roleplays.py -> assets/data/roleplays.json.
In-app dialogue with a town character: 3 goals, a hint per turn, slow replay, Persian translation, report card.
The build fails on an unknown spot or voice, missing Persian, a turn without exactly one best option, or
goals that can't all be reached. Run tool/render_voices.py afterwards (it reads roleplays.json)."""
import json, os, re, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
sys.path.insert(0, os.path.join(H, 'roleplay')); from roleplays import R
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
SPOTS = {s['id'] for s in json.load(open(os.path.join(A, 'data', 'spots.json')))}
FA = re.compile(r'[\u0600-\u06FF]')
bad, out = [], []
def p(t): return {'en': t[0], 'fa': t[1]}
for (id, lv, spot, voice, npc, title, titleFa, intro, goals, turns, end) in R:
    if spot not in SPOTS: bad.append(f'{id}: unknown spot {spot}')
    if voice not in VOICES: bad.append(f'{id}: unknown voice {voice}')
    if len(goals) != 3: bad.append(f'{id}: needs 3 goals')
    reach = set()
    for i, (line, hint, opts) in enumerate(turns):
        if sum(1 for o in opts if o[0] == 2) != 1: bad.append(f'{id} turn {i}: needs exactly one best option')
        if not any(o[0] == 0 for o in opts): bad.append(f'{id} turn {i}: needs a wrong option')
        for o in opts:
            if o[0] >= 1 and o[1] >= 0: reach.add(o[1])
            if o[0] == 0 and o[1] >= 0: bad.append(f'{id} turn {i}: a wrong option cannot reach a goal')
        for t in [line, hint] + [(o[2], o[3]) for o in opts] + [(o[4], o[5]) for o in opts]:
            if not FA.search(t[1]): bad.append(f'{id} turn {i}: missing Persian for {t[0]!r}')
    if reach != {0, 1, 2}: bad.append(f'{id}: goals not all reachable ({sorted(reach)})')
    out.append({'id': id, 'level': lv, 'spot': spot, 'sp': voice, 'npc': npc, 'title': title, 'titleFa': titleFa,
                'intro': p(intro), 'goals': [p(g) for g in goals], 'end': p(end),
                'turns': [{'npc': p(l), 'hint': p(h), 'opts': [{'q': o[0], 'g': o[1], 'en': o[2], 'fa': o[3], 'fb': {'en': o[4], 'fa': o[5]}} for o in opts]} for (l, h, opts) in turns]})
if bad: print('\n'.join(bad)); sys.exit(1)
json.dump({'roleplays': out}, open(os.path.join(A, 'data', 'roleplays.json'), 'w'), ensure_ascii=False, indent=1)
print(f'{len(out)} role-plays, {sum(len(r["turns"]) for r in out)} turns')
