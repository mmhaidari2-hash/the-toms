#!/usr/bin/env python3
"""Build the poster, Play feature graphic, and captioned store screenshots.

Usage (from the repo root or app/):
  python3 app/tool/make_launch_kit.py --repo .
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas as pdfcanvas

NAVY = (27, 42, 74, 255)
INK = (20, 32, 58, 255)
RED = (200, 16, 46, 255)
GOLD = (233, 185, 73, 255)
CREAM = (251, 247, 240, 255)
MIST = (238, 232, 221, 255)
MUTED = (107, 115, 133, 255)
PAPER = (255, 255, 255, 255)
ICON_EDGE = (45, 38, 35, 255)

PLACEHOLDER_URL = "https://github.com/mmhaidari2-hash/the-toms-preview/releases"

CAPTIONS = [
    ("01_map.png", "Explore a UK neighbourhood"),
    ("02_conversation.png", "Practise everyday conversations"),
    ("03_nursery.png", "English for UK nursery work"),
    ("04_library.png", "Walk in and open a book"),
    ("05_library_hall.png", "Walk the library and open a book"),
    ("06_lifeuk.png", "Practise for Life in the UK — not the official test"),
    ("07_school.png", "Grammar from beginner to advanced"),
    ("08_visa.png", "Practice forms, with official site links"),
]


def repo_from_args() -> Path:
    p = argparse.ArgumentParser()
    p.add_argument("--repo", default=".", help="Repository root")
    args = p.parse_args()
    root = Path(args.repo).resolve()
    if (root / "app" / "pubspec.yaml").exists():
        return root
    if (root / "pubspec.yaml").exists():
        return root.parent
    raise SystemExit(f"Cannot find repo root from {root}")


def font_dir(root: Path) -> Path:
    return root / "app" / "assets" / "google_fonts"


def load_font(root: Path, family: str, weight: str, size: int) -> ImageFont.FreeTypeFont:
    path = font_dir(root) / f"{family}-{weight}.ttf"
    return ImageFont.truetype(str(path), size=size)


def fa(text: str) -> str:
    # Pillow on this box is built with raqm, which shapes logical RTL itself.
    # arabic_reshaper + get_display would reverse the letters a second time.
    return text


def wrap_en(text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = w if not cur else f"{cur} {w}"
        if font.getlength(trial) <= max_width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines or [text]


def wrap_fa(text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = w if not cur else f"{cur} {w}"
        if font.getlength(fa(trial)) <= max_width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return [fa(line) for line in (lines or [text])]


def rounded(im: Image.Image, radius: int) -> Image.Image:
    im = im.convert("RGBA")
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0], im.size[1]), radius=radius, fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def shadow(im: Image.Image, offset: int = 18, blur: int = 24, alpha: int = 90) -> Image.Image:
    w, h = im.size
    base = Image.new("RGBA", (w + offset * 2 + blur, h + offset * 2 + blur), (0, 0, 0, 0))
    sh = Image.new("RGBA", im.size, (0, 0, 0, alpha))
    sh.putalpha(im.split()[-1].point(lambda p: alpha if p > 0 else 0))
    base.alpha_composite(sh, (offset + 6, offset + 10))
    base = base.filter(ImageFilter.GaussianBlur(blur / 3))
    base.alpha_composite(im, (offset, offset))
    return base


def load_icon(root: Path, size: int, radius: int | None = None) -> Image.Image:
    src = root / "app" / "tool" / "brand" / "icon_1024.png"
    if not src.exists():
        src = root / "app" / "tool" / "brand" / "icon_3d_source.jpg"
        im = Image.open(src).convert("RGBA")
        # Official crop used for the launcher: (114, 107, 910, 903)
        im = im.crop((114, 107, 910, 903))
    else:
        im = Image.open(src).convert("RGBA")
    im = im.resize((size, size), Image.Resampling.LANCZOS)
    if radius is None:
        radius = max(24, size // 8)
    return rounded(im, radius)


def text_size(font: ImageFont.ImageFont, text: str) -> tuple[int, int]:
    box = font.getbbox(text)
    return box[2] - box[0], box[3] - box[1]


def draw_centre(draw: ImageDraw.ImageDraw, y: int, text: str, font, fill, canvas_w: int, gap: int = 16) -> int:
    # anchor 'mt' = horizontal centre, top of glyphs, so the next line cannot overlap descenders.
    draw.text((canvas_w / 2, y), text, font=font, fill=fill, anchor="mt")
    box = font.getbbox(text)
    return y + (box[3] - box[1]) + gap


def make_feature_graphic(root: Path, dest: Path) -> None:
    W, H = 1024, 500
    img = Image.new("RGBA", (W, H), CREAM)
    draw = ImageDraw.Draw(img)
    # Soft right-hand wash and a thin gold baseline.
    for x in range(W):
        t = x / (W - 1)
        r = int(251 - 8 * t)
        g = int(247 - 10 * t)
        b = int(240 - 14 * t)
        draw.line([(x, 0), (x, H)], fill=(r, g, b, 255))
    # Subtle left panel behind the icon
    draw.rounded_rectangle((36, 36, 470, 464), radius=36, fill=MIST)
    icon = shadow(load_icon(root, 360, radius=78), offset=14, blur=20, alpha=80)
    img.alpha_composite(icon, (70, 48))

    title = load_font(root, "Fraunces", "Bold", 72)
    sub = load_font(root, "Inter", "SemiBold", 26)
    small = load_font(root, "Inter", "Medium", 20)
    tiny = load_font(root, "Inter", "Medium", 16)

    tx = 500
    draw.text((tx, 130), "New Life UK", font=title, fill=NAVY)
    # Gold underline under the title
    tw, th = text_size(title, "New Life UK")
    draw.rounded_rectangle((tx, 130 + th + 16, tx + min(tw, 420), 130 + th + 22), radius=3, fill=GOLD)

    line1 = "British English for everyday life"
    line2 = "Shops · work · health · home"
    draw.text((tx, 250), line1, font=sub, fill=INK)
    draw.text((tx, 292), line2, font=small, fill=MUTED)
    draw.text((tx, 400), "Independent learning app  ·  Adults 18+", font=tiny, fill=MUTED)

    dest.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(dest, "PNG", optimize=True)
    print(f"feature graphic {dest} {dest.stat().st_size}")


def make_qr(size: int) -> Image.Image:
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=2,
    )
    qr.add_data(PLACEHOLDER_URL)
    qr.make(fit=True)
    raw = qr.make_image(fill_color=INK[:3], back_color=(255, 255, 255)).convert("RGBA")
    return raw.resize((size, size), Image.Resampling.NEAREST)


def make_poster(root: Path, png_dest: Path, pdf_dest: Path) -> None:
    W, H = 2480, 3508  # A4 at 300 dpi
    img = Image.new("RGBA", (W, H), CREAM)
    draw = ImageDraw.Draw(img)

    # Top navy band
    draw.rectangle((0, 0, W, 220), fill=NAVY)
    band_title = load_font(root, "Inter", "SemiBold", 42)
    label = "A4 poster  ·  replace the QR before public printing"
    bw, bh = text_size(band_title, label)
    draw.text(((W - bw) / 2, (220 - bh) / 2 - 4), label, font=band_title, fill=CREAM)

    icon = shadow(load_icon(root, 820, radius=160), offset=20, blur=28, alpha=85)
    img.alpha_composite(icon, ((W - icon.size[0]) // 2, 250))

    y = 250 + icon.size[1] + 4
    title = load_font(root, "Fraunces", "Bold", 140)
    y = draw_centre(draw, y, "New Life UK", title, NAVY, W, gap=18)
    draw.rounded_rectangle((W // 2 - 180, y, W // 2 + 180, y + 10), radius=5, fill=GOLD)
    y += 28
    fa_title = load_font(root, "Vazirmatn", "Bold", 64)
    y = draw_centre(draw, y, fa("زندگی تازه در بریتانیا"), fa_title, INK, W, gap=28)

    en_sub = load_font(root, "Inter", "SemiBold", 48)
    for line in wrap_en("British English for everyday life in the UK", en_sub, W - 400):
        y = draw_centre(draw, y, line, en_sub, INK, W) + 12
    fa_sub = load_font(root, "Vazirmatn", "Medium", 44)
    for line in wrap_fa("انگلیسی بریتانیایی برای زندگی روزمره در بریتانیا", fa_sub, W - 400):
        y = draw_centre(draw, y, line, fa_sub, MUTED, W) + 10
    y += 28

    body = load_font(root, "Inter", "Regular", 40)
    fa_body = load_font(root, "Vazirmatn", "Regular", 40)
    en_copy = (
        "Practise the everyday British English you need at the shops, at work, "
        "with health services and when renting a home."
    )
    fa_copy = (
        "انگلیسی روزمره‌ای را که در فروشگاه، محل کار، خدمات درمانی "
        "و اجارهٔ خانه لازم دارید تمرین کنید."
    )
    for line in wrap_en(en_copy, body, W - 480):
        y = draw_centre(draw, y, line, body, INK, W) + 10
    y += 12
    for line in wrap_fa(fa_copy, fa_body, W - 480):
        y = draw_centre(draw, y, line, fa_body, INK, W) + 10
    y += 36

    # QR panel
    qr_size = 620
    panel_top = y
    panel_h = 860
    # If we're running long, compress the panel rather than overflowing.
    if panel_top + panel_h > H - 420:
        overflow = (panel_top + panel_h) - (H - 420)
        qr_size = max(480, qr_size - overflow)
        panel_h = H - 420 - panel_top
    draw.rounded_rectangle((200, panel_top, W - 200, panel_top + panel_h), radius=36, fill=PAPER)
    # Warning strip
    draw.rounded_rectangle((200, panel_top, W - 200, panel_top + 120), radius=36, fill=RED)
    draw.rectangle((200, panel_top + 60, W - 200, panel_top + 120), fill=RED)
    warn = load_font(root, "Inter", "Bold", 36)
    warn_t = "TEMPORARY QR  ·  replace with the Google Play link before public printing"
    ww, wh = text_size(warn, warn_t)
    draw.text(((W - ww) / 2, panel_top + (120 - wh) / 2 - 4), warn_t, font=warn, fill=PAPER)

    qr = make_qr(qr_size)
    qr_x = (W - qr_size) // 2
    qr_y = panel_top + 150
    # White pad + thin navy frame
    pad = 18
    draw.rounded_rectangle(
        (qr_x - pad, qr_y - pad, qr_x + qr_size + pad, qr_y + qr_size + pad),
        radius=20,
        outline=NAVY,
        width=6,
        fill=PAPER,
    )
    img.alpha_composite(qr, (qr_x, qr_y))

    url_font = load_font(root, "Inter", "Medium", 28)
    scan_font = load_font(root, "Inter", "SemiBold", 32)
    fa_scan = load_font(root, "Vazirmatn", "SemiBold", 32)
    ty = qr_y + qr_size + 28
    ty = draw_centre(draw, ty, "Scan to learn more", scan_font, NAVY, W) + 8
    ty = draw_centre(draw, ty, fa("برای اطلاعات بیشتر اسکن کنید"), fa_scan, NAVY, W) + 8
    ty = draw_centre(draw, ty, PLACEHOLDER_URL, url_font, MUTED, W) + 6
    note = load_font(root, "Inter", "Regular", 26)
    fa_note = load_font(root, "Vazirmatn", "Regular", 28)
    note_en = "This QR currently points to a test-release page, not the Play Store."
    note_fa = "این کد فعلاً به صفحهٔ نسخه‌های آزمایشی می‌رود، نه فروشگاه گوگل پلی."
    ty = draw_centre(draw, ty, note_en, note, MUTED, W) + 4
    draw_centre(draw, ty, fa(note_fa), fa_note, MUTED, W)

    # Footer disclaimer
    foot_top = H - 380
    draw.rectangle((0, foot_top, W, H), fill=NAVY)
    f_en = load_font(root, "Inter", "Regular", 30)
    f_fa = load_font(root, "Vazirmatn", "Regular", 30)
    fy = foot_top + 36
    en_foot = (
        "For adults (18+). An independent learning app — not connected to the UK Government, "
        "the Home Office, the NHS or any exam body. Practice tests are not official tests "
        "and do not guarantee a pass. Always check GOV.UK or a qualified adviser."
    )
    fa_foot = (
        "برای بزرگسالان (۱۸ سال به بالا). یک اپ آموزشی مستقل است و به دولت بریتانیا، "
        "وزارت کشور، NHS یا هیچ نهاد آزمونی وابسته نیست. آزمون‌های تمرینی رسمی نیستند "
        "و قبولی را تضمین نمی‌کنند."
    )
    for line in wrap_en(en_foot, f_en, W - 360):
        fy = draw_centre(draw, fy, line, f_en, CREAM, W) + 6
    fy += 10
    for line in wrap_fa(fa_foot, f_fa, W - 360):
        fy = draw_centre(draw, fy, line, f_fa, CREAM, W) + 6
    fy += 16
    contact = load_font(root, "Inter", "Medium", 28)
    draw_centre(draw, fy, "Support: [SUPPORT_EMAIL]   ·   New Life UK", contact, GOLD, W)

    png_dest.parent.mkdir(parents=True, exist_ok=True)
    rgb = img.convert("RGB")
    rgb.save(png_dest, "PNG", optimize=True)
    print(f"poster png {png_dest} {png_dest.stat().st_size}")

    c = pdfcanvas.Canvas(str(pdf_dest), pagesize=A4)
    c.setTitle("New Life UK — community poster (QR placeholder)")
    c.setAuthor("New Life UK")
    c.drawImage(ImageReader(rgb), 0, 0, width=A4[0], height=A4[1], preserveAspectRatio=True, anchor="c")
    c.save()
    print(f"poster pdf {pdf_dest} {pdf_dest.stat().st_size}")


def caption_shots(root: Path, raw_dir: Path, out_dir: Path) -> list[Path]:
    written: list[Path] = []
    title_f = load_font(root, "Fraunces", "Bold", 56)
    cap_f = load_font(root, "Inter", "SemiBold", 44)
    brand_f = load_font(root, "Inter", "Medium", 24)
    W, H = 1080, 1920
    band = 200
    for fname, caption in CAPTIONS:
        src = raw_dir / fname
        if not src.exists():
            print(f"skip missing raw shot {src}")
            continue
        raw = Image.open(src).convert("RGB")
        # Contain-fit the full UI under the caption band (no cropping of chrome).
        area_w, area_h = W - 48, H - band - 24
        scale = min(area_w / raw.width, area_h / raw.height)
        nw, nh = int(raw.width * scale), int(raw.height * scale)
        raw = raw.resize((nw, nh), Image.Resampling.LANCZOS)
        phone = rounded(raw.convert("RGBA"), radius=36)
        # Soft drop shadow
        shadowed = shadow(phone, offset=10, blur=18, alpha=70)

        canvas = Image.new("RGB", (W, H), CREAM[:3])
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((0, 0, W, band), fill=NAVY[:3])
        draw.rectangle((0, band - 6, W, band), fill=GOLD[:3])
        draw.text((56, 28), "New Life UK", font=brand_f, fill=GOLD)
        lines = wrap_en(caption, cap_f, W - 112)
        sizes = [text_size(cap_f, line) for line in lines]
        block_h = sum(h for _, h in sizes) + 8 * (len(lines) - 1)
        y = 70 + max(0, (band - 70 - 16 - block_h) // 2)
        for line, (_, h) in zip(lines, sizes):
            draw.text((56, y), line, font=cap_f, fill=CREAM)
            y += h + 8
        px = (W - shadowed.size[0]) // 2
        py = band + 8 + max(0, (H - band - 8 - shadowed.size[1]) // 2)
        canvas.paste(shadowed, (px, py), shadowed)
        dest = out_dir / fname
        canvas.save(dest, "PNG", optimize=True)
        print(f"captioned {dest} {dest.stat().st_size} {canvas.size}")
        written.append(dest)
    return written


def main() -> None:
    root = repo_from_args()
    launch = root / "docs" / "launch"
    store = launch / "store"
    store.mkdir(parents=True, exist_ok=True)
    make_feature_graphic(root, store / "feature_graphic_1024x500.png")
    make_poster(root, launch / "poster_qr_EN_FA.png", launch / "poster_qr_EN_FA.pdf")
    raw_dir = store / "raw"
    if raw_dir.exists() and any(raw_dir.glob("*.png")):
        caption_shots(root, raw_dir, store)
    else:
        print(f"no raw screenshots in {raw_dir} yet; caption step skipped")


if __name__ == "__main__":
    main()
