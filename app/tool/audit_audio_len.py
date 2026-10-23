"""Fast whole-corpus audio sanity check: every clip's duration (48 kbps CBR, so bytes -> seconds) must fit its
line length. Flags silent/truncated clips (too short) and runaway/looping clips (too long). Exit 1 on any flag."""
import json,os,re,glob,hashlib,sys
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets'); OUT=os.path.join(A,'audio')
def key(sp,t): return hashlib.md5(f'{sp}|{t}'.encode()).hexdigest()[:16]
def clean(t):
  t=t; t=re.sub(r'\*[^*]*\*','',t); return re.sub(r'[\U0001F000-\U0001FFFF\u2600-\u27BF]','',t).strip()
items={}
for f in glob.glob(os.path.join(A,'data/scenes/*.json')):
  d=json.load(open(f)); sid=os.path.basename(f)[:-5]
  for n in d['nodes'].values():
    items[key(n['speaker'],n['text'])]=(n['speaker'],n['text'],sid)
    for b in n.get('branches',[]): sp=d.get('guest','me'); items[key(sp,b['suggestion'])]=(sp,b['suggestion'],sid)
bad=[]
for k,(sp,t,sid) in items.items():
  p=f'{OUT}/{k}.mp3'
  if not os.path.exists(p): continue
  sec=os.path.getsize(p)*8/48000; w=len(re.findall(r"[A-Za-z0-9']+",clean(t)))
  if w==0: continue
  lo=0.1*w+0.2; hi=0.75*w+2.5
  if sec<lo or sec>hi: bad.append((round(sec,2),w,sp,sid,clean(t)[:100],k))
for b in sorted(bad,key=lambda b:b[0]/b[1]): print(*b,sep=' | ')
print(len(items),'clips checked,',len(bad),'flagged')
sys.exit(1 if bad else 0)
