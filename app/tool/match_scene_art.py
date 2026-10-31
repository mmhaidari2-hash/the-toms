#!/usr/bin/env python3
"""Scene art audit + mapping (2026-10): every conversation opens on a painting that matches ITS setting and the
people in it. -> assets/data/scene_art.json  {sceneId: {"img": painting|null, "place": place id|null, "spot": icon, "label": setting}}
Rules: the setting comes from the lesson's place (or a hotspot), overridden by strong cues in the titles (nursery,
hospital, museum, Tube...). (Superseded 2026-10-23: the best painting of the setting is always used.) Was: a painting may be used only if it shows that setting (or a room of the same kind) AND
every main character painted in it (the family) actually speaks in the scene: never a main character who
isn't there (a location's own background staff may stay in a painting of that location). Otherwise the
scene gets a neutral, people-free location card: the setting's painting blurred beyond recognition (no faces)
under a plain symbol + setting name (the painted map icons show people, so they're not used); plain colour where no painting of the setting exists yet and is listed in
tool/audit/scenes_needing_art.md so new paintings can be commissioned. Run after editing lessons/scenes/places."""
import json, os, re, collections
H = os.path.dirname(os.path.abspath(__file__)); A = os.path.join(H, '..', 'assets')
J = lambda p: json.load(open(os.path.join(A, 'data', p)))
scenes = J('scenes_bundle.json'); course = J('course.json')
places = {p['id']: p for t in J('places.json') for p in t['places'] if p.get('image')}
# 2026-10-23 run 22: paintings of settings that aren't visitable places (assets/data/art_places.json)
ARTPLACES = {p['id'] for p in J('art_places.json')}
places.update({p['id']: p for p in J('art_places.json')})
GROUP = {**{k: 'home' for k in ['kitchen', 'hallway', 'living', 'bathroom', 'bedroom', 'eveningtea', 'birthday', 'christmas', 'poorly']},
         **{k: 'school' for k in ['firstday', 'school', 'parentsevening', 'sportsday']},
         **{k: 'shops' for k in ['supermarket', 'bigsupermarket', 'bakery', 'shoppingcentre', 'phoneshop']},
         **{k: 'health' for k in ['gp', 'doctor']}, 'university': 'uni', 'conference': 'uni',
         **{k: 'nursery' for k in ['nursery', 'nurserydoor', 'nurseryoffice']}, **{k: 'homes' for k in ['homes', 'viewing']},
         **{k: 'hospital' for k in ['hospital', 'hospitalreception']}}
EVENT = {'birthday', 'christmas', 'sportsday', 'parentsevening', 'firstday', 'poorly', 'playdate'}  # only for their own setting
SPOT = {'home': 'home', 'school': 'school', 'shops': 'shops', 'health': 'gp', 'uni': 'university', 'dentist': 'gp', 'pharmacy': 'pharmacy',
        'bus': 'bus', 'train': 'station', 'bank': 'bank', 'postoffice': 'postoffice', 'library': 'library', 'park': 'park', 'coffee': 'cafe',
        'restaurant': 'restaurant', 'pub': 'pub', 'gym': 'gym', 'barber': 'barber', 'petrol': 'garage', 'driving': 'garage', 'interview': 'work',
        'playdate': 'playdate', 'nursery': 'nursery', 'hospital': 'hospital', 'museum': 'museum', 'cinema': 'cinema', 'work': 'work', 'homes': 'homes'}
LABEL = {'nursery': ("Vida's nursery", 'مهدکودک پرایمروز لین'), 'hospital': ('The hospital', 'بیمارستان'), 'museum': ('The museum', 'موزه'),
         'cinema': ('The cinema', 'سینما'), 'homes': ('Hartley & Wren Homes', 'املاک هارتلی و رن'), 'work': ('At work', 'سر کار')}
CUES = [(r'\bnursery\b|\bVida\b', 'nursery'), (r'\bhospital\b|\bA&E\b|\bward\b', 'hospital'), (r'\bmuseum\b', 'museum'),
        (r'\bthe Tube\b|\bUnderground\b', 'train'), (r'\bcinema\b', 'cinema')]
NONSPEAK = {'me', 'learner', 'narrator'}
# Main characters: never painted into a scene they're not in. A location's own background staff (the bus
# passenger, the baker...) may stay in a painting of THAT location.
MAIN = {'tom', 'leslie', 'william', 'nicola', 'ryan', 'weda', 'george', 'learner'}
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
    if l.get('pack') == 'homes': return 'homes'
    for rx, loc in CUES:
        if re.search(rx, text, re.I): return loc
    return hot.get(sid) or l.get('place')
def speakers(s):
    sp = {n['speaker'] for n in s['nodes'].values()} | {s['characterId']}
    return sp - NONSPEAK - ({s['guest']} if s.get('guest') else set())
