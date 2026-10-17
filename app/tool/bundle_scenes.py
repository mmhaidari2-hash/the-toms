"""One compact scenes_bundle.json instead of ~2000 per-scene requests at app start (iPhone)."""
import json,os
A=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','data')
ids=json.load(open(os.path.join(A,'scenes_index.json')))
b={i:json.load(open(os.path.join(A,'scenes',i+'.json'))) for i in ids}
json.dump(b,open(os.path.join(A,'scenes_bundle.json'),'w'),ensure_ascii=False,separators=(',',':'))
print(len(b),'scenes bundled',os.path.getsize(os.path.join(A,'scenes_bundle.json'))//1024,'KB')
