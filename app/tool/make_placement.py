"""Placement test items: per course level, listening items (real voiced lines from that level) + one hand-written choice item.
Writes assets/data/placement.json. Deterministic."""
import json,os,random,hashlib,re
A=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','data')
course=json.load(open(os.path.join(A,'course.json'))); bundle=json.load(open(os.path.join(A,'scenes_bundle.json')))
audio=set(json.load(open(os.path.join(A,'..','audio','index.json'))))
def key(s,t): return hashlib.md5(f'{s}|{t}'.encode()).hexdigest()[:16]
CHOICE={
 1:[("Nicola ___ five years old.","is",["is","are","am"],"نیکولا پنج سالشه.")],
 2:[("Yesterday we ___ to the park.","went",["went","go","going"],"دیروز رفتیم پارک.")],
 3:[("I've lived in London ___ two years.","for",["for","since","from"],"دو ساله تو لندن زندگی می‌کنم.")],
 4:[("If I ___ known, I would have called you.","had",["had","have","would"],"اگه می‌دونستم، بهت زنگ می‌زدم.")],
 5:[("\"It's not bad\" from a Brit usually means…","It's quite good",["It's quite good","It's terrible","They don't know"],"«بد نیست» از زبان یه بریتانیایی یعنی…")],
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
  for q,a,ch,fa in CHOICE[lv]:
    c=ch[:]; rnd.shuffle(c)
    out.append({'level':lv,'type':'choice','text':q,'fa':fa,'choices':c,'answer':a})
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
