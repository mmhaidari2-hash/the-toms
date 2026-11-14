#!/usr/bin/env python3
"""
learn_pages.py: plain HTML pages that search engines and AI assistants can read, built from the app's own
conversations (assets/assets/data/roleplays.json).

The app itself is a Flutter canvas: crawlers see only its title, none of its lessons. These pages put each
real-life conversation (café, bus, pharmacy, GP, post office, bank, renting) on its own page, in English
and Persian, with the good and the not-so-good replies and why. Each page links into the app to practise.

  python3 _tools/learn_pages.py      # writes learn/, sitemap.xml, llms.txt (GitHub Pages serves them as-is)
"""

from __future__ import annotations

import datetime as dt
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "assets" / "data" / "roleplays.json"
BASE = "https://mmhaidari2-hash.github.io/the-toms"
APP = f"{BASE}/"
e = html.escape


def mixed(text: str) -> str:
    """Escape, then isolate English runs inside Persian text so they read in the right order."""
    import re
    return re.sub(r"[A-Za-z][A-Za-z0-9 '’.,…?!/&-]*[A-Za-z0-9?!.…]|[A-Za-z]",
                  lambda m: f'<bdi dir="ltr" lang="en">{m.group(0)}</bdi>', html.escape(text, quote=False))

# What people actually type, per conversation (used as page titles and headings).
TITLES = {
    "rp_cafe": ("How to order a coffee in British English: phrases and a real café conversation",
                "سفارش قهوه به انگلیسی در کافه‌های انگلیس: جمله‌ها و یک مکالمه واقعی"),
    "rp_bus": ("How to catch a bus in the UK: what to say to the driver, in British English",
               "سوار اتوبوس شدن در انگلیس: به راننده چه بگوییم؟ مکالمه انگلیسی"),
    "rp_pharmacy": ("What to say at a UK pharmacy: asking the pharmacist in British English",
                    "مکالمه انگلیسی در داروخانه انگلیس: چطور از داروساز بپرسیم"),
    "rp_gp": ("How to book a GP appointment in the UK: phone phrases in British English",
              "وقت گرفتن از دکتر عمومی (GP) در انگلیس: مکالمه تلفنی به انگلیسی"),
    "rp_post": ("How to send a parcel at a UK Post Office: phrases in British English",
                "فرستادن بسته از پست انگلیس: مکالمه انگلیسی در Post Office"),
    "rp_bank": ("How to open a bank account in the UK: what to say at the bank, in English",
                "باز کردن حساب بانکی در انگلیس: مکالمه انگلیسی در بانک"),
    "rp_homes": ("How to rent a flat in the UK: talking to a letting agent in British English",
                 "اجاره خانه در انگلیس: مکالمه انگلیسی با بنگاه (letting agent)"),
}

UI = {
    "en": {"dir": "ltr", "brand": "New Life UK", "level": "Level", "goals": "What you need to do", "conv": "The conversation",
           "they": "They say", "best": "Best reply", "ok": "Understood, but not natural", "no": "Doesn't answer", "why": "Why",
           "tip": "Tip", "ends": "How it ends", "practise": "Practise this conversation free in the app",
           "pwhy": "You speak the replies yourself and get feedback, offline, with British voices.",
           "all": "All everyday conversations", "other": "فارسی", "index_t": "Everyday British English conversations for life in the UK",
           "index_d": "Seven real situations newcomers face in their first weeks in the UK, with the exact British phrases to use and the ones to avoid."},
    "fa": {"dir": "rtl", "brand": "New Life UK", "level": "سطح", "goals": "کاری که باید بکنی", "conv": "مکالمه",
           "they": "آن‌ها می‌گویند", "best": "بهترین جواب", "ok": "می‌فهمند، ولی طبیعی نیست", "no": "جواب سؤال نیست", "why": "چرا",
           "tip": "نکته", "ends": "پایان مکالمه", "practise": "این مکالمه را رایگان در اپ تمرین کن",
           "pwhy": "جواب‌ها را خودت می‌گویی و بازخورد می‌گیری؛ آفلاین، با صدای بریتیش.",
           "all": "همه مکالمه‌های روزمره", "other": "English", "index_t": "مکالمه‌های روزمره انگلیسی بریتیش برای زندگی در انگلیس",
           "index_d": "هفت موقعیت واقعی هفته‌های اول زندگی در انگلیس، با جمله‌های دقیق بریتیش که باید گفت و جمله‌هایی که بهتر است نگفت."},
}

