# Run 28: who speaks together (scenes, cinema, radio, missions, ...) -> voice_groups.json, checked by tool/qa/qa_voice.py
import json,glob,os,collections
A='/workspace/british-life/app/assets/data'
G={}
def g(name,sps): 
  s=set(x for x in sps if x); 
  if len(s)>1: G[name]=s
for f in glob.glob(A+'/scenes/*.json'):
  d=json.load(open(f)); sp=[n['speaker'] for n in d['nodes'].values()]
  if any(n.get('branches') for n in d['nodes'].values()): sp.append(d.get('guest','me'))
  g('scene:'+os.path.basename(f)[:-5],sp)
def L(fn): 
  p=f'{A}/{fn}'; return json.load(open(p)) if os.path.exists(p) else None
d=L('cinema.json'); [g('cinema:'+str(i),[l['sp'] for l in s['lines']]) for i,s in enumerate(d['scenes'])] if d else 0
d=L('radio.json'); [g('radio:'+str(i),[l['sp'] for l in s['lines']]) for i,s in enumerate(d['segments'])] if d else 0
d=L('missions.json'); [g('mission:'+str(i),[l['sp'] for l in x['say']+x['hear']]) for i,x in enumerate(d['missions'])] if d else 0
d=L('messages.json'); [g('msg:'+str(i),[m['sp'] for m in t['msgs'] if m['kind']=='voice']) for i,t in enumerate(d['threads'])] if d else 0
d=L('seasons.json'); [g('season:'+str(i),[l['sp'] for l in e['lines']]) for i,e in enumerate(d['events'])] if d else 0
d=L('roleplays.json'); [g('rp:'+str(i),[r['sp'],'me']) for i,r in enumerate(d['roleplays'])] if d else 0
d=L('driving.json'); [g('drive:'+str(i),[l['sp'] for l in e['lines']]+['narrator']) for i,e in enumerate(d['lessons'])] if d else 0
d=L('library.json'); [g('lib:'+str(i),[st.get('sp','narrator') for c in b['chapters'] for st in c['sentences']]) for i,b in enumerate(d['books'])] if d else 0
# places: characters on the same map screen
def walk(o,acc):
  if isinstance(o,dict):
    if o.get('characterId'): acc.add(o['characterId'])
    pr=o.get('prop')
    if isinstance(pr,dict): acc.add('narrator'); [acc.add(m[0]) for m in pr.get('mini',[])]
    for v in o.values(): walk(v,acc)
  elif isinstance(o,list): [walk(v,acc) for v in o]
pl=L('places.json')
for i,p in enumerate(pl if isinstance(pl,list) else pl.get('places',pl.values() if isinstance(pl,dict) else [])):
  acc=set(); walk(p,acc); g('place:'+str(i),acc)
json.dump({k:sorted(v) for k,v in G.items()},open('/workspace/british-life/app/tool/audit/voice_groups.json','w'),indent=0)
P=collections.Counter()
for s in G.values():
  for a in s:
    for b in s:
      if a<b: P[(a,b)]+=1
json.dump({f'{a}|{b}':n for (a,b),n in P.items()},open('/tmp/voice_pairs.json','w'))
print(len(G),'groups',len(P),'pairs'); print(collections.Counter(k.split(':')[0] for k in G))
