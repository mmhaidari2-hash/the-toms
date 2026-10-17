"""British English lint over every authored English line (lessons, packs, explore, places, characters).
Exit 1 if an American spelling/word is found. Allow-list exact phrases via ALLOW."""
import json,glob,os,re,sys
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets','data')
US={r'colou?r':None}
BAD={ # regex (word-boundary, case-insensitive) -> British form
 r'colors?|colored|colorful':'colour','favou?rites?':None,'favorites?|favorite':'favourite','favors?':'favour','honors?':'honour','humor':'humour',
 'neighbors?|neighborhoods?':'neighbour(hood)','labor':'labour','behaviors?':'behaviour','flavors?':'flavour','rumors?':'rumour','harbor':'harbour',
 r'reali[z]e[sd]?|realizing':'realise','organiz(e|es|ed|ing|ation)':'organise','recogniz(e|es|ed|ing)':'recognise','apologiz(e|es|ed|ing)':'apologise',
 r'(memo|summa|catego|priori)riz(e|es|ed|ing)':'-ise','centers?':'centre','theaters?':'theatre','liters?':'litre',r'(\d+|kilo|centi|milli|square) ?meters?':'metre',
 r'traveled|traveling|traveler':'travelled/travelling','canceled|canceling':'cancelled','jewelry':'jewellery','gray':'grey',
 r'moms?|mommy':'mum/mummy','apartments?':'flat','elevators?':'lift','candy':'sweets','diapers?':'nappy',
 r'pacifier':'dummy','strollers?':'pushchair/buggy','sidewalks?':'pavement','gas station':'petrol station','trash( can)?':'rubbish/bin',
 r'garbage':'rubbish','vacations?':'holiday','soccer':'football','math':'maths','cell ?phones?':'mobile','zip ?code':'postcode',
 r'parking lot':'car park','restrooms?':'toilets','faucet':'tap','flashlight':'torch','french fries':'chips','defense':'defence',
 r'offense':'offence','catalog':'catalogue','dialog':'dialogue','analyz(e|es|ed|ing)':'analyse','aluminum':'aluminium','airplanes?':'aeroplane/plane',
 r'gotten':'got','toward':'towards','pajamas':'pyjamas','tire(s)? (pressure|is flat)':'tyre','check(s)? (please|for the table)':'bill',
 r'driver\'?s license':'driving licence','(I|you|we|they|to) practice\b':'practise (verb)','(TV|radio) programs?':'programme','fall (term|semester)':'autumn term',
 r'semester':'term','eggplant':'aubergine','zucchini':'courgette','cilantro':'coriander','takeout':'takeaway','stand in line':'queue',
 r'store clerk|grocery store':'shop assistant/supermarket','mailman|mailbox':'postman/postbox','first floor':None,
}
BAD={k:v for k,v in BAD.items() if v}
ALLOW={'Facebook Marketplace','Times Square','Centre Point'}
def lines():
  for f in glob.glob(os.path.join(A,'scenes','*.json')):
    d=json.load(open(f)); sid=os.path.basename(f)[:-5]
    for n in d['nodes'].values():
      yield sid,n['text']
      for b in n.get('branches',[]): yield sid,b['suggestion']
      for w in n.get('newWords',[]): yield sid,w.get('word','')
      if n.get('cultureNote'): yield sid,n['cultureNote'].get('en','') if isinstance(n['cultureNote'],dict) else str(n['cultureNote'])
  for f in ['characters.json','places.json','course.json']:
    def walk(o,path):
      if isinstance(o,dict):
        for k,v in o.items():
          if not k.endswith('Fa') and k not in ('fa','id','image','avatar','cover'): yield from walk(v,f'{path}.{k}')
      elif isinstance(o,list):
        for v in o: yield from walk(v,path)
      elif isinstance(o,str): yield path,o
    yield from walk(json.load(open(os.path.join(A,f))),f)
hits={}
for where,t in lines():
  if not t or re.search(r'[\u0600-\u06FF]',t) or re.search(r'Americ|\bUS\b|\(US\)|British vs|British spelling|in America',t): continue
  for rx,br in BAD.items():
    m=re.search(r'\b(?:'+rx+r')\b',t,re.I)
    if m and not any(a in t for a in ALLOW):
      hits.setdefault((m.group(0).lower(),br),[]).append((where,t))
for (w,br),L in sorted(hits.items(),key=lambda x:-len(x[1])):
  print(f'{len(L):4d}  {w!r} -> {br}   e.g. [{L[0][0]}] {L[0][1][:110]}')
sys.exit(1 if hits else 0)
