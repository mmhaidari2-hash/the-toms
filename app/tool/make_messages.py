#!/usr/bin/env python3
"""Family voice messages: tool/messages/threads.txt -> assets/data/messages.json.

Threads of texts and voice notes from the Thompsons and friends; texting conventions are glossed; the
learner answers a quick question, then replies by picking, typing or saying the best reply.
'say' = the reply without emoji / kisses / lol: what the speech or typing check compares against.
The build fails on an unknown sender, missing Persian, a line too long for its level, no voice note,
no gloss, or a bad question/reply. Run tool/render_voices.py after adding lines, then this again.
"""
import hashlib, json, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
VOICES = set(re.findall(r"'([a-z]+)':\('en-", open(os.path.join(H, 'render_voices.py')).read()))
CAST = {c['id']: c for c in json.load(open(os.path.join(A, 'data', 'characters.json')))}
LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1']
MAXW = {'A1': 9, 'A2': 13, 'B1': 20, 'B2': 28, 'C1': 28}
EMOJI = re.compile('[\U0001F300-\U0001FAFF\u2600-\u27BF\uFE0F]')
NUM = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve']
MIN = {'00': "o'clock", '15': 'fifteen', '30': 'thirty', '45': 'forty-five'}
def spoken(t):
    t = re.sub(r'\b(\d{1,2})\.(00|15|30|45)\b', lambda m: f"{NUM[int(m.group(1))]} {MIN[m.group(2)]}", t)  # 7.30 -> seven thirty
    t = EMOJI.sub('', t)
    t = re.sub(r'(?<![\w\'])(x+|lol)(?![\w\'])', '', t)
    return re.sub(r'\s+', ' ', t).strip()
bad, out, th = [], [], None
for n, raw in enumerate(open(os.path.join(H, 'messages', 'threads.txt')), 1):
    line = raw.rstrip('\n')
    if not line.strip() or (line.startswith('#') and not re.match(r'^# [a-z0-9_]+ \|', line)):
        continue
    if line.startswith('# '):
        t = [x.strip() for x in line[2:].split('|')]
        if len(t) != 6: bad.append(f'{n}: thread header needs 6 fields'); continue
        th = dict(zip(['id', 'level', 'from', 'title', 'titleFa', 'time'], t), msgs=[], gloss=[], quiz=None, reply=None)
        out.append(th); continue
    if line.startswith('Q:'):
        q, opts = [x.strip() for x in line[2:].split('|')]
        o = [x.strip() for x in opts.split(';')]
        if len(o) != 3 or len(set(o)) != 3: bad.append(f'{n}: question needs 3 different options')
        th['quiz'] = dict(q=q, options=o, answer=0); continue
    if line.startswith('reply:'):
        best, rest = [x.strip() for x in line[6:].split('|', 1)]
        p = [x.strip() for x in rest.split(';')]
        if len(p) != 3: bad.append(f'{n}: reply needs "best | Persian ; wrong ; wrong"'); continue
        th['reply'] = dict(options=[best, p[1], p[2]], answer=0, fa=p[0], say=spoken(best)); continue
    if line.startswith('gloss:'):
        m = re.match(r'^gloss: (.+?) = (.+?) \| (.+)$', line)
        if not m: bad.append(f'{n}: gloss needs "term = meaning | Persian"'); continue
        th['gloss'].append(dict(term=m.group(1).strip(), en=m.group(2).strip(), fa=m.group(3).strip())); continue
    m = re.match(r'^(voice|text) ([a-z]+): (.+?) \| (.+)$', line)
    if not m: bad.append(f'{n}: cannot parse: {line}'); continue
    kind, sp, en, fa = m.groups()
    if sp not in CAST: bad.append(f'{n}: {sp} is not in characters.json')
    if kind == 'voice' and sp not in VOICES: bad.append(f'{n}: no voice for {sp}')
    if len(en.split()) > MAXW[th['level']]: bad.append(f"{n}: {len(en.split())} words is too long for {th['level']}")
    th['msgs'].append(dict(kind=kind, sp=sp, spn=CAST.get(sp, {}).get('name', sp), en=en.strip(), fa=fa.strip()))

def ms(sp, en):
    f = os.path.join(A, 'audio', hashlib.md5(f'{sp}|{en}'.encode()).hexdigest()[:16] + '.mp3')
    if not os.path.exists(f): return 0
    o = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout
    return int(float(o.strip() or 0) * 1000)

ids, missing = set(), 0
for t in out:
    if t['id'] in ids: bad.append(f"duplicate id {t['id']}")
    ids.add(t['id'])
    if t['level'] not in LEVELS: bad.append(f"{t['id']}: bad level")
    if t['from'] not in CAST: bad.append(f"{t['id']}: unknown contact {t['from']}")
    else: t['fromName'] = CAST[t['from']]['name']; t['avatar'] = CAST[t['from']]['avatar']
    if not re.match(r'^\d\d:\d\d$', t['time']): bad.append(f"{t['id']}: time must be HH:MM")
    if not any(m['kind'] == 'voice' for m in t['msgs']): bad.append(f"{t['id']}: needs a voice note")
    if not t['gloss']: bad.append(f"{t['id']}: needs a texting gloss")
    if not t['quiz'] or not t['reply']: bad.append(f"{t['id']}: needs Q: and reply:")
    elif len(t['reply']['say'].split()) < 2: bad.append(f"{t['id']}: reply too short to say")
    for m in t['msgs']:
        if not m['fa']: bad.append(f"{t['id']}: no Persian for {m['en']}")
        if m['kind'] == 'voice':
            m['ms'] = ms(m['sp'], m['en']); missing += m['ms'] == 0
if bad:
    print('\n'.join(bad)); sys.exit(1)
json.dump({'threads': out}, open(os.path.join(A, 'data', 'messages.json'), 'w'), ensure_ascii=False, indent=0)
for t in out: print(t['level'], t['id'], len(t['msgs']), 'msgs', len(t['gloss']), 'gloss', '| say:', t['reply']['say'])
if missing: print(f'WARNING: {missing} voice notes have no clip yet: run tool/render_voices.py, then this again')
