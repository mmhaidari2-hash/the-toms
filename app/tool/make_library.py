"""Library (graded readers): tool/library/<level>.txt -> assets/data/library.json.
DSL:  # id | level | title | titleFa | cover place | blurb | blurbFa
      ## chapter title | titleFa
      English sentence | Persian
      Q: question | correct ; wrong ; wrong
      W: word=fa ; phrase=fa          (book glossary; overrides the base dictionary)
      speaker> "Quoted line" | Persian  (B1+: dialogue read in that character's British voice;
                                        speaker = a voice id in render_voices.py, e.g. tom, leslie, weda)
      tool/library/gloss_<level>.txt: 'word=fa ; word=fa' lines shared by every book of that level
Every word must resolve to a Persian gloss (book W > BASE > NAMES > course words, with simple
lemmatising), so tap-to-translate never comes up empty. Fails loudly listing missing words."""
import json,os,re,sys,glob
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets')
BASE=dict(x.split('=',1) for x in '''a=یک ; an=یک ; the=(حرف تعریف) ؛ آن ; is=است ; are=هستند ; am=هستم ; was=بود ; were=بودند ; be=بودن ; been=بوده
i=من ; you=تو ؛ شما ; he=او (مذکر) ; she=او (مؤنث) ; it=آن ؛ این ; we=ما ; they=آن‌ها ; me=من را ; him=او را ; her=او را ؛ ـش (مؤنث) ; us=ما را ; them=آن‌ها را
my=ـم ؛ مال من ; your=ـت ؛ مال تو ; his=ـش ؛ مال او ; its=ـش ; our=ـمان ; their=ـشان ; this=این ; that=آن ؛ که ; these=این‌ها ; those=آن‌ها
and=و ; but=اما ; or=یا ; so=پس ؛ آن‌قدر ; because=چون ; then=بعد ; when=وقتی ; if=اگر ; than=از (مقایسه) ; as=مثل ؛ به‌عنوان
to=به ؛ تا ; in=در ؛ داخل ; on=روی ; at=در ؛ ساعت ; of=ـِ (مالکیت) ؛ از ; for=برای ; with=با ; from=از ; by=کنار ؛ تا ; up=بالا ; down=پایین ; into=به داخل ; out=بیرون ; about=دربارهٔ ; over=روی ؛ بالای ; off=خاموش ؛ جدا ; round=دور ; past=گذشته ؛ از کنار
very=خیلی ; not=نه ؛ نـ ; no=نه ؛ هیچ ; yes=بله ; oh=آه ؛ اوه ; please=لطفاً ; now=حالا ; there=آنجا ; here=اینجا ; what=چه ؛ چی ; where=کجا ; who=چه کسی ; how=چطور ; why=چرا ; which=کدام
can=می‌تواند ; do=انجام دادن ؛ (فعل کمکی) ; does=(فعل کمکی) ; did=(فعل کمکی گذشته) ؛ انجام داد ; don't=نکن ؛ نمی‌… ; has=دارد ; have=داشتن ؛ دارند ; had=داشت ; got=گرفت ؛ دارد (have got) ; will=خواهد ; too=هم ؛ خیلی ; all=همه ; some=کمی ؛ چند ; every=هر ; any=هیچ ؛ هر ; much=خیلی ؛ زیاد ; more=بیشتر ; most=بیشترین ; a lot=کلی ; lot=کلی
one=یک ; two=دو ; three=سه ; four=چهار ; five=پنج ; six=شش ; seven=هفت ; eight=هشت ; nine=نه ; ten=ده ; twelve=دوازده ; forty-two=چهل و دو ; forty=چهل
big=بزرگ ; small=کوچک ; little=کوچک ؛ کمی ; old=پیر ؛ قدیمی ؛ ساله ; new=جدید ; good=خوب ; red=قرمز ; green=سبز ; day=روز ; night=شب ; home=خانه ; house=خانه ; school=مدرسه ; park=پارک ; shop=مغازه ; bus=اتوبوس ; buses=اتوبوس‌ها ; train=قطار ; tea=چای ; family=خانواده ; friend=دوست
says=می‌گوید ; said=گفت ; go=رفتن ; goes=می‌رود ; like=دوست داشتن ؛ مثل ; likes=دوست دارد ; loves=عاشق … است ; want=خواستن ; wants=می‌خواهد ; see=دیدن ; look=نگاه کردن ; make=درست کردن ; eat=خوردن ; buy=خریدن ; let's=بیایید ; it's=این … است ; that's=آن … است ; i'm=من … هستم ; you're=تو … هستی ; they're=آن‌ها … هستند ; he's=او … است ; she's=او … است ; what's=چیست ; where's=کجاست ; is there=آیا … هست ; there is=… هست ; there are=… هستند ; there was=… بود ; there were=… بودند
mummy=مامانی ; daddy=بابایی ; mum=مامان ; dad=بابا ; nana=نانا (پرستار بچه) ; sister=خواهر ; mr=آقای ; mrs=خانم ; miss=خانم (معلم) ; today=امروز ; again=دوباره ; ever=تا به حال ; also=همچنین ; else=دیگر ; just=فقط ؛ همین الان ; even=حتی ; only=فقط ; never=هرگز ; always=همیشه ; still=هنوز ; later=بعداً ; then=بعد
saturday=شنبه ; sunday=یکشنبه ; monday=دوشنبه ; tuesday=سه‌شنبه ; thursday=پنجشنبه ; friday=جمعه ; saturdays=شنبه‌ها ; o'clock=ساعت ; minutes=دقیقه ; hour=ساعت ; year=سال ; years=سال‌ها ; morning=صبح
full=پر ; ran=دوید ; told=گفت ; took=برداشت ؛ گرفت ؛ طول کشید ; ice cream=بستنی ; bit=کمی ؛ تکه ; last=آخرین ؛ گذشته ; sun=خورشید ؛ آفتاب ; stop=ایستگاه ؛ توقف ; looks=نگاه می‌کند ؛ به نظر می‌رسد ; slowly=آهسته ; has got=دارد ; have got=دارند ؛ دارم ; kitchen=آشپزخانه ; puddle=چالهٔ آب ; comes=می‌آید ; man=مرد ; fell=افتاد ; made=درست کرد ; woke=بیدار شد ; stood=ایستاد ; chip=یک تکه سیب‌زمینی سرخ‌کرده
'''.replace('\n',' ; ').split(' ; ') if '=' in x)
BASE.update(dict(x.split('=',1) for x in '''would=(فعل کمکی شرطی) ؛ می‌… ; could=می‌توانست ؛ ممکن است ; know=دانستن ؛ شناختن ; knew=می‌دانست ؛ می‌شناخت ; known=شناخته‌شده ؛ معروف ; knowing=دانستن ; think=فکر کردن ؛ فکر می‌کنم ; time=زمان ؛ بار ؛ وقت ; spent=گذراند ؛ خرج کرد ; come=آمدن ; something=چیزی ; few=چند ؛ کم ; main=اصلی ; story=داستان ؛ ماجرا ; let=اجازه دادن ; rather=نسبتاً ؛ به‌جای ; simply=به‌سادگی ؛ فقط ; public=عمومی ؛ جمع ; led=هدایت کرد ؛ رساند ; spoke=صحبت کرد ; themselves=خودشان ; least=کمترین ؛ حداقل ; luck=شانس ; worry=نگرانی ؛ نگران بودن ; life=زندگی ; car=ماشین ; many=خیلی ؛ بسیاری ; woman=زن ; child=کودک ؛ بچه ; doctor=پزشک ; during=در طول ; felt=احساس کرد ; final=نهایی ؛ آخر ; fire=آتش ؛ شومینه ; hello=سلام ; eye=چشم ; lesson=درس ; university=دانشگاه ; perhaps=شاید ; example=مثال ؛ نمونه ; eleven=یازده ; sixty=شصت ; ninety=نود ; yourself=خودت ; begin=شروع کردن ; began=شروع شد ; given=داده‌شده ; written=نوشته‌شده ; threw=پرت کرد ؛ دور انداخت ; meant=منظور داشت ؛ یعنی ; hung up=قطع کرد (تلفن) ; hung=آویزان کرد ؛ قطع کرد
i'll=من … خواهم ؛ ـم (آینده) ; i've=من … ام (حال کامل) ; you'll=تو … خواهی ; you've=تو … ای (حال کامل) ; you'd=تو … می‌… (would/had) ; she'd=او … (would/had) ; we'll=ما … خواهیم ; we've=ما … ایم (حال کامل) ; they'll=آن‌ها … خواهند ; hadn't=نداشت ؛ نـ…ـه بود ; wasn't=نبود ; wouldn't=نمی‌… ؛ نمی‌خواست ; haven't=ندارم ؛ نـ…ـه‌ام'''.replace('\n',' ; ').split(' ; ') if '=' in x))
BASE={k.strip():v.strip() for k,v in BASE.items()}
BASE.update({'maple grove':'میپل گروو (اسم مدرسه)', 'primrose lane':'پرایمروز لین (اسم مهدکودک)'})
NAMES={'William':'ویلیام','Tom':'تام','Leslie':'لزلی','Nicola':'نیکولا','Ryan':'رایان','Maggie':'مگی','Patel':'پاتل','Biscuit':'بیسکویت (اسم گربه)','Gareth':'گرت',
 'Ellis':'الیس','Khan':'خان','Hackney':'هاکنی (محله‌ای در لندن)','Mare':'مِر (اسم خیابان)','Street':'خیابان','Brown':'براون','Thompsons':'تامسون‌ها','Thompson':'تامسون',
 'overground':'اورگراند (قطار شهری لندن)','Highbury':'هایبری','Victoria':'ویکتوریا (ایستگاه)','Brighton':'برایتون','King':'پادشاه','Fairy':'پری','Tooth':'دندان','Happy':'مبارک','Birthday':'تولد','London':'لندن','England':'انگلستان','Spain':'اسپانیا','TV':'تلویزیون','L':'ال (حرف)',
 'Birmingham':'بیرمنگام','Dave':'دیو','Alastair':'آلستر','Know-Nothings':'هیچ‌ندان‌ها (اسم تیم)','Doris':'دوریس','Bradley':'بردلی','George':'جورج','Dover':'داور (شهری ساحلی)',
 'France':'فرانسه','Maya':'مایا','Clarke':'کلارک','Hannah':'هانا','Mary':'مری','St':'سنت (قدیس)','Ms':'خانم','Riverside':'ریورساید (بیمارستان)','Leeds':'لیدز','Glasgow':'گلاسگو','Bennett':'بنت',
 'Siân':'شان','Imogen':'ایموجن','Priya':'پریا','Suffolk':'سافک','Acorns':'ایکورنز (اسم مهد)','Harris':'هریس','Jo':'جو','Oscar':'اسکار','Vida':'ویدا','Canada':'کانادا','Hale':'هیل',
 'Liverpool':'لیورپول','Margaret':'مارگارت','Frank':'فرانک','Montreal':'مونترال','Ontario':'انتاریو','Arthur':'آرتور'}
