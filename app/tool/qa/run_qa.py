"""New Life UK automated QA. Runs before every deploy (tool/qa/gate.sh) and blocks it on any BLOCKING issue.
Sections: text (spelling, grammar heuristics, banned US words, real brands, 'Mahdi', leftover code keys),
translation (practice prompt = faithful rendering of the answer, per helper language), content (every exercise
solvable, assets exist, lessons in their building), UI (every route at 3 phone sizes x LTR/RTL languages: overflow,
exceptions, missing images, unknown routes; optional screenshots of the built site), audio (every clip exists, timing,
cut-off endings, long pauses, loudness, speech-to-text WER on a sample; --fix tightens/re-renders bad clips).
Writes build/qa/report.md + report.html (+ a dated copy in /workspace/qa_reports). Exit 1 = blocking issues.
Usage: python3 tool/qa/run_qa.py [--fix] [--no-ui] [--no-audio] [--stt N] [--shots URL]"""
import os, re, sys, json, glob, time, subprocess, html, random, collections
H = os.path.dirname(os.path.abspath(__file__)); APP = os.path.abspath(os.path.join(H, '..', '..'))
os.chdir(APP); sys.path.insert(0, H); sys.path.insert(0, os.path.join(APP, 'tool'))
ARGS = sys.argv[1:]
def opt(n, d=None):
    return ARGS[ARGS.index(n) + 1] if n in ARGS else d
OUT = os.path.join(APP, 'build', 'qa'); os.makedirs(OUT, exist_ok=True)
ALLOW = json.load(open(os.path.join(H, 'allow.json')))
issues = []  # (level, section, check, where, detail)   level: block | warn | fixed
stats = collections.OrderedDict()
def add(level, sec, check, where, detail=''): issues.append((level, sec, check, where, detail))
def log(*a): print(*a, flush=True)
FA = re.compile('[\u0600-\u06FF]')

# ---------------------------------------------------------------- text
SKIP_KEY = re.compile(r'(^|_)(id|ids|image|img|avatar|cover|still|src|audio|voice|speaker|sp|kind|type|rule|spot|place|color|icon|art|scene|sceneId|key|route|slot|level|from|to|npc|video|link|url|href|asset|file|char|characterId|accent|family|growthStage|role)$', re.I)
def english_strings():
    files = [f for f in glob.glob('assets/data/**/*.json', recursive=True) if not f.endswith('_bundle.json') and '/i18n/' not in f]
    for f in files:
        try: d = json.load(open(f))
        except Exception: continue
        def walk(o, path):
            if isinstance(o, dict):
                for k, v in o.items(): yield from walk(v, path + [str(k)])
            elif isinstance(o, list):
                for i, v in enumerate(o): yield from walk(v, path + [str(i)])
            elif isinstance(o, str):
                last = next((p for p in reversed(path) if not p.isdigit()), '')
                if SKIP_KEY.search(last) or last.endswith('Fa') or last in ('fa', 'translations'): return
                if FA.search(o) or not re.search('[A-Za-z]', o): return
                if not (' ' in o or re.match('^[A-Z]', o)): return
                yield f + ':' + '.'.join(path), o
        yield from walk(d, [])
