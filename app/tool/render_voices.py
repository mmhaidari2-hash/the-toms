"""Pre-render every spoken line with British neural voices (Azure Speech, uksouth; edge-tts before run 23). Content-addressed:
key = md5('speaker|text')[:16] -> assets/audio/<key>.mp3 (24kHz mono 48kbps). Re-run after editing dialogue."""
import json,glob,hashlib,os,re,asyncio,sys
import edge_tts
A=os.path.join(os.path.dirname(__file__),'..','assets'); OUT=os.path.join(A,'audio'); os.makedirs(OUT,exist_ok=True)
V={ # speaker -> (voice, pitch, rate). Run 28 recast: distinct voice per scene (tool/audit/verify_voices.py), |pitch|<=8Hz except the young children
 'tom':('en-GB-OllieMultilingualNeural','+0Hz','-4%'),
 'leslie':('en-GB-AdaMultilingualNeural','+0Hz','-4%'),
 'nicola':('en-GB-AbbiNeural','+25Hz','+2%'),
 'ryan':('en-GB-ElliotNeural','+0Hz','-2%'),
 'weda':('en-GB-MiaNeural','+0Hz','-8%'),
 'william':('en-GB-MaisieNeural','+0Hz','-3%'),
 'george':('en-GB-ThomasNeural','-4Hz','-8%'),
 'vida':('en-GB-HollieNeural','+0Hz','-8%'),
 'me':('en-GB-RyanNeural','+0Hz','-4%'),
 'learner':('en-GB-RyanNeural','+0Hz','-4%'),
 'narrator':('en-GB-SoniaNeural','+0Hz','-7%'),
 'agent':('en-GB-LibbyNeural','+0Hz','+0%'),
 'al':('en-GB-AlfieNeural','+0Hz','-4%'),
 'arthur':('en-GB-NoahNeural','-4Hz','-8%'),
 'baker':('en-GB-OliverNeural','+0Hz','-5%'),
 'bennett':('en-GB-OliverNeural','+0Hz','-6%'),
 'bex':('en-GB-SoniaNeural','+0Hz','-2%'),
 'bilal':('en-IN-ArjunNeural','+0Hz','-5%'),
 'butcher':('en-IE-ConnorNeural','+0Hz','-4%'),
 'callum':('en-GB-EthanNeural','+0Hz','+0%'),
 'clarke':('en-ZA-LeahNeural','+0Hz','-4%'),
 'coach':('en-ZA-LukeNeural','+0Hz','-5%'),
 'council':('en-GB-OliviaNeural','+0Hz','-4%'),
 'courier':('en-GB-EthanNeural','+0Hz','-2%'),
 'dan':('en-AU-WilliamMultilingualNeural','+0Hz','-3%'),
 'dave':('en-IE-ConnorNeural','+0Hz','-5%'),
 'dawson':('en-GB-AlfieNeural','+0Hz','-4%'),
 'dev':('en-GB-EthanNeural','+0Hz','+0%'),
 'doris':('en-GB-LibbyNeural','+0Hz','-8%'),
 'ellis':('en-GB-OliviaNeural','+0Hz','-6%'),
 'energy':('en-GB-AlfieNeural','+0Hz','+0%'),
 'engineer':('en-GB-AlfieNeural','+0Hz','-4%'),
 'examiner':('en-GB-OliverNeural','+0Hz','-5%'),
 'grace':('en-NG-EzinneNeural','+0Hz','-4%'),
 'graham':('en-GB-OliverNeural','+0Hz','-5%'),
 'harris':('en-GB-OliverNeural','+0Hz','-5%'),
 'hughes':('en-GB-OliviaNeural','+0Hz','-5%'),
 'instructor':('en-GB-LibbyNeural','+0Hz','-4%'),
 'jade':('en-GB-OliviaNeural','+0Hz','+0%'),
 'jo':('en-IE-EmilyNeural','+0Hz','-4%'),
 'kai':('en-GB-AlfieNeural','+0Hz','+0%'),
 'khan':('en-IN-AartiNeural','+0Hz','-6%'),
 'malcolm':('en-GB-NoahNeural','+0Hz','-5%'),
 'maya':('en-GB-BellaNeural','+0Hz','-2%'),
 'mechanic':('en-GB-NoahNeural','+0Hz','-5%'),
 'mia':('en-GB-LibbyNeural','+20Hz','-2%'),
 'mrspatel':('en-IN-KavyaNeural','+0Hz','-8%'),
 'okafor':('en-NG-AbeoNeural','+0Hz','-4%'),
 'oldman':('en-GB-NoahNeural','-4Hz','-8%'),
 'oscar':('en-GB-OliviaNeural','+20Hz','-3%'),
 'owen':('en-GB-EthanNeural','+0Hz','-2%'),
 'patel':('en-IN-PrabhatNeural','+0Hz','-2%'),
 'plumber':('en-GB-NoahNeural','+0Hz','-4%'),
 'police':('en-GB-EthanNeural','+0Hz','-2%'),
 'priya':('en-IN-NeerjaNeural','+0Hz','+0%'),
 'receptionist':('en-GB-SoniaNeural','+0Hz','-5%'),
 'sal':('en-GB-NoahNeural','+0Hz','-5%'),
 'sara':('en-GB-BellaNeural','+0Hz','+0%'),
 'schooloffice':('en-GB-SoniaNeural','+0Hz','-5%'),
 'sian':('en-IE-EmilyNeural','+0Hz','-2%'),
 'sophie':('en-GB-BellaNeural','+0Hz','+0%'),
 'triage':('en-NG-EzinneNeural','+0Hz','-4%'),
 'tutor':('en-GB-OliverNeural','+0Hz','-5%'),
 'vet':('en-GB-LibbyNeural','+0Hz','-4%'),
 'workcoach':('en-NG-AbeoNeural','+0Hz','-4%'),
 'zara':('en-KE-AsiliaNeural','+0Hz','-2%'),
}
def key(sp,t): return hashlib.md5(f'{sp}|{t}'.encode()).hexdigest()[:16]
# TTS-only respellings for Persian words the British voices mangle (audit 2026-10)
PRON={r'\bsetar\b':'seh-taar',r'\bSimorgh\b':'See-morgh'}
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))); from you_neutral import neutral
def clean(t):
  t=neutral(t)  # never say a name: the learner's name is theirs (shown in text only)
  for a,b in PRON.items(): t=re.sub(a,b,t)
  t=re.sub(r'\*[^*]*\*','',t)
  t=re.sub(r'[\U0001F000-\U0001FFFF\u2600-\u27BF]','',t); return t.strip()