NOPREFIX={'Street','King','TV','Happy','Birthday','Fairy','Tooth','London','England','Spain','L','Birmingham','Dover','France','St','Ms','Mary','Riverside','Leeds','Glasgow','Suffolk','Acorns','Canada','Liverpool','Montreal','Ontario','Know-Nothings'}
COURSE={}
c=json.load(open(os.path.join(A,'data/course.json')))
for u in c['units']+[u for p in c.get('packs',[]) for u in p['units']]:
  for l in u['lessons']:
    for w in l.get('words',[]): COURSE.setdefault(w['word'].lower(),w['fa'])
# The app's own glossary (every word the course explains) is the last offline fallback.
GLOSSARY={k.lower():v[1] for k,v in json.load(open(os.path.join(A,'data/glossary.json'))).items() if isinstance(v,list) and len(v)>1 and v[1]}
for k,v in GLOSSARY.items(): COURSE.setdefault(k,v)
TOK=re.compile(r"[A-Za-zÀ-ÿ]+(?:['’-][A-Za-zÀ-ÿ]+)*")
def variants(w):
  out=[w]
  for suf,rep in [("'s",''),('ies','y'),('es',''),('s',''),('ied','y'),('ed',''),('ed','e'),('d',''),('ing',''),('ing','e'),('ly',''),('er',''),('est','')]:
    if w.endswith(suf) and len(w)-len(suf)>=2: out.append(w[:-len(suf)]+rep)
  if re.search(r'(.)\1(ed|ing)$',w): out.append(re.sub(r'(.)\1(ed|ing)$',r'\1',w))
  return out
