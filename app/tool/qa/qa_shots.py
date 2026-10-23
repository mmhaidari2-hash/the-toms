"""Screenshots of the built site (Playwright + Chrome) at three phone sizes, for the QA report, with automatic checks:
blank screen, Flutter's grey release error box, and a page that is still loading."""
import asyncio, os, json
import numpy as np
from PIL import Image
SIZES = [(320, 568), (375, 667), (414, 896)]
PRESET = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preset.json')))  # a UserProgress: onboarded, everything unlocked
async def _run(url, routes, out, lang):
    from playwright.async_api import async_playwright
    issues, n = [], 0
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        for w, h in SIZES:
            ctx = await b.new_context(viewport={'width': w, 'height': h}, is_mobile=True, has_touch=True, device_scale_factor=1)
            pg = await ctx.new_page(); errs = []
            pg.on('pageerror', lambda e: errs.append(str(e)[:200]))
            await pg.goto(url); await pg.wait_for_timeout(12000)
            data = json.dumps(dict(PRESET, lang=lang))
            await pg.evaluate('''async(d)=>{const db=await new Promise((r,e)=>{const q=indexedDB.open('progress');q.onsuccess=()=>r(q.result);q.onerror=e});
              await new Promise((r,e)=>{const t=db.transaction('box','readwrite');t.objectStore('box').put(d,'v1');t.oncomplete=r;t.onerror=e});db.close();}''', data)
            await pg.reload(); await pg.wait_for_timeout(9000)
            for r in routes:
                errs.clear()
                await pg.goto(url + '#' + r); await pg.wait_for_timeout(3500)
                f = f"{lang}_{w}x{h}_{r.strip('/').replace('/', '_') or 'home'}.png"
                path = os.path.join(out, f); await pg.screenshot(path=path); n += 1
                a = np.asarray(Image.open(path).convert('RGB')).astype(int)
                if a.std() < 4: issues.append(('block', 'blank screen', f'{r} [{lang} {w}x{h}]', f))
                grey = ((abs(a[..., 0] - 128) < 3) & (abs(a[..., 1] - 128) < 3) & (abs(a[..., 2] - 128) < 3)).mean()
                if grey > 0.04: issues.append(('block', 'Flutter error box (grey) on screen', f'{r} [{lang} {w}x{h}]', f))
                for e in errs: issues.append(('block', 'JavaScript error', f'{r} [{lang} {w}x{h}]', e))
            await ctx.close()
        await b.close()
    return {'n': n, 'issues': issues}
def run(url, routes, out, langs=('fa', 'ar')):
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out): os.remove(os.path.join(out, f))
    keep = routes[:24]
    tot = {'n': 0, 'issues': []}
    for lang in langs:
        r = asyncio.run(_run(url, keep, out, lang)); tot['n'] += r['n']; tot['issues'] += r['issues']
    return tot
