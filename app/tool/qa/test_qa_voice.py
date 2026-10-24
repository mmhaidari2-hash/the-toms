"""Unit tests for the voice-identity gate (tool/qa/qa_voice.py) and the audio cache version (tool/make_sw.py).
Run: cd tool/qa && python3 -m unittest -q test_qa_voice"""
import os, sys, json, shutil, tempfile, unittest, importlib.util
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_voice as Q

def two_voices():
    """Two existing clips from speakers with different voices (tom: Ollie, leslie: Ada)."""
    man = json.load(open(os.path.join(Q.AUDIT, 'voice_manifest.json')))
    pick = {}
    for k, (sp, s) in sorted(man.items()):
        if sp in ('tom', 'leslie') and sp not in pick and os.path.exists(os.path.join(Q.AUD, k + '.mp3')) and os.path.getsize(os.path.join(Q.AUD, k + '.mp3')) > 5000:
            pick[sp] = k
        if len(pick) == 2: break
    return pick['tom'], pick['leslie']

class Manifest(unittest.TestCase):
    def test_stale_clip_is_flagged_and_unknown_blocks(self):
        V = {'a': ('en-GB-AbbiNeural', '+25Hz', '+2%')}
        man = {'k1': ['a', 'en-GB-AbbiNeural|+25Hz|+2%'], 'k2': ['a', 'en-GB-MaisieNeural|+0Hz|-4%']}
        out = Q.check_manifest(man, {'k1': 'x', 'k2': 'y', 'k3': 'z'}, V)
        self.assertEqual({(l, k) for l, _, k, _ in out}, {('rerender', 'k2'), ('block', 'k3')})

class Revoiced(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(); self.old = os.path.join(self.tmp, 'old'); self.aud = os.path.join(self.tmp, 'aud')
        os.makedirs(self.old); os.makedirs(self.aud); self.ka, self.kb = two_voices()
        self.keep = Q.AUD; Q.AUD = self.aud
    def tearDown(self): Q.AUD = self.keep; shutil.rmtree(self.tmp)
    def _run(self, new_src, old_voice='en-GB-MaisieNeural'):
        shutil.copy(os.path.join(self.keep, self.ka + '.mp3'), os.path.join(self.old, 'k.mp3'))
        shutil.copy(os.path.join(self.keep, new_src + '.mp3'), os.path.join(self.aud, 'k.mp3'))
        V = {'c': ('en-GB-AbbiNeural', '+25Hz', '+2%')}
        prints = {'c': {'sig': f'{old_voice}|+0Hz|-4%', 'print': [0] * 39}}
        man = {'k': ['c', Q.sig(V['c'])]}
        return Q.check_revoiced(man, V, prints, [self.old])[0]
    def test_unchanged_audio_after_a_voice_change_blocks(self):  # the Nicola bug: cast changed, clip did not
        self.assertTrue(any(l == 'block' for l, *_ in self._run(self.ka)))
    def test_really_different_voice_passes(self):
        self.assertEqual(self._run(self.kb), [])
    def test_retune_with_identical_file_blocks(self):  # same voice, new pitch/rate, but the file is the old one
        self.assertTrue(any(l == 'block' for l, *_ in self._run(self.ka, old_voice='en-GB-AbbiNeural')))

class Scenes(unittest.TestCase):
    def test_identical_settings_in_one_scene_block(self):
        V = {'a': ('en-GB-LibbyNeural', '+0Hz', '-4%'), 'b': ('en-GB-LibbyNeural', '+0Hz', '-4%')}
        out = Q.check_scenes(V, {'s1': ['a', 'b']}, {})
        self.assertTrue(any('identical' in c for _, c, *_ in out))
    def test_same_voice_other_settings_in_one_scene_block(self):
        V = {'a': ('en-GB-LibbyNeural', '+0Hz', '-4%'), 'b': ('en-GB-LibbyNeural', '+6Hz', '+0%')}
        self.assertTrue(any('same voice' in c for _, c, *_ in Q.check_scenes(V, {'s1': ['a', 'b']}, {})))
    def test_acoustically_similar_blocks_and_distinct_passes(self):
        V = {'a': ('en-GB-LibbyNeural', '+0Hz', '-4%'), 'b': ('en-GB-BellaNeural', '+0Hz', '-4%')}
        near = {'a': {'sig': Q.sig(V['a']), 'print': [1.0] * 39}, 'b': {'sig': Q.sig(V['b']), 'print': [1.1] * 39}}
        far = {'a': {'sig': Q.sig(V['a']), 'print': [1.0] * 39}, 'b': {'sig': Q.sig(V['b']), 'print': [9.0] * 39}}
        self.assertTrue(any('too similar' in c for _, c, *_ in Q.check_scenes(V, {'s1': ['a', 'b']}, near)))
        self.assertEqual(Q.check_scenes(V, {'s1': ['a', 'b']}, far), [])
    def test_same_voice_in_different_scenes_is_allowed(self):
        V = {'a': ('en-GB-LibbyNeural', '+0Hz', '-4%'), 'b': ('en-GB-LibbyNeural', '+0Hz', '-2%')}
        self.assertEqual(Q.check_scenes(V, {'s1': ['a', 'x'], 's2': ['b', 'y']}, {}), [])

class AudioCache(unittest.TestCase):
    def test_audio_cache_name_changes_when_a_clip_is_revoiced(self):
        # load audio_version() from make_sw.py without running the script body
        src = open(os.path.join(Q.APP, 'tool', 'make_sw.py')).read()
        start = src.index('def audio_version'); end = src.index('aver = audio_version')
        ns = {'os': os, 'hashlib': __import__('hashlib'), '__file__': os.path.join(Q.APP, 'tool', 'make_sw.py')}; exec(src[start:end], ns)
        root = tempfile.mkdtemp(); os.makedirs(os.path.join(root, 'a', 'audio'))
        f = os.path.join(root, 'a', 'audio', 'k.mp3'); open(f, 'wb').write(b'x' * 10)
        v1 = ns['audio_version'](root, ['a/audio/k.mp3'])
        open(f, 'wb').write(b'y' * 12)
        v2 = ns['audio_version'](root, ['a/audio/k.mp3'])
        self.assertNotEqual(v1, v2); shutil.rmtree(root)
        self.assertNotIn("thetoms-audio-v3'", src)  # never a hand-bumped constant again

if __name__ == '__main__': unittest.main()