items={}
NAMED=set()
def add(sp,t):
  if not t or not isinstance(t,str): return
  c=clean(t)
  if len(re.sub(r'\W','',c))<2: return
  items[key(sp,t)]=(sp,c)
  if '{you}' in t: NAMED.add(key(sp,t))
for f in glob.glob(os.path.join(A,'data/scenes/*.json')):
  d=json.load(open(f))
  for n in d['nodes'].values():
    sp=n['speaker']; add(sp,n['text']); add(sp,n.get('coolReply'))
    if n.get('xray'): add(sp,n['xray'].get('connected'))
    for r in n.get('recasts') or []: add(sp,r.get('echo'))
    for b in n.get('branches',[]): add(d.get('guest','me'),b.get('suggestion'))
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
gram=os.path.join(A,'data/grammar.json')  # Grammar School (tool/make_grammar.py): Mrs Ellis reads explanations + examples
if os.path.exists(gram):
  for t in json.load(open(gram))['topics']:
    for x in t['teach']+t['examples']: add('ellis',x['en'])
lib=os.path.join(A,'data/library.json')  # graded readers (tool/make_library.py): narrator reads every sentence
if os.path.exists(lib):
  for b in json.load(open(lib))['books']:
    for c in b['chapters']:
      for st in c['sentences']: add(st.get('sp','narrator'),st['en'])  # B1+: dialogue in the character's voice
