"""Audio QA: every clip exists, has sane timing and loudness, ends cleanly, and (sampled) says its text.
Speech-to-text uses Azure Speech (uksouth, key in env AZURE_SPEECH_KEY_1, never printed); results are cached."""
import os, re, json, random, subprocess, hashlib, time, urllib.request, urllib.error
import numpy as np
from concurrent.futures import ThreadPoolExecutor
APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
AUD = os.path.join(APP, 'assets', 'audio'); AUDIT = os.path.join(APP, 'tool', 'audit')
CACHE = os.path.join(APP, 'tool', 'qa', 'cache'); os.makedirs(CACHE, exist_ok=True)
import sys; sys.path.insert(0, os.path.join(APP, 'tool'))
import tighten_audio as T
SR = 16000

def items():
    """{key: (speaker, text)} for every clip the app can play (the manifest written by tool/render_voices.py)."""
    man = json.load(open(os.path.join(AUDIT, 'voice_manifest.json')))
    lines = os.path.join(AUDIT, 'voice_texts.json')
    texts = json.load(open(lines)) if os.path.exists(lines) else {}
    return man, texts

def analyse(k):
    p = os.path.join(AUD, k + '.mp3')
    if not os.path.exists(p): return {'missing': True}
    x = T.load(p)
    if len(x) < T.FR * 5: return {'dur': len(x) / T.SR, 'empty': True}
    db = T.frames_db(x); thr = max(-50.0, float(np.percentile(db, 95)) - 38)
    sp = np.where(db >= thr)[0]
    if len(sp) == 0: return {'dur': len(x) / T.SR, 'silent': True}
    runs = T.silent_runs(db, thr); n = len(db)
    inner = [(e - s) / 100 for s, e in runs if s > 0 and e < n]
    lead = sp[0] / 100; tail = (n - 1 - sp[-1]) / 100
    # Cut-off ending: the last speech frame is still loud (no decay) within 40 ms of the end of the file.
    last = db[sp[-1]]; cut = tail < 0.04 and last > float(np.percentile(db[sp], 50))
    # Loudness of speech, and jumps between the speech stretches of one clip (one sentence much louder).
    segs, s0 = [], sp[0]
    for a, b in zip(sp, sp[1:]):
        if b - a > 25: segs.append((s0, a)); s0 = b
    segs.append((s0, sp[-1]))
    lv = [float(np.median(db[a:b + 1])) for a, b in segs if b - a >= 15]
    peak = float(np.max(np.abs(x))) / 32768
    return {'dur': round(len(x) / T.SR, 2), 'lead': round(lead, 2), 'tail': round(tail, 2), 'pause': round(max(inner, default=0), 2),
            'cut': bool(cut), 'loud': round(float(np.median(db[sp])), 1), 'jump': round(max(lv) - min(lv), 1) if len(lv) > 1 else 0.0,
            'clip': peak > 0.995}

def stt(k):
    """Azure speech-to-text of one clip (en-GB), or None."""
    p = os.path.join(AUD, k + '.mp3')
    wav = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', p, '-ac', '1', '-ar', str(SR), '-f', 'wav', '-'], capture_output=True).stdout
    url = 'https://uksouth.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-GB&format=simple&profanity=raw'
    for i in range(5):
        req = urllib.request.Request(url, data=wav, method='POST', headers={'Ocp-Apim-Subscription-Key': os.environ['AZURE_SPEECH_KEY_1'],
                                     'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000', 'Accept': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=60) as r: j = json.loads(r.read())
            return j.get('DisplayText', '') if j.get('RecognitionStatus') == 'Success' else ''
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503): time.sleep(2 ** i); continue
            return None
        except Exception: time.sleep(2 ** i)
    return None

NUM = {'0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four', '5': 'five', '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine', '10': 'ten'}
def words(t):
    t = t.lower().replace('’', "'")
    t = re.sub(r"[^a-z0-9' ]", ' ', t)
    return [NUM.get(w, w).strip("'") for w in t.split() if w.strip("'")]
def wer(ref, hyp):
    r, h = words(ref), words(hyp)
    if not r: return 0.0
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            cur = min(d[j] + 1, d[j - 1] + 1, prev + (r[i - 1] != h[j - 1])); prev, d[j] = d[j], cur
    return d[len(h)] / len(r)