CSS = """
:root{--ink:#1B2A4A;--paper:#FBF7F0;--red:#C8102E;--slate:#4a5568;--line:#e6dfd3;--ok:#1f7a4c;--warn:#9a5b00}
*{box-sizing:border-box}html{background:var(--paper);color:var(--ink)}
body{margin:0;font:17px/1.75 Vazirmatn,system-ui,-apple-system,"Segoe UI",sans-serif}
a{color:inherit}a:focus-visible{outline:3px solid var(--ink);outline-offset:3px}
.top{display:flex;justify-content:space-between;align-items:center;gap:16px;max-width:860px;margin:0 auto;padding:16px}
.brand{font-family:Georgia,serif;font-weight:700;text-decoration:none}.top nav{display:flex;gap:16px;font-size:15px}
main{max-width:860px;margin:0 auto;padding:8px 16px 56px}
h1{font-size:clamp(26px,4.5vw,38px);line-height:1.25;margin:12px 0 16px;text-wrap:balance}
h2{font-size:22px;margin:36px 0 12px}
.lede{color:var(--slate);max-width:65ch}
.level{display:inline-block;padding:2px 10px;border-radius:999px;background:var(--ink);color:#fff;font-size:13px;font-weight:700}
.turn{margin:20px 0;padding:16px 18px;border:1px solid var(--line);border-radius:16px;background:#fff}
.they{font-size:19px;font-weight:700}.they span,.opt span{display:block;font-weight:400;color:var(--slate);font-size:15px}
.opts{list-style:none;padding:0;margin:12px 0 0;display:grid;gap:10px}
.opt{padding:10px 12px;border-radius:12px;border-inline-start:4px solid var(--line);background:var(--paper)}
.opt.q2{border-color:var(--ok)}.opt.q1{border-color:var(--warn)}.opt.q0{border-color:var(--red)}
.tag{font-size:13px;font-weight:700}.q2 .tag{color:var(--ok)}.q1 .tag{color:var(--warn)}.q0 .tag{color:var(--red)}
.en{font-weight:700}.fb{font-size:15px;margin-top:4px}
.cta{margin:40px 0;padding:22px;border-radius:18px;background:var(--ink);color:#fff}.cta p{margin:0 0 12px}
.btn{display:inline-block;padding:11px 18px;border-radius:12px;background:var(--red);color:#fff;font-weight:800;text-decoration:none}
.grid{list-style:none;padding:0;display:grid;gap:14px;grid-template-columns:repeat(auto-fill,minmax(250px,1fr))}
.grid a{display:block;height:100%;padding:16px;border:1px solid var(--line);border-radius:16px;background:#fff;text-decoration:none;font-weight:700}
.grid small{display:block;font-weight:400;color:var(--slate);margin-top:4px}
footer{max-width:860px;margin:0 auto;padding:24px 16px;color:var(--slate);font-size:14px;border-top:1px solid var(--line)}
"""


def shell(lang: str, title: str, desc: str, path: str, alt: str, body: str, ld: list[dict]) -> str:
    u = UI[lang]
    lds = "".join(f'<script type="application/ld+json">{json.dumps(x, ensure_ascii=False)}</script>' for x in ld)
    other = "en" if lang == "fa" else "fa"
    return f"""<!doctype html>
<html lang="{lang}" dir="{u['dir']}">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title><meta name="description" content="{e(desc[:300])}">
<link rel="canonical" href="{BASE}{path}">
<link rel="alternate" hreflang="{lang}" href="{BASE}{path}"><link rel="alternate" hreflang="{other}" href="{BASE}{alt}">
<meta property="og:title" content="{e(title)}"><meta property="og:description" content="{e(desc[:300])}"><meta property="og:type" content="article">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{BASE}/learn/learn.css">
{lds}
</head>
<body>
<header class="top"><a class="brand" href="{APP}">{u['brand']}</a><nav><a href="{BASE}/learn/{lang}/">{u['all']}</a><a href="{BASE}{alt}" hreflang="{other}">{u['other']}</a></nav></header>
<main>{body}</main>
<footer><p><a href="{APP}">{u['brand']}</a>: {e(u['pwhy'])}</p></footer>
</body></html>
"""


