"""Procedural, role-specific avatars for NPCs that have no hand-drawn art.
Each NPC gets its own skin/hair/clothes/background and a role prop, so none is a copy of another character."""
import os
OUT=os.path.join(os.path.dirname(__file__),'..','assets','avatars')
SK={'fair':'#F6D2B8','light':'#F1C7A5','tan':'#D9A47A','brown':'#B07A52','deep':'#7A4E32'}
def hair(style,c):
  return {
   'short':f'<path d="M60 84 Q58 46 100 46 Q142 46 140 84 Q128 64 100 64 Q72 64 60 84 Z" fill="{c}"/>',
   'buzz':f'<path d="M62 80 Q62 50 100 50 Q138 50 138 80 Q120 62 100 62 Q80 62 62 80 Z" fill="{c}" opacity=".85"/>',
   'bald':f'<path d="M62 84 Q60 72 66 66 L70 84 Z M138 84 Q140 72 134 66 L130 84 Z" fill="{c}"/>',
   'bob':f'<path d="M56 110 Q50 44 100 44 Q150 44 144 110 L132 110 Q136 70 112 66 Q100 76 74 68 Q64 80 68 110 Z" fill="{c}"/>',
   'long':f'<path d="M54 140 Q46 44 100 42 Q154 44 146 140 L132 140 Q138 74 112 66 Q96 78 72 68 Q62 90 68 140 Z" fill="{c}"/>',
   'bun':f'<circle cx="100" cy="40" r="15" fill="{c}"/><path d="M60 86 Q58 48 100 48 Q142 48 140 86 Q124 64 100 66 Q76 64 60 86 Z" fill="{c}"/>',
   'curly':''.join(f'<circle cx="{x}" cy="{y}" r="13" fill="{c}"/>' for x,y in [(66,70),(78,54),(96,48),(114,50),(130,60),(138,76),(62,86)]),
   'pony':f'<path d="M140 80 Q170 100 150 140 Q156 104 136 92 Z" fill="{c}"/><path d="M60 86 Q58 46 100 46 Q142 46 140 86 Q124 64 100 66 Q76 64 60 86 Z" fill="{c}"/>',
  }[style]
def prop(p):
  return {
   'none':'',
   'glasses':'<g stroke="#222" stroke-width="3" fill="none"><circle cx="86" cy="90" r="10"/><circle cx="114" cy="90" r="10"/><line x1="96" y1="90" x2="104" y2="90"/></g>',
   'beard':'<path d="M64 98 Q66 134 100 136 Q134 134 136 98 Q128 120 100 118 Q72 120 64 98 Z" fill="{h}"/>',
   'moustache':'<path d="M84 104 Q100 96 116 104 Q100 102 84 104 Z" fill="{h}" stroke="{h}" stroke-width="3"/>',
   'cap':'<path d="M58 74 Q60 40 100 40 Q140 40 142 74 Z" fill="{a}"/><path d="M58 72 L160 76 Q150 84 132 78 L58 78 Z" fill="{a}"/>',
   'policehat':'<path d="M58 70 Q60 34 100 32 Q140 34 142 70 Z" fill="#111827"/><rect x="56" y="64" width="88" height="10" fill="#111827"/><g fill="#fff"><rect x="56" y="64" width="11" height="10"/><rect x="78" y="64" width="11" height="10"/><rect x="100" y="64" width="11" height="10"/><rect x="122" y="64" width="11" height="10"/></g><circle cx="100" cy="50" r="7" fill="#C0C7D1"/>',
   'headset':'<path d="M58 92 Q58 42 100 42 Q142 42 142 92" stroke="#222" stroke-width="5" fill="none"/><rect x="52" y="84" width="12" height="20" rx="5" fill="#222"/><path d="M60 104 Q66 120 84 118" stroke="#222" stroke-width="3" fill="none"/><circle cx="86" cy="118" r="4" fill="#222"/>',
   'hijab':'<path d="M50 150 Q44 40 100 38 Q156 40 150 150 L134 150 Q140 70 100 58 Q60 70 66 150 Z" fill="{a}"/>',
   'hardhat':'<path d="M56 74 Q58 36 100 36 Q142 36 144 74 Z" fill="#FACC15"/><rect x="50" y="70" width="100" height="8" rx="4" fill="#EAB308"/>',
   'earrings':'<circle cx="60" cy="104" r="4" fill="#FBBF24"/><circle cx="140" cy="104" r="4" fill="#FBBF24"/>',
  }[p]
