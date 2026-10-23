"""Painted map-spot icons: a square crop of each spot's own painting (or of the map painting around the spot),
so the map uses one painted style instead of platform emoji. Writes assets/spots/<id>.webp (128px)."""
import json,os
from PIL import Image
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets'); OUT=os.path.join(A,'spots'); os.makedirs(OUT,exist_ok=True)
SRC={'home':('kitchen',.5),'playdate':('playdate',.5),'bus':('bus',.35),'nursery':('firstday',.5),'homes':(None,0),'school':('school',.5),'park':('park',.5),
 'station':('train',.5),'cafe':('coffee',.45),'restaurant':('restaurant',.5),'pharmacy':('pharmacy',.5),'shops':('bakery',.5),'barber':('barber',.5),
 'supermarket':('supermarket',.5),'shoppingcentre':('shoppingcentre',.5),'library':('library',.5),'postoffice':('postoffice',.5),'bank':('bank',.5),
 'gp':('gp',.5),'hospital':('doctor',.5),'museum':(None,0),'cinema':(None,0),'radio':(None,0),'missions':(None,0),'gym':('gym',.5),'pub':('pub',.5),'garage':('petrol',.5),
 'work':('interview',.5),'university':('university',.5)}
spots=json.load(open(os.path.join(A,'data','spots.json')))
M=Image.open(os.path.join(A,'places','map.webp')).convert('RGB')
for s in spots:
  pl,fx=SRC.get(s['id'],(None,0))
  own=os.path.join(H,'spot_src',s['id']+'.jpg')  # a painting made for the spot itself (e.g. the estate agent's shopfront)
  if os.path.exists(own):
    im=Image.open(own).convert('RGB'); w,h=im.size; c=im.crop((int(w*.2),int(h*.24),int(w*.86),int(h*.9)))
  elif pl:
    im=Image.open(os.path.join(A,'places',pl+'.webp')).convert('RGB'); w,h=im.size; side=int(h*.8)
    x=int(min(max(fx*w-side/2,0),w-side)); y=int((h-side)*.35); c=im.crop((x,y,x+side,y+side))
  else:  # no painting of its own: a painted crop of the map around the spot
    w,h=M.size; side=int(h*.16); x=int(min(max(s['x']*w-side/2,0),w-side)); y=int(min(max(s['y']*h-side*.7,0),h-side)); c=M.crop((x,y,x+side,y+side))
  c.resize((128,128),Image.LANCZOS).save(os.path.join(OUT,s['id']+'.webp'),quality=80)
print(len(spots),'painted spot icons')
