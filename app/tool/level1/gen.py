"""Compile tool/level1/u*.txt (lesson DSL) into scene JSON + assets/data/course.json."""
import json,glob,os,re,sys
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','..','assets','data')
STOP=set("a an the i i'm you you're is are am it it's to of and or in on at be do does my your me so too yes no not very this that what with for".split())
def toks(s): return [w for w in re.sub(r"[^a-z' ]"," ",s.lower().replace('{you}',' ')).split() if w and w not in STOP]
def kws(mine,other):
  o=set(toks(other)); u=[w for w in toks(mine) if w not in o]
  u=sorted(set(u),key=lambda w:-len(w))[:4]
  if u: return u
  allw=lambda x: re.sub(r"[^a-z' ]"," ",x.lower().replace('{you}',' ')).split()
  o2=set(allw(other)); u=[w for w in allw(mine) if w not in o2]
  if not u: raise ValueError(f'reply is a subset of its sibling: {mine!r} vs {other!r}')
  return u[:3]
def words(s):
  out=[]
  for p in s.split(';'):
    if '=' in p: w,f=p.split('=',1); out.append({'word':w.strip(),'fa':f.strip()})
  return out
units=[];scenes={};errs=[]
FILES=sorted(glob.glob(os.path.join(H,'..','level*','u*.txt')),key=lambda f:(int(re.search(r'level(\d+)',os.path.basename(os.path.dirname(f))).group(1)),f))
for f in FILES:
  LV=int(re.search(r'level(\d+)',os.path.basename(os.path.dirname(f))).group(1))
  unit=None;les=None;node=None
  for raw in open(f,encoding='utf-8'):
    l=raw.rstrip('\n').strip()
    if not l: continue
    if l.startswith('## '):
      uid,t,tf,place,can,canfa=[x.strip() for x in l[3:].split('|')]
      unit={'level':LV,'id':uid,'title':t,'titleFa':tf,'place':place,'canDo':can,'canDoFa':canfa,'lessons':[]};units.append(unit);continue
    if l.startswith('# '):
      p=[x.strip() for x in l[2:].split('|')]
      les={'id':p[0],'lead':p[1],'title':p[2],'titleFa':p[3],'grammar':p[4],'grammarFa':p[5],'place':(p[6] if len(p)>6 else unit['place']),'nodes':[]}
      unit['lessons'].append(les);node=None;continue
    if l.startswith('>'):
      p=[x.strip() for x in l[1:].split('|')]; node['replies'].append((p[0],p[1] if len(p)>1 else ''));continue
    if l.startswith('W:'): node['words']+=words(l[2:]);continue
    if l.startswith('C:'):
      e,fa=[x.strip() for x in l[2:].split('|')]; node['culture']={'en':e,'fa':fa};continue
    if l.startswith('X:'):
      m,rest=l[2:].split('=>'); echo,better,bfa=[x.strip() for x in rest.split('|')]
      node['recasts'].append({'match':[x.strip() for x in m.split(';') if x.strip()],'echo':echo,'better':better,'betterFa':bfa});continue
    sp,rest=l.split(':',1); t,fa=[x.strip() for x in rest.split('|')]
    node={'speaker':sp.strip(),'text':t,'fa':fa,'replies':[],'words':[],'culture':None,'recasts':[]}; les['nodes'].append(node)
course={'units':[]}
for ui,u in enumerate(units):
  cu={k:u[k] for k in ('level','id','title','titleFa','place','canDo','canDoFa')}; cu['lessons']=[]
  for les in u['lessons']:
    sid=les['id']; N={}; ns=les['nodes']; lvl=('A0' if ui<3 else 'A1') if u['level']==1 else {2:'A2',3:'B1',4:'B2'}.get(u['level'],'C1')
    allw=[]
    for i,n in enumerate(ns):
      nid=f'n{i+1}'; nxt=f'n{i+2}' if i+1<len(ns) else None
      if n['speaker']=='nicola' and len(n['text'].split())>18: errs.append(f'{sid}/{nid} nicola too long')
      if n['speaker']=='william' and len(n['text'].split())>6: errs.append(f'{sid}/{nid} william too long')
      if len(n['text'])>{'A0':90,'A1':110,'A2':130,'B1':150,'B2':190}.get(lvl,230): errs.append(f'{sid}/{nid} too long {len(n["text"])}')
      br=[]
      R=n['replies']
      for j,(s,sf) in enumerate(R):
        other=' '.join(x[0] for k,x in enumerate(R) if k!=j)
        try: kw=kws(s,other)
        except ValueError as e: errs.append(f'{sid}/{nid} {e}'); kw=['x']
        br.append({'keywords':kw,'suggestion':s,'suggestionFa':sf,'trustDelta':6-j,'next':nxt,'success':True})
      if nxt and not br: errs.append(f'{sid}/{nid} has no replies but is not last')
      d={'id':nid,'speaker':n['speaker'],'text':n['text'],'translations':{'fa':n['fa']},'branches':br,'newWords':n['words']}
      if n['culture']: d['cultureNote']=n['culture']
      if n['recasts']: d['recasts']=n['recasts']
      N[nid]=d; allw+=n['words']
    scene={'id':sid,'characterId':les['lead'],'title':les['title'],'titleFa':les['titleFa'],'setting':f"{u['title']} · Level {u['level']}",'settingFa':u['titleFa'],'requires':None,'start':'n1','level':lvl,'nodes':N}
    scenes[sid]=scene
    cu['lessons'].append({'id':sid,'title':les['title'],'titleFa':les['titleFa'],'lead':les['lead'],'place':les['place'],'grammar':les['grammar'],'grammarFa':les['grammarFa'],'sceneIds':[sid],'words':allw,'turns':2*len(ns)-1})
  course['units'].append(cu)
PL={p['id']:p for t in json.load(open(os.path.join(A,'places.json'))) for p in t['places']}
for u in course['units']:
  for l in u['lessons']:
    if l['place'] not in PL: errs.append(f"{l['id']} unknown place {l['place']}")
    elif l['lead'] not in {h['characterId'] for h in PL[l['place']].get('hotspots',[])}: errs.append(f"{l['id']}: lead {l['lead']} is not in the {l['place']} painting")
if errs: print('\n'.join(errs)); sys.exit(1)
for sid,s in scenes.items(): json.dump(s,open(os.path.join(A,'scenes',sid+'.json'),'w'),ensure_ascii=False,indent=1)
idx=[i for i in json.load(open(os.path.join(A,'scenes_index.json'))) if not re.match(r'l\d+_',i)]+list(scenes)
json.dump(idx,open(os.path.join(A,'scenes_index.json'),'w'),indent=1)
json.dump(course,open(os.path.join(A,'course.json'),'w'),ensure_ascii=False,indent=1)
W={w['word'].lower() for u in course['units'] for l in u['lessons'] for w in l['words']}
print(len(course['units']),'units',sum(len(u['lessons']) for u in course['units']),'lessons',len(W),'words',sum(l['turns'] for u in course['units'] for l in u['lessons']),'turns')
# role-switch variants must be rebuilt whenever scenes change
import subprocess; subprocess.run([sys.executable, os.path.join(H,'..','explore','build.py')], check=True); subprocess.run([sys.executable, os.path.join(H,'..','make_roles.py')], check=True); subprocess.run([sys.executable, os.path.join(H,'..','bundle_scenes.py')], check=True)
