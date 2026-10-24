"""Voice-identity QA (run 28; blocking). Catches a character whose voice did not really change, stale clips, and
two speakers in one scene who sound the same.
1. manifest: every clip's recorded (voice, pitch, rate) in tool/audit/voice_manifest.json matches the cast table
   (V in tool/render_voices.py) -> stale clips block (re-rendered with --fix).
2. re-voiced: a character whose cast entry differs from its stored voice print (tool/audit/voice_prints.json) must
   sound different from before: per-clip distance to the backed-up old clips (same key), else to the stored print.
3. scenes: no two speakers who share a scene (tool/audit/voice_groups.json) have the same voice+settings, the same
   voice at all, or acoustically near-identical prints.
Acoustic print = mean/std of 19 MFCCs over speech frames + median pitch (numpy only; parselmouth when available)."""
import os, re, json, random, subprocess, collections
import numpy as np
APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
AUD = os.path.join(APP, 'assets', 'audio'); AUDIT = os.path.join(APP, 'tool', 'audit')
PRINTS = os.path.join(AUDIT, 'voice_prints.json'); GROUPS = os.path.join(AUDIT, 'voice_groups.json')
SR = 16000
# Distances (print units), calibrated run 28: the same clip re-rendered in the same voice ~0.1-0.6; one character's
# 16-clip print vs another sample of it 0.8-1.9; two different neural voices 2.4-12; Nicola Maisie -> Abbi+25Hz ~5.
THRESH = {'newvoice_min': 2.0,   # cast voice changed: same-key old/new clips must be at least this far apart
          'retuned_min': 0.12,   # only pitch/rate changed: the clip must still differ measurably (not a stale copy)
          'scene_min': 1.6}      # two speakers in one scene: prints at least this far apart

def voices():
    src = open(os.path.join(APP, 'tool', 'render_voices.py')).read()
    m = re.search(r'^V=\{.*?^\}', src, re.S | re.M)
    return eval(m.group(0)[2:])
def sig(v): return '|'.join(v)

def _mel(n_fft=512, n_mel=40):
    f = np.linspace(0, SR / 2, n_fft // 2 + 1); m = lambda h: 2595 * np.log10(1 + h / 700); im = lambda x: 700 * (10 ** (x / 2595) - 1)
    pts = im(np.linspace(m(60), m(7600), n_mel + 2)); fb = np.zeros((n_mel, len(f)))
    for i in range(n_mel):
        a, b, c = pts[i], pts[i + 1], pts[i + 2]
        fb[i] = np.clip(np.minimum((f - a) / (b - a), (c - f) / (c - b)), 0, None)
    return fb
FB = _mel(); DCT = np.cos(np.pi / 40 * (np.arange(40)[None, :] + 0.5) * np.arange(20)[:, None])

def load(p):
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', p, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'], capture_output=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768

def pitch(x):
    try:
        import parselmouth
        v = parselmouth.Sound(x.astype(np.float64), SR).to_pitch(pitch_floor=70, pitch_ceiling=600).selected_array['frequency']
    except ImportError:  # autocorrelation fallback
        v = []
        for i in range(0, len(x) - 640, 320):
            fr = x[i:i + 640] * np.hanning(640)
            if np.sqrt(np.mean(fr ** 2)) < 0.02: continue
            ac = np.correlate(fr, fr, 'full')[639:]; lo, hi = SR // 600, SR // 70
            j = lo + int(np.argmax(ac[lo:hi])); v.append(SR / j if ac[j] > 0.3 * ac[0] else 0)
        v = np.array(v)
    v = np.asarray(v); v = v[v > 0]
    return float(np.median(v)) if len(v) else 0.0

def features(p):
    """Acoustic print of one clip: 19 MFCC means, 19 stds, 12*log2(F0) (semitones)."""
    x = load(p)
    if len(x) < SR // 4: return None
    x = np.append(x[0], x[1:] - 0.97 * x[:-1])
    n = 1 + (len(x) - 400) // 160
    fr = np.lib.stride_tricks.sliding_window_view(x, 400)[::160][:n] * np.hamming(400)
    pw = np.abs(np.fft.rfft(fr, 512)) ** 2
    e = 10 * np.log10(pw.sum(1) + 1e-10); keep = e > np.percentile(e, 40)
    mf = (DCT @ np.log(FB @ pw[keep].T + 1e-10)).T[:, 1:]
    f0 = pitch(load(p))
    return np.concatenate([mf.mean(0), mf.std(0), [12 * np.log2(f0 / 100) if f0 else 0.0]])

# Each dimension scaled so a typical between-voice difference is ~1 (stable across runs; from the run 28 cast).
W = None
def dist(a, b):
    a, b = np.asarray(a), np.asarray(b)
    w = np.concatenate([np.full(19, 1 / 2.0), np.full(19, 1 / 1.5), [1 / 1.5]])  # MFCC mean, MFCC std, semitone pitch
    return float(np.sqrt(np.mean(((a - b) * w) ** 2)) * np.sqrt(3))

def clip_keys(man, ch):
    return sorted(k for k, v in man.items() if v[0] == ch and os.path.exists(os.path.join(AUD, k + '.mp3')))
def char_print(keys, n=16, seed=28):
    rnd = random.Random(seed); ks = keys if len(keys) <= n else rnd.sample(keys, n)
    fs = [f for f in (features(os.path.join(AUD, k + '.mp3')) for k in ks) if f is not None]
    return np.mean(fs, 0) if fs else None

