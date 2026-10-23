"""Azure Speech (uksouth) text-to-speech over REST. The key is read from env AZURE_SPEECH_KEY_1 and never printed."""
import os, time, urllib.request, urllib.error
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

def synth(text, voice, out, pitch='+0Hz', rate='+0%', style=None, tries=6):
    body, billed = ssml(text, voice, pitch, rate, style); body = body.encode('utf-8')
    for i in range(tries):
        req = urllib.request.Request(URL, data=body, method='POST', headers={
            'Ocp-Apim-Subscription-Key': os.environ['AZURE_SPEECH_KEY_1'],
            'Content-Type': 'application/ssml+xml', 'X-Microsoft-OutputFormat': FMT, 'User-Agent': 'newlifeuk-render'})
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
