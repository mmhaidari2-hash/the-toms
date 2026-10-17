"""Pre-render every spoken line with British neural voices (edge-tts). Content-addressed:
key = md5('speaker|text')[:16] -> assets/audio/<key>.mp3 (24kHz mono 48kbps). Re-run after editing dialogue."""
import json,glob,hashlib,os,re,asyncio,sys
import edge_tts
A=os.path.join(os.path.dirname(__file__),'..','assets'); OUT=os.path.join(A,'audio'); os.makedirs(OUT,exist_ok=True)
V={ # speaker -> (voice, pitch, rate)
 'tom':('en-GB-RyanNeural','+0Hz','+0%'),'leslie':('en-GB-SoniaNeural','+0Hz','+0%'),
 'nicola':('en-GB-MaisieNeural','+0Hz','+0%'),'ryan':('en-GB-ThomasNeural','+6Hz','+4%'),
 'weda':('en-GB-LibbyNeural','-4Hz','-6%'),'william':('en-GB-MaisieNeural','+10Hz','-3%'),
 'mia':('en-GB-MaisieNeural','+10Hz','+4%'),'me':('en-GB-ThomasNeural','-4Hz','+0%'),'mehdi':('en-GB-ThomasNeural','-4Hz','+0%'),
 'priya':('en-IN-NeerjaNeural','+0Hz','+0%'),'patel':('en-IN-PrabhatNeural','+0Hz','+0%'),
 'callum':('en-IE-ConnorNeural','+0Hz','+6%'),'hughes':('en-GB-LibbyNeural','-8Hz','-4%'),
 'bennett':('en-GB-RyanNeural','-14Hz','-10%'),'okafor':('en-GB-ThomasNeural','-12Hz','-4%'),
 'doris':('en-GB-LibbyNeural','-16Hz','-14%'),'sian':('en-IE-EmilyNeural','+0Hz','+0%'),
 'clarke':('en-GB-SoniaNeural','-8Hz','-4%'),'al':('en-GB-RyanNeural','-6Hz','+4%'),
 'dave':('en-IE-ConnorNeural','-12Hz','+0%'),'maya':('en-GB-SoniaNeural','+6Hz','+4%'),
 'sophie':('en-IE-EmilyNeural','+8Hz','+6%'),'arthur':('en-GB-RyanNeural','-18Hz','-14%'),
 'dawson':('en-GB-ThomasNeural','-14Hz','-6%'),'sal':('en-IE-ConnorNeural','-8Hz','+4%'),
 'jade':('en-GB-LibbyNeural','+10Hz','+8%'),'baker':('en-IE-ConnorNeural','-16Hz','-4%'),
 'butcher':('en-GB-RyanNeural','-20Hz','+0%'),'plumber':('en-GB-ThomasNeural','-18Hz','+2%'),
 'ellis':('en-GB-LibbyNeural','-12Hz','-10%'),'coach':('en-GB-RyanNeural','-10Hz','+6%'),
 'george':('en-GB-ThomasNeural','-16Hz','-14%'),
 'courier':('en-GB-ThomasNeural','-6Hz','+10%'),
 'engineer':('en-GB-RyanNeural','-14Hz','+2%'),
 'khan':('en-IN-NeerjaNeural','-10Hz','-4%'),
 'receptionist':('en-GB-SoniaNeural','-6Hz','+4%'),
 'vet':('en-GB-LibbyNeural','-2Hz','+0%'),
 'triage':('en-GB-LibbyNeural','-8Hz','+6%'),
 'schooloffice':('en-GB-SoniaNeural','-10Hz','-2%'),
 'police':('en-GB-RyanNeural','-4Hz','+0%'),
 'energy':('en-GB-ThomasNeural','+2Hz','+6%'),
 'agent':('en-GB-SoniaNeural','+4Hz','+8%'),
 'mechanic':('en-GB-RyanNeural','-20Hz','-4%'),
 'workcoach':('en-GB-ThomasNeural','-10Hz','-2%'),
 'council':('en-GB-LibbyNeural','-10Hz','+0%'),
 'narrator':('en-GB-SoniaNeural','+0Hz','-8%'),
}
def key(sp,t): return hashlib.md5(f'{sp}|{t}'.encode()).hexdigest()[:16]
def clean(t):
  t=t.replace('{you}','Mehdi'); t=re.sub(r'\*[^*]*\*','',t)
  t=re.sub(r'[\U0001F000-\U0001FFFF\u2600-\u27BF]','',t); return t.strip()
items={}
def add(sp,t):
  if not t or not isinstance(t,str): return
  c=clean(t)
  if len(re.sub(r'\W','',c))<2: return
  items[key(sp,t)]=(sp,c)
for f in glob.glob(os.path.join(A,'data/scenes/*.json')):
  d=json.load(open(f))
  for n in d['nodes'].values():
    sp=n['speaker']; add(sp,n['text']); add(sp,n.get('coolReply'))
    if n.get('xray'): add(sp,n['xray'].get('connected'))
    for r in n.get('recasts') or []: add(sp,r.get('echo'))
    for b in n.get('branches',[]): add('me',b.get('suggestion'))
def walk(o):
  if isinstance(o,dict):
    if o.get('characterId') and isinstance(o.get('ambient'),dict): add(o['characterId'],o['ambient'].get('en'))
    pr=o.get('prop')
    if isinstance(pr,dict):
      add('narrator',pr.get('phrase'))
      for m in pr.get('mini',[]): add(m[0],m[1])
    for v in o.values(): walk(v)
  elif isinstance(o,list):
    for v in o: walk(v)
walk(json.load(open(os.path.join(A,'data/places.json'))))
dump=os.path.join(os.path.dirname(__file__),'..','build','voice_lines.json')  # from test/audit_test.dart (incl. computed X-Ray, ghost hints, words)
if os.path.exists(dump):
  for sp,t in json.load(open(dump)): add(sp,t)
todo=[(k,v) for k,v in items.items() if not os.path.exists(f'{OUT}/{k}.mp3')]
print(len(items),'lines,',len(todo),'to render')
async def one(k,sp,t,sem):
  v,p,r=V.get(sp,V['narrator'])
  async with sem:
    for i in range(4):
      try:
        await asyncio.wait_for(edge_tts.Communicate(t,v,pitch=p,rate=r).save(f'{OUT}/{k}.tmp'),40); os.replace(f'{OUT}/{k}.tmp',f'{OUT}/{k}.mp3'); return
      except Exception as e: await asyncio.sleep(2+i*3)
    print('FAIL',k,sp,t)
async def main():
  sem=asyncio.Semaphore(8); await asyncio.gather(*[one(k,sp,t,sem) for k,(sp,t) in todo])
asyncio.run(main())
# 24 kbps speech MP3 (see compress_audio.py) so the full course fits GitHub Pages
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))); import compress_audio
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(8) as ex: print(sum(ex.map(compress_audio.one,[f'{k}.mp3' for k,_ in todo if os.path.exists(f'{OUT}/{k}.mp3')])),'new clips compressed')
for f in os.listdir(OUT):
  if f.endswith('.mp3') and f!='silence.mp3' and f[:-4] not in items: os.remove(f'{OUT}/{f}')
json.dump(sorted(k for k in items if os.path.exists(f'{OUT}/{k}.mp3')),open(f'{OUT}/index.json','w'))
