"""Character growth: chapter-dependent lines (0=Y1 Autumn, 1=Y1 Spring, 2=Y2 Autumn, 3=Y2 Summer, 4=Y3 Autumn, 5=Y3 Summer, 6=Y4 Autumn).
Replies stay the same, so every line must still fit the original reply choices. Idempotent."""
import json,os
A=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','data','scenes')
L={
 ('ep1_morning_table','k3'):{2:("Oops! My jam fell down, Mummy!","وای! مربام افتاد، مامان!"),4:("Oops! I dropped my strawberry. Sorry, Mummy!","وای! توت‌فرنگی‌ام افتاد. ببخشید مامان!")},
 ('ep1_morning_table','k4'):{1:("Can I have jam on mine, please? I'm six now, so I can spread it myself!","می‌شه روی مال من مربا بزنید؟ حالا شش سالمه، خودم می‌تونم بمالم!"),3:("Could I have jam on mine, please? Strawberry, not raspberry — I've gone off raspberry.","می‌شه روی مال من مربا بزنید؟ توت‌فرنگی، نه تمشک — دیگه تمشک دوست ندارم.")},
 ('ep1_morning_table','k5'):{4:("Alright? Shattered — driving lesson at eight. Any toast left, or has Dad scoffed it?","چطوری؟ داغونم — ساعت هشت کلاس رانندگی دارم. نون تست مونده یا بابا همه رو خورده؟"),6:("Alright? Last breakfast before uni, mate. Any toast left, or has Dad scoffed it?","چطوری؟ آخرین صبحونه قبل از دانشگاه، رفیق. نون تست مونده یا بابا همه رو خورده؟")},
 ('nicola_park','p1'):{2:("Hiya! Will you push me on the swings? Mia's coming too — she's my best friend!","سلام! منو روی تاب هل می‌دی؟ میا هم میاد — بهترین دوستمه!")},
 ('nicola_park','p3'):{1:("Guess what? I'm six now! Next birthday I'll be SEVEN. What's your favourite cake?","حدس بزن چی؟ الان شش سالمه! تولد بعدی هفت می‌شم. کیک مورد علاقه‌ات چیه؟")},
 ('tom_breakfast','t3'):{6:("Right, I'm off — and we're driving Ryan to uni this weekend. What're you up to today?","خب، من رفتم — این آخر هفته رایان رو می‌بریم دانشگاه. امروز چی کار می‌کنی؟")},
}
n=0
for (sid,nid),v in L.items():
  p=os.path.join(A,sid+'.json'); s=json.load(open(p))
  if nid not in s['nodes']: print('skip',sid,nid); continue
  s['nodes'][nid]['byChapter']={str(k):{'text':t,'fa':f} for k,(t,f) in v.items()}; n+=len(v)
  json.dump(s,open(p,'w'),ensure_ascii=False,indent=1)
print(n,'chapter lines')