def cta(lang: str) -> str:
    u = UI[lang]
    return f'<aside class="cta"><p>{e(u["pwhy"])}</p><a class="btn" href="{APP}">{e(u["practise"])}</a></aside>'


def roleplay_page(rp: dict, lang: str) -> tuple[str, str, str]:
    u = UI[lang]
    t_en, t_fa = TITLES.get(rp["id"], (rp["title"], rp.get("titleFa", rp["title"])))
    title = t_fa if lang == "fa" else t_en
    tr = (lambda d: d.get("fa") or d.get("en", "")) if lang == "fa" else (lambda d: d.get("en", ""))
    intro = tr(rp["intro"])
    goals = "".join(f"<li>{e(tr(g))}</li>" for g in rp.get("goals", []))
    turns = []
    best_lines = []
    for t in rp.get("turns", []):
        opts = sorted(t.get("opts", []), key=lambda o: -o.get("q", 0))
        lis = []
        for o in opts:
            q = o.get("q", 0)
            tag = u["best"] if q == 2 else u["ok"] if q == 1 else u["no"]
            if q == 2:
                best_lines.append(o["en"])
            sub = f"<span>{e(o.get('fa', ''))}</span>" if lang == "fa" else ""
            fb = tr(o.get("fb", {}))
            lis.append(f'<li class="opt q{q}"><div class="tag">{e(tag)}</div><div class="en" dir="ltr" lang="en">{e(o["en"])}</div>{sub}'
                       f'<div class="fb">{mixed(fb) if lang == "fa" else e(fb)}</div></li>')
        they_sub = f"<span>{e(t['npc'].get('fa', ''))}</span>" if lang == "fa" else ""
        hint = tr(t.get("hint", {}))
        turns.append(f'<div class="turn"><div class="tag">{e(u["they"])}</div><p class="they"><bdi dir="ltr" lang="en">{e(t["npc"]["en"])}</bdi>{they_sub}</p>'
                     + (f'<p><strong>{e(u["tip"])}:</strong> {mixed(hint) if lang == "fa" else e(hint)}</p>' if hint else "") + f'<ul class="opts">{"".join(lis)}</ul></div>')
    end = rp.get("end", {})
    body = (f'<article><p><span class="level">{u["level"]} {e(rp.get("level", ""))}</span></p><h1>{e(title)}</h1>'
            f'<p class="lede">{e(intro)}</p><h2>{e(u["goals"])}</h2><ol>{goals}</ol>'
            f'<h2>{e(u["conv"])}</h2>{"".join(turns)}'
            + (f'<h2>{e(u["ends"])}</h2><p class="they" dir="ltr" lang="en">{e(end.get("en", ""))}</p>' + (f'<p>{e(end.get("fa", ""))}</p>' if lang == "fa" else "") if end else "")
            + f"{cta(lang)}</article>")
    slug = rp["id"].removeprefix("rp_")
    path, alt = f"/learn/{lang}/{slug}.html", f"/learn/{'en' if lang == 'fa' else 'fa'}/{slug}.html"
    desc = f"{intro} " + " ".join(f"“{b}”" for b in best_lines[:3])
    ld = [{"@context": "https://schema.org", "@type": "LearningResource", "name": title, "description": desc[:500], "inLanguage": lang,
           "educationalLevel": rp.get("level", ""), "learningResourceType": "Conversation practice", "teaches": "British English for everyday life in the UK",
           "isAccessibleForFree": True, "url": f"{BASE}{path}",
           "provider": {"@type": "Organization", "name": "New Life UK", "url": APP}},
          {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
              {"@type": "ListItem", "position": 1, "name": u["all"], "item": f"{BASE}/learn/{lang}/"},
              {"@type": "ListItem", "position": 2, "name": title, "item": f"{BASE}{path}"}]}]
    return path, shell(lang, title, desc, path, alt, body, ld), title