def gloss(w,raw,book):
  for v in variants(w):
    for d in (book,BASE,COURSE):
      if v in d: return d[v]
  if raw.endswith("'s") and raw[:-2] in NAMES: return 'مالِ '+NAMES[raw[:-2]]+' ('+raw[:-2]+')'
  if raw in NAMES: return 'اسم: '+NAMES[raw] if raw[0].isupper() and raw not in NOPREFIX else NAMES[raw]
  return None
VOICES=set(re.findall(r"'([a-z]+)':\('en-",open(os.path.join(H,'render_voices.py')).read()))
CAST={c['id']:c['name'] for c in json.load(open(os.path.join(A,'data/characters.json')))}
CAST.update({'mrspatel':'Mrs Patel','oldman':'The old man'})  # minor library characters (own voices, no portrait)
LEVELG={}
for gf in glob.glob(os.path.join(H,'library','gloss_*.txt')):
  lv=os.path.basename(gf)[6:-4].upper(); d=LEVELG.setdefault(lv,{})
  for ln in open(gf,encoding='utf-8'):
    ln=ln.strip()
    if not ln or ln.startswith('#'): continue
    for kv in ln.split(' ; '):
      k,v=kv.split('=',1); d[k.strip().lower()]=v.strip()
# Library sections (lib/features/library/library_data.dart Library.categories). The 30 family stories:
# A1 = Children's & Easy Reads; everyday-Britain stories = Travel & UK Life; the rest = Fiction.
SECTIONS={'fiction','children','poetry','history','science','biography','uklife','reference'}
CAT={'a2_driving':'uklife','b1_train':'uklife','b2_interview':'uklife','b2_ae':'uklife','b2_scam':'uklife','c1_inspection':'uklife','c1_postoffice':'uklife','a2_wallet':'uklife','c1_letters':'history'}
SPK=re.compile(r'^([a-z]+)> (.*)$')
books=[]; missing={}; bad=[]
for f in sorted(g for g in glob.glob(os.path.join(H,'library','*.txt')) if not os.path.basename(g).startswith('gloss_')):
  bk=ch=None
  for ln in open(f,encoding='utf-8'):
    ln=ln.rstrip('\n').strip()
    if not ln: continue
    if ln.startswith('## '):
      t=[x.strip() for x in ln[3:].split('|')]; ch={'title':t[0],'titleFa':t[1],'sentences':[],'quiz':[]}; bk['chapters'].append(ch)
    elif ln.startswith('# '):
      t=[x.strip() for x in ln[2:].split('|')]
      bk={'id':t[0],'level':t[1],'title':t[2],'titleFa':t[3],'cover':t[4],'blurb':t[5],'blurbFa':t[6],'chapters':[],'gloss':{}}; books.append(bk)
      bk['cat']=CAT.get(t[0],'children' if t[1]=='A1' else 'fiction')
    elif ln.startswith('@ '):
      # @ cat=history | author=… | src=… | audio=device | orig=1
      for kv in ln[2:].split(' | '):
        k,v=kv.split('=',1); k=k.strip(); v=v.strip()
        if k not in ('cat','author','src','audio','orig'): bad.append(f"{bk['id']}: unknown @{k}")
        bk[k]=(v=='1') if k=='orig' else v
    elif ln.startswith('Q:'):
      q,opts=[x.strip() for x in ln[2:].split('|')]; o=[x.strip() for x in opts.split(';')]
      ch['quiz'].append({'q':q,'options':o,'answer':0})
    elif ln.startswith('W:'):
      for kv in ln[2:].split(' ; '):
        k,v=kv.split('=',1); bk['gloss'][k.strip().lower()]=v.strip()
    else:
      m=SPK.match(ln); sp=None
      if m: sp,ln=m.group(1),m.group(2)
      en,fa=[x.strip() for x in ln.split('|')]; st={'en':en,'fa':fa}
      if sp:
        if sp not in VOICES or sp=='narrator': bad.append(f"{bk['id']}: unknown speaker {sp}")
        st['sp']=sp; st['spn']=CAST.get(sp,sp.title())
      ch['sentences'].append(st)