cine=os.path.join(A,'data/cinema.json')  # Cinema & dubbing (tool/make_cinema.py): every line in its character's voice
if os.path.exists(cine):
  for sc in json.load(open(cine))['scenes']:
    for l in sc['lines']: add(l['sp'],l['en'])
radio=os.path.join(A,'data/radio.json')  # Hackney Hum (tool/make_radio.py): every segment line in its speaker's voice
if os.path.exists(radio):
  for sg in json.load(open(radio))['segments']:
    for l in sg['lines']: add(l['sp'],l['en'])
mis=os.path.join(A,'data/missions.json')  # Real-life missions (tool/make_missions.py): phrases (voice 'me') + what you might hear
if os.path.exists(mis):
  for x in json.load(open(mis))['missions']:
    for l in x['say']+x['hear']: add(l['sp'],l['en'])
msg=os.path.join(A,'data/messages.json')  # Family voice messages (tool/make_messages.py): voice notes in the sender's voice
if os.path.exists(msg):
  for t in json.load(open(msg))['threads']:
    for m in t['msgs']:
      if m['kind']=='voice': add(m['sp'],m['en'])
luk=os.path.join(A,'data/lifeuk.json')  # Life in the UK prep (tool/make_lifeuk.py): chapter explanations in the tutor's voice
if os.path.exists(luk):
  for c in json.load(open(luk))['chapters']:
    for e in c['expl']: add('tutor',e['en'])
sea=os.path.join(A,'data/seasons.json')  # Seasonal events (tool/make_seasons.py): scene lines in each speaker's voice + vocab
if os.path.exists(sea):
  for e in json.load(open(sea))['events']:
    for l in e['lines']: add(l['sp'],l['en'])
    for w in e['words']: add('narrator',w['w'])
thy=os.path.join(A,'data/theory.json')  # Driving theory prep (tool/make_theory.py): explanations in the instructor's voice
if os.path.exists(thy):
  for c in json.load(open(thy))['chapters']:
    for e in c['expl']: add('instructor',e['en'])
rp=os.path.join(A,'data/roleplays.json')  # Role-play missions (tool/make_roleplays.py): NPC lines + every reply option (voice 'me')
if os.path.exists(rp):
  for r in json.load(open(rp))['roleplays']:
    add(r['sp'],r['end']['en'])
    for t in r['turns']:
      add(r['sp'],t['npc']['en'])
      for o in t['opts']: add('me',o['en'])
drv=os.path.join(A,'data/driving.json')  # Driving School dialogues (tool/make_driving.py): lines in each speaker's voice + vocab
if os.path.exists(drv):
  for e in json.load(open(drv))['lessons']:
    for l in e['lines']: add(l['sp'],l['en'])
    for w in e['words']: add('narrator',w['w'])
dump=os.path.join(os.path.dirname(__file__),'..','build','voice_lines.json')  # from test/audit_test.dart (incl. computed X-Ray, ghost hints, words)
if os.path.exists(dump):
  for sp,t in json.load(open(dump)): add(sp,t)