def index_page(lang: str, items: list[tuple[str, str, str]]) -> tuple[str, str]:
    u = UI[lang]
    lis = "".join(f'<li><a href="{BASE}{p}">{e(t)}<small>{u["level"]} {e(lv)}</small></a></li>' for p, t, lv in items)
    body = f'<h1>{e(u["index_t"])}</h1><p class="lede">{e(u["index_d"])}</p><ul class="grid">{lis}</ul>{cta(lang)}'
    path, alt = f"/learn/{lang}/", f"/learn/{'en' if lang == 'fa' else 'fa'}/"
    ld = [{"@context": "https://schema.org", "@type": "ItemList", "name": u["index_t"],
           "itemListElement": [{"@type": "ListItem", "position": i + 1, "url": f"{BASE}{p}"} for i, (p, _, _) in enumerate(items)]}]
    return path, shell(lang, u["index_t"], u["index_d"], path, alt, body, ld)


LIFE = {
    "en": {"t": "Life in the UK test practice: {c} (free questions with answers)", "hub": "Free Life in the UK test practice, by topic",
           "hubd": "Explanations, key facts and practice questions with answers for each part of the Life in the UK test, in English and Persian.",
           "key": "Key facts", "qs": "Practice questions", "ans": "Answer", "src": "Official sources",
           "about": "The test has {q} questions, you have {m} minutes, and you need {p}% to pass (at least {n} correct).",
           "warn": "This is free practice made by New Life UK. It is not the official test or handbook and does not guarantee a pass. Study the official handbook and book the test only on GOV.UK."},
    "fa": {"t": "تمرین آزمون Life in the UK به فارسی: {c} (سؤال رایگان با جواب)", "hub": "تمرین رایگان آزمون Life in the UK به فارسی، بخش به بخش",
           "hubd": "توضیح، نکته‌های کلیدی و سؤال تمرینی با جواب برای هر بخش آزمون Life in the UK، به فارسی و انگلیسی.",
           "key": "نکته‌های کلیدی", "qs": "سؤال‌های تمرینی", "ans": "جواب", "src": "منابع رسمی",
           "about": "آزمون {q} سؤال دارد، {m} دقیقه وقت داری و برای قبولی {p}٪ لازم است (دست‌کم {n} جواب درست).",
           "warn": "این تمرین رایگانِ New Life UK است. آزمون یا کتاب رسمی نیست و قبولی را تضمین نمی‌کند. کتاب رسمی را بخوان و آزمون را فقط از GOV.UK رزرو کن."},
}