if bad: print('\n'.join(bad)); sys.exit(1)
for bk in books:
  bk['gloss']={**LEVELG.get(bk['level'],{}),**bk['gloss']}
  used={}
  phrases=sorted([k for k in list(bk['gloss'])+list(BASE) if ' ' in k],key=lambda k:-len(k.split()))
  for ch in bk['chapters']:
    for s in ch['sentences']:
      toks=[(m.start(),m.end(),m.group()) for m in TOK.finditer(s['en'])]
      segs=[]; pos=0; i=0
      while i<len(toks):
        a,b,raw=toks[i]; hit=None
        for p in phrases:
          n=len(p.split())
          if i+n<=len(toks) and ' '.join(t[2].lower().replace('’',"'") for t in toks[i:i+n])==p: hit=(p,n); break
        if hit:
          key,n=hit; b=toks[i+n-1][1]; used[key]=bk['gloss'].get(key) or BASE[key]
        else:
          n=1; key=raw.lower().replace('’',"'"); g=gloss(key,raw,bk['gloss'])
          if g is None: missing.setdefault(bk['id'],set()).add(raw); g=''
          used[key]=g
        if a>pos: segs.append([s['en'][pos:a],''])
        segs.append([s['en'][a:b],key]); pos=b; i+=n
      if pos<len(s['en']): segs.append([s['en'][pos:],''])
      s['segs']=segs
  bk['gloss']=used
  bk['words']=sum(len(TOK.findall(s['en'])) for c in bk['chapters'] for s in c['sentences'])
