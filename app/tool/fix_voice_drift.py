#!/usr/bin/env python3
"""One-off repair (2026-10): find clips rendered with an older voice than their speaker's current one (voice settings
changed, or the speaker had no voice yet and fell back to the narrator) by re-rendering and comparing durations
(edge-tts output is deterministic for the same text+voice). Replaces drifted clips, then records every clip's voice in
tool/audit/voice_manifest.json so render_voices.py re-renders automatically when a voice changes.
Usage: python3 tool/fix_voice_drift.py [speaker ...|--sample N|--keys file]"""
import asyncio, json, os, random, subprocess, sys
import edge_tts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_voice_sync as a
items, V, OUT = a.load_items()
TMP = '/tmp/voice_drift'; os.makedirs(TMP, exist_ok=True)
def dur(p): return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p], capture_output=True, text=True).stdout or 0)
args = sys.argv[1:]
if args[:1] == ['--keys']: keys = [k for k in open(args[1]).read().split() if k in items]
elif args[:1] == ['--sample']: keys = random.Random(5).sample(list(items), int(args[1]))
else: keys = [k for k, (sp, t) in items.items() if sp in args]
drift, fail = {}, []
async def one(k, sem):
    sp, t = items[k]; v, p, r = V.get(sp, V['narrator'])
    raw, c = f'{TMP}/{k}.raw.mp3', f'{TMP}/{k}.mp3'
    async with sem:
        for i in range(4):
            try:
                await asyncio.wait_for(edge_tts.Communicate(t, v, pitch=p, rate=r).save(raw), 40); break
            except Exception: await asyncio.sleep(2 + 3 * i)
        else: fail.append(k); return
    await asyncio.to_thread(subprocess.run, ['ffmpeg', '-v', 'quiet', '-y', '-i', raw, '-ac', '1', '-ar', '24000', '-b:a', '24k', c])
    old, new = dur(f'{OUT}/{k}.mp3'), dur(c)
    if new > 0.3 and abs(old - new) > 0.05:
        drift[k] = (sp, round(old, 2), round(new, 2), t[:60]); os.replace(c, f'{OUT}/{k}.mp3')
async def main():
    sem = asyncio.Semaphore(10); await asyncio.gather(*[one(k, sem) for k in keys])
asyncio.run(main())
from collections import Counter
print(len(keys), 'clips re-checked;', len(drift), 'were in a different voice and were re-rendered;', len(fail), 'failed')
print(dict(Counter(v[0] for v in drift.values())))
rep = '/workspace/british-life/app/build/voice_drift.json'
old = json.load(open(rep)) if os.path.exists(rep) else {}
old.update(drift); json.dump(old, open(rep, 'w'), indent=0, ensure_ascii=False)
