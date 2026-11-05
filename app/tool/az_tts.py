"""Azure Speech (uksouth) text-to-speech over REST. The key comes from env AZURE_SPEECH_KEY_1 or a
host-scoped HTTPS credential proxy; it is never printed."""
import os, subprocess, time, urllib.request, urllib.error
from xml.sax.saxutils import escape
REGION = 'uksouth'
URL = f'https://{REGION}.tts.speech.microsoft.com/cognitiveservices/v1'
FMT = 'audio-24khz-48kbitrate-mono-mp3'

BILLED = [0]  # billable characters sent (text + markup inside <voice>), for the cost report

def ssml(text, voice, pitch='+0Hz', rate='+0%', style=None):
    """Azure bills markup inside <voice> too, so attributes that do nothing are left out."""
    lang = '-'.join(voice.split('-')[:2])
    attrs = ''.join(f' {n}="{v}"' for n, v in (('pitch', pitch), ('rate', rate)) if v not in ('+0Hz', '+0%', '0Hz', '0%'))
    inner = f'<prosody{attrs}>{escape(text)}</prosody>' if attrs else escape(text)
    if style:
        inner = f'<mstts:express-as style="{style}">{inner}</mstts:express-as>'
    return (f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" '
            f'xml:lang="{lang}"><voice name="{voice}">{inner}</voice></speak>'), len(inner)

def _curl(body, out):
    """Credential-proxy path: curl honours the injected proxy reliably; returns the HTTP status."""
    r = subprocess.run(['curl', '-s', '-m', '60', '-o', out + '.tmp', '-w', '%{http_code}', '-X', 'POST',
                        '-H', 'Content-Type: application/ssml+xml', '-H', f'X-Microsoft-OutputFormat: {FMT}',
                        '-H', 'User-Agent: newlifeuk-render', '--data-binary', '@-', URL],
                       input=body, capture_output=True)
    try:
        return int(r.stdout.decode() or 0)
    except ValueError:
        return 0

def synth(text, voice, out, pitch='+0Hz', rate='+0%', style=None, tries=6):
    body, billed = ssml(text, voice, pitch, rate, style); body = body.encode('utf-8')
    if not os.environ.get('AZURE_SPEECH_KEY_1'):
        for i in range(tries):
            code = _curl(body, out)
            if code == 200 and os.path.getsize(out + '.tmp') >= 200:
                os.replace(out + '.tmp', out); BILLED[0] += billed
                return True
            if code in (400, 401, 403, 404):
                raise RuntimeError(f'HTTP {code}')
            time.sleep(min(60, 2 ** i))
        return False
    for i in range(tries):
        headers = {'Content-Type': 'application/ssml+xml', 'X-Microsoft-OutputFormat': FMT, 'User-Agent': 'newlifeuk-render'}
        key = os.environ.get('AZURE_SPEECH_KEY_1')
        if key:  # otherwise a host-scoped credential proxy injects the header
            headers['Ocp-Apim-Subscription-Key'] = key
        req = urllib.request.Request(URL, data=body, method='POST', headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            if len(data) < 200:
                raise ValueError('short audio')
            open(out + '.tmp', 'wb').write(data); os.replace(out + '.tmp', out)
            BILLED[0] += billed
            return True
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(min(60, 2 ** i + float(e.headers.get('Retry-After') or 0)))
                continue
            raise RuntimeError(f'HTTP {e.code}')
        except Exception:
            time.sleep(2 ** i)
    return False
