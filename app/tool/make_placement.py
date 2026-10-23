"""Placement test items: per course level, listening items (real voiced lines from that level) + one hand-written choice item.
Writes assets/data/placement.json. Deterministic."""
import json,os,random,hashlib,re
A=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','data')
course=json.load(open(os.path.join(A,'course.json'))); bundle=json.load(open(os.path.join(A,'scenes_bundle.json')))
audio=set(json.load(open(os.path.join(A,'..','audio','index.json'))))
def key(s,t): return hashlib.md5(f'{s}|{t}'.encode()).hexdigest()[:16]
# Hand-written items per course level (1=A1 … 5=C1): grammar, vocabulary and a short reading text.
# Each: (type, question, answer, choices, question_fa, passage, passage_fa)
CHOICE={
 1:[("grammar","Nicola ___ five years old.","is",["is","are","am"],"نیکولا پنج سالشه.",None,None),
    ("vocab","You eat soup with a ___.","spoon",["spoon","chair","coat"],"سوپ را با ___ می‌خوری.",None,None),
    ("read","How many brothers has Nicola got?","Two",["Two","One","Three"],"نیکولا چند تا برادر داره؟",
     "Hi, I'm Nicola. I'm eight. I live in Hackney with my mum, my dad and my two brothers. I love cats.",
     "سلام، من نیکولا هستم. هشت سالمه. با مامان، بابا و دو تا برادرم تو هکنی زندگی می‌کنم. گربه خیلی دوست دارم.")],
 2:[("grammar","Yesterday we ___ to the park.","went",["went","go","going"],"دیروز رفتیم پارک.",None,None),
    ("vocab","The bus was late, so I ___ my train.","missed",["missed","lost","forgot"],"اتوبوس دیر کرد، پس قطارم را از دست دادم.",None,None),
    ("read","What happens if your book is due on Monday?","You can return it on Tuesday without paying.",["You can return it on Tuesday without paying.","You have to pay a fine.","You must return it on Sunday."],"اگه موعد کتابت دوشنبه باشه چی میشه؟",
     "NOTICE: The library is closed on Monday for cleaning. It opens again on Tuesday at 9am. Books due on Monday can be returned on Tuesday with no fine.",
     "اطلاعیه: کتابخانه دوشنبه برای نظافت بسته است. سه‌شنبه ساعت ۹ صبح دوباره باز می‌شود. کتاب‌هایی که موعدشان دوشنبه است را می‌شود سه‌شنبه بدون جریمه پس داد.")],
 3:[("grammar","I've lived in London ___ two years.","for",["for","since","from"],"دو ساله تو لندن زندگی می‌کنم.",None,None),
    ("vocab","Could you ___ the kids while I pop to the shop?","keep an eye on",["keep an eye on","look for","take after"],"می‌شه تا من یه سر می‌رم مغازه، حواست به بچه‌ها باشه؟",None,None),
    ("read","Why should children arrive by 8.30?","Because the coach leaves at 8.45.",["Because the coach leaves at 8.45.","Because lunch is at 8.30.","Because the museum opens at 8.30."],"چرا بچه‌ها باید تا ۸:۳۰ برسند؟",
     "Dear parents, Year 5 will visit the Science Museum on Friday. Children should bring a packed lunch and wear school uniform. The coach leaves at 8.45, so please arrive by 8.30. Mr Patel",
     "والدین گرامی، کلاس پنجم جمعه به موزهٔ علوم می‌رود. بچه‌ها ناهار همراه بیاورند و لباس مدرسه بپوشند. اتوبوس ساعت ۸:۴۵ حرکت می‌کند، پس لطفاً تا ۸:۳۰ برسید. آقای پاتل")],
 4:[("grammar","If I ___ known, I would have called you.","had",["had","have","would"],"اگه می‌دونستم، بهت زنگ می‌زدم.",None,None),
    ("vocab","The landlord refused to ___ responsibility for the damp.","take",["take","make","do"],"صاحبخانه حاضر نشد مسئولیت نم را بپذیرد.",None,None),
    ("read","Why are some residents unhappy?","They feel they weren't properly consulted.",["They feel they weren't properly consulted.","The council has stopped recycling.","Their petition was rejected."],"چرا بعضی از ساکنان ناراضی‌اند؟",
     "Although the council has promised to improve recycling, many residents say collections are still unreliable. Some have started a petition, arguing that the new schedule was introduced without proper consultation.",
     "با اینکه شورا قول داده بازیافت را بهتر کند، خیلی از ساکنان می‌گویند جمع‌آوری هنوز قابل‌اعتماد نیست. بعضی‌ها طوماری راه انداخته‌اند و می‌گویند برنامهٔ جدید بدون مشورت درست اجرا شده.")],
 5:[("grammar","No sooner ___ sat down than the phone rang.","had I",["had I","I had","did I"],"تازه نشسته بودم که تلفن زنگ زد.",None,None),
    ("vocab","\"It's not bad\" from a Brit usually means…","It's quite good",["It's quite good","It's terrible","They don't know"],"«بد نیست» از زبان یه بریتانیایی یعنی…",None,None),
    ("read","What does the writer suggest about the council?","Its case is weaker because it hasn't shared all its data.",["Its case is weaker because it hasn't shared all its data.","It has published all of its data.","It agrees with the critics."],"نویسنده دربارهٔ شورا چه چیزی را القا می‌کند؟",
     "Critics contend that, far from easing congestion, the scheme has merely pushed traffic onto residential side streets — a claim the council disputes, citing data it has nonetheless declined to publish in full.",
     "منتقدان می‌گویند این طرح نه‌تنها ترافیک را کم نکرده، بلکه فقط آن را به خیابان‌های فرعی مسکونی کشانده — ادعایی که شورا رد می‌کند و به داده‌هایی استناد می‌کند که با این حال حاضر نشده کامل منتشر کند.")],
}
out=[]
rnd=random.Random(7)
for lv in range(1,6):
  lines=[]
  for u in course['units']:
    if u['level']!=lv: continue
    for l in u['lessons']:
      for sid in l['sceneIds']:
        s=bundle.get(sid)
        if not s: continue
        for n in s['nodes'].values():
          t=n.get('text',''); sp=n.get('speaker')
          if sp in (None,'me','narrator') or '{you}' in t or '"' in t: continue
          w=len(t.split())
          if (5 if lv<3 else 8)<=w<=(10 if lv<3 else 18) and key(sp,t) in audio and (n.get('translations') or {}).get('fa'):
            lines.append((sp,t,n['translations']['fa']))
  rnd.shuffle(lines)
  picked=lines[:2]; pool=lines[2:60]
  for sp,t,fa in picked:
    ln=len(t.split())
    ds=sorted(pool,key=lambda x:abs(len(x[1].split())-ln))[:8]; rnd.shuffle(ds)
    ds=[d for d in ds if d[1]!=t][:2]
    ch=[(t,fa)]+[(d[1],d[2]) for d in ds]; rnd.shuffle(ch)
    out.append({'level':lv,'type':'listen','speaker':sp,'text':t,'fa':fa,'choices':[c[0] for c in ch],'choicesFa':[c[1] for c in ch],'answer':t})
  for ty,q,a,ch,fa,ps,psfa in CHOICE[lv]:
    c=ch[:]; rnd.shuffle(c)
    it={'level':lv,'type':ty,'text':q,'fa':fa,'choices':c,'answer':a}
    if ps: it['passage']=ps; it['passageFa']=psfa
    out.append(it)
# Optional speaking item: a short, already-voiced Level 1 line (so 'Hear it' plays the real clip).
sp=None
for u in course['units']:
  if u['level']!=1 or sp: continue
  for l in u['lessons']:
    for sid in l['sceneIds']:
      for n in (bundle.get(sid) or {'nodes':{}})['nodes'].values():
        t=n.get('text','')
        if not sp and n.get('speaker')=='tom' and 5<=len(t.split())<=8 and '{you}' not in t and key('tom',t) in audio and t.endswith(('.','?','!')) and (n.get('translations') or {}).get('fa'):
          sp={'type':'speak','speaker':'tom','text':t,'fa':n['translations']['fa']}
speak=sp
json.dump({'items':out,'speak':speak},open(os.path.join(A,'placement.json'),'w'),ensure_ascii=False,indent=1)
print(len(out),'placement items')
