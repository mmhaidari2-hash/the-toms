"""Rebuild free-explore scenes from tool/explore/<scene_id>.txt (lesson-DSL body lines).
Keeps the scene's metadata (title, setting, requires, characterId, level); replaces nodes. 16-24 turns enforced."""
import json,glob,os,re,sys
H=os.path.dirname(os.path.abspath(__file__)); S=os.path.join(H,'..','..','assets','data','scenes')
sys.path.insert(0,os.path.join(H,'..','level1'))
STOP=set("a an the i i'm you you're is are am it it's to of and or in on at be do does my your me so too yes no not very this that what with for".split())
def toks(s): return [w for w in re.sub(r"[^a-z' ]"," ",s.lower()).split() if w and w not in STOP]
def kws(m,o):
  O=set(toks(o)); u=sorted(set(w for w in toks(m) if w not in O),key=lambda w:-len(w))[:4]
  if u: return u
  A=lambda x: re.sub(r"[^a-z' ]"," ",x.lower()).split(); O2=set(A(o)); u=[w for w in A(m) if w not in O2]
  if u: return u[:3]
  raise SystemExit(f'reply subset: {m!r} / {o!r}')
LIM={'A0':90,'A1':110,'A2':130,'B1':150,'B2':190}
errs=[]
for f in sorted(glob.glob(os.path.join(H,'*.txt'))):
  sid=os.path.basename(f)[:-4]; p=os.path.join(S,sid+'.json'); d=json.load(open(p)); ns=[]
  for raw in open(f,encoding='utf-8'):
    l=raw.strip()
    if not l: continue
    if l.startswith('>'): a=[x.strip() for x in l[1:].split('|')]; ns[-1]['r'].append((a[0],a[1]));continue
    if l.startswith('W:'): ns[-1]['w']+=[{'word':a.split('=',1)[0].strip(),'fa':a.split('=',1)[1].strip()} for a in l[2:].split(';') if '=' in a];continue
    if l.startswith('C:'): e,fa=[x.strip() for x in l[2:].split('|')]; ns[-1]['c']={'en':e,'fa':fa};continue
    sp,rest=l.split(':',1); t,fa=[x.strip() for x in rest.split('|')]; ns.append({'s':sp.strip(),'t':t,'fa':fa,'r':[],'w':[],'c':None})
  turns=2*len(ns)-1
  if not 16<=turns<=24: errs.append(f'{sid}: {turns} turns')
  N={}
  for i,n in enumerate(ns):
    nid=f'n{i+1}'; nxt=f'n{i+2}' if i+1<len(ns) else None
    if n['s']=='william' and len(n['t'].split())>6: errs.append(f'{sid}/{nid} william too long')
    if n['s']=='nicola' and len(n['t'].split())>18: errs.append(f'{sid}/{nid} nicola too long')
    if len(n['t'])>LIM.get(d.get('level') or 'A1',230): errs.append(f'{sid}/{nid} too long {len(n["t"])}')
    if nxt and not n['r']: errs.append(f'{sid}/{nid} no replies')
    if not nxt and n['r']: errs.append(f'{sid}/{nid} last node has replies')
    br=[{'keywords':kws(s,' '.join(x[0] for k,x in enumerate(n['r']) if k!=j)),'suggestion':s,'suggestionFa':sf,'trustDelta':7-j,'next':nxt,'success':True} for j,(s,sf) in enumerate(n['r'])]
    N[nid]={'id':nid,'speaker':n['s'],'text':n['t'],'translations':{'fa':n['fa']},'branches':br,'newWords':n['w'],'cultureNote':n['c']}
  d['start']='n1'; d['nodes']=N; d['_out']=p
  globals().setdefault('OUT',[]).append(d)
if errs: print('\n'.join(errs)); sys.exit(1)
for d in globals().get('OUT',[]):
  p=d.pop('_out'); json.dump(d,open(p,'w'),ensure_ascii=False,indent=1)
print(len(globals().get('OUT',[])),'explore scenes rebuilt')
