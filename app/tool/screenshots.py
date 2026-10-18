import asyncio,sys,os
from playwright.async_api import async_playwright
BASE=sys.argv[1]; O=sys.argv[2]; os.makedirs(O,exist_ok=True)
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch(executable_path='/usr/bin/google-chrome',args=['--no-sandbox','--autoplay-policy=no-user-gesture-required'])
    ctx=await b.new_context(viewport={'width':375,'height':667},is_mobile=True,has_touch=True,device_scale_factor=2)
    pg=await ctx.new_page(); pg.on('console', lambda m: print('CONSOLE', m.text[:300])); pg.on('pageerror', lambda e: print('PAGEERR', str(e)[:300])); await pg.goto(BASE); await pg.wait_for_timeout(15000)
    acts=sys.argv[3:]
    if acts and acts[0].startswith('preset='):
      # Skip onboarding: write a UserProgress JSON straight into the Hive box (IndexedDB 'progress'/'box', key 'v1'), then reload.
      val=acts.pop(0)[7:]; data=open(val[1:]).read() if val.startswith('@') else val
      await pg.evaluate('''async(d)=>{const db=await new Promise((r,e)=>{const q=indexedDB.open('progress');q.onsuccess=()=>r(q.result);q.onerror=e});
        await new Promise((r,e)=>{const t=db.transaction('box','readwrite');t.objectStore('box').put(d,'v1');t.oncomplete=r;t.onerror=e});db.close();}''', data)
      await pg.goto(BASE+'#/'); await pg.reload(); await pg.wait_for_timeout(12000)
    else:
      await pg.touchscreen.tap(187,489); await pg.wait_for_timeout(1200)
      await pg.touchscreen.tap(60,633); await pg.wait_for_timeout(1200)
      await pg.touchscreen.tap(187,308); await pg.wait_for_timeout(700)
    for a in acts:
      kind,val=a.split('=',1)
      if kind=='goto': await pg.goto(BASE+'#'+val); await pg.wait_for_timeout(7000)
      elif kind=='tap':
        x,y=map(int,val.split(',')); await pg.touchscreen.tap(x,y); await pg.wait_for_timeout(900)
      elif kind=='click':
        x,y=map(int,val.split(',')); await pg.mouse.click(x,y); await pg.wait_for_timeout(900)
      elif kind=='tapi':
        x,y=map(int,val.split(',')); await pg.touchscreen.tap(x*375/576,y*375/576); await pg.wait_for_timeout(900)
      elif kind=='type': await pg.keyboard.type(val.replace('_',' '),delay=40); await pg.wait_for_timeout(600)
      elif kind=='dumpdb': print('DB', await pg.evaluate('''async()=>{const db=await new Promise(r=>{const q=indexedDB.open('progress');q.onsuccess=()=>r(q.result)});const t=db.transaction('box');const a=await new Promise(r=>{const q=t.objectStore('box').getAllKeys();q.onsuccess=()=>r(q.result)});const v=await new Promise(r=>{const q=t.objectStore('box').getAll();q.onsuccess=()=>r(q.result)});db.close();return JSON.stringify([a,v.map(x=>typeof x+':'+String(x).slice(0,60))])}'''))
      elif kind=='drag':
        dx,dy=map(int,val.split(',')); cdp=await ctx.new_cdp_session(pg); x0,y0=187,400
        await cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':x0,'y':y0}]})
        for i in range(1,16):
          await cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':x0+dx*i/15,'y':y0+dy*i/15}]}); await pg.wait_for_timeout(25)
        await cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]}); await pg.wait_for_timeout(1500)
      elif kind=='hscroll':
        await pg.mouse.move(187,400); await pg.mouse.wheel(int(val),0); await pg.wait_for_timeout(1200)
      elif kind=='wait': await pg.wait_for_timeout(int(val))
      elif kind=='scroll':
        await pg.mouse.move(187,400); await pg.mouse.wheel(0,int(val)); await pg.wait_for_timeout(900)
      elif kind=='shot': await pg.screenshot(path=O+val); print(O+val)
    print('URL', pg.url); await b.close()
asyncio.run(main())
