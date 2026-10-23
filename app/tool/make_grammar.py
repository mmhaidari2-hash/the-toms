"""Grammar School: tool/grammar/<level>.txt -> assets/data/grammar.json.
DSL:  # id | level | title | titleFa | R: regex for related course lessons (matched on lesson.grammar)
      T: teacher line | Persian          (Mrs Ellis explains; voiced as 'ellis')
      E: example | Persian               (voiced as 'ellis')
      P: kind | prompt | answers         practice;  M: same = mini test
kinds: gap (prompt has ___; answers 'right ; wrong ; wrong'), choose (prompt; 'right ; wrong ; wrong'),
       order (the sentence; tiles are its words), transform (prompt; accepted answers 'a ; b')."""
import json,os,re,glob,sys
H=os.path.dirname(os.path.abspath(__file__)); A=os.path.join(H,'..','assets')
course=json.load(open(os.path.join(A,'data/course.json')))
LV={'A1':1,'A2':2,'B1':3,'B2':4,'C1':5}
topics=[]; errs=[]
for f in sorted(glob.glob(os.path.join(H,'grammar','*.txt'))):
  t=None
  for ln in open(f,encoding='utf-8'):
    ln=ln.strip()
    if not ln: continue
    if ln.startswith('# '):
      p=[x.strip() for x in ln[2:].split('|')]
      rx=p[4][2:].strip() if len(p)>4 and p[4].startswith('R:') else ''
      t={'id':p[0],'level':p[1],'title':p[2],'titleFa':p[3],'teach':[],'examples':[],'practice':[],'test':[],'related':[]}
      if rx:
        r=re.compile(rx)
        for u in course['units']:
          if u['level']>LV[p[1]]: continue
          for l in u['lessons']:
            if r.search(l.get('grammar','')) and len(t['related'])<3: t['related'].append(l['id']); break
      topics.append(t)
    elif ln[:2] in('T:','E:'):
      en,fa=[x.strip() for x in ln[2:].split('|')]
      t['teach' if ln[0]=='T' else 'examples'].append({'en':en,'fa':fa})
    elif ln[:2] in('P:','M:'):
      p=[x.strip() for x in ln[2:].split('|')]
      kind=p[0]; item={'kind':kind,'prompt':p[1]}
      if kind in('gap','choose','transform'): item['answers']=[a.strip() for a in p[2].split(';')]
      if kind=='gap' and '___' not in p[1]: errs.append(f"{t['id']}: gap without ___: {p[1]}")
      if kind=='order': item['answers']=[p[1]]
      if kind not in('gap','choose','order','transform'): errs.append(f"{t['id']}: bad kind {kind}")
      t['practice' if ln[0]=='P' else 'test'].append(item)
# syllabus order inside each class (topics not listed keep file order, after the listed ones)
ORDER='''a1_be a1_this a1_poss a1_plurals a1_articles a1_there a1_have a1_present a1_do a1_freq a1_qwords a1_can a1_imp a1_prep a1_obj a1_wouldlike
a2_cont a2_simple_cont a2_was a2_past_reg a2_past_irr a2_past_cont a2_going_to a2_will a2_count a2_compare a2_adverbs a2_too a2_should a2_verbpat
b1_pp b1_pp_past b1_ppc b1_pastperf b1_future b1_zero b1_first_cond b1_modals b1_able b1_relative b1_gerinf b1_edadj b1_tags b1_indirect b1_phrasal
b2_used_to b2_ppc_past b2_future b2_second_cond b2_third_cond b2_condlinks b2_passive b2_reported b2_reporting b2_deduction b2_shouldhave b2_nondef b2_linking b2_participle
c1_future_past c1_mixed_cond c1_wish c1_modals c1_inversion c1_cleft c1_emphasis c1_causative c1_subjunctive c1_ellipsis c1_formal'''.split()
ids=[t['id'] for t in topics]
for i in ids:
  if ids.count(i)>1: errs.append(f'duplicate id {i}')
topics.sort(key=lambda t:(LV[t['level']], ORDER.index(t['id']) if t['id'] in ORDER else 999))
for t in topics:
  if len(t['teach'])<2 or len(t['examples'])<2 or len(t['practice'])<5 or len(t['test'])<4: errs.append(f"{t['id']}: too few items")
  if not t['related']: errs.append(f"{t['id']}: no related lesson")
if errs: print('\n'.join(errs)); sys.exit(1)
json.dump({'topics':topics},open(os.path.join(A,'data/grammar.json'),'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
for t in topics: print(t['level'],t['id'],len(t['practice']),'+',len(t['test']),'related',t['related'])