# 2026-10-23: settings with no painting of their own yet (nursery, hospital, museum, cinema) borrow the closest
# existing painting per scene (the room/activity that best matches), so nothing opens on a blurred card.
# Run 22: each scene in a newly painted setting gets the view of that setting that fits it best.
ART = {
    'weda_illness': 'poorly',  # William poorly at home
    **{f'nur_{a}': 'nurserydoor' for a in ['1_1', '4_1', '4_2', '4_4', '5_4', '6_4']},
    **{f'nur_{a}': 'nurseryoffice' for a in ['4_3', '5_1', '5_2', '5_3', '6_1', '6_2', '6_3']},
    **{f'est_{a}': 'viewing' for a in ['1_2', '3_2', '4_3']},
    'l2_u20_1': 'gp',  # Dr Okafor reads the hospital letter at the surgery
    'l2_u58_1': 'living', 'l2_u58_2': 'living', 'l2_u58_3': 'living',  # film night, booking online, cinema at home
    'l2_u20_2': 'hospitalreception', 'l3_u11_1': 'hospitalreception', 'l2_u20_3': 'hospital', 'l2_u20_4': 'hospital',
    'l2_u21_2': 'train',  # getting to South Kensington with Maya the conductor
}
BORROW = {
    'weda_illness': 'poorly',
    'nur_1_1': 'firstday', 'nur_1_2': 'bathroom', 'nur_1_3': 'eveningtea', 'nur_1_4': 'playdate',
    'nur_2_1': 'bathroom', 'nur_2_2': 'eveningtea', 'nur_2_3': 'poorly', 'nur_2_4': 'park',
    'nur_3_1': 'playdate', 'nur_3_2': 'playdate', 'nur_3_3': 'living', 'nur_3_4': 'playdate',
    'nur_4_1': 'firstday', 'nur_4_2': 'parentsevening', 'nur_4_3': 'parentsevening', 'nur_4_4': 'poorly',
    'nur_5_1': 'parentsevening', 'nur_5_2': 'living', 'nur_5_3': 'parentsevening', 'nur_5_4': 'firstday',
    'nur_6_1': 'parentsevening', 'nur_6_2': 'eveningtea', 'nur_6_3': 'school', 'nur_6_4': 'parentsevening',
    'l2_u20_1': 'doctor', 'l2_u20_2': 'doctor', 'l2_u20_3': 'doctor', 'l2_u20_4': 'doctor', 'l3_u11_1': 'doctor',
    'l2_u21_1': 'library', 'l2_u21_2': 'train', 'l2_u21_3': 'coffee', 'l2_u21_4': 'library',
    # Hartley & Wren Homes (estate agent): no painting of its own yet; office talks borrow the bank desk, home visits the rooms
    'est_1_1': 'hallway', 'est_1_2': 'living', 'est_1_3': 'bank', 'est_2_1': 'bank', 'est_2_2': 'bank', 'est_2_3': 'interview',
    'est_3_1': 'bank', 'est_3_2': 'living', 'est_3_3': 'kitchen', 'est_4_1': 'bathroom', 'est_4_2': 'bedroom', 'est_4_3': 'hallway',
    'est_5_1': 'bank', 'est_5_2': 'living', 'est_5_3': 'interview', 'est_5_4': 'bank',
    'l2_u58_1': 'living', 'l2_u58_2': 'living', 'l2_u58_3': 'conference', 'l2_u58_4': 'pub',
}
# Fallback for any future scene in those settings.
BORROW_SETTING = {'nursery': 'playdate', 'hospital': 'doctor', 'museum': 'library', 'cinema': 'living', 'work': 'interview', 'homes': 'bank'}
out, need = {}, collections.defaultdict(list)
for sid, s in scenes.items():
    if '__' in sid: continue  # role variants use their base scene's art
    loc, S = setting(sid, s), speakers(s)
    g = GROUP.get(loc, loc)
    # 2026-10-23: a painting of the setting always beats a blurred card. Prefer the setting itself, then
    # paintings with no absent main character, then the most speakers shown; event paintings come last.
    if sid in ART:
        a = ART[sid]
        # A painting of a visitable place (home, GP, train) is labelled with that place; new setting paintings keep the setting label.
        lab = (places[a]['title'], places[a]['titleFa']) if a not in ARTPLACES else (LABEL.get(loc) or ((places[loc]['title'], places[loc]['titleFa']) if loc in places else (s.get('setting', ''), s.get('settingFa', ''))))
        out[sid] = dict(img=places[a]['image'], place=a, spot=f"assets/spots/{SPOT.get(g, SPOT.get(loc, 'home'))}.webp", label=lab[0], labelFa=lab[1])
        continue
    cands = [pid for pid, p in places.items() if pid == loc or GROUP.get(pid) == g]
    cands.sort(key=lambda pid: (pid != loc, pid in EVENT, len(mains(places[pid]) - S), -len(people(places[pid]) & S)))
    lab = LABEL.get(loc) or ((places[loc]['title'], places[loc]['titleFa']) if loc in places else (s.get('setting', ''), s.get('settingFa', '')))
    if cands:
        out[sid] = dict(img=places[cands[0]]['image'], place=cands[0], spot=f"assets/spots/{SPOT.get(g, SPOT.get(loc, 'home'))}.webp", label=lab[0], labelFa=lab[1])
    elif (BORROW.get(sid) or BORROW_SETTING.get(loc)) in places:
        b = BORROW.get(sid) or BORROW_SETTING[loc]
        out[sid] = dict(img=places[b]['image'], place=b, spot=f"assets/spots/{SPOT.get(g, SPOT.get(loc, 'home'))}.webp", label=lab[0], labelFa=lab[1], borrowed=True)
        need['(borrowed) ' + loc].append((sid, s['title'], sorted(S)))
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
n = sum(len(x) for k, x in need.items() if not k.startswith('(borrowed)'))
print(len(out), 'scenes;', len(out) - n, 'on a matching painting;', n, 'on a neutral location card')
print({k: len(v) for k, v in sorted(need.items(), key=lambda x: -len(x[1]))})
