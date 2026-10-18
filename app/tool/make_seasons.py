#!/usr/bin/env python3
"""Seasonal events: tool/seasons/events.txt -> assets/data/seasons.json.

A calendar of British celebrations (and multicultural London's), each with a Thompson-family scene in
British voices, Persian, vocab and a 3-question quiz. Dates are computed in the app from the rule
(fixed / Easter-relative / nth weekday / a table for moon and equinox festivals).
The build fails on an unknown speaker, missing Persian, a line too long for its level, a bad rule or quiz.
Run tool/render_voices.py after adding lines, then this again to fill in clip lengths.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
CAST = {c['id']: c for c in json.load(open(os.path.join(A, 'data', 'characters.json')))}
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']
MAXW = {'A1': 9, 'A2': 13, 'B1': 20, 'B2': 28, 'C1': 28}
RULE = re.compile(r'^(fixed:\d\d-\d\d|easter:[+-]?\d+|(nth:\d\d:[1-7]:-?[1-5])(,nth:\d\d:[1-7]:-?[1-5])*|table:\d{4}-\d\d-\d\d(,\d{4}-\d\d-\d\d)*)$')
def ms(sp, en):
    f = os.path.join(A, 'audio', hashlib.md5(f'{sp}|{en}'.encode()).hexdigest()[:16] + '.mp3')
    if not os.path.exists(f): return 0
    o = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(o.strip() or 0) * 1000)
bad, out, ev = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'seasons', 'events.txt')), 1):
    line = raw.strip()
    if not line or (line.startswith('#') and not re.match(r'^# [a-z0-9]+ \|', line)): continue
    if line.startswith('# '):
        p = [x.strip() for x in line[2:].split('|')]
        if len(p) != 5: bad.append(f'{n}: header needs 5 fields'); continue
        rule, approx = p[2].replace(' approx', ''), p[2].endswith(' approx')
        if not RULE.match(rule): bad.append(f'{n}: bad rule {p[2]}')
        ev = dict(id=p[0], level=p[1], rule=rule, approx=approx, title=p[3], titleFa=p[4], when='', whenFa='', note='', noteFa='', lines=[], words=[], qs=[], src=[])
        out.append(ev); continue
    k, _, v = line.partition(': ')
    if k == 'src': ev['src'].append(v.strip()); continue
    if k in ('when', 'note'):
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
    if k == 'me' or k in CAST:
        p = [x.strip() for x in v.split('|')]
        if len(p) != 2 or not all(p): bad.append(f'{n}: line needs English | Persian'); continue
        if k not in VOICES: bad.append(f'{n}: no voice for {k}')
        if len(p[0].split()) > MAXW.get(ev['level'], 0): bad.append(f"{n}: {len(p[0].split())} words is too long for {ev['level']}")
        c = CAST.get(k, {})
        ev['lines'].append(dict(sp=k, name=c.get('name', 'You'), avatar=c.get('avatar', ''), en=p[0], fa=p[1], ms=ms(k, p[0]))); continue
    bad.append(f'{n}: unknown line {k}')
ids, missing = set(), 0
for e in out:
    if e['id'] in ids: bad.append(f"duplicate id {e['id']}")
    ids.add(e['id'])
    if e['level'] not in LEVELS: bad.append(f"{e['id']}: bad level")
    if not (e['when'] and e['note']): bad.append(f"{e['id']}: needs when: and note:")
    if len(e['lines']) < 5 or len(e['words']) < 4 or len(e['qs']) != 3: bad.append(f"{e['id']}: needs 5+ lines, 4+ words and 3 questions")
    missing += sum(1 for l in e['lines'] if not l['ms'])
for lv in LEVELS:
    if not any(e['level'] == lv for e in out): bad.append(f'no events at {lv}')
if bad: print('\n'.join(bad)); sys.exit(1)
json.dump({'events': out}, open(os.path.join(A, 'data', 'seasons.json'), 'w'), ensure_ascii=False, indent=0)
for e in out: print(e['level'], e['id'], e['rule'], len(e['lines']), 'lines')
if missing: print(f'WARNING: {missing} lines have no clip yet: run tool/render_voices.py, then this again')