def body(kind,c,a):
  base=f'<path d="M30 210 Q32 150 100 146 Q168 150 170 210 Z" fill="{c}"/>'
  extra={
   'shirt':f'<path d="M86 148 L100 166 L114 148" stroke="#fff" stroke-width="4" fill="none"/>',
   'tie':f'<path d="M86 148 L100 162 L114 148" fill="#fff"/><path d="M96 160 L104 160 L106 196 L100 204 L94 196 Z" fill="{a}"/>',
   'hivis':f'<path d="M52 170 L70 150 L84 210 L66 210 Z M148 170 L130 150 L116 210 L134 210 Z" fill="#D9F99D"/><path d="M58 186 L78 182 M142 186 L122 182" stroke="#E5E7EB" stroke-width="5"/>',
   'scrubs':f'<path d="M84 148 L100 170 L116 148" fill="#fff" opacity=".6"/>',
   'stetho':f'<path d="M78 150 Q74 186 100 188 Q126 186 122 150" stroke="#374151" stroke-width="4" fill="none"/><circle cx="100" cy="190" r="6" fill="#9CA3AF"/>',
   'overalls':f'<rect x="72" y="166" width="56" height="44" fill="{a}"/><path d="M76 168 L72 148 M124 168 L128 148" stroke="{a}" stroke-width="7"/>',
   'cardigan':f'<path d="M100 150 L100 210" stroke="{a}" stroke-width="6"/><circle cx="100" cy="176" r="3" fill="#fff"/><circle cx="100" cy="192" r="3" fill="#fff"/>',
   'lanyard':f'<path d="M84 150 L100 186 L116 150" stroke="{a}" stroke-width="3" fill="none"/><rect x="92" y="184" width="16" height="20" rx="2" fill="#fff"/>',
   'police':f'<path d="M84 150 L100 166 L116 150" fill="#fff"/><path d="M50 176 L150 176 L150 192 L50 192 Z" fill="#D9F99D" opacity=".9"/>',
  }[kind]
  return base+extra
def svg(bg,skin,hs,hc,cloth,kind,acc='#1F2937',props=(),mouth='smile'):
  h=hair(hs,hc); P=''.join(prop(p).replace('{h}',hc).replace('{a}',acc) for p in props)
  front=[p for p in props if p in('hijab',)]
  m={'smile':'<path d="M89 106 Q100 116 111 106" stroke="#7A3B2E" stroke-width="3.2" fill="none" stroke-linecap="round"/>',
     'flat':'<path d="M90 109 L110 109" stroke="#7A3B2E" stroke-width="3.2" stroke-linecap="round"/>',
     'grin':'<path d="M86 104 Q100 120 114 104 Z" fill="#7A3B2E"/>'}[mouth]
  s=SK[skin]
  under=hair('long',hc) if False else ''
  return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200"><defs><clipPath id="c"><circle cx="100" cy="100" r="100"/></clipPath></defs><g clip-path="url(#c)">'
   f'<rect width="200" height="200" fill="{bg}"/><circle cx="40" cy="40" r="26" fill="#fff" opacity=".35"/><circle cx="170" cy="150" r="34" fill="#fff" opacity=".25"/>'
   + (h if hs in('long','bob') and 'hijab' not in props else '') +
   body(kind,cloth,acc)+f'<rect x="88" y="118" width="24" height="22" rx="8" fill="{s}"/>'
   f'<circle cx="60" cy="92" r="8" fill="{s}"/><circle cx="140" cy="92" r="8" fill="{s}"/><circle cx="100" cy="88" r="40" fill="{s}"/>'
   '<circle cx="86" cy="90" r="4.2" fill="#2A2320"/><circle cx="114" cy="90" r="4.2" fill="#2A2320"/><circle cx="87.5" cy="88.5" r="1.3" fill="#fff"/><circle cx="115.5" cy="88.5" r="1.3" fill="#fff"/>'
   '<circle cx="77" cy="102" r="6" fill="#F08A8A" opacity=".4"/><circle cx="123" cy="102" r="6" fill="#F08A8A" opacity=".4"/>'+m
   + ('' if hs in('long','bob') or 'hijab' in props or any(p in props for p in('policehat','hardhat')) else h)
   + (h if hs in('long','bob') and 'hijab' not in props else '')*0 + P + '</g></svg>')
