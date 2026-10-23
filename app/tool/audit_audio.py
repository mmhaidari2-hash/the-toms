"""Text<->audio spot-check: transcribe a sample of rendered clips with faster-whisper and flag clips whose
word error rate vs the authored line is above a threshold. Usage: python3 tool/audit_audio.py [N_random] [out.json]"""
import json,os,re,sys,random,hashlib,glob
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets'); OUT=os.path.join(A,'audio')
def key(sp,t): return hashlib.md5(f'{sp}|{t}'.encode()).hexdigest()[:16]
def clean(t):
  t=t; t=re.sub(r'\*[^*]*\*','',t)
  return re.sub(r'[\U0001F000-\U0001FFFF\u2600-\u27BF]','',t).strip()
items={}
for f in glob.glob(os.path.join(A,'data/scenes/*.json')):
  d=json.load(open(f))
  for n in d['nodes'].values():
    items[key(n['speaker'],n['text'])]=(n['speaker'],n['text'],os.path.basename(f)[:-5])
    for b in n.get('branches',[]):
      sp=d.get('guest','me'); items[key(sp,b['suggestion'])]=(sp,b['suggestion'],os.path.basename(f)[:-5])
items={k:v for k,v in items.items() if os.path.exists(f'{OUT}/{k}.mp3') and len(clean(v[1]).split())>=3}
NAMES=r"Hackney|Thompson|Navarino|Mare Street|Leyton|Orient|Brisbane|Okoro|my team back home|their rivals|Tehran|Okafor|Dawson|Vida|Sara|Doris|Maggie|Callum|Priya|Sian|Gareth|Brighton|Barnaby|Palace cinema|Glenmore|Alastair|Parvin|setar|Chats Palace|Kettle"
named=[k for k,v in items.items() if re.search(NAMES,v[1])]
rnd=random.Random(7); N=int(sys.argv[1]) if len(sys.argv)>1 else 300
pick=sorted(set(rnd.sample(named,min(len(named),N//2))+rnd.sample(list(items),N)))
if len(sys.argv)>3: pick=[k for k in json.load(open(sys.argv[3])) if k in items]  # re-check a list of keys
NUM={'0':'zero','1':'one','2':'two','3':'three','4':'four','5':'five','6':'six','7':'seven','8':'eight','9':'nine','10':'ten','12':'twelve','15':'fifteen','20':'twenty','30':'thirty','38':'thirty eight','50':'fifty','80':'eighty','100':'hundred','999':'nine nine nine','111':'one one one'}
def norm(t):
  t=t.lower().replace('£',' ').replace('%',' percent').replace('&',' and ').replace('-',' ')
  t=re.sub(r"[^a-z0-9' ]"," ",t); w=[]
  for x in t.split():
    x=x.strip("'"); w+= NUM.get(x,x).split()
  return [x for x in w if x not in ('uh','um','oh','ooh','ah')]
def wer(r,h):
  d=list(range(len(h)+1))
  for i in range(1,len(r)+1):
    p=d[:]; d[0]=i
    for j in range(1,len(h)+1): d[j]=min(p[j]+1,d[j-1]+1,p[j-1]+(r[i-1]!=h[j-1]))
  return d[len(h)]/max(1,len(r))
import subprocess, numpy as np
from faster_whisper import WhisperModel
m=WhisperModel('small.en',device='cpu',compute_type='int8',cpu_threads=8)
res=[]
for i,k in enumerate(pick):
  sp,t,sid=items[k]
  pcm=subprocess.run(['ffmpeg','-v','quiet','-i',f'{OUT}/{k}.mp3','-f','s16le','-ac','1','-ar','16000','-'],capture_output=True).stdout
  a=np.frombuffer(pcm,np.int16).astype(np.float32)/32768; pad=np.zeros(8000,np.float32)
  segs,_=m.transcribe(np.concatenate([pad,a,pad]),beam_size=5,language='en',condition_on_previous_text=False)
  hyp=' '.join(s.text for s in segs).strip()
  e=wer(norm(clean(t)),norm(hyp)); res.append({'key':k,'speaker':sp,'scene':sid,'text':clean(t),'heard':hyp,'wer':round(e,3)})
  if i%25==0: print(i,len(pick),flush=True)
out=sys.argv[2] if len(sys.argv)>2 else '/workspace/british-life/audit/audio_wer.json'
json.dump(res,open(out,'w'),ensure_ascii=False,indent=1)
bad=[r for r in res if r['wer']>0.35]
print(len(res),'clips checked; mean WER',round(sum(r['wer'] for r in res)/len(res),3),'; flagged >0.35:',len(bad))