# One line = one clip in its speaker's own voice. No silent narrator fallback for a speaker without a voice,
# and a clip whose recorded voice (tool/audit/voice_manifest.json) differs from the speaker's current one is re-rendered.
nov=sorted({sp for sp,_ in items.values() if sp not in V})
if nov: sys.exit(f'NO VOICE for speakers {nov}: add them to V')
# The exact text of every clip, for the audio QA (speech-to-text comparison and re-renders): tool/qa/qa_audio.py
json.dump({k:v[1] for k,v in sorted(items.items())},open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'audit','voice_texts.json'),'w'),ensure_ascii=False,separators=(',',':'))
if os.environ.get('RENDER_LIST_ONLY'): sys.exit(0)
def sig(sp): return '|'.join(V[sp])
MANP=os.path.join(os.path.dirname(os.path.abspath(__file__)),'audit','voice_manifest.json')
MAN=json.load(open(MANP)) if os.path.exists(MANP) else {}
# One-off: clips recorded when '{you}' was spoken as the old fixed name are re-rendered with the neutral wording.
YOUF=os.path.join(os.path.dirname(os.path.abspath(__file__)),'audit','you_neutral_v1.done')
REDO=set() if os.path.exists(YOUF) else NAMED
# Run 23: rendered by Azure Speech (tool/az_tts.py, key in env AZURE_SPEECH_KEY_1, never printed).
# tool/audit/voice_engine.json lists clips already rendered by Azure, so the switch is resumable: a clip
# not yet in it is re-rendered even when its speaker's voice line is unchanged. Throttled to 8 requests at a time.
ENGP=os.path.join(os.path.dirname(MANP),'voice_engine.json')
ENG=set(json.load(open(ENGP))) if os.path.exists(ENGP) else set()
todo=[(k,v) for k,v in items.items() if k in REDO or k not in ENG or not os.path.exists(f'{OUT}/{k}.mp3') or (k in MAN and MAN[k]!=[v[0],sig(v[0])])]
OLDER=float(os.environ.get('RENDER_OLDER_THAN','0') or 0)  # re-render every clip whose file is older than this epoch time
if OLDER: todo=[(k,v) for k,v in items.items() if not os.path.exists(f'{OUT}/{k}.mp3') or os.path.getmtime(f'{OUT}/{k}.mp3')<OLDER]
LIMIT=int(os.environ.get('RENDER_LIMIT','0') or 0)
if LIMIT: todo=todo[:LIMIT]
print(len(items),'lines,',len(todo),'to render,',sum(len(t) for _,(_,t) in todo),'characters')
import threading,time
from concurrent.futures import ThreadPoolExecutor
from az_tts import synth, BILLED
import compress_audio, tighten_audio
lock=threading.Lock(); done=[0]; fails=[]; t0=time.time()
def save_state():
  json.dump(sorted(ENG),open(ENGP+'.tmp','w')); os.replace(ENGP+'.tmp',ENGP)
  json.dump(MAN,open(MANP+'.tmp','w'),separators=(',',':')); os.replace(MANP+'.tmp',MANP)
def one(kv):
  k,(sp,t)=kv; v,p,r=V[sp]
  try: ok=synth(t,v,f'{OUT}/{k}.az.mp3',pitch=p,rate=r)
  except Exception as e: ok=False; print('ERR',k,sp,e,flush=True)
  if ok:
    os.replace(f'{OUT}/{k}.az.mp3',f'{OUT}/{k}.mp3'); compress_audio.one(f'{k}.mp3'); tighten_audio.one(k)  # short sentence pauses, trimmed lead-in/tail
  with lock:
    if ok: ENG.add(k); MAN[k]=[sp,sig(sp)]
    else: fails.append(k)
    done[0]+=1
    if done[0]%250==0:
      save_state(); el=time.time()-t0; print(f'{done[0]}/{len(todo)} {done[0]/el:.1f}/s fails={len(fails)} billed={BILLED[0]} eta {int((len(todo)-done[0])/(done[0]/el)/60)}m',flush=True)
with ThreadPoolExecutor(int(os.environ.get('RENDER_THREADS','8'))) as ex: list(ex.map(one,todo))
save_state(); print('rendered',done[0]-len(fails),'fails',len(fails),'billed characters',BILLED[0])
if fails: print('FAILED',fails[:20])
for f in os.listdir(OUT):
  if f.endswith('.mp3') and f!='silence.mp3' and f[:-4] not in items: os.remove(f'{OUT}/{f}')
json.dump(sorted(k for k in items if os.path.exists(f'{OUT}/{k}.mp3')),open(f'{OUT}/index.json','w'))
os.makedirs(os.path.dirname(MANP),exist_ok=True)
json.dump({k:MAN[k] for k in sorted(items) if k in MAN and os.path.exists(f'{OUT}/{k}.mp3')},open(MANP,'w'),separators=(',',':'))  # the voice that really rendered each clip
open(YOUF,'w').write('clips with the learner name re-rendered neutrally\n')