def life_pages(lang: str) -> list[tuple[str, str, str]]:
    d = json.loads((ROOT / "assets" / "assets" / "data" / "lifeuk.json").read_text(encoding="utf-8"))
    L, u = LIFE[lang], UI[lang]
    m = d.get("mock", {})
    about = L["about"].format(q=m.get("questions", 24), m=m.get("minutes", 45), p=m.get("pass", 75),
                              n=-(-m.get("questions", 24) * m.get("pass", 75) // 100))
    other = "en" if lang == "fa" else "fa"
    warn = f'<p class="lede" role="note"><strong>{e(L["warn"])}</strong></p>'
    pages, items = [], []
    for c in d["chapters"]:
        cname = c.get("titleFa") if lang == "fa" else c["title"]
        title = L["t"].format(c=cname)
        tx = (lambda x, k="fa": x.get(k) or x.get("en", "")) if lang == "fa" else (lambda x, k="en": x.get("en", ""))
        expl = "".join(f"<p>{mixed(tx(x)) if lang == 'fa' else e(tx(x))}</p>" for x in c.get("expl", []))
        cards = "".join(f'<li><strong dir="ltr" lang="en">{e(k["front"])}</strong>: {e(k.get("fa") if lang == "fa" else k["back"])}</li>' for k in c.get("cards", []))
        qs, faq = [], []
        for q in c.get("qs", []):
            qtext = q.get("fa") if lang == "fa" and q.get("fa") else q["q"]
            right = q["options"][q["answer"]] if q.get("options") else ""
            why = q.get("whyFa") if lang == "fa" and q.get("whyFa") else q.get("why", "")
            opts = "".join(f'<li dir="ltr" lang="en">{e(o)}</li>' for o in q.get("options", []))
            sub = f'<span dir="ltr" lang="en">{e(q["q"])}</span>' if lang == "fa" else ""
            qs.append(f'<div class="turn"><p class="they">{e(qtext)}{sub}</p><ul class="opts">{opts}</ul>'
                      f'<details><summary>{e(L["ans"])}</summary><p><strong dir="ltr" lang="en">{e(right)}</strong>. {mixed(why) if lang == "fa" else e(why)}</p></details></div>')
            faq.append({"@type": "Question", "name": qtext, "acceptedAnswer": {"@type": "Answer", "text": f"{right}. {why}"}})
        srcs = "".join(f'<li><a href="{e(x)}" rel="noopener" dir="ltr">{e(x)}</a></li>' for x in c.get("src", []))
        path, alt = f"/learn/{lang}/life-in-the-uk-{c['id']}.html", f"/learn/{other}/life-in-the-uk-{c['id']}.html"
        body = (f"<article><h1>{e(title)}</h1>{warn}<p>{e(about)}</p>{expl}<h2>{e(L['key'])}</h2><ul>{cards}</ul>"
                f"<h2>{e(L['qs'])}</h2>{''.join(qs)}<h2>{e(L['src'])}</h2><ul>{srcs}</ul>{cta(lang)}</article>")
        ld = [{"@context": "https://schema.org", "@type": "FAQPage", "inLanguage": lang, "mainEntity": faq},
              {"@context": "https://schema.org", "@type": "LearningResource", "name": title, "inLanguage": lang, "isAccessibleForFree": True,
               "url": f"{BASE}{path}", "about": "Life in the UK test", "provider": {"@type": "Organization", "name": "New Life UK", "url": APP}}]
        pages.append((path, shell(lang, title, f"{about} {L['warn']}", path, alt, body, ld), title))
        items.append((path, title, ""))
    hub_lis = "".join(f'<li><a href="{BASE}{p}">{e(t)}</a></li>' for p, t, _ in items)
    hpath, halt = f"/learn/{lang}/life-in-the-uk.html", f"/learn/{other}/life-in-the-uk.html"
    hbody = f'<h1>{e(L["hub"])}</h1>{warn}<p class="lede">{e(L["hubd"])}</p><p>{e(about)}</p><ul class="grid">{hub_lis}</ul>{cta(lang)}'
    pages.append((hpath, shell(lang, L["hub"], L["hubd"], hpath, halt, hbody, []), L["hub"]))
    return pages


def main() -> None:
    rps = json.loads(DATA.read_text(encoding="utf-8"))["roleplays"]
    out = ROOT / "learn"
    urls = []
    (out).mkdir(exist_ok=True)
    (out / "learn.css").write_text(CSS, encoding="utf-8")
    for lang in ("en", "fa"):
        d = out / lang
        d.mkdir(parents=True, exist_ok=True)
        items = []
        for rp in rps:
            path, page, title = roleplay_page(rp, lang)
            (ROOT / path.lstrip("/")).write_text(page, encoding="utf-8")
            items.append((path, title, rp.get("level", "")))
            urls.append(BASE + path)
        for path, page, title in life_pages(lang):
            (ROOT / path.lstrip("/")).write_text(page, encoding="utf-8")
            urls.append(BASE + path)
            if path.endswith("life-in-the-uk.html"):
                items.append((path, title, ""))
        path, page = index_page(lang, items)
        (d / "index.html").write_text(page, encoding="utf-8")
        urls.append(BASE + path)
    today = dt.date.today().isoformat()
    urls.insert(0, APP)
    (ROOT / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                                      + "".join(f"<url><loc>{u}</loc><lastmod>{today}</lastmod></url>\n" for u in urls) + "</urlset>\n", encoding="utf-8")
    llms = ["# New Life UK (The Toms)", "",
            "> A free app for newcomers to the UK: learn British English by living with a British family, offline, in English and Persian (more languages coming).", "",
            f"App: {APP}", "", "## Everyday conversations (English)"]
    llms += [f"- [{TITLES[r['id']][0]}]({BASE}/learn/en/{r['id'].removeprefix('rp_')}.html)" for r in rps if r["id"] in TITLES]
    llms += ["", "## مکالمه‌های روزمره (فارسی)"]
    llms += [f"- [{TITLES[r['id']][1]}]({BASE}/learn/fa/{r['id'].removeprefix('rp_')}.html)" for r in rps if r["id"] in TITLES]
    (ROOT / "llms.txt").write_text("\n".join(llms) + "\n", encoding="utf-8")
    print(f"{len(urls)} URLs")


if __name__ == "__main__":
    main()
