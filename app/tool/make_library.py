"""Library (graded readers): tool/library/<level>.txt -> assets/data/library.json.
DSL:  # id | level | title | titleFa | cover place | blurb | blurbFa
      ## chapter title | titleFa
      English sentence | Persian
      Q: question | correct ; wrong ; wrong
      W: word=fa ; phrase=fa          (book glossary; overrides the base dictionary)
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
BASE={k.strip():v.strip() for k,v in BASE.items()}
NAMES={'William':'ویلیام','Tom':'تام','Leslie':'لزلی','Nicola':'نیکولا','Ryan':'رایان','Maggie':'مگی','Patel':'پاتل','Biscuit':'بیسکویت (اسم گربه)','Gareth':'گرت',
 'Ellis':'الیس','Khan':'خان','Hackney':'هاکنی (محله‌ای در لندن)','Mare':'مِر (اسم خیابان)','Street':'خیابان','Brown':'براون','Thompsons':'تامسون‌ها','Thompson':'تامسون',
 'Overground':'اورگراند (قطار شهری لندن)','Highbury':'هایبری','Victoria':'ویکتوریا (ایستگاه)','Brighton':'برایتون','King':'پادشاه','Fairy':'پری','Tooth':'دندان','Happy':'مبارک','Birthday':'تولد','London':'لندن','England':'انگلستان','Spain':'اسپانیا','TV':'تلویزیون','L':'ال (حرف)'}
COURSE={}
c=json.load(open(os.path.join(A,'data/course.json')))
for u in c['units']+[u for p in c.get('packs',[]) for u in p['units']]:
  for l in u['lessons']:
    for w in l.get('words',[]): COURSE.setdefault(w['word'].lower(),w['fa'])
TOK=re.compile(r"[A-Za-z]+(?:['’-][A-Za-z]+)*")
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
  if raw in NAMES: return 'اسم: '+NAMES[raw] if raw[0].isupper() and raw not in('Street','King','TV','Happy','Birthday','Fairy','Tooth','London','England','Spain','L') else NAMES[raw]
  return None
books=[]; missing={}
for f in sorted(glob.glob(os.path.join(H,'library','*.txt'))):
  bk=ch=None
  for ln in open(f,encoding='utf-8'):
    ln=ln.rstrip('\n').strip()
    if not ln: continue
    if ln.startswith('## '):
      t=[x.strip() for x in ln[3:].split('|')]; ch={'title':t[0],'titleFa':t[1],'sentences':[],'quiz':[]}; bk['chapters'].append(ch)
    elif ln.startswith('# '):
      t=[x.strip() for x in ln[2:].split('|')]
      bk={'id':t[0],'level':t[1],'title':t[2],'titleFa':t[3],'cover':t[4],'blurb':t[5],'blurbFa':t[6],'chapters':[],'gloss':{}}; books.append(bk)
    elif ln.startswith('Q:'):
      q,opts=[x.strip() for x in ln[2:].split('|')]; o=[x.strip() for x in opts.split(';')]
      ch['quiz'].append({'q':q,'options':o,'answer':0})
    elif ln.startswith('W:'):
      for kv in ln[2:].split(' ; '):
        k,v=kv.split('=',1); bk['gloss'][k.strip().lower()]=v.strip()
    else:
      en,fa=[x.strip() for x in ln.split('|')]; ch['sentences'].append({'en':en,'fa':fa})
for bk in books:
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
json.dump({'books':books},open(os.path.join(A,'data/library.json'),'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
for bk in books: print(bk['level'],bk['id'],len(bk['chapters']),'ch',bk['words'],'words')
