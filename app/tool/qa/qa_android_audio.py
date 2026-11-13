"""QA: Android build must play Azure clips, never device TTS.
Fails the gate if flutter_tts sneaks back in, if speech_io loses the remote base / mpeg mime /
cache-buster, or if a sample of remote clips is unreachable.
"""
import json, os, re, sys, urllib.request

APP = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

def main():
    issues = []
    pub = open(os.path.join(APP, 'pubspec.yaml')).read()
    if re.search(r'^\s*flutter_tts\s*:', pub, re.M):
        issues.append(('block', 'android-audio', 'flutter_tts dependency present', 'pubspec.yaml', 'device TTS is forbidden'))
    io_path = os.path.join(APP, 'lib/core/platform/speech_io.dart')
    io = open(io_path).read()
    for needle, msg in [
        ("remoteBase = 'https://mmhaidari2-hash.github.io/the-toms/assets/'", 'remoteBase missing or wrong'),
        ('mimeType: \'audio/mpeg\'', 'audio/mpeg mimeType missing (MediaPlayer may reject audio/mp3)'),
        ('kAudioCacheVer', 'cache-buster audio ver missing'),
        ('DeviceFileSource', 'on-device file cache missing'),
        ('bundled.json', 'bundled early-lesson list missing'),
    ]:
        if needle not in io:
            issues.append(('block', 'android-audio', msg, 'speech_io.dart', needle))
    # No TTS API calls
    if re.search(r'FlutterTts|TextToSpeech|speechSynthesis', io):
        issues.append(('block', 'android-audio', 'TTS API referenced in speech_io', 'speech_io.dart', ''))
    voice = open(os.path.join(APP, 'lib/core/platform/voice.dart')).read()
    if 'NO robotic TTS' not in voice and 'never' not in voice.lower():
        pass  # soft
    if 'flutter_tts' in voice or 'FlutterTts' in voice:
        issues.append(('block', 'android-audio', 'TTS in voice.dart', 'voice.dart', ''))
    # Bundled list + ver files exist
    bund = os.path.join(APP, 'assets/audio/bundled.json')
    ver = os.path.join(APP, 'assets/audio/ver.json')
    if not os.path.exists(bund):
        issues.append(('block', 'android-audio', 'bundled.json missing', 'assets/audio/bundled.json', ''))
    else:
        keys = json.load(open(bund))
        if len(keys) < 50:
            issues.append(('block', 'android-audio', f'bundled.json too small ({len(keys)})', 'bundled.json', 'expected early-lesson clips'))
    if not os.path.exists(ver):
        issues.append(('block', 'android-audio', 'ver.json missing', 'assets/audio/ver.json', ''))
    # Live fetch of a few clips (network)
    try:
        idx = json.load(open(os.path.join(APP, 'assets/audio/index.json')))
        sample = idx[:5]
        v = json.load(open(ver))['v'] if os.path.exists(ver) else 'x'
        for k in sample:
            url = f'https://mmhaidari2-hash.github.io/the-toms/assets/assets/audio/{k}.mp3?v={v}'
            req = urllib.request.Request(url, method='HEAD')
            with urllib.request.urlopen(req, timeout=20) as r:
                if r.status != 200:
                    issues.append(('block', 'android-audio', f'clip HTTP {r.status}', url, ''))
                ctype = r.headers.get('Content-Type', '')
                if 'audio' not in ctype and 'octet' not in ctype:
                    issues.append(('block', 'android-audio', f'bad content-type {ctype}', url, ''))
    except Exception as e:
        issues.append(('block', 'android-audio', f'live clip fetch failed: {e}', 'network', ''))
    return issues

if __name__ == '__main__':
    iss = main()
    for l, sec, c, k, t in iss:
        print(f'{l}\t{sec}\t{c}\t{k}\t{t}')
    print(f'android-audio issues: {len(iss)}')
    sys.exit(1 if iss else 0)
