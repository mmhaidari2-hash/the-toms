"""Full role switching: for every scene, build a variant per family member who speaks in it (>=2 lines).
The learner says that member's lines; the guest (Mehdi) becomes an NPC who says the original best reply.
Writes assets/data/scenes/<id>__as_<role>.json (+ scenes_index). Deterministic; re-run after content changes."""
import json,os,re,glob
A=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','data')
FAMILY=['tom','leslie','nicola','ryan','weda']
NAMES={'tom':'Tom','leslie':'Leslie','nicola':'Nicola','ryan':'Ryan','weda':'Nana Maggie'}
BACK=[('Mm-hm.','آهان.'),('Oh, right!','آهان، درسته!'),('Really?','واقعاً؟'),('OK!','باشه!')]
STOP=set("a an the i i'm you you're is are am it it's to of and or in on at be do does my your me so too yes no not very this that what with for".split())
def kw(s):
  w=[x for x in re.sub(r"[^a-z' ]"," ",s.lower().replace('{you}',' ')).split() if x]
  k=[x for x in w if x not in STOP] or w
  return sorted(set(k),key=lambda x:-len(x))[:5] or ['ok']
idx=[i for i in json.load(open(os.path.join(A,'scenes_index.json'))) if '__as_' not in i]
for f in glob.glob(os.path.join(A,'scenes','*__as_*.json')): os.remove(f)
made=[]
for sid in idx:
  s=json.load(open(os.path.join(A,'scenes',sid+'.json')))
  N=s['nodes']
  # walk the best path (highest trust branch), collecting utterances
  path=[];cur=s['start'];seen=set()
  while cur and cur not in seen:
    seen.add(cur); n=N[cur]; path.append(n)
    br=sorted(n['branches'],key=lambda b:-b.get('trustDelta',0))
    n['_best']=br[0] if br else None
    cur=br[0]['next'] if br else None
  speakers=[n['speaker'] for n in path]
  G=s.get('guest','mehdi')  # the guest who becomes the NPC (Sara in Vida's Nursery)
  for L in FAMILY:
    if speakers.count(L)<2: continue
    U=[]  # (who, text, fa, node)  who: 'USER' or speaker id
    for n in path:
      U.append(('USER' if n['speaker']==L else n['speaker'],n['text'],n['translations'].get('fa',''),n))
      b=n['_best']
      if b: U.append((G,b['suggestion'],b.get('suggestionFa',''),None))
    if U[0][0]=='USER': U.insert(0,(G,f"Hi, {NAMES[L]}!",f"سلام {NAMES[L]}!",None))
    if U[-1][0]=='USER': U.append((G,f"Thanks, {NAMES[L]}! See you later.",f"ممنون {NAMES[L]}! بعداً می‌بینمت.",None))
    # fold into engine nodes: NPC line, then a user turn
    nodes=[];i=0;bc=0
    while i<len(U):
      who,t,fa,src=U[i]; assert who!='USER'
      user=None
      if i+1<len(U) and U[i+1][0]=='USER': user=U[i+1][1:3]; i+=2
      elif i+1<len(U): user=BACK[bc%len(BACK)]; bc+=1; i+=1
      else: i+=1
      nodes.append((who,t,fa,src,user))
    out={}
    for k,(who,t,fa,src,user) in enumerate(nodes):
      nid=f'r{k+1}'; nxt=f'r{k+2}' if k+1<len(nodes) else None
      d={'id':nid,'speaker':who,'text':t.replace('{you}','Mehdi'),'translations':{'fa':fa},'branches':[],'newWords':(src or {}).get('newWords',[])}
      if src and src.get('cultureNote'): d['cultureNote']=src['cultureNote']
      if user and nxt:
        d['branches']=[{'keywords':kw(user[0]),'suggestion':user[0].replace('{you}','Mehdi'),'suggestionFa':user[1],'trustDelta':5,'next':nxt,'success':True}]
      elif user and not nxt:
        # last NPC line followed by user's final line: add closing
        pass
      out[nid]=d
    # guarantee the last node ends (no branches) and no dangling user turn
    last=out[f'r{len(nodes)}']; last['branches']=[]
    v={**{k:s[k] for k in s if k not in('nodes','start')},'id':f'{sid}__as_{L}','baseId':sid,'playAs':L,'start':'r1','nodes':out,'requires':None,
       'title':f"(As {NAMES[L]}) {s['title']}",'titleFa':f"(در نقش {NAMES[L]}) {s['titleFa']}"}
    v.pop('requiresTrust',None)
    json.dump(v,open(os.path.join(A,'scenes',v['id']+'.json'),'w'),ensure_ascii=False,indent=1)
    made.append(v['id'])
json.dump(idx+made,open(os.path.join(A,'scenes_index.json'),'w'),indent=1)
print(len(made),'role variants over',len(idx),'scenes')