def check_manifest(man, texts, V):
    out = []
    for k in sorted(texts):
        if k not in man: out.append(('block', 'clip not in voice manifest (voice unknown)', k, texts[k])); continue
        sp, s = man[k]
        if sp not in V: out.append(('block', f'speaker {sp} has no voice in the cast', k, texts[k]))
        elif s != sig(V[sp]): out.append(('rerender', f'stale voice for {sp}: clip has {s}, cast says {sig(V[sp])}', k, texts[k]))
    return out

def check_revoiced(man, V, prints, old_dirs, n=10):
    """Characters whose cast entry changed since their print: clips must sound different from the old voice."""
    out, newp = [], {}
    by = collections.defaultdict(list)
    for k, (sp, s) in man.items(): by[sp].append(k)
    for ch, v in V.items():
        p = prints.get(ch)
        if not p or p['sig'] == sig(v): continue
        ks = sorted(k for k in by.get(ch, []) if man[k][1] == sig(v))
        if not ks: continue
        rnd = random.Random(ch); pick = ks if len(ks) <= n else rnd.sample(ks, n)
        ds = []
        for k in pick:
            new = features(os.path.join(AUD, k + '.mp3'))
            old = next((os.path.join(d, k + '.mp3') for d in old_dirs if os.path.exists(os.path.join(d, k + '.mp3'))), None)
            ref = features(old) if old else np.asarray(p['print'])
            if new is not None and ref is not None: ds.append(dist(new, ref))
        if not ds: continue
        med = float(np.median(ds)); newvoice = p['sig'].split('|')[0] != v[0]
        lim = THRESH['newvoice_min'] if newvoice else THRESH['retuned_min']
        if med < lim:
            out.append(('block', f'{"re-voiced" if newvoice else "re-tuned"} but sounds unchanged (median distance {med:.2f} < {lim}) — {p["sig"]} -> {sig(v)}', ch, ''))
        newp[ch] = med
    return out, newp

def check_scenes(V, groups, prints):
    out = []
    for g, sps in groups.items():
        sps = sorted({'me' if s == 'learner' else s for s in sps})
        for i, a in enumerate(sps):
            for b in sps[i + 1:]:
                if a not in V or b not in V: continue
                if V[a] == V[b]: out.append(('block', f'identical voice+settings in one scene: {a} & {b} ({sig(V[a])})', g, ''))
                elif V[a][0] == V[b][0]: out.append(('block', f'same voice in one scene: {a} & {b} ({V[a][0]})', g, ''))
                elif a in prints and b in prints and prints[a]['sig'] == sig(V[a]) and prints[b]['sig'] == sig(V[b]):
                    d = dist(prints[a]['print'], prints[b]['print'])
                    if d < THRESH['scene_min']: out.append(('block', f'acoustically too similar in one scene: {a} & {b} (distance {d:.2f})', g, ''))
    seen, uniq = set(), []
    for o in out:
        key = o[1]
        if key not in seen: seen.add(key); uniq.append(o)
    return uniq

def update_prints(man, V, prints, only=None):
    by = collections.defaultdict(list)
    for k, (sp, s) in man.items():
        if sp in V and s == sig(V[sp]): by[sp].append(k)
    for ch in V:
        if only is not None and ch not in only: continue
        if ch in prints and prints[ch]['sig'] == sig(V[ch]): continue
        ks = sorted(k for k in by.get(ch, []) if os.path.exists(os.path.join(AUD, k + '.mp3')))
        pr = char_print(ks)
        if pr is not None: prints[ch] = {'sig': sig(V[ch]), 'print': [round(float(x), 4) for x in pr]}
    json.dump(prints, open(PRINTS, 'w'), indent=0)
    return prints

def run(fix=False, log=print, old_dirs=None):
    man = json.load(open(os.path.join(AUDIT, 'voice_manifest.json')))
    texts = json.load(open(os.path.join(AUDIT, 'voice_texts.json')))
    V = voices(); prints = json.load(open(PRINTS)) if os.path.exists(PRINTS) else {}
    old_dirs = old_dirs if old_dirs is not None else [d for d in os.environ.get('QA_OLD_CLIPS', '').split(':') if d]
    issues = check_manifest(man, texts, V)
    stale = sorted({k for l, _, k, _ in issues if l == 'rerender'})
    fixed = 0
    if stale and fix and os.environ.get('AZURE_SPEECH_KEY_1'):
        import qa_audio
        fixed = qa_audio.rerender(stale, {k: [man[k][0]] for k in stale}, texts, log)
        for k in stale: man[k] = [man[k][0], sig(V[man[k][0]])]
        json.dump(man, open(os.path.join(AUDIT, 'voice_manifest.json'), 'w'), separators=(',', ':'))
        issues = [i for i in issues if i[0] != 'rerender'] + check_manifest(man, texts, V)
    rv, dists = check_revoiced(man, V, prints, old_dirs)
    issues += rv
    if not any(i[0] == 'block' for i in rv):
        prints = update_prints(man, V, prints)
    groups = json.load(open(GROUPS)) if os.path.exists(GROUPS) else {}
    issues += check_scenes(V, groups, prints)
    log(f'voice identity: {len(man)} clips, {len(stale)} stale, re-voiced {len(dists)} ({", ".join(f"{c} {d:.2f}" for c, d in sorted(dists.items()))}), {len(groups)} scenes')
    return {'issues': issues, 'stale': len(stale), 'fixed': fixed, 'revoiced': dists}
