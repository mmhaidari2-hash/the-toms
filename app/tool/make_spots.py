"""Living-town map: every building/object on the map -> the lessons set THERE.
Index = lesson place tag (painting) + extra tags from title/unit keywords (+ manual ids). Writes assets/data/spots.json.
Run after gen.py (gen.py calls it)."""
import json,os,re,sys
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets','data')
# id, title, titleFa, icon, x, y (normalised on map.webp), places, keyword regex (title / unit title), pack, manual lesson ids
SPOTS=[
 ('home','Home — the Toms\' house','خانهٔ خانوادهٔ تام','🏠',.47,.70,['kitchen','hallway','living','bathroom','bedroom','birthday','christmas','eveningtea','poorly'],None,None,[]),
 ('playdate','Mia\'s house','خانهٔ میا','🧸',.06,.77,['playdate'],None,None,[]),
 ('bus','The 38 bus','اتوبوس ۳۸','🚌',.36,.46,['bus'],r'\bbus\b|travel card|tapping in|next stop|missed my stop',None,[]),
 ('nursery','Vida\'s Nursery','مهدکودک ویدا','🧒',.10,.53,[],None,'nursery',[]),
 ('school','St Mary\'s School','مدرسهٔ سنت مری','🏫',.25,.63,['school','firstday','parentsevening','sportsday'],r'school|parents\' evening|homework|teacher',None,[]),
 ('park','London Fields park','پارک لندن فیلدز','🌳',.82,.68,['park'],None,None,[]),
 ('station','Train station','ایستگاه قطار','🚆',.88,.33,['train'],r'\btrain|tube|underground|railcard|platform',None,[]),
 ('cafe','Callum\'s café','کافهٔ کالوم','☕',.73,.33,['coffee'],r'caf[eé]\b|coffee',None,[]),
 ('restaurant','The Copper Kettle','رستوران کاپر کتل','🍽️',.64,.40,['restaurant'],r'restaurant|booking a table',None,[]),
 ('pharmacy','Dawson\'s Pharmacy','داروخانهٔ داوسون','💊',.47,.42,['pharmacy'],r'pharmac|chemist|prescription',None,[]),
 ('shops','High street shops & market','مغازه‌ها و بازار','🥖',.60,.52,['bakery'],r'market|baker|butcher|greengrocer',None,[]),
 ('barber','Sal\'s barber shop','آرایشگاه سال','💈',.53,.55,['barber'],r'barber|hair',None,[]),
 ('supermarket','Supermarkets & corner shop','سوپرمارکت و فروشگاه محله','🛒',.69,.52,['supermarket','bigsupermarket'],r'supermarket|aisle|self-checkout|click & collect|shopping list|special offers|loyalty|checkout|bags for life',None,[]),
 ('shoppingcentre','Shopping centre','مرکز خرید','🛍️',.61,.29,['shoppingcentre','phoneshop'],r'coat|what size|shoes|trainers|clothes shopping|returning|faulty|too big',None,[]),
 ('library','Library & Service Centre','کتابخانه و مرکز خدمات','📚',.24,.33,['library'],r'library|council',None,[]),
 ('postoffice','Post office','اداره پست','📮',.05,.40,['postoffice'],r'post office|parcel|stamp|posting',None,[]),
 ('bank','The bank','بانک','🏦',.42,.30,['bank'],r'\bbank|account|mortgage|cash',None,[]),
 ('gp','GP surgery & dentist','مطب پزشک و دندانپزشک','🩺',.33,.38,['gp','dentist'],r'\bgp\b|doctor|dentist|surgery|appointment',None,[]),
 ('hospital','Riverside Hospital','بیمارستان ریورساید','🏥',.30,.24,['doctor'],r'hospital|a&e|triage|outpatient|ward|discharged',None,[]),
 ('museum','Museum','موزه','🏛️',.12,.25,[],r'museum',None,[]),
 ('cinema','Cinema & arena','سینما و سالن','🎬',.75,.21,[],r'cinema|film|movie|popcorn',None,['l2_u8_4']),
 ('radio','Hackney Hum radio','رادیو هاکنی هام','📻',.55,.235,[],None,None,['l1_u6_1','l2_u37_1','l2_u37_4','l4_u8_2','l4_u8_4']),  # rooftop studio on the glass office block
 ('missions','Real-life missions','مأموریت‌های زندگی واقعی','🎯',.675,.655,[],None,None,['l1_u43_1','l2_u2_1','l2_u4_1','l2_u37_1','l2_u51_1']),  # the corner where the high street meets the park
 ('gym','The gym','باشگاه ورزشی','🏋️',.17,.43,['gym'],r'\bgym\b|fitness',None,[]),
 ('pub','The Red Lion pub','میخانهٔ رد لاین','🍺',.39,.55,['pub'],r'\bpub\b|quiz night',None,[]),
 ('garage','Mick\'s Motors & petrol station','تعمیرگاه میک و پمپ بنزین','🚗',.20,.50,['driving','petrol'],r'driving|mot\b|petrol|car\b',None,[]),
 ('work','Work & interviews','کار و مصاحبه','💼',.50,.20,['interview'],r'interview|work|job|career|promotion',None,[]),
 ('university','University','دانشگاه','🎓',.90,.22,['university','conference'],r'universit|\buni\b|campus|conference',None,[]),
]
def build():
  c=json.load(open(os.path.join(A,'course.json')))
  units=c['units']+[dict(u,pack=pk['id']) for pk in c.get('packs',[]) for u in pk['units']]
  out=[]
  for sid,t,tf,icon,x,y,places,rx,pack,manual in SPOTS:
    ids=[]
    for u in units:
      for l in u['lessons']:
        hit=(l['place'] in places) or (pack and u.get('pack')==pack) or l['id'] in manual or (rx and re.search(rx,(l['title']+' | '+u['title']).lower()))
        if hit: ids.append(l['id'])
    out.append({'id':sid,'title':t,'titleFa':tf,'icon':icon,'x':x,'y':y,'pack':pack,'lessons':ids})
  bad=[s['id'] for s in out if not s['lessons']]
  if bad: print('EMPTY map spots:',bad); sys.exit(1)
  json.dump(out,open(os.path.join(A,'spots.json'),'w'),ensure_ascii=False,indent=1)
  print(len(out),'map spots;',', '.join(f"{s['id']}={len(s['lessons'])}" for s in out))
if __name__=='__main__': build()
