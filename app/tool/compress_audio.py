"""Re-encode voice clips to 24 kbps mono MP3 (speech quality, half the size) so 1000 lessons fit GitHub Pages.
Idempotent: clips already at <=24 kbps are skipped (bitrate read from the first MPEG frame header)."""
import os,sys,subprocess
from concurrent.futures import ThreadPoolExecutor
D=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','audio')
BR={1:[0,32,40,48,56,64,80,96,112,128,160,192,224,256,320],0:[0,8,16,24,32,40,48,56,64,80,96,112,128,144,160]}
def kbps(p):
  b=open(p,'rb').read(4096); i=0
  if b[:3]==b'ID3': i=10+((b[6]<<21)|(b[7]<<14)|(b[8]<<7)|b[9])
  b=open(p,'rb').read(i+4096)[i:] if i>=4096-4 else b[i:]
  for j in range(len(b)-3):
    if b[j]==0xFF and (b[j+1]&0xE0)==0xE0:
      v=(b[j+1]>>3)&3; return BR[1 if v==3 else 0][b[j+2]>>4]
  return 0
def one(f):
  p=os.path.join(D,f)
  if b'Lavf' in open(p,'rb').read(256) or kbps(p)<=24: return 0  # ffmpeg-written (already compressed) or low bitrate
  t=p+'.c.mp3'
  r=subprocess.run(['ffmpeg','-loglevel','error','-y','-i',p,'-ac','1','-ar','24000','-b:a','24k',t])
  if r.returncode==0 and os.path.getsize(t)>200: os.replace(t,p); return 1
  if os.path.exists(t): os.remove(t)
  return 0
if __name__=='__main__':
  fs=[f for f in os.listdir(D) if f.endswith('.mp3') and not f.endswith('.c.mp3')]
  with ThreadPoolExecutor(int(sys.argv[1]) if len(sys.argv)>1 else 8) as ex: n=sum(ex.map(one,fs))
  print(n,'clips compressed of',len(fs))
