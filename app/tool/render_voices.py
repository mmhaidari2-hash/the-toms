"""Pre-render every spoken line with British neural voices (Azure Speech, uksouth; edge-tts before run 23). Content-addressed:
key = md5('speaker|text')[:16] -> assets/audio/<key>.mp3 (24kHz mono 48kbps). Re-run after editing dialogue.
Use --dry-run for a read-only inventory with no API calls.
Obsolete clips are retained unless RENDER_PRUNE_OBSOLETE=1 is explicitly set."""
import json,glob,hashlib,os,re,asyncio,sys
A=os.path.join(os.path.dirname(__file__),'..','assets'); OUT=os.path.join(A,'audio'); os.makedirs(OUT,exist_ok=True)
V={ # speaker -> (voice, pitch, rate[, style]). 2026-11 A/B: nicola B, william B, tom B, learner/me C. Run 28 recast: distinct voice per scene (tool/audit/verify_voices.py), |pitch|<=8Hz except the young children
 'tom':('en-GB-OllieMultilingualNeural','+0Hz','+0%'),
 'leslie':('en-GB-AdaMultilingualNeural','+0Hz','-4%'),
 'nicola':('en-GB-AbbiNeural','+0Hz','-2%'),
 'ryan':('en-GB-ElliotNeural','+0Hz','-2%'),
 'weda':('en-GB-MiaNeural','+0Hz','-8%'),
 'william':('en-GB-MaisieNeural','+0Hz','+0%'),
 'george':('en-GB-ThomasNeural','-4Hz','-8%'),
 'vida':('en-GB-HollieNeural','+0Hz','-8%'),
 'me':('en-GB-RyanNeural','+0Hz','-2%','chat'),
 'learner':('en-GB-RyanNeural','+0Hz','-2%','chat'),
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
  t=re.sub(r'\s+[—–]\s+',', ',t)  # A/B run 2026-11: a spaced dash made the voices pause unnaturally
  t=re.sub(r'[\U0001F000-\U0001FFFF\u2600-\u27BF]','',t); return t.strip()
items={}
NAMED=set()
def add(sp,t):
  if not t or not isinstance(t,str): return
  c=clean(t)
  if len(re.sub(r'\W','',c))<2: return
  items[key(sp,t)]=(sp,c)
  if '{you}' in t: NAMED.add(key(sp,t))
  return key(sp,t)
# Learner path: scene id -> its position in the main course (A1 unit 1 lesson 1 = 0), used to order the render queue.
PATH={}
POS=[]  # course position -> (level, lesson id), for --coverage
_course=os.path.join(A,'data','course.json')
if os.path.exists(_course):
  for _u in sorted(json.load(open(_course))['units'],key=lambda u:u['level']):  # stable: keeps unit order inside a level
    for _l in _u['lessons']:
      for _s in _l.get('sceneIds',[]):
        if _s not in PATH: PATH[_s]=len(PATH); POS.append((_u['level'],_l.get('id',_s)))
RANK={}  # clip key -> earliest course position of a scene that speaks it
_add=add
for f in sorted(glob.glob(os.path.join(A,'data/scenes/*.json'))):
  d=json.load(open(f))
  _r=PATH.get(d.get('id'))
  def add(sp,t,_r=_r):
    k=_add(sp,t)
    if k and _r is not None: RANK[k]=min(RANK.get(k,_r),_r)
    return k
  for n in d['nodes'].values():
    sp=n['speaker']; add(sp,n['text']); add(sp,n.get('coolReply'))
    if n.get('xray'): add(sp,n['xray'].get('connected'))
    for r in n.get('recasts') or []: add(sp,r.get('echo'))
    for b in n.get('branches',[]): add(d.get('guest','me'),b.get('suggestion'))
add=_add
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
# Grammar School (tool/make_grammar.py), Persian speakers' mistakes and IELTS Life Skills prep (tool/content/):
# Mrs Ellis reads explanations + examples
for gram in [os.path.join(A,'data',f) for f in ('grammar.json','mistakes.json','lifeskills.json')]:
  if not os.path.exists(gram): continue
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
arrival=os.path.join(A,'data','arrival_pack.json')
if os.path.exists(arrival):
  for phrase in json.load(open(arrival)).get('phrases',[]):
    add(phrase.get('sp','narrator'),phrase['en'])
if os.path.exists(dump):
  for sp,t in json.load(open(dump)): add(sp,t)
# One line = one clip in its speaker's own voice. No silent narrator fallback for a speaker without a voice,
# and a clip whose recorded voice (tool/audit/voice_manifest.json) differs from the speaker's current one is re-rendered.
nov=sorted({sp for sp,_ in items.values() if sp not in V})
if nov: sys.exit(f'NO VOICE for speakers {nov}: add them to V')
# The exact text of every clip, for the audio QA (speech-to-text comparison and re-renders): tool/qa/qa_audio.py
if '--dry-run' not in sys.argv and '--coverage' not in sys.argv:
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
FRESH=float(os.environ.get('RENDER_FRESH_SINCE','0') or 0)  # resume: a clip written after this epoch time is already re-rendered
def _fresh(k): return os.path.exists(f'{OUT}/{k}.mp3') and os.path.getmtime(f'{OUT}/{k}.mp3')>=FRESH
if FRESH:
  for k,v in todo:
    if _fresh(k): ENG.add(k); MAN[k]=[v[0],sig(v[0])]
  todo=[(k,v) for k,v in todo if not _fresh(k)]
# The free tier only covers ~0.5M characters a month, so the newest packs go first: Persian speakers' mistakes,
# IELTS Life Skills, then Life in the UK (stable sort keeps the old order inside each group).
PRIO={}
for n,f in enumerate(('mistakes.json','lifeskills.json')):
  fp=os.path.join(A,'data',f)
  if os.path.exists(fp):
    for t in json.load(open(fp))['topics']:
      for x in t['teach']+t['examples']: PRIO.setdefault(x['en'],n)
todo.sort(key=lambda kv: (PRIO.get(kv[1][1],9), 0 if kv[1][0]=='ellis' else 1) if kv[1][1] in PRIO else (9,1))
# Then the main course in the order a learner meets it (A1 unit 1 lesson 1 first), so the first lessons are never silent.
# Default: inside the "everything else" group only. RENDER_ORDER=path puts the course path ahead of the packs above.
_N=len(PATH)+1
if os.environ.get('RENDER_ORDER')=='path':
  todo.sort(key=lambda kv: RANK.get(kv[0],_N))
else:
  todo.sort(key=lambda kv: (1, RANK.get(kv[0],_N)) if kv[1][1] not in PRIO else (0,0))
LIMIT=int(os.environ.get('RENDER_LIMIT','0') or 0)
if LIMIT: todo=todo[:LIMIT]
print(len(items),'lines,',len(todo),'to render,',sum(len(t) for _,(_,t) in todo),'characters')
if '--coverage' in sys.argv:
  # Read-only report: how much of each course level a learner will hear. A line counts as voiced when its
  # clip file exists (a clip queued only for a voice refresh still plays, so it counts).
  per={}; gap=None
  for k,r in sorted(RANK.items(),key=lambda kv:kv[1]):
    lv=POS[r][0]; ok=os.path.exists(f'{OUT}/{k}.mp3')
    d=per.setdefault(lv,[0,0]); d[0]+=ok; d[1]+=1
    if not ok and gap is None: gap=POS[r][1]
  print('Course audio coverage (lesson scene lines with a clip):')
  for lv in sorted(per):
    a,b=per[lv]; print(f'  Level {lv}: {a}/{b} = {100*a/max(1,b):.1f}%')
  print('  first lesson with a silent line:',gap or 'none')
  sys.exit(0)
if '--dry-run' in sys.argv:
  print('queue head:',[(k,RANK.get(k)) for k,_ in todo[:5]])
  missing=[{'key':k,'speaker':sp,'text':t} for k,(sp,t) in sorted(items.items()) if not os.path.exists(f'{OUT}/{k}.mp3')]
  print(json.dumps({'missing':missing,'obsoleteRetained':sum(1 for f in os.listdir(OUT) if re.fullmatch(r'[0-9a-f]{16}\.mp3',f) and f[:-4] not in items)},ensure_ascii=False))
  sys.exit(0)
import threading,time
from concurrent.futures import ThreadPoolExecutor
from az_tts import synth, BILLED, CODES
import compress_audio, tighten_audio
lock=threading.Lock(); done=[0]; fails=[]; skipped=[0]; t0=time.time()
# Monthly character cap (RENDER_CHAR_CAP, e.g. 480000 = inside Azure's free 0.5M neural characters a month on an F0 key).
# The ledger tool/audit/tts_month.json keeps what this tool billed per calendar month across runs; at the cap it stops.
LEDP=os.path.join(os.path.dirname(MANP),'tts_month.json'); MONTH=time.strftime('%Y-%m')
LED=json.load(open(LEDP)) if os.path.exists(LEDP) else {}
CAP=int(os.environ.get('RENDER_CHAR_CAP','0') or 0); BASE=LED.get(MONTH,0)
if CAP:
  left=CAP-BASE; print(f'cap {CAP} for {MONTH}: {BASE} already billed, {max(0,left)} left',flush=True)
  if left<=0: print('monthly cap reached; nothing rendered'); sys.exit(0)
def save_ledger():
  LED[MONTH]=BASE+BILLED[0]; json.dump(LED,open(LEDP+'.tmp','w'),indent=1); os.replace(LEDP+'.tmp',LEDP)
def save_state():
  json.dump(sorted(ENG),open(ENGP+'.tmp','w')); os.replace(ENGP+'.tmp',ENGP)
  json.dump(MAN,open(MANP+'.tmp','w'),separators=(',',':')); os.replace(MANP+'.tmp',MANP)
def one(kv):
  k,(sp,t)=kv
  if CAP and BASE+BILLED[0]+len(t)+400>CAP:  # 400 = SSML markup that Azure also bills
    with lock: done[0]+=1; skipped[0]+=1
    return
  v,p,r=V[sp][:3]; st=V[sp][3] if len(V[sp])>3 else None
  try: ok=synth(t,v,f'{OUT}/{k}.az.mp3',pitch=p,rate=r,style=st)
  except Exception as e: ok=False; print('ERR',k,sp,e,flush=True)
  if ok:
    os.replace(f'{OUT}/{k}.az.mp3',f'{OUT}/{k}.mp3'); compress_audio.one(f'{k}.mp3'); tighten_audio.one(k)  # short sentence pauses, trimmed lead-in/tail
  with lock:
    if ok: ENG.add(k); MAN[k]=[sp,sig(sp)]
    else: fails.append(k)
    done[0]+=1
    if done[0]%250==0:
      save_state(); save_ledger(); el=time.time()-t0; print(f'{done[0]}/{len(todo)} {done[0]/el:.1f}/s fails={len(fails)} billed={BILLED[0]} codes={CODES} eta {int((len(todo)-done[0])/(done[0]/el)/60)}m',flush=True)
with ThreadPoolExecutor(int(os.environ.get('RENDER_THREADS','8'))) as ex: list(ex.map(one,todo))
save_state(); save_ledger(); print('rendered',done[0]-len(fails)-skipped[0],'skipped (cap)',skipped[0],'fails',len(fails),'billed characters',BILLED[0])
if fails: print('FAILED',fails[:20])
if os.environ.get('RENDER_PRUNE_OBSOLETE') == '1':
  for f in os.listdir(OUT):
    if re.fullmatch(r'[0-9a-f]{16}\.mp3',f) and f[:-4] not in items: os.remove(f'{OUT}/{f}')
json.dump(sorted(f[:-4] for f in os.listdir(OUT) if re.fullmatch(r'[0-9a-f]{16}\.mp3',f)),open(f'{OUT}/index.json','w'))
os.makedirs(os.path.dirname(MANP),exist_ok=True)
json.dump({k:MAN[k] for k in sorted(MAN) if os.path.exists(f'{OUT}/{k}.mp3')},open(MANP,'w'),separators=(',',':'))  # the voice that really rendered each clip
open(YOUF,'w').write('clips with the learner name re-rendered neutrally\n')
