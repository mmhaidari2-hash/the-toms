#!/usr/bin/env python3
"""Generate Android and web launcher icons from a source image.

Usage:
  python3 app/tool/make_app_icons.py --source /path/to/icon.jpg \
      --repo /path/to/the-toms [--crop 86,86,938,938] \
      [--preview /workspace/icon_preview_grid.png]

  # Regenerate from the approved 1024 master (no frame crop):
  python3 app/tool/make_app_icons.py --source app/tool/brand/icon_master.png \
      --repo . --no-crop --preview /workspace/icon_preview_grid.png

The approved v7 still has a baked-in rounded frame. By default this
script crops inside that frame, upscales to 1024, writes
app/tool/brand/icon_master.png (and icon_1024.png), then resizes every
Android mipmap and web icon in place. If the source is already the
1024 master, the frame crop is skipped and the master is left untouched.

Android adaptive foreground: the master is scaled to the central 48dp
of the 108dp canvas (ADAPTIVE_SCALE = 48/108). The launcher then
masks the inner 72dp viewport. 48dp is the largest 4-aligned size
that fits the whole square — black door, fanlight, steps, cornice,
bay window, family, and framed flag — inside a 72dp circle (the
inscribed square is ~50.9dp; 48dp leaves ~1.5dp for antialiasing)
and therefore also inside squircle and rounded-square masks. The
ring around the picture (12dp visible in the viewport, plus the
18dp outer bleed) is filled with a solid colour sampled from the
master's 4px edge so the mat matches the dusk brick and parallax
has no hard empty edge. Web maskable icons stay full-bleed (the
80% safe zone already shows the same scene). Legacy square/round
icons are a straight resize of the master. File names are unchanged
so manifests do not need editing. No pub dependencies are added;
Pillow is only used on the machine that runs this script.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

# PIL crop box used for icon_v7_final.jpg (left, upper, right, lower).
# Inclusive pixels 86–937 on both axes; 852×852, no frame / rounded-corner remnant.
DEFAULT_CROP = (86, 86, 938, 938)
MASTER_SIZE = 1024
# Dark dusk brick / shadow, mean of the master's outer 4px ring, so
# the visible mat around the shrunken adaptive picture (and the 18dp
# parallax bleed) blends with the house instead of a navy or stretched
# edge halo. Recomputed by sample_edge_color() when the generator runs.
BG_COLOR = (0x36, 0x2D, 0x29)  # #362D29
ANDROID_VIEWPORT = 72 / 108  # launcher mask shows the central 72dp of 108dp
ANDROID_SAFE = ANDROID_VIEWPORT  # kept as an alias for older call sites
WEB_MASKABLE_SAFE = 80 / 100  # typical maskable safe zone (subject must fit)

# Adaptive foreground (and monochrome): scale the master into the
# central 48dp of the 108dp canvas so the whole square fits inside
# the 72dp circle mask (and therefore squircle / rounded-square too).
# offset is a fraction of the canvas; +x is right, +y is down. Web
# maskable stays full-bleed (scale=1).
ADAPTIVE_SCALE = 48 / 108
ADAPTIVE_OFFSET = (0.0, 0.0)
WEB_MASKABLE_SCALE = 1.0
WEB_MASKABLE_OFFSET = (0.0, 0.0)

DENSITIES = {
    "mdpi": 1,
    "hdpi": 2,
    "xhdpi": 2,  # placeholder, overwritten below with exact px
}

# Legacy launcher (48dp) and adaptive foreground (108dp) sizes in px.
LEGACY_PX = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
FOREGROUND_PX = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}


def parse_crop(text: str) -> tuple[int, int, int, int]:
    parts = [int(p.strip()) for p in text.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("crop must be left,top,right,bottom")
    return tuple(parts)  # type: ignore[return-value]


def sample_edge_color(im: Image.Image, border: int = 4) -> tuple[int, int, int]:
    """Mean RGB of the outer `border` pixels, used as the adaptive mat."""
    im = im.convert("RGB")
    w, h = im.size
    b = max(1, min(border, min(w, h) // 2))
    total = [0, 0, 0]
    n = 0
    px = im.load()
    for y in range(h):
        for x in range(w):
            if x < b or y < b or x >= w - b or y >= h - b:
                r, g, bch = px[x, y]
                total[0] += r
                total[1] += g
                total[2] += bch
                n += 1
    if n == 0:
        return BG_COLOR
    return (round(total[0] / n), round(total[1] / n), round(total[2] / n))


def resample(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    return im.resize(size, Image.Resampling.LANCZOS)


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Keep RGB for opaque images, RGBA when alpha is used.
    im.save(path, format="PNG", optimize=True, compress_level=9)


def make_master(source: Image.Image, crop: tuple[int, int, int, int] | None) -> Image.Image:
    im = source.convert("RGB")
    if crop:
        left, top, right, bottom = crop
        if right <= left or bottom <= top:
            raise SystemExit(f"invalid crop box: {crop}")
        im = im.crop((left, top, right, bottom))
    if im.size != (MASTER_SIZE, MASTER_SIZE):
        im = resample(im, (MASTER_SIZE, MASTER_SIZE))
    return im


def _cover_crop(
    master: Image.Image,
    canvas_size: int,
    scale: float,
    offset: tuple[float, float],
) -> Image.Image:
    """Resize the master to cover the canvas at `scale`, then crop.

    scale=1 and offset=(0, 0) is a straight edge-to-edge resize.
    scale>1 zooms in; offset shifts the crop (fraction of canvas size).
    """
    src_size = max(canvas_size, int(round(canvas_size * max(scale, 1.0))))
    scene = resample(master, (src_size, src_size))
    extra = src_size - canvas_size
    ox = int(round(extra / 2 + offset[0] * canvas_size))
    oy = int(round(extra / 2 + offset[1] * canvas_size))
    ox = max(0, min(extra, ox))
    oy = max(0, min(extra, oy))
    return scene.crop((ox, oy, ox + canvas_size, oy + canvas_size))


def _edge_extend(content: Image.Image, canvas_size: int, origin: tuple[int, int]) -> Image.Image:
    """Paste content and fill the remaining ring by stretching edge pixels.

    The bleed is lightly blurred, then the original content is pasted
    back so the visible 72dp stays sharp and the join has no hard seam.
    """
    content = content.convert("RGB")
    cw, ch = content.size
    x0, y0 = origin
    x1, y1 = x0 + cw, y0 + ch
    if x0 < 0 or y0 < 0 or x1 > canvas_size or y1 > canvas_size:
        raise ValueError("content does not fit on the canvas")
    canvas = Image.new("RGB", (canvas_size, canvas_size))
    canvas.paste(content, (x0, y0))
    if y0 > 0:
        top = content.crop((0, 0, cw, 1)).resize((cw, y0), Image.Resampling.BILINEAR)
        canvas.paste(top, (x0, 0))
    if y1 < canvas_size:
        bot = content.crop((0, ch - 1, cw, ch)).resize((cw, canvas_size - y1), Image.Resampling.BILINEAR)
        canvas.paste(bot, (x0, y1))
    if x0 > 0:
        left = canvas.crop((x0, 0, x0 + 1, canvas_size)).resize((x0, canvas_size), Image.Resampling.BILINEAR)
        canvas.paste(left, (0, 0))
    if x1 < canvas_size:
        right = canvas.crop((x1 - 1, 0, x1, canvas_size)).resize(
            (canvas_size - x1, canvas_size), Image.Resampling.BILINEAR
        )
        canvas.paste(right, (x1, 0))
    pad = min(x0, y0, canvas_size - x1, canvas_size - y1)
    if pad > 0:
        radius = max(1.0, pad / 3.0)
        canvas = canvas.filter(ImageFilter.GaussianBlur(radius=radius))
        canvas.paste(content, (x0, y0))
    return canvas


def _fit_with_bleed(
    master: Image.Image,
    canvas_size: int,
    scale: float,
    offset: tuple[float, float],
) -> Image.Image:
    """Scale the master into the centre and fill the outer ring by edge extension."""
    content = max(1, int(round(canvas_size * scale)))
    if (canvas_size - content) % 2:
        content -= 1
        content = max(1, content)
    pad = (canvas_size - content) // 2
    ox = pad + int(round(offset[0] * canvas_size))
    oy = pad + int(round(offset[1] * canvas_size))
    ox = max(0, min(canvas_size - content, ox))
    oy = max(0, min(canvas_size - content, oy))
    scene = resample(master, (content, content))
    return _edge_extend(scene, canvas_size, (ox, oy))


def full_bleed(
    master: Image.Image,
    canvas_size: int,
    scale: float,
    offset: tuple[float, float],
    background: tuple[int, ...] | None,
) -> Image.Image:
    """Place the master on a square canvas.

    scale >= 1 covers the canvas (zoom/crop). scale < 1 shrinks the
    master into the centre (scale=48/108 fits the 72dp circle). When
    background is set, the ring is that solid colour so the visible
    mat and the 18dp bleed match the house. When it is omitted, the
    ring is filled by stretching and blurring the master's edge.
    """
    if scale >= 1.0:
        scene = _cover_crop(master, canvas_size, scale, offset)
        if background is None:
            if scene.mode != "RGBA":
                return scene.convert("RGBA")
            return scene
        canvas = Image.new("RGB", (canvas_size, canvas_size), background[:3])
        canvas.paste(scene.convert("RGB"), (0, 0))
        return canvas
    if background is None:
        return _fit_with_bleed(master, canvas_size, scale, offset)
    content = max(1, int(round(canvas_size * scale)))
    if (canvas_size - content) % 2:
        content -= 1
        content = max(1, content)
    pad = (canvas_size - content) // 2
    ox = pad + int(round(offset[0] * canvas_size))
    oy = pad + int(round(offset[1] * canvas_size))
    ox = max(0, min(canvas_size - content, ox))
    oy = max(0, min(canvas_size - content, oy))
    scene = resample(master, (content, content))
    canvas = Image.new("RGB", (canvas_size, canvas_size), background[:3])
    canvas.paste(scene.convert("RGB"), (ox, oy))
    return canvas


def place_in_safe_zone(
    master: Image.Image,
    canvas_size: int,
    safe_frac: float,
    background: tuple[int, ...] | None,
) -> Image.Image:
    """Scale the full scene into the centre safe_frac of a square canvas.

    Kept for previews of the old padded treatment; launcher icons no
    longer use this for adaptive foreground or web maskable assets.
    """
    content = max(1, int(round(canvas_size * safe_frac)))
    # Keep content even/odd matched to canvas so padding is symmetric.
    if (canvas_size - content) % 2:
        content -= 1
        content = max(1, content)
    pad = (canvas_size - content) // 2
    scene = resample(master, (content, content))
    if background is None:
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        if scene.mode != "RGBA":
            scene = scene.convert("RGBA")
        canvas.paste(scene, (pad, pad), scene)
        return canvas
    canvas = Image.new("RGB", (canvas_size, canvas_size), background[:3])
    canvas.paste(scene.convert("RGB"), (pad, pad))
    return canvas


def viewport_crop(layer: Image.Image, viewport_frac: float) -> Image.Image:
    """Centre-crop a 108dp layer to the 72dp (or other) launcher viewport."""
    canvas_size = layer.size[0]
    vis = max(1, int(round(canvas_size * viewport_frac)))
    if (canvas_size - vis) % 2:
        vis -= 1
        vis = max(1, vis)
    pad = (canvas_size - vis) // 2
    return layer.crop((pad, pad, canvas_size - pad, canvas_size - pad))


def adaptive_visible(
    master: Image.Image,
    display_px: int,
    scale: float = ADAPTIVE_SCALE,
    offset: tuple[float, float] = ADAPTIVE_OFFSET,
) -> Image.Image:
    """What an Android launcher shows: centre 72/108 of the 108dp layer, with the master at ADAPTIVE_SCALE."""
    # Render the 108dp layer at a multiple of 108 so the 72dp crop is exact.
    layer_px = 108 * 10
    layer = full_bleed(master, layer_px, scale, offset, background=BG_COLOR)
    visible = viewport_crop(layer, ANDROID_VIEWPORT)
    return resample(visible, (display_px, display_px))


def circle_mask(size: int) -> Image.Image:
    # 4x supersample for a smooth edge, then downscale.
    scale = 4
    big = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(big).ellipse((0, 0, size * scale - 1, size * scale - 1), fill=255)
    return big.resize((size, size), Image.Resampling.LANCZOS)


def apply_circle(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    mask = circle_mask(im.size[0])
    rgba.putalpha(mask)
    return rgba


def make_monochrome(master: Image.Image, size: int) -> Image.Image:
    """White silhouette of the lit window and doorway, framed like the colour foreground.

    The glyph uses the same central 48dp as the colour artwork. The bleed
    stays transparent: edge-extending a thresholded silhouette would leak
    white streaks into themed icons.
    """
    content = max(1, int(round(size * ADAPTIVE_SCALE)))
    if (size - content) % 2:
        content -= 1
        content = max(1, content)
    pad = (size - content) // 2
    ox = pad + int(round(ADAPTIVE_OFFSET[0] * size))
    oy = pad + int(round(ADAPTIVE_OFFSET[1] * size))
    ox = max(0, min(size - content, ox))
    oy = max(0, min(size - content, oy))
    placed = resample(master, (content, content))
    gray = ImageOps.autocontrast(placed.convert("L"), cutoff=1)
    # Slight blur before the threshold fills pane gaps without jagged speckles.
    soft = gray.filter(ImageFilter.GaussianBlur(1.2))
    glyph = soft.point(lambda p: 255 if p >= 80 else 0)
    glyph = glyph.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    alpha = Image.new("L", (size, size), 0)
    alpha.paste(glyph, (ox, oy))
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def sharpen_small(im: Image.Image, size: int) -> Image.Image:
    if size <= 64:
        return im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=80, threshold=2))
    if size <= 192:
        return im.filter(ImageFilter.UnsharpMask(radius=0.8, percent=50, threshold=2))
    return im


def write_android(master: Image.Image, res: Path) -> list[Path]:
    written: list[Path] = []
    for density, legacy_px in LEGACY_PX.items():
        folder = res / f"mipmap-{density}"
        square = sharpen_small(resample(master, (legacy_px, legacy_px)), legacy_px)
        square_path = folder / "ic_launcher.png"
        save_png(square.convert("RGB"), square_path)
        written.append(square_path)

        round_path = folder / "ic_launcher_round.png"
        save_png(apply_circle(square), round_path)
        written.append(round_path)

        fg_px = FOREGROUND_PX[density]
        fg = full_bleed(master, fg_px, ADAPTIVE_SCALE, ADAPTIVE_OFFSET, background=BG_COLOR)
        if fg_px <= 192:
            fg = sharpen_small(fg, fg_px)
        fg_path = folder / "ic_launcher_foreground.png"
        save_png(fg, fg_path)
        written.append(fg_path)

    mono_path = res / "mipmap-xxxhdpi" / "ic_launcher_monochrome.png"
    save_png(make_monochrome(master, FOREGROUND_PX["xxxhdpi"]), mono_path)
    written.append(mono_path)

    bg_xml = res / "values" / "ic_launcher_background.xml"
    bg_xml.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="ic_launcher_background">#{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}</color>\n'
        "</resources>\n"
    )
    # XML is written above; it is not an image so it stays out of `written`.
    return written


def write_web(master: Image.Image, web: Path) -> list[Path]:
    written: list[Path] = []
    icons = web / "icons"

    def full(size: int) -> Image.Image:
        return sharpen_small(resample(master, (size, size)), size).convert("RGB")

    def maskable(size: int) -> Image.Image:
        im = full_bleed(
            master, size, WEB_MASKABLE_SCALE, WEB_MASKABLE_OFFSET, background=BG_COLOR
        )
        return sharpen_small(im, size).convert("RGB")

    mapping: list[tuple[Path, Image.Image]] = [
        (icons / "Icon-192.png", full(192)),
        (icons / "Icon-512.png", full(512)),
        (icons / "Icon-maskable-192.png", maskable(192)),
        (icons / "Icon-maskable-512.png", maskable(512)),
        (icons / "nl3-192.png", full(192)),
        (icons / "nl3-512.png", full(512)),
        (icons / "nl3-maskable-192.png", maskable(192)),
        (icons / "nl3-maskable-512.png", maskable(512)),
        (icons / "nl3-152.png", full(152)),
        (icons / "nl3-167.png", full(167)),
        (icons / "nl3-180.png", full(180)),
        (icons / "apple-touch-icon.png", full(180)),
        (web / "apple-touch-icon.png", full(180)),
        (web / "apple-touch-icon-precomposed.png", full(180)),
        (web / "favicon.png", full(32)),
        (web / "favicon-nl3-32.png", full(32)),
        (web / "favicon-nl3-16.png", full(16)),
    ]
    for path, im in mapping:
        save_png(im, path)
        written.append(path)
    return written


def squircle_mask(size: int, n: float = 5.0) -> Image.Image:
    """Superellipse mask similar to an Android adaptive squircle."""
    scale = 4
    s = size * scale
    mask = Image.new("L", (s, s), 0)
    px = mask.load()
    c = (s - 1) / 2.0
    r = c
    for y in range(s):
        for x in range(s):
            nx = abs(x - c) / r
            ny = abs(y - c) / r
            if nx ** n + ny ** n <= 1.0:
                px[x, y] = 255
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def rounded_square_mask(size: int, radius_frac: float = 0.25) -> Image.Image:
    """Rounded-square launcher mask; 0.25 of the side is ~18dp on a 72dp viewport."""
    scale = 4
    s = size * scale
    rad = max(1, int(round(s * radius_frac)))
    big = Image.new("L", (s, s), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, s - 1, s - 1), radius=rad, fill=255)
    return big.resize((size, size), Image.Resampling.LANCZOS)


def apply_mask(im: Image.Image, mask: Image.Image, bg=(245, 245, 247)) -> Image.Image:
    base = Image.new("RGB", im.size, bg)
    rgba = im.convert("RGBA")
    rgba.putalpha(mask)
    base.paste(Image.new("RGB", im.size, bg), (0, 0))
    out = Image.new("RGBA", im.size, bg + (255,))
    out.alpha_composite(rgba)
    return out.convert("RGB")


def _scale_tag() -> str:
    return f"{int(round(ADAPTIVE_SCALE * 108))}/108"


def write_preview(
    master: Image.Image,
    dest: Path,
    web_icon_192: Image.Image,
    web_maskable_192: Image.Image,
) -> None:
    # Adaptive compositing at each preview size: 108dp layer (master in
    # the central 48dp, solid sampled-colour mat), then the launcher
    # viewport (centre 72/108), then the shape mask.
    sizes = (48, 96, 192)
    scale_tag = _scale_tag()
    canvas = Image.new("RGB", (1200, 1400), (28, 30, 36))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (24, 16),
        f"New Life UK icon preview  —  adaptive {scale_tag} framing + web maskable  (v7 master)",
        fill=(230, 230, 230),
    )
    legend = (
        f"Adaptive: master scaled to centre {scale_tag} so the whole square fits "
        f"the 72dp circle  ·  web maskable: full-bleed, 80% safe  ·  "
        f"bg #{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}"
    )
    draw.text((24, 36), legend, fill=(170, 176, 186))

    def adaptive_tile(px: int) -> Image.Image:
        return adaptive_visible(master, px)

    def legacy_tile(px: int) -> Image.Image:
        return resample(master, (px, px))

    y = 70
    rows = [
        (f"Adaptive · circle (48 / 96 / 192)  —  master in centre {scale_tag} of the 108dp layer", adaptive_tile, circle_mask),
        (f"Adaptive · squircle (48 / 96 / 192)  —  master in centre {scale_tag} of the 108dp layer", adaptive_tile, squircle_mask),
        (f"Adaptive · rounded square (48 / 96 / 192)  —  master in centre {scale_tag} of the 108dp layer", adaptive_tile, rounded_square_mask),
        ("Legacy full-bleed · circle (48 / 96 / 192)", legacy_tile, circle_mask),
        ("Legacy full-bleed · squircle (48 / 96 / 192)", legacy_tile, squircle_mask),
    ]
    for label, maker, mask_fn in rows:
        draw.text((24, y), label, fill=(210, 214, 220))
        y += 22
        x = 24
        for px in sizes:
            tile = maker(px)
            mask = mask_fn(px)
            plate = Image.new("RGB", (px + 16, px + 16), (42, 45, 54))
            masked = apply_mask(tile, mask, bg=(42, 45, 54))
            plate.paste(masked, (8, 8))
            canvas.paste(plate, (x, y + (192 - plate.size[1]) // 2))
            cap = f"{px}px"
            draw.text((x, y + 192 - 2), cap, fill=(150, 154, 164))
            x += 192 + 36
        y += 192 + 16

    draw.text(
        (24, y),
        "Web · Icon-192 (any) and Icon-maskable-192 (full-bleed, shown raw and under a circle / squircle)",
        fill=(210, 214, 220),
    )
    y += 22
    x = 24
    any192 = web_icon_192.convert("RGB")
    canvas.paste(any192, (x, y))
    draw.text((x, y + 196), "Icon-192 / nl3-192", fill=(150, 154, 164))
    x += 192 + 36
    mask192 = web_maskable_192.convert("RGB")
    canvas.paste(mask192, (x, y))
    draw.text((x, y + 196), "maskable-192 raw", fill=(150, 154, 164))
    x += 192 + 36
    circled = apply_mask(mask192, circle_mask(192), bg=(42, 45, 54))
    canvas.paste(circled, (x, y))
    draw.text((x, y + 196), "maskable · circle crop", fill=(150, 154, 164))
    x += 192 + 36
    squir = apply_mask(mask192, squircle_mask(192), bg=(42, 45, 54))
    canvas.paste(squir, (x, y))
    draw.text((x, y + 196), "maskable · squircle crop", fill=(150, 154, 164))

    dest.parent.mkdir(parents=True, exist_ok=True)
    save_png(canvas, dest)


def verify(written: list[Path], expected: dict[Path, tuple[int, int]]) -> None:
    errors = []
    for path, (w, h) in expected.items():
        if not path.is_file():
            errors.append(f"missing {path}")
            continue
        with Image.open(path) as im:
            if im.size != (w, h):
                errors.append(f"{path} is {im.size}, expected {(w, h)}")
    if errors:
        raise SystemExit("verification failed:\n  " + "\n  ".join(errors))


def verify_adaptive_margin(res: Path) -> None:
    """Foreground corners must be the sampled mat; the centre must be the picture."""
    errors = []
    for density, fg_px in FOREGROUND_PX.items():
        path = res / f"mipmap-{density}" / "ic_launcher_foreground.png"
        content = int(round(fg_px * ADAPTIVE_SCALE))
        if (fg_px - content) % 2:
            content -= 1
        pad = (fg_px - content) // 2
        with Image.open(path) as im:
            im = im.convert("RGB")
            for pt in ((0, 0), (fg_px - 1, 0), (0, fg_px - 1), (fg_px - 1, fg_px - 1)):
                if im.getpixel(pt) != BG_COLOR:
                    errors.append(f"{path} corner {pt} is {im.getpixel(pt)}, expected {BG_COLOR}")
            mid = im.getpixel((fg_px // 2, fg_px // 2))
            if mid == BG_COLOR:
                errors.append(f"{path} centre {mid} should be the photograph, not the mat")
            if pad < 1:
                errors.append(f"{path} pad {pad} is too small for scale {ADAPTIVE_SCALE}")
    bg_xml = res / "values" / "ic_launcher_background.xml"
    text = bg_xml.read_text()
    hex_bg = f"#{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}"
    if hex_bg not in text:
        errors.append(f"{bg_xml} missing {hex_bg}")
    if errors:
        raise SystemExit("adaptive margin check failed:\n  " + "\n  ".join(errors))


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True, type=Path, help="Path to the approved source image")
    p.add_argument("--repo", type=Path, default=None, help="Repo root (contains app/)")
    p.add_argument(
        "--crop",
        type=parse_crop,
        default=DEFAULT_CROP,
        help="PIL crop box left,top,right,bottom (default 86,86,938,938). Use 0,0,0,0 to skip.",
    )
    p.add_argument("--no-crop", action="store_true", help="Use the full source, already a tight square")
    p.add_argument("--preview", type=Path, default=None, help="Optional preview grid path")
    args = p.parse_args(argv)

    source_path = args.source.expanduser().resolve()
    if not source_path.is_file():
        raise SystemExit(f"source not found: {source_path}")
    if "icon_v6_final" in source_path.name:
        raise SystemExit("refused: icon_v6_final.jpg was rejected; pass the approved source")

    repo = (args.repo or Path.cwd()).expanduser().resolve()
    app = repo / "app"
    if not (app / "android").is_dir() or not (app / "web").is_dir():
        raise SystemExit(f"does not look like the app repo root: {repo}")

    using_master = source_path.name in {"icon_master.png", "icon_1024.png"}
    crop = None if args.no_crop or args.crop == (0, 0, 0, 0) else args.crop
    if crop and using_master and args.crop == DEFAULT_CROP:
        print("source is the approved 1024 master; skipping the v7 frame crop")
        crop = None

    with Image.open(source_path) as src:
        print(f"source: {source_path}  size={src.size} mode={src.mode}")
        master = make_master(src, crop)
    if crop:
        print(f"crop:   {crop}  ({crop[2]-crop[0]}x{crop[3]-crop[1]})  upscaled to {master.size}")
    else:
        print(f"crop:   none  master={master.size}")

    global BG_COLOR
    sampled = sample_edge_color(master, border=4)
    if sampled != BG_COLOR:
        print(
            f"edge colour: sampled #{sampled[0]:02X}{sampled[1]:02X}{sampled[2]:02X} "
            f"(constant was #{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}); using sampled"
        )
        BG_COLOR = sampled
    else:
        print(f"edge colour: #{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}  (matches 4px edge mean)")

    brand_dir = app / "tool" / "brand"
    master_path = brand_dir / "icon_master.png"
    icon_1024_path = brand_dir / "icon_1024.png"
    # Do not recompress the approved master when it is the (uncropped) source.
    rewrite_master = True
    try:
        src_resolved = source_path.resolve()
        if crop is None and src_resolved in {master_path.resolve(), icon_1024_path.resolve()}:
            rewrite_master = False
    except FileNotFoundError:
        rewrite_master = True
    if rewrite_master:
        save_png(master, master_path)
        save_png(master, icon_1024_path)

    res = app / "android" / "app" / "src" / "main" / "res"
    web = app / "web"
    written = [master_path, icon_1024_path]
    written += write_android(master, res)
    written += write_web(master, web)

    expected: dict[Path, tuple[int, int]] = {
        master_path: (1024, 1024),
        icon_1024_path: (1024, 1024),
        web / "favicon.png": (32, 32),
        web / "favicon-nl3-32.png": (32, 32),
        web / "favicon-nl3-16.png": (16, 16),
        web / "apple-touch-icon.png": (180, 180),
        web / "apple-touch-icon-precomposed.png": (180, 180),
        web / "icons" / "apple-touch-icon.png": (180, 180),
        web / "icons" / "Icon-192.png": (192, 192),
        web / "icons" / "Icon-512.png": (512, 512),
        web / "icons" / "Icon-maskable-192.png": (192, 192),
        web / "icons" / "Icon-maskable-512.png": (512, 512),
        web / "icons" / "nl3-152.png": (152, 152),
        web / "icons" / "nl3-167.png": (167, 167),
        web / "icons" / "nl3-180.png": (180, 180),
        web / "icons" / "nl3-192.png": (192, 192),
        web / "icons" / "nl3-512.png": (512, 512),
        web / "icons" / "nl3-maskable-192.png": (192, 192),
        web / "icons" / "nl3-maskable-512.png": (512, 512),
    }
    for density, px in LEGACY_PX.items():
        expected[res / f"mipmap-{density}" / "ic_launcher.png"] = (px, px)
        expected[res / f"mipmap-{density}" / "ic_launcher_round.png"] = (px, px)
        expected[res / f"mipmap-{density}" / "ic_launcher_foreground.png"] = (
            FOREGROUND_PX[density],
            FOREGROUND_PX[density],
        )
    expected[res / "mipmap-xxxhdpi" / "ic_launcher_monochrome.png"] = (432, 432)
    verify(written, expected)
    verify_adaptive_margin(res)

    if args.preview:
        write_preview(
            master,
            args.preview,
            Image.open(web / "icons" / "Icon-192.png"),
            Image.open(web / "icons" / "Icon-maskable-192.png"),
        )
        print(f"preview: {args.preview}")

    print(f"wrote {len(written)} files:")
    for path in written:
        rel = path.relative_to(repo) if path.is_relative_to(repo) else path
        with Image.open(path) as im:
            print(f"  {im.size[0]}x{im.size[1]}  {im.mode:4s}  {path.stat().st_size:8d}  {rel}")
    bg_xml = res / "values" / "ic_launcher_background.xml"
    print(f"  background color  #{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}  {bg_xml.relative_to(repo)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
