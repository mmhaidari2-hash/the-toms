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
 ('homes','Fennick & Rowe Homes','بنگاه املاک فنیک اند رو','🔑',.765,.585,[],None,'homes',[]),
 ('nursery','Vida\'s Nursery','مهدکودک ویدا','🧒',.10,.53,[],None,'nursery',[]),
 ('school','St Mary\'s School','مدرسهٔ سنت مری','🏫',.25,.63,['school','firstday','parentsevening','sportsday'],r'school|parents\' evening|homework|teacher',None,[]),
 ('park','London Fields park','پارک لندن فیلدز','🌳',.82,.68,['park'],None,None,[]),
 ('station','Train station','ایستگاه قطار','🚆',.88,.33,['train'],r'\btrains?\b|\btube\b|underground|railcard|platform',None,[]),
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
 ('hospital','Riverside Hospital','بیمارستان ریورساید','🏥',.30,.24,['doctor'],r'hospital|a&e|triage|outpatient|\bward\b|discharged',None,[]),
 ('museum','Museum','موزه','🏛️',.12,.25,[],r'museum',None,['l2_u21_1','l2_u21_2','l2_u21_3','l2_u21_4']),
 ('cinema','Cinema & arena','سینما و سالن','🎬',.75,.21,[],r'cinema|film|movie|popcorn',None,['l2_u8_4']),
 ('radio','Hackney Hum radio','رادیو هاکنی هام','📻',.55,.235,[],None,None,['l1_u6_1','l2_u37_1','l2_u37_4','l4_u8_2','l4_u8_4']),  # rooftop studio on the glass office block
 ('missions','Real-life missions','مأموریت‌های زندگی واقعی','🎯',.675,.655,[],None,None,['l1_u43_1','l2_u2_1','l2_u4_1','l2_u37_1','l2_u51_1']),  # the corner where the high street meets the park
 ('gym','The gym','باشگاه ورزشی','🏋️',.17,.43,['gym'],r'\bgym\b|fitness',None,[]),
 ('pub','The Red Lion pub','میخانهٔ رد لاین','🍺',.39,.55,['pub'],r'\bpub\b|quiz night',None,[]),
 ('garage','Mick\'s Motors & petrol station','تعمیرگاه میک و پمپ بنزین','🚗',.20,.50,['driving','petrol'],r'driving|mot\b|petrol|car\b',None,[]),
 ('work','Work & interviews','کار و مصاحبه','💼',.50,.20,['interview'],r'interview|work|job|career|promotion',None,[]),
 ('university','University','دانشگاه','🎓',.90,.22,['university','conference'],r'universit|\buni\b|campus|conference',None,[]),
]
# Spots that LINK to lessons owned by other buildings (radio shows, real-life missions). Every other lesson has exactly one building.
LINK_SPOTS={'radio','missions'}
# When only title keywords decide, the more specific building wins (school before work: "homework"; hospital before gp ...).
RX_ORDER=['school','hospital','gp','pharmacy','cinema','museum','restaurant','cafe','barber','postoffice','library','station','bus','supermarket','shoppingcentre','shops','gym','pub','university','bank','garage','work']
# Keywords too broad to name a building from a unit title alone ("jobs around the house", "cash", "car").
GENERIC={'work','bank','garage','bus'}
def owner(l,u):
  """The ONE building a lesson belongs to: its pack's building, else a manual pin, else its painting's place, else the most specific title keyword."""
  if u.get('pack'): return next(sp[0] for sp in SPOTS if sp[8]==u['pack'])
  for sp in SPOTS:
    if sp[0] not in LINK_SPOTS and l['id'] in sp[9]: return sp[0]
  by={sp[0]:sp for sp in SPOTS}
  def rx(text,order):
    for sid in order:
      if by[sid][7] and re.search(by[sid][7],text.lower()): return sid
  # The unit's topic names the building ("Going to the cinema", "A&E") even when the scene borrows another painting.
  hit=rx(u['title'],[x for x in RX_ORDER if x not in GENERIC])
  if hit: return hit
  # A lesson whose own title names one of these places ("A&E triage", "Talking about films") belongs there.
  hit=rx(l['title'],['hospital','cinema','museum'])
  if hit: return hit
  for sp in SPOTS:
    if l['place'] in sp[6]: return sp[0]
  return rx(l['title']+' | '+u['title'],RX_ORDER+[sp[0] for sp in SPOTS if sp[0] not in RX_ORDER])
def build():
  c=json.load(open(os.path.join(A,'course.json')))
  units=c['units']+[dict(u,pack=pk['id']) for pk in c.get('packs',[]) for u in pk['units']]
  own={l['id']:owner(l,u) for u in units for l in u['lessons']}
  out=[]
  for sid,t,tf,icon,x,y,places,rx,pack,manual in SPOTS:
    ids=[l['id'] for u in units for l in u['lessons'] if own[l['id']]==sid or (sid in LINK_SPOTS and l['id'] in manual)]
    out.append({'id':sid,'title':t,'titleFa':tf,'icon':icon,'x':x,'y':y,'pack':pack,'lessons':ids})
  lost=[k for k,v in own.items() if v is None]
  if lost: print('lessons with no building:',len(lost),lost[:10])
  bad=[s['id'] for s in out if not s['lessons']]
  if bad: print('EMPTY map spots:',bad); sys.exit(1)
  json.dump(out,open(os.path.join(A,'spots.json'),'w'),ensure_ascii=False,indent=1)
  print(len(out),'map spots;',', '.join(f"{s['id']}={len(s['lessons'])}" for s in out))
if __name__=='__main__': build()
