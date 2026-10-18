#!/usr/bin/env python3
"""Scene art audit + mapping (2026-10): every conversation opens on a painting that matches ITS setting and the
people in it. -> assets/data/scene_art.json  {sceneId: {"img": painting|null, "place": place id|null, "spot": icon, "label": setting}}
Rules: the setting comes from the lesson's place (or a hotspot), overridden by strong cues in the titles (nursery,
hospital, museum, Tube...). A painting may be used only if it shows that setting (or a room of the same kind) AND
every main character painted in it (the family) actually speaks in the scene: never a main character who
isn't there (a location's own background staff may stay in a painting of that location). Otherwise the
scene gets a neutral, people-free location card: the setting's painting blurred beyond recognition (no faces)
under the painted map icon + setting name; plain colour where no painting of the setting exists yet and is listed in
tool/audit/scenes_needing_art.md so new paintings can be commissioned. Run after editing lessons/scenes/places."""
import json, os, re, collections
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
J = lambda p: json.load(open(os.path.join(A, 'data', p)))
scenes = J('scenes_bundle.json'); course = J('course.json')
places = {p['id']: p for t in J('places.json') for p in t['places'] if p.get('image')}
GROUP = {**{k: 'home' for k in ['kitchen', 'hallway', 'living', 'bathroom', 'bedroom', 'eveningtea', 'birthday', 'christmas', 'poorly']},
         **{k: 'school' for k in ['firstday', 'school', 'parentsevening', 'sportsday']},
         **{k: 'shops' for k in ['supermarket', 'bigsupermarket', 'bakery', 'shoppingcentre', 'phoneshop']},
         **{k: 'health' for k in ['gp', 'doctor']}, 'university': 'uni', 'conference': 'uni'}
EVENT = {'birthday', 'christmas', 'sportsday', 'parentsevening', 'firstday', 'poorly', 'playdate'}  # only for their own setting
SPOT = {'home': 'home', 'school': 'school', 'shops': 'shops', 'health': 'gp', 'uni': 'university', 'dentist': 'gp', 'pharmacy': 'pharmacy',
        'bus': 'bus', 'train': 'station', 'bank': 'bank', 'postoffice': 'postoffice', 'library': 'library', 'park': 'park', 'coffee': 'cafe',
        'restaurant': 'restaurant', 'pub': 'pub', 'gym': 'gym', 'barber': 'barber', 'petrol': 'garage', 'driving': 'garage', 'interview': 'work',
        'playdate': 'playdate', 'nursery': 'nursery', 'hospital': 'hospital', 'museum': 'museum', 'cinema': 'cinema', 'work': 'work'}
LABEL = {'nursery': ("Vida's nursery", 'مهدکودک ویدا'), 'hospital': ('The hospital', 'بیمارستان'), 'museum': ('The museum', 'موزه'),
         'cinema': ('The cinema', 'سینما'), 'work': ('At work', 'سر کار')}
CUES = [(r'\bnursery\b|\bVida\b', 'nursery'), (r'\bhospital\b|\bA&E\b|\bward\b', 'hospital'), (r'\bmuseum\b', 'museum'),
        (r'\bthe Tube\b|\bUnderground\b', 'train'), (r'\bcinema\b', 'cinema')]
NONSPEAK = {'me', 'mehdi', 'narrator'}
# Main characters: never painted into a scene they're not in. A location's own background staff (the bus
# passenger, the baker...) may stay in a painting of THAT location.
MAIN = {'tom', 'leslie', 'william', 'nicola', 'ryan', 'weda', 'george', 'mehdi'}
lesson = {}
for u in course['units'] + [u for p in course.get('packs', []) for u in p['units']]:
    pk = next((p['id'] for p in course.get('packs', []) if u in p['units']), None)
    for l in u['lessons']:
        for s in l['sceneIds']: lesson[s] = dict(place=l['place'], title=l['title'], unit=u['title'], pack=pk)
hot = {h['sceneId']: pid for pid, p in places.items() for h in p['hotspots'] if h.get('sceneId')}
def people(p): return {h['characterId'] for h in p['hotspots'] if h.get('characterId')}
def mains(p): return people(p) & MAIN
def setting(sid, s):
    l = lesson.get(sid, {})
    text = ' '.join([s.get('title', ''), s.get('setting', ''), l.get('title', ''), l.get('unit', '')])
    if l.get('pack') == 'nursery': return 'nursery'
    for rx, loc in CUES:
        if re.search(rx, text, re.I): return loc
    return hot.get(sid) or l.get('place')
def speakers(s):
    sp = {n['speaker'] for n in s['nodes'].values()} | {s['characterId']}
    return sp - NONSPEAK - ({s['guest']} if s.get('guest') else set())
out, need = {}, collections.defaultdict(list)
for sid, s in scenes.items():
    if '__' in sid: continue  # role variants use their base scene's art
    loc, S = setting(sid, s), speakers(s)
    g = GROUP.get(loc, loc)
    cands = [pid for pid, p in places.items() if (pid == loc or (GROUP.get(pid) == g and pid not in EVENT)) and mains(p) <= S]
    cands.sort(key=lambda pid: (pid != loc, -len(people(places[pid]) & S)))
    lab = LABEL.get(loc) or ((places[loc]['title'], places[loc]['titleFa']) if loc in places else (s.get('setting', ''), s.get('settingFa', '')))
    if cands:
        out[sid] = dict(img=places[cands[0]]['image'], place=cands[0], spot=f"assets/spots/{SPOT.get(g, SPOT.get(loc, 'home'))}.webp", label=lab[0], labelFa=lab[1])
    else:
        bgp = loc if loc in places else next((pid for pid in places if GROUP.get(pid) == g and pid not in EVENT), None)
        out[sid] = dict(img=None, place=None, bg=f'assets/places/blur/{bgp}.webp' if bgp else None, spot=f"assets/spots/{SPOT.get(g, SPOT.get(loc, 'home'))}.webp", label=lab[0], labelFa=lab[1])
        need[loc].append((sid, s['title'], sorted(S)))
for v in out.values(): assert os.path.exists(os.path.join(A, '..', v['spot'])), v['spot']
json.dump(out, open(os.path.join(A, 'data', 'scene_art.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
os.makedirs(os.path.join(H, 'audit'), exist_ok=True)
with open(os.path.join(H, 'audit', 'scenes_needing_art.md'), 'w') as f:
    f.write('# Scenes waiting for a matching painting\n\nGenerated by tool/match_scene_art.py. These scenes show a neutral location card (no people) until a painting of the setting with exactly these speakers exists.\n\n')
    for loc, xs in sorted(need.items(), key=lambda x: -len(x[1])):
        f.write(f'## {loc} ({len(xs)})\n\n')
        for sid, t, S in xs: f.write(f"- `{sid}` {t} — {', '.join(S)}\n")
        f.write('\n')
n = sum(len(x) for x in need.values())
print(len(out), 'scenes;', len(out) - n, 'on a matching painting;', n, 'on a neutral location card')
print({k: len(v) for k, v in sorted(need.items(), key=lambda x: -len(x[1]))})
