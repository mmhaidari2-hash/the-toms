#!/usr/bin/env python3
"""Whole-corpus voice/text sync audit (2026-10). Every line the app can speak must be ONE clip in ONE voice that
matches its speaker, complete to the end. Checks, for every (speaker, text) that tool/render_voices.py renders:
  missing / empty clip · clip too short or too long for its word count (truncated or runaway render)
  · abrupt ending (still speaking in the last 60 ms, no trailing silence) · voice config drift: the clip was rendered
  with a different voice than the speaker's current one (tool/audit/voice_manifest.json, written by render_voices.py).
Usage: python3 tool/audit_voice_sync.py [--json build/voice_audit.json]   Exit 1 on any problem."""
import json, os, re, subprocess, sys
from concurrent.futures import ProcessPoolExecutor
import numpy as np
H = os.path.dirname(os.path.abspath(__file__))
def load_items():
    s = open(os.path.join(H, 'render_voices.py')).read(); s = s[:s.index('todo=')]
    g = {'__file__': os.path.join(H, 'render_voices.py')}; cwd = os.getcwd(); os.chdir(H)
    try: exec(s, g)
    finally: os.chdir(cwd)
    return g['items'], g['V'], g['OUT']
def words(t): return len(re.findall(r"[A-Za-z0-9']+", t))
def scan(arg):
    k, sp, t, path = arg
    if not os.path.exists(path) or os.path.getsize(path) < 300: return (k, 'missing', 0, 0)
    pcm = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', path, '-f', 's16le', '-ac', '1', '-ar', '16000', '-'], capture_output=True).stdout
    x = np.frombuffer(pcm, np.int16).astype(np.float32)
    sec = len(x) / 16000
    if len(x) < 1600: return (k, 'empty', sec, 0)
    fr = x[: len(x) // 320 * 320].reshape(-1, 320); rms = np.sqrt((fr ** 2).mean(1)) + 1e-6  # 20 ms frames
    peak = np.percentile(rms, 95); tail = rms[-3:].max() / peak  # last 60 ms vs the loud part
    w = words(t)
    if w and sec < 0.12 * w + 0.25: return (k, 'short', sec, tail)
    if w and sec > 0.8 * w + 3: return (k, 'long', sec, tail)
    if tail > 0.12: return (k, 'abrupt', sec, tail)
    return (k, 'ok', sec, tail)
def sig(V, sp): return '|'.join(V.get(sp, V['narrator']))
if __name__ == '__main__':
    items, V, OUT = load_items()
    man_p = os.path.join(H, 'audit', 'voice_manifest.json')
    man = json.load(open(man_p)) if os.path.exists(man_p) else {}
    args = [(k, sp, t, f'{OUT}/{k}.mp3') for k, (sp, t) in items.items()]
    with ProcessPoolExecutor(8) as ex: res = list(ex.map(scan, args, chunksize=64))
    bad = {}
    for k, st, sec, tail in res:
        sp, t = items[k]
        if st != 'ok': bad[k] = dict(sp=sp, text=t, problem=st, sec=round(sec, 2), tail=round(float(tail), 3))
        m = man.get(k)
        if m is None: bad.setdefault(k, dict(sp=sp, text=t, problem='no-manifest', sec=round(sec, 2)))
        elif m[0] != sp or m[1] != sig(V, sp): bad[k] = dict(sp=sp, text=t, problem='voice-drift', was=m, sec=round(sec, 2))
        if sp not in V: bad[k] = dict(sp=sp, text=t, problem='no-voice (narrator fallback)')
    from collections import Counter
    print(len(items), 'clips checked;', len(bad), 'problems:', dict(Counter(b['problem'] for b in bad.values())))
    by = Counter((b['problem'], b['sp']) for b in bad.values())
    for (p, sp), n in sorted(by.items(), key=lambda x: -x[1])[:40]: print(f'  {p:12} {sp:12} {n}')
    if '--json' in sys.argv:
        out = sys.argv[sys.argv.index('--json') + 1]; os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
        json.dump(bad, open(out, 'w'), indent=0, ensure_ascii=False)
    sys.exit(1 if bad else 0)