if missing:
  for k,v in missing.items(): print('MISSING',k,sorted(v))
  sys.exit(1)
for bk in books:
  if bk['cat'] not in SECTIONS: bad.append(f"{bk['id']}: unknown section {bk['cat']}")
  if bk.get('audio','recorded') not in ('recorded','device'): bad.append(f"{bk['id']}: audio must be recorded|device")
  if bk['cat']!='children' and bk['level']!='A1' and bk.get('orig') is None and bk.get('author') and not bk.get('src'): bad.append(f"{bk['id']}: classic without src")
  # Words worth learning: content words (not grammar words, not names); the app subtracts the learner's own words.
  bk['vocab']=sorted(k for k,v in bk['gloss'].items() if k not in BASE and v and not v.startswith('اسم:') and not v.startswith('مالِ ') and len(k)>2 and k.isascii())
if bad: print('\n'.join(bad)); sys.exit(1)
# Offline dictionary card (part of speech, simple English definition, example) from Open English WordNet 2025
# (CC BY 4.0, https://github.com/globalwordnet/english-wordnet), compacted by /workspace/wordnet/build_min.py.
# Only the words the books use are shipped. Without the compact file the previous dictionary asset is kept.
WN=os.environ.get('OEWN_MIN','/workspace/wordnet/oewn_min.json')
DPATH=os.path.join(A,'data/library_dict.json')
if os.path.exists(WN):
  wn=json.load(open(WN)); E=wn['entries']; F=wn['forms']; D={}
  for bk in books:
    for k in bk['gloss']:
      if k in D or not k.isascii(): continue
      for v in [k, F.get(k,'')]+variants(k):
        if v and v in E: D[k]=E[v]; break
  json.dump({'_source':'Open English WordNet 2025 (CC BY 4.0) https://github.com/globalwordnet/english-wordnet — definitions shortened to the first sense per part of speech','entries':D},open(DPATH,'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
  print('dictionary',len(D),'of',len({k for b in books for k in b['gloss']}),'words')
json.dump({'books':books},open(os.path.join(A,'data/library.json'),'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
for bk in books: print(bk['level'],bk['cat'],bk['id'],len(bk['chapters']),'ch',bk['words'],'words')
print('TOTAL',len(books),'books',sum(len(b['chapters']) for b in books),'chapters',sum(b['words'] for b in books),'words')
