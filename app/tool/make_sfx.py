#!/usr/bin/env python3
"""Synthesised sound effects for the Driving School scenes (no recordings, no licences needed):
engine (start + idle), indicator (tick-tock) and brake (soft squeal + tyre hiss). -> assets/sfx/*.mp3"""
import numpy as np, os, subprocess
SR = 24000; H = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(H, '..', 'assets', 'sfx'); os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
def save(name, x):
    x = x / (np.abs(x).max() + 1e-9) * 0.6
    raw = (x * 32767).astype(np.int16).tobytes()
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', '-b:a', '32k', os.path.join(OUT, name + '.mp3')], input=raw, check=True)
def env(n, a, r):
    e = np.ones(n); a, r = int(a * SR), int(r * SR); e[:a] = np.linspace(0, 1, a); e[-r:] = np.linspace(1, 0, r); return e
t = np.arange(int(2.6 * SR)) / SR
f = 32 + 40 * np.exp(-((t - 0.5) ** 2) / 0.05)  # starter rev, then idle
ph = 2 * np.pi * np.cumsum(f) / SR
eng = sum(np.sin(k * ph) / k for k in range(1, 7)) * (1 + 0.3 * np.sin(2 * np.pi * 9 * t))
noise = np.convolve(rng.standard_normal(len(t)), np.ones(40) / 40, 'same')
save('engine', (eng + 0.5 * noise) * env(len(t), .15, .6))
tick = np.zeros(int(2.4 * SR))
for i in range(6):
    s = int(i * 0.4 * SR); n = int(0.025 * SR); fr = 1800 if i % 2 == 0 else 1300
    tt = np.arange(n) / SR; tick[s:s + n] += np.sin(2 * np.pi * fr * tt) * np.exp(-tt * 180)
save('indicator', tick)
t = np.arange(int(1.3 * SR)) / SR
hiss = np.convolve(rng.standard_normal(len(t)), np.ones(6) / 6, 'same') * np.exp(-t * 2.2)
sq = np.sin(2 * np.pi * np.cumsum(2400 - 600 * t) / SR) * 0.25 * np.exp(-t * 3)
save('brake', (hiss + sq) * env(len(t), .05, .3))
print(sorted(os.listdir(OUT)))
