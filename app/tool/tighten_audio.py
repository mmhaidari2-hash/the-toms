"""Natural timing for TTS clips. Azure leaves ~1 s of silence at every sentence boundary and ~0.9 s at the end, so
short lines sound like separate, detached sentences ("Hello! ... I'm Tom."). This shortens long pauses inside a clip
to PAUSE, trims the lead-in to LEAD and the tail to TAIL, levels the loudness to LOUD (after a short fade, never into the last word), and writes
24 kbps mono MP3. Idempotent: a clip whose pauses are already short is left as it is.
Usage: python3 tool/tighten_audio.py [keys...]   (no keys: every clip in tool/audit/voice_engine.json)"""
import os, sys, json, subprocess, numpy as np
from concurrent.futures import ThreadPoolExecutor
H = os.path.dirname(os.path.abspath(__file__)); AUD = os.path.join(H, '..', 'assets', 'audio')
SR = 24000; FR = 240  # 10 ms frames
PAUSE, LEAD, TAIL = 0.42, 0.06, 0.30  # seconds
LOUD = -21.0  # dBFS median of the speech frames: every voice at one level, so lines never jump in volume
def load(p):
    r = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', p, '-f', 's16le', '-ac', '1', '-ar', str(SR), '-'], capture_output=True)
    return np.frombuffer(r.stdout, np.int16).astype(np.float32)
def frames_db(x):
    n = len(x) // FR
    if n == 0: return np.array([])
    e = np.sqrt(np.mean(x[:n * FR].reshape(n, FR) ** 2, axis=1) + 1e-9)
    return 20 * np.log10(e / 32768 + 1e-12)
def silent_runs(db, thr):
    runs, s = [], None
    for i, v in enumerate(db):
        if v < thr and s is None: s = i
        elif v >= thr and s is not None: runs.append((s, i)); s = None
    if s is not None: runs.append((s, len(db)))
    return runs
def plan(x):
    db = frames_db(x)
    if len(db) == 0: return None
    thr = max(-50.0, np.percentile(db, 95) - 38)  # relative to the loud speech, so quiet voices are not cut
    runs = silent_runs(db, thr)
    return db, thr, runs
CEIL = 0.84  # limiter ceiling (-1.5 dBFS): leaves headroom for MP3 encoding overshoot, so decoded peaks never hit full scale
SEG_MAX = 9.0  # dB: most a single sentence is raised or lowered to match the others
def level(y):
    """Even out loudness between the sentences of one clip, then a look-ahead peak limiter. Returns (y, changed)."""
    db = frames_db(y)
    if len(db) < 10: return y, False
    thr = max(-50.0, float(np.percentile(db, 95)) - 38); sp = np.where(db >= thr)[0]
    if len(sp) == 0: return y, False
    segs, s0 = [], sp[0]
    for a, b in zip(sp, sp[1:]):
        if b - a > 25: segs.append((s0, a)); s0 = b
    segs.append((s0, sp[-1]))
    segs = [(a, b) for a, b in segs if b - a >= 15]
    changed = False
    if len(segs) > 1:
        med = [float(np.median(db[a:b + 1])) for a, b in segs]  # same measure as qa_audio's 'jump'
        tgt = float(np.median(db[sp]))
        gs = [float(np.clip(tgt - m, -SEG_MAX, SEG_MAX)) for m in med]
        if max(abs(g) for g in gs) > 1.5:
            # per-frame gain: each sentence its own gain, linear ramps across the pauses between them
            xs = [c for (a, b) in segs for c in (a, b)]; ys = [g for g in gs for _ in (0, 1)]
            gf = np.interp(np.arange(len(db)), xs, ys)
            gsmp = np.repeat(10 ** (gf / 20), FR)
            gsmp = np.concatenate([gsmp, np.full(max(0, len(y) - len(gsmp)), gsmp[-1])])[:len(y)]
            y = y * gsmp; changed = True
    # look-ahead limiter on 1 ms blocks: attack over 5 ms ahead of a peak, 60 ms release
    B = 24; n = len(y) // B
    if n > 8:
        pk = np.abs(y[:n * B]).reshape(n, B).max(axis=1)
        need = np.minimum(1.0, CEIL * 32768 / np.maximum(pk, 1.0))
        if need.min() < 0.999:
            la = np.lib.stride_tricks.sliding_window_view(np.concatenate([need, np.ones(5)]), 6).min(axis=1)[:n]
            g = np.empty(n); cur = 1.0; rel = 1 - np.exp(-1 / 60)
            for i, v in enumerate(la):
                cur = v if v < cur else cur + (v - cur) * rel
                g[i] = cur
            gs = np.repeat(g, B); gs = np.concatenate([gs, np.full(len(y) - len(gs), g[-1])])
            y = y * gs; changed = True
            y = np.clip(y, -CEIL * 32768, CEIL * 32768)
    return y, changed
def tighten(x):
    p = plan(x)
    if p is None: return x, False
    db, thr, runs = p
    n = len(db); keep = np.ones(len(x), bool); changed = False
    for s, e in runs:
        L = (e - s) * FR / SR
        if s == 0:  # lead-in
            if L > LEAD + 0.02: keep[: max(0, e * FR - int(LEAD * SR))] = False; changed = True
        elif e >= n:  # tail: keep TAIL after the last speech frame
            if L > TAIL + 0.02: keep[s * FR + int(TAIL * SR):] = False; changed = True
        elif L > PAUSE + 0.04:  # a pause inside: keep both edges (breath / release of the consonant), drop the middle
            a = s * FR + int(PAUSE / 2 * SR); b = e * FR - int(PAUSE / 2 * SR); keep[a:b] = False; changed = True
    sp = db >= thr
    g = LOUD - float(np.median(db[sp])) if sp.any() else 0.0
    peak = float(np.max(np.abs(x))) or 1.0
    g = min(g, 20 * np.log10(32000 / peak))  # never clip
    if abs(g) > 1.0: changed = True
    y = x[keep] * (10 ** (g / 20) if abs(g) > 1.0 else 1.0)
    y, lc = level(y)
    if not (changed or lc): return x, False
    f = int(0.06 * SR)  # short fade at the very end so the tail cut never clicks
    if len(y) > f: y[-f:] *= np.linspace(1, 0, f)
    return y, True
def one(k):
    p = os.path.join(AUD, k + '.mp3')
    if not os.path.exists(p): return 0
    x = load(p)
    y, ch = tighten(x)
    if not ch: return 0
    t = p + '.t.mp3'
    r = subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', '-b:a', '24k', t],
                       input=np.clip(y, -32768, 32767).astype(np.int16).tobytes())
    if r.returncode == 0 and os.path.getsize(t) > 200: os.replace(t, p); return 1
    if os.path.exists(t): os.remove(t)
    return 0
if __name__ == '__main__':
    ks = sys.argv[1:] or json.load(open(os.path.join(H, 'audit', 'voice_engine.json')))
    with ThreadPoolExecutor(int(os.environ.get('TIGHTEN_THREADS', '4'))) as ex: n = sum(ex.map(one, ks))
    print(n, 'clips tightened of', len(ks))
