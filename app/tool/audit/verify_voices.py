"""Run 28: every scene/group must have distinct voices per speaker; family+recurring distinct; pitch/rate limits."""
import json,sys,collections,re
G=json.load(open(''+__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'voice_groups.json')+''))
sys.path.insert(0,'/workspace/british-life/app/tool')
src=open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'..','render_voices.py')).read()
V=eval(src[src.index('V={')+2:src.index('\n}\n')+2])
bad=[]
for g,sps in G.items():
  sps=[s for s in sps if s!='learner' or 'me' not in sps]
  by=collections.defaultdict(list)
  for s in sps:
    if s in('me','learner'): s='me'
    by[V[s][0]].append(s)
  for v,cs in by.items():
    if len(set(cs))>1: bad.append((g,v,sorted(set(cs))))
FAM=['tom','leslie','nicola','ryan','weda','william','george','vida','me']
REC=['ellis','doris','maya','al','callum','priya','sian','arthur']
R=FAM+REC; dup=[v for v,n in collections.Counter(V[c][0] for c in R).items() if n>1]
EXC={'nicola','mia','oscar'}
lim=[(c,V[c]) for c in V if c not in EXC and (abs(int(V[c][1][:-2]))>8 or not -9<=int(V[c][2][:-1])<=2)]
print('groups',len(G),'same-voice clashes',len(bad),bad[:10]); print('family/recurring duplicate voices',dup); print('limit violations',lim)
print('max share',collections.Counter(v[0] for c,v in V.items() if c!='learner').most_common(5))
sys.exit(1 if bad or dup or lim else 0)