NPC={
 'courier':  dict(bg='#FDE7D3',skin='light',hs='buzz',hc='#3B2A1E',cloth='#C2410C',kind='hivis',props=('cap',),acc='#C2410C',mouth='grin'),
 'engineer': dict(bg='#E5E7EB',skin='fair',hs='short',hc='#B45309',cloth='#4B5563',kind='overalls',acc='#1E3A8A',props=('beard',)),
 'khan':     dict(bg='#CCFBF1',skin='brown',hs='long',hc='#111',cloth='#0F766E',kind='cardigan',acc='#F59E0B',props=('hijab','earrings'),mouth='grin'),
 'receptionist':dict(bg='#EDE9FE',skin='fair',hs='bob',hc='#D97706',cloth='#7C3AED',kind='lanyard',acc='#1F2937',props=('headset',)),
 'vet':      dict(bg='#DCFCE7',skin='tan',hs='pony',hc='#1F2937',cloth='#15803D',kind='scrubs',props=('glasses',)),
 'triage':   dict(bg='#FEE2E2',skin='deep',hs='bun',hc='#111',cloth='#1D4ED8',kind='stetho',props=('earrings',)),
 'schooloffice':dict(bg='#FCE7F3',skin='light',hs='curly',hc='#9CA3AF',cloth='#9D174D',kind='cardigan',acc='#FBCFE8',props=('glasses',)),
 'police':   dict(bg='#DBEAFE',skin='light',hs='short',hc='#6B4423',cloth='#111827',kind='police',props=('policehat',),mouth='flat'),
 'energy':   dict(bg='#FEF9C3',skin='tan',hs='short',hc='#111',cloth='#CA8A04',kind='shirt',props=('headset',),mouth='grin'),
 'agent':    dict(bg='#FCE7F3',skin='fair',hs='long',hc='#F5D07A',cloth='#BE185D',kind='lanyard',acc='#111',props=('earrings',),mouth='grin'),
 'mechanic': dict(bg='#E5E7EB',skin='fair',hs='bald',hc='#9CA3AF',cloth='#374151',kind='overalls',acc='#DC2626',props=('moustache',)),
 'workcoach':dict(bg='#CFFAFE',skin='deep',hs='buzz',hc='#111',cloth='#0E7490',kind='tie',acc='#FACC15',props=('glasses',)),
 'council':  dict(bg='#EDE9FE',skin='light',hs='bob',hc='#7C2D12',cloth='#6D28D9',kind='lanyard',acc='#6D28D9',props=('glasses','earrings'),mouth='flat'),
 'vida':     dict(bg='#FCE7F3',skin='light',hs='pony',hc='#5B3A29',cloth='#B5577B',kind='lanyard',acc='#FBBF24',props=('earrings',),mouth='grin'),
 'jo':       dict(bg='#CFFAFE',skin='fair',hs='bob',hc='#B45309',cloth='#0E7490',kind='lanyard',acc='#0E7490',props=('glasses',)),
 'oscar':    dict(bg='#DCFCE7',skin='brown',hs='curly',hc='#1F2937',cloth='#16A34A',kind='shirt',props=(),mouth='grin'),
 'dan':      dict(bg='#FEF3C7',skin='fair',hs='short',hc='#C2913A',cloth='#065F46',kind='hivis',props=('beard',)),
 'harris':   dict(bg='#E2E8F0',skin='tan',hs='bald',hc='#6B7280',cloth='#334155',kind='tie',acc='#7C3AED',props=('glasses',),mouth='flat'),
}
if __name__=='__main__':
  for k,v in NPC.items(): open(os.path.join(OUT,k+'.svg'),'w').write(svg(**v))
  print(len(NPC),'npc avatars')