def dart_strings():
    for f in glob.glob('lib/**/*.dart', recursive=True):
        if f.endswith('.g.dart'): continue
        for i, line in enumerate(open(f), 1):
            for m in re.finditer(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", line):
                s = m.group(1) or m.group(2) or ''
                if ' ' in s and re.search('[A-Za-z]{3}', s) and not s.startswith(('assets/', 'package:', 'http')) and '$' not in s[:1]:
                    yield f'{f}:{i}', s
BANNED_US = ['color', 'colors', 'favorite', 'favorites', 'mom', 'moms', 'apartment', 'apartments', 'cookie', 'cookies', 'candy', 'pants', 'vacation',
             'soccer', 'gotten', 'center', 'centers', 'realize', 'realized', 'trash', 'movie', 'movies', 'diaper', 'elevator', 'sidewalk', 'gas station',
             'parking lot', 'zip code', 'cell phone', 'garbage', 'truck', 'faucet', 'flashlight', 'stroller']
BRANDS = ['Tesco', "Sainsbury's", 'Asda', 'Lidl', 'Aldi', 'Waitrose', 'Morrisons', 'Superdrug', 'Starbucks', 'Costa Coffee', 'Greggs', "McDonald's",
          'KFC', "Nando's", "Domino's", 'Barclays', 'HSBC', 'Lloyds', 'NatWest', 'Santander', 'Monzo', 'Revolut', 'Primark', 'Argos', 'Amazon', 'eBay',
          'Uber', 'Deliveroo', 'Just Eat', 'Rightmove', 'Zoopla', 'Vodafone', 'Netflix', 'Spotify', 'Google', 'iPhone', 'Facebook', 'Instagram',
          'WhatsApp', 'TikTok', 'YouTube', 'Ryanair', 'easyJet', 'British Airways', 'IKEA', 'John Lewis', 'Marks & Spencer', 'Marks and Spencer',
          'Royal Mail', 'Evri', 'Duolingo', 'Babbel', 'Coca-Cola', 'Pepsi', 'Cadbury', 'Lego', 'Nike', 'Adidas', 'Gumtree', 'Ocado', 'Currys',
          'Wetherspoons', 'Premier Inn', 'Travelodge', 'Specsavers', 'PayPal', 'Klarna', 'Trainline', 'British Gas', 'Thames Water', 'Octopus Energy',
          'BBC', 'ITV', 'Oyster', 'Busuu', 'Memrise', 'Rosetta Stone', 'Twix', 'Snickers', 'KitKat', 'Kit Kat', 'Haribo', 'Ribena', 'Marmite',
          'Heinz', 'Hovis', "Kellogg's", 'Pringles', 'Lucozade', 'Irn-Bru', 'PG Tips', 'Yorkshire Tea', 'Calpol', 'Nurofen', 'Lemsip', 'Gaviscon',
          'Sudocrem', 'Pampers', 'Huggies', 'Persil', 'Vimto', 'Red Bull', 'Nutella', 'Hobnobs', 'PlayStation', 'Xbox', 'Nintendo', 'Fortnite',
          'Minecraft', 'FIFA', 'Pokémon', 'Pokemon', 'Peppa Pig', 'Disney', 'Harry Potter', 'Beatles', 'Hogwarts', 'Marvel', 'Barbie', 'Ferrero',
          'Dairy Milk', 'Quality Street', 'Maltesers', 'Jaffa Cakes', 'Sellotape', 'Blu Tack', 'Tupperware', 'Velcro',
          'Wikipedia', 'ChatGPT', 'Skype', 'Microsoft', 'Samsung', 'Tinder', 'Airbnb', 'Booking.com', 'Expedia', 'Halfords', 'Kwik Fit', 'Wilko',
          'Poundland', 'B&M', 'Home Bargains', 'TK Maxx', 'River Island', 'JD Sports', 'Sports Direct', 'Boots Advantage', 'Clubcard', 'Nectar']
CODE = [(re.compile(r'\{(?!you\})[A-Za-z_][\w.]*\}'), 'unfilled placeholder'), (re.compile(r'\b(TODO|FIXME|XXX|lorem ipsum|undefined|NaN)\b'), 'leftover code text'),
        (re.compile(r'\bnull\b'), 'leftover "null"'), (re.compile(r'\\n|\\u[0-9a-f]{4}'), 'escaped characters shown as text'),
        (re.compile(r'\b[a-z]+_[a-z0-9]+(?:_[a-z0-9]+)+\b'), 'code key in text'), (re.compile(r'\$\{?\w'), 'unfilled Dart interpolation')]
A_AN_OK = re.compile(r'^(uni|use|usu|uti|eu|one|once|ur[aio]|ewe|u[bkst]|ufo|uk\b)', re.I)
AN_OK = re.compile(r'^(hour|honest|honou?r|heir|mp\b|mot\b|fbi|sms|nhs|x|f\b|l\b|m\b|n\b|r\b|s\b|h\b|a&e|lgbt|mri|rsvp|8|11|18|80)', re.I)
def british_known(sc, w):
    if w in sc: return True
    for a, b in (('our', 'or'), ('ise', 'ize'), ('isation', 'ization'), ('yse', 'yze'), ('tre', 'ter'), ('ogue', 'og'), ('lled', 'led'), ('lling', 'ling'),
                 ('ence', 'ense'), ('mme', 'm'), ('ae', 'e'), ('oe', 'e'), ('ised', 'ized'), ('ising', 'izing'), ('ller', 'ler'), ('eable', 'able')):
        if a in w and w.replace(a, b) in sc: return True
    return False
def text_checks():
    data = list(english_strings()); ui = list(dart_strings())
    stats['English strings checked'] = len(data) + len(ui)
    allow_w = set(ALLOW.get('words', [])); allow_b = ALLOW.get('brands', {}); seen = set()
    contrast = re.compile(r'\b(Americans?|US|U\.S\.|America|British English for)\b')
    allow_f = ALLOW.get('files', {})
    for where, s in data + ui:
        dart = where.startswith('lib/')
        if where.split(':')[0] in allow_f: continue
        if dart:  # Dart source: interpolations and escapes are code, not text the learner sees
            s = re.sub(r'\$\{[^}]*\}?|\$[A-Za-z_]\w*', '…', s)
        low = s.lower()
        for w in BANNED_US:
            if re.search(r"(?<![\w-])" + re.escape(w) + r"(?![\w-])", low) and (w, s) not in seen and f'{w}|{s}' not in allow_w and not contrast.search(s):
                seen.add((w, s)); add('block', 'text', f'American word “{w}”', where, s)
        for b in BRANDS:
            if re.search(r'(?<![\w])' + re.escape(b) + r'(?![\w])', s) and b not in allow_b:
                add('block', 'text', f'real brand “{b}”', where, s)
        if re.search(r'mahdi', s, re.I): add('block', 'text', '“Mahdi” in app text', where, s)
        for rx, what in CODE:
            m = rx.search(s)
            if dart and what != 'leftover code text': continue
            if m and not (what == 'code key in text' and dart): add('block' if what != 'code key in text' else 'warn', 'text', what, where, s)
        # Grammar heuristics
        m = re.search(r'\b(\w+) \1\b', s, re.I)
        if m and m.group(1).lower() not in ('very', 'no', 'bye', 'yes', 'ha', 'really', 'so', 'quick', 'more', 'come', 'knock', 'well', 'go', 'now', 'there', 'night', 'tick', 'oh', 'hip', 'ding', 'boo', 'choo', 'beep', 'yum', 'run', 'one', 'that', 'had', 'blah', 'hello', 'hi', 'shh', 'wait', 'please', 'ready', 'push', 'two', 'had', 'round', 'pull', 'up', 'away', 'out', 'faster', 'higher', 'back', 'down', 'again', 'splash', 'jump', 'slowly', 'step', 'all', 'ow', 'mm', 'hmm', 'woof', 'moo', 'quack', 'baa', 'oink', 'neigh', 'tweet', 'meow', 'ah', 'la', 'uh'):
            add('warn', 'text', f'doubled word “{m.group(0)}”', where, s)
        for m in re.finditer(r'\b([Aa]n?) ([A-Za-z][\w’\']*)', s):
            art, nxt = m.group(1).lower(), m.group(2)
            vowel = nxt[0].lower() in 'aeiou'
            if art == 'a' and vowel and not A_AN_OK.match(nxt): add('warn', 'text', f'“a {nxt}” (an?)', where, s)
            if art == 'an' and not vowel and not AN_OK.match(nxt): add('warn', 'text', f'“an {nxt}” (a?)', where, s)
        if re.search(r'\s[,.!?;:](?!\.)', s) and not re.search(r'\s[.…]{2,}|\s\?\s*$|_ ', s): add('warn', 'text', 'space before punctuation', where, s)
        if '  ' in s.strip(): add('warn', 'text', 'double space', where, s)
    # Helper-language tables: no real brand may survive in a machine translation
    for f in glob.glob('assets/i18n/*.json'):
        try: tab = json.load(open(f))
        except Exception: continue
        for k, v in tab.items():
            if not isinstance(v, str): continue
            for b in BRANDS:
                if b not in allow_b and re.search(r'(?<![\w])' + re.escape(b) + r'(?![\w])', v): add('block', 'text', f'real brand “{b}” in a translation', f, v)
    # Spelling (British): unknown words that are not names, places or allowed words.
    try:
        from spellchecker import SpellChecker
        sc = SpellChecker(); names = set()
        for c in json.load(open('assets/data/characters.json')): names |= set(w.lower() for w in re.findall(r'[A-Za-z]+', c['name']))
        known = set(w.lower() for w in ALLOW.get('spelling', []))
        cnt = collections.Counter(); ex = {}
        for where, s in data:
            for w in re.findall(r"(?<![\w'’-])[A-Za-z]+(?:['’][a-z]+)?(?![\w'’-])", s):
                if w[0].isupper() and not s.startswith(w): continue  # proper nouns
                lw = w.lower().replace('’', "'")
                if len(lw) < 3 or lw in names or lw in known: continue
                if not british_known(sc, lw.split("'")[0]): cnt[lw] += 1; ex.setdefault(lw, (where, s))
        stats['possible misspellings (distinct)'] = len(cnt)
        for w, n in cnt.most_common(400):
            add('warn', 'text', f'spelling? “{w}” ×{n}', ex[w][0], ex[w][1])
    except ImportError:
        add('warn', 'text', 'spellchecker not installed', '', 'pip install --user pyspellchecker')

# ---------------------------------------------------------------- translation
def translation_checks():
    import qa_translate as Q
    r = Q.run(log=log, allow_mt=('--no-mt' not in ARGS))
    stats.update(r['stats'])
    for lvl, check, where, detail in r['issues']: add(lvl, 'translation', check, where, detail)

# ---------------------------------------------------------------- content / assets
def content_checks():
    missing = 0; refs = 0
    for f in glob.glob('assets/data/**/*.json', recursive=True):
        s = open(f).read()
        for m in re.finditer(r'"((?:assets/)?[\w./-]+\.(?:webp|png|jpg|jpeg|mp3|mp4|svg|gif))"', s):
            p = m.group(1); refs += 1
            p2 = p if p.startswith('assets/') else None
            cands = [p2] if p2 else [os.path.join('assets', d, p) for d in ('places', 'portraits', 'images', 'covers', 'stills', 'audio', 'sfx', 'art', '')]
            if not any(c and os.path.exists(c) for c in cands) and not glob.glob('assets/**/' + os.path.basename(p), recursive=True):
                missing += 1; add('block', 'content', 'missing asset', f, p)
    stats['asset references'] = refs
    stats['missing assets'] = missing

def flutter(test_files, label):
    env = dict(os.environ, PATH='/home/box/flutter/bin:' + os.environ.get('PATH', ''))
    for attempt in range(3):
        r = subprocess.run(['timeout', '2700', 'flutter', 'test', *test_files], capture_output=True, text=True, env=env)
        if 'No file or variants found for asset' not in r.stdout + r.stderr: break
        time.sleep(5)  # a clip being written while the asset bundle was built: try again
    tail = (r.stdout + r.stderr)[-4000:]
    ok = r.returncode == 0
    if not ok:
        fails = re.findall(r'^\s*(?:test/\S+: )?(.+?) \[E\]$', r.stdout, re.M)
        add('block', label, 'flutter tests failed', ' '.join(test_files), '; '.join(sorted(set(fails))[:10]) or tail[-600:])
    return ok, tail

def ui_routes():
    j = lambda p: json.load(open(p))
    rnd = random.Random(int(time.time()) // 86400)  # a different sample each day, stable within a day
    R = ['/', '/family', '/plan', '/placement', '/howto', '/legal', '/school', '/library', '/cinema', '/lifeuk', '/lifeuk/mock', '/park', '/messages',
         '/driving', '/theory', '/theory/mock', '/seasons', '/missions', '/radio', '/progress', '/premium', '/leitner', '/diary', '/course', '/practice/mistakes']
    R += [f'/school/{lv}' for lv in range(1, 6)] + [f'/certificate/{lv}' for lv in (1, 3, 5)]
    def some(xs, n): xs = list(xs); rnd.shuffle(xs); return xs[:n]
    R += ['/grammar/' + t['id'] for t in some(j('assets/data/grammar.json')['topics'], 3)]
    R += ['/read/' + t['id'] for t in some(j('assets/data/library.json')['books'], 3)]
    for ch in some(j('assets/data/lifeuk.json')['chapters'], 2): R += [f"/lifeuk/{ch['id']}", f"/lifeuk/{ch['id']}/cards", f"/lifeuk/{ch['id']}/quiz"]
    for ch in some(j('assets/data/theory.json')['chapters'], 2): R += [f"/theory/{ch['id']}", f"/theory/{ch['id']}/quiz"]
    R += ['/driving/' + t['id'] for t in some(j('assets/data/driving.json')['lessons'], 2)]
    R += ['/seasons/' + t['id'] for t in some(j('assets/data/seasons.json')['events'], 2)]
    R += ['/messages/' + t['id'] for t in some(j('assets/data/messages.json')['threads'], 2)]
    R += ['/missions/' + t['id'] for t in some(j('assets/data/missions.json')['missions'], 2)]
    R += ['/roleplay/' + t['id'] for t in some(j('assets/data/roleplays.json')['roleplays'], 2)]
    R += ['/radio/' + t['id'] for t in some(j('assets/data/radio.json')['segments'], 2)]
    R += ['/cinema/' + t['id'] for t in some(j('assets/data/cinema.json')['scenes'], 2)]
    course = j('assets/data/course.json')
    lessons = [l['id'] for u in course['units'] for l in u['lessons']]
    R += ['/practice/' + u['id'] for u in some(course['units'], 2)]
    for l in some(lessons, 6): R += ['/lesson/' + l, '/practice/' + l]
    R += ['/place/' + p['id'] for t in some(j('assets/data/places.json'), 2) for p in some(t['places'], 2)]
    R += ['/chat/' + s for s in some(j('assets/data/scenes_index.json'), 6)]
    return R

def ui_checks():
    routes = ui_routes()
    cfg = {'routes': routes, 'sizes': [[320, 568], [375, 667], [414, 896]], 'langs': ['fa', 'ar', 'ur', 'hi', 'en']}
    json.dump(cfg, open(os.path.join(OUT, 'routes.json'), 'w'))
    stats['UI routes x sizes x languages'] = f"{len(routes)} x 3 x {len(cfg['langs'])} = {len(routes) * 3 * len(cfg['langs'])} screens"
    ok, _ = flutter(['test/qa_content_test.dart', 'test/qa_ui_test.dart', 'test/word_gap_test.dart', 'test/map_loupe_test.dart'], 'ui')  # word_gap: English and gloss never glued; map_loupe: glass exactly on its pin
    try:
        res = json.load(open(os.path.join(OUT, 'ui_results.json')))
        stats['UI screens rendered'] = len(res)
        for r in res:
            if not r['ok']: add('block', 'ui', 'screen error / overflow', f"{r['route']} [{r['lang']} {r['size']}]", r.get('why', ''))
    except Exception: pass
    try:
        c = json.load(open(os.path.join(OUT, 'content_results.json')))
        stats['exercises generated and solved'] = c['items']
        for b in c['bad']: add('block', 'content', 'unsolvable exercise', '', b)
    except Exception: pass

def shots(url):
    import qa_shots
    r = qa_shots.run(url, ui_routes(), os.path.join(OUT, 'shots'))
    stats['screenshots'] = r['n']
    for lvl, check, where, detail in r['issues']: add(lvl, 'ui', check, where, detail)
    return r

def audio_checks():
    import qa_audio
    r = qa_audio.run(sample=int(opt('--stt', '150')), fix='--fix' in ARGS, log=log)
    stats['audio clips'] = r['clips']; stats['clips checked by speech-to-text (total)'] = r['stt_checked']; stats['speech-to-text mean WER'] = r['wer_mean']
    stats['clips tightened'] = r['fixed']['tightened']; stats['clips re-rendered'] = r['fixed']['rerendered']
    lv = {'block': 'block', 'warn': 'warn', 'fix': 'fixed' if '--fix' in ARGS else 'warn', 'rerender': 'fixed' if '--fix' in ARGS and r['fixed']['rerendered'] else 'warn'}
    for l, check, k, t in r['issues']: add(lv[l], 'audio', check, k, t)

def report(t0):
    by = collections.Counter((i[0], i[1]) for i in issues)
    blocking = sum(1 for i in issues if i[0] == 'block')
    stamp = time.strftime('%Y-%m-%d %H:%M %Z')
    md = [f'# QA report — {stamp}', '', f"**Result: {'BLOCKED — deploy stopped' if blocking else 'PASS'}** ({blocking} blocking, "
          f"{sum(1 for i in issues if i[0] == 'warn')} warnings, {sum(1 for i in issues if i[0] == 'fixed')} auto-fixed) in {int(time.time() - t0)} s", '', '## Coverage']
    md += [f'- {k}: {v}' for k, v in stats.items()]
    md += ['', '## Issues by section', '', '| section | blocking | warnings | auto-fixed |', '|---|---|---|---|']
    for sec in ('text', 'translation', 'content', 'ui', 'audio'):
        md.append(f"| {sec} | {by[('block', sec)]} | {by[('warn', sec)]} | {by[('fixed', sec)]} |")
    for lvl, title in (('block', 'Blocking'), ('warn', 'Warnings'), ('fixed', 'Auto-fixed')):
        rows = [i for i in issues if i[0] == lvl]
        if not rows: continue
        md += ['', f'## {title} ({len(rows)})', '']
        groups = collections.defaultdict(list)
        for i in rows: groups[(i[1], re.sub(r'“[^”]*”|×\d+|[\d.]+ ?(s|dB|%)', '…', i[2]))].append(i)
        for (sec, chk), g in sorted(groups.items(), key=lambda x: -len(x[1])):
            md.append(f'### {sec}: {chk} ({len(g)})')
            for i in g[:25]: md.append(f'- {i[2]} — `{i[3]}` — {i[4][:220]}')
            if len(g) > 25: md.append(f'- … and {len(g) - 25} more (issues.json)')
    open(os.path.join(OUT, 'report.md'), 'w').write('\n'.join(md))
    json.dump(issues, open(os.path.join(OUT, 'issues.json'), 'w'), ensure_ascii=False, indent=0)
    body = html.escape('\n'.join(md))
    body = re.sub(r'^# (.*)$', r'<h1>\1</h1>', body, flags=re.M); body = re.sub(r'^## (.*)$', r'<h2>\1</h2>', body, flags=re.M)
    body = re.sub(r'^### (.*)$', r'<h3>\1</h3>', body, flags=re.M); body = re.sub(r'^- (.*)$', r'<li>\1</li>', body, flags=re.M)
    body = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', body); body = re.sub(r'`(.*?)`', r'<code>\1</code>', body)
    thumbs = ''
    sd = os.path.join(OUT, 'shots')
    if os.path.isdir(sd):
        thumbs = '<h2>Screenshots</h2><div style="display:flex;flex-wrap:wrap;gap:8px">' + ''.join(
            f'<figure style="width:150px;margin:0"><img src="shots/{f}" style="width:150px;border:1px solid #ccc"><figcaption style="font-size:10px">{html.escape(f)}</figcaption></figure>'
            for f in sorted(os.listdir(sd)) if f.endswith('.png')) + '</div>'
    open(os.path.join(OUT, 'report.html'), 'w').write(f'<!doctype html><meta charset="utf-8"><title>QA report</title><body style="font-family:system-ui;max-width:1100px;margin:auto;white-space:pre-line">{body}{thumbs}</body>')
    dst = os.path.join('/workspace/qa_reports', time.strftime('%Y%m%d_%H%M')); os.makedirs(dst, exist_ok=True)
    for f in ('report.md', 'report.html', 'issues.json'): subprocess.run(['cp', os.path.join(OUT, f), dst])
    if os.path.isdir(sd): subprocess.run(['cp', '-a', sd, dst])
    log('\n'.join(md[:12 + len(stats)])); log('report:', os.path.join(dst, 'report.html'))
    return blocking

if __name__ == '__main__':
    t0 = time.time()
    only = opt('--only')
    secs = [('text', text_checks), ('translation', translation_checks), ('content', content_checks)]
    if '--no-ui' not in ARGS: secs.append(('ui', ui_checks))
    if '--no-audio' not in ARGS: secs.append(('audio', audio_checks))
    if opt('--shots'): secs.append(('shots', lambda: shots(opt('--shots'))))
    for name, fn in secs:
        if only and name not in only.split(','): continue
        log('== QA', name)
        try: fn()
        except Exception as e:
            import traceback; traceback.print_exc(); add('block', name, 'QA check crashed', name, repr(e)[:300])
    sys.exit(1 if report(t0) else 0)