def run(sample=150, fix=False, threads=8, log=print):
    man, texts = items()
    keys = sorted(man)
    cpath = os.path.join(CACHE, 'audio.json')
    cache = json.load(open(cpath)) if os.path.exists(cpath) else {}
    def sig(k):
        p = os.path.join(AUD, k + '.mp3')
        return f'{os.path.getsize(p)}:{int(os.path.getmtime(p))}' if os.path.exists(p) else 'missing'
    todo = [k for k in keys if cache.get(k, {}).get('sig') != sig(k)]
    log(f'audio: {len(keys)} clips, analysing {len(todo)} new/changed')
    with ThreadPoolExecutor(threads) as ex:
        for k, r in zip(todo, ex.map(analyse, todo)):
            r['sig'] = sig(k); old = cache.get(k, {}); r.update({x: old[x] for x in ('stt', 'stt_sig') if x in old}); cache[k] = r
    json.dump(cache, open(cpath, 'w'))
    issues = []
    eng = set(json.load(open(os.path.join(AUDIT, 'voice_engine.json')))) if os.path.exists(os.path.join(AUDIT, 'voice_engine.json')) else set()
    for k in keys:
        a = cache[k]; t = texts.get(k, '')
        if a.get('missing'): issues.append(('block', 'missing clip', k, t)); continue
        if a.get('empty') or a.get('silent'): issues.append(('block', 'silent/empty clip', k, t)); continue
        if a['pause'] > 0.75: issues.append(('fix', f"long pause {a['pause']}s inside (sounds like detached sentences)", k, t))
        if a['lead'] > 0.35 or a['tail'] > 0.7: issues.append(('fix', f"slow start/end (lead {a['lead']}s, tail {a['tail']}s)", k, t))
        if a['cut']: issues.append(('rerender', 'ending cut off (no decay before the file ends)', k, t))
        if a['jump'] > 12: issues.append(('warn', f"volume jump {a['jump']} dB between sentences", k, t))
        if a['clip']: issues.append(('warn', 'clipping (peaks at full scale)', k, t))
        n = len(re.sub(r'\W', '', t)) if t else 0
        if n >= 12 and a['dur'] / n < 0.035: issues.append(('rerender', f"too short for its text ({a['dur']}s for {n} letters)", k, t))
        if n >= 4 and a['dur'] > 4 + 0.2 * n: issues.append(('rerender', f"too long for its text ({a['dur']}s for {n} letters)", k, t))
    # Speech-to-text: a random sample of Azure clips plus every clip already flagged.
    stt_n = 0
    if os.environ.get('AZURE_SPEECH_KEY_1') and sample:
        flagged = {k for lvl, _, k, _ in issues if lvl in ('rerender',)}
        pool = [k for k in keys if k in eng and texts.get(k) and cache[k].get('stt_sig') != cache[k]['sig']]
        random.seed(int(time.time()) // 86400)
        pick = sorted(flagged & set(pool)) + random.sample(sorted(set(pool) - flagged), min(sample, len(set(pool) - flagged)))
        with ThreadPoolExecutor(6) as ex:
            for k, h in zip(pick, ex.map(stt, pick)):
                if h is None: continue
                cache[k]['stt'] = h; cache[k]['stt_sig'] = cache[k]['sig']; stt_n += 1
        json.dump(cache, open(cpath, 'w'))
        for k in keys:
            a = cache[k]
            if 'stt' in a and a.get('stt_sig') == a['sig'] and texts.get(k):
                w = wer(texts[k], a['stt'])
                a['wer'] = round(w, 2)
                if w > 0.4 and len(words(texts[k])) >= 3: issues.append(('rerender', f"speech-to-text mismatch (WER {w:.0%}): heard “{a['stt']}”", k, texts[k]))
    checked = sum(1 for k in keys if 'wer' in cache[k])
    fixed = {'tightened': 0, 'rerendered': 0}
    if fix:
        tk = sorted({k for lvl, _, k, _ in issues if lvl == 'fix'})
        fixed['tightened'] = sum(T.one(k) for k in tk)
        rk = sorted({k for lvl, _, k, _ in issues if lvl == 'rerender'})
        if rk and os.environ.get('AZURE_SPEECH_KEY_1'):
            fixed['rerendered'] = rerender(rk, man, texts, log)
    return {'clips': len(keys), 'stt_new': stt_n, 'stt_checked': checked, 'issues': issues, 'fixed': fixed,
            'wer_mean': round(float(np.mean([cache[k]['wer'] for k in keys if 'wer' in cache[k]] or [0])), 3)}

def voices():
    src = open(os.path.join(APP, 'tool', 'render_voices.py')).read()
    m = re.search(r'^V=\{.*?^\}', src, re.S | re.M)
    return eval(m.group(0)[2:])
def rerender(keys, man, texts, log):
    from az_tts import synth
    V = voices(); n = 0
    for k in keys:
        sp = man[k][0]; t = texts.get(k)
        if not t or sp not in V: continue
        v, p, r = V[sp]
        out = os.path.join(AUD, k + '.mp3')
        if synth(t, v, '/tmp/qa_rr_' + k + '.mp3', pitch=p, rate=r):
            os.replace('/tmp/qa_rr_' + k + '.mp3', out)
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', out, '-ac', '1', '-ar', '24000', '-b:a', '24k', out + '.c.mp3']); os.replace(out + '.c.mp3', out)
            T.one(k); n += 1
    log(f'audio: re-rendered {n} clips')
    return n
