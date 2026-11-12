#!/usr/bin/env python3
"""Generate Android and web launcher icons from a source image.

Usage:
  python3 app/tool/make_app_icons.py --source /path/to/icon.jpg \\
      --repo /path/to/the-toms [--crop 86,86,938,938] \\
      [--preview /workspace/icon_preview_grid.png]

The approved v7 still has a baked-in rounded frame. By default this
script crops inside that frame, upscales to 1024, writes
app/tool/brand/icon_master.png (and icon_1024.png), then resizes every
Android mipmap and web icon in place. File names are unchanged so
manifests do not need editing. No pub dependencies are added; Pillow
is only used on the machine that runs this script.
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
BG_COLOR = (6, 26, 66)  # existing #061A42 in ic_launcher_background.xml
ANDROID_SAFE = 66 / 100  # adaptive foreground safe zone (72/108 dp)
WEB_MASKABLE_SAFE = 80 / 100  # typical maskable safe zone

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


def place_in_safe_zone(
    master: Image.Image,
    canvas_size: int,
    safe_frac: float,
    background: tuple[int, ...] | None,
) -> Image.Image:
    """Scale the full scene into the centre safe_frac of a square canvas."""
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
    """White silhouette of the lit window and doorway, in the 66% safe zone."""
    from PIL import ImageChops

    placed = place_in_safe_zone(master, size, ANDROID_SAFE, background=None)
    gray = ImageOps.autocontrast(placed.convert("L"), cutoff=1)
    # Slight blur before the threshold fills pane gaps without jagged speckles.
    soft = gray.filter(ImageFilter.GaussianBlur(1.2))
    glyph = soft.point(lambda p: 255 if p >= 80 else 0)
    glyph = glyph.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    safe = placed.split()[-1].point(lambda p: 255 if p > 128 else 0)
    glyph = ImageChops.multiply(glyph, safe)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(glyph)
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
        fg = place_in_safe_zone(master, fg_px, ANDROID_SAFE, background=None)
        fg_path = folder / "ic_launcher_foreground.png"
        save_png(fg, fg_path)
        written.append(fg_path)

    mono_path = res / "mipmap-xxxhdpi" / "ic_launcher_monochrome.png"
    save_png(make_monochrome(master, FOREGROUND_PX["xxxhdpi"]), mono_path)
    written.append(mono_path)
    return written


def write_web(master: Image.Image, web: Path) -> list[Path]:
    written: list[Path] = []
    icons = web / "icons"

    def full(size: int) -> Image.Image:
        return sharpen_small(resample(master, (size, size)), size).convert("RGB")

    def maskable(size: int) -> Image.Image:
        return place_in_safe_zone(master, size, WEB_MASKABLE_SAFE, background=BG_COLOR).convert("RGB")

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


def apply_mask(im: Image.Image, mask: Image.Image, bg=(245, 245, 247)) -> Image.Image:
    base = Image.new("RGB", im.size, bg)
    rgba = im.convert("RGBA")
    rgba.putalpha(mask)
    base.paste(Image.new("RGB", im.size, bg), (0, 0))
    out = Image.new("RGBA", im.size, bg + (255,))
    out.alpha_composite(rgba)
    return out.convert("RGB")


def write_preview(
    master: Image.Image,
    dest: Path,
    web_icon_192: Image.Image,
    web_maskable_192: Image.Image,
) -> None:
    # Adaptive compositing at each preview size: navy bg + 66% scene, then mask.
    sizes = (48, 96, 192)
    tile_gap = 24
    label_h = 28
    col_w = 192
    # rows: adaptive circle, adaptive squircle, legacy circle, legacy squircle, web
    rows_spec = [
        "Adaptive · circle",
        "Adaptive · squircle",
        "Legacy full-bleed · circle",
        "Legacy full-bleed · squircle",
        "Web Icon-192 / maskable-192",
    ]
    width = 40 + (col_w + tile_gap) * 3 + 40 + 192 + tile_gap + 192 + 40
    height = 60 + len(rows_spec) * (192 + label_h + tile_gap) + 40
    # tighter: use row height based on 192
    canvas = Image.new("RGB", (1200, 1180), (28, 30, 36))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 16), "New Life UK icon preview  —  adaptive + web  (v7 crop, full-bleed master)", fill=(230, 230, 230))
    legend = "Safe zone: adaptive 66%  ·  web maskable 80%  ·  bg #061A42"
    draw.text((24, 36), legend, fill=(170, 176, 186))

    def adaptive_tile(px: int) -> Image.Image:
        return place_in_safe_zone(master, px, ANDROID_SAFE, background=BG_COLOR)

    def legacy_tile(px: int) -> Image.Image:
        return resample(master, (px, px))

    y = 70
    # rows 1-2 adaptive, 3-4 legacy
    for row_i, (label, maker) in enumerate(
        [
            ("Adaptive · circle (48 / 96 / 192)", lambda px: adaptive_tile(px)),
            ("Adaptive · squircle (48 / 96 / 192)", lambda px: adaptive_tile(px)),
            ("Legacy full-bleed · circle (48 / 96 / 192)", lambda px: legacy_tile(px)),
            ("Legacy full-bleed · squircle (48 / 96 / 192)", lambda px: legacy_tile(px)),
        ]
    ):
        draw.text((24, y), label, fill=(210, 214, 220))
        y += 22
        is_circle = "circle" in label and "squircle" not in label
        x = 24
        for px in sizes:
            tile = maker(px)
            mask = circle_mask(px) if is_circle else squircle_mask(px)
            # paste onto a slightly lighter plate so the mask edge is visible
            plate = Image.new("RGB", (px + 16, px + 16), (42, 45, 54))
            masked = apply_mask(tile, mask, bg=(42, 45, 54))
            plate.paste(masked, (8, 8))
            canvas.paste(plate, (x, y + (192 - plate.size[1]) // 2))
            cap = f"{px}px"
            draw.text((x, y + 192 - 2), cap, fill=(150, 154, 164))
            x += 192 + 36
        y += 192 + 16

    draw.text((24, y), "Web · Icon-192 (any) and Icon-maskable-192 (80% pad, shown raw and under a circle)", fill=(210, 214, 220))
    y += 22
    x = 24
    # web any
    any192 = web_icon_192.convert("RGB")
    canvas.paste(any192, (x, y))
    draw.text((x, y + 196), "Icon-192 / nl3-192", fill=(150, 154, 164))
    x += 192 + 36
    # maskable raw (shows navy pad)
    mask192 = web_maskable_192.convert("RGB")
    canvas.paste(mask192, (x, y))
    draw.text((x, y + 196), "maskable-192 raw", fill=(150, 154, 164))
    x += 192 + 36
    # maskable under circle (how some launchers crop)
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

    crop = None if args.no_crop or args.crop == (0, 0, 0, 0) else args.crop
    with Image.open(source_path) as src:
        print(f"source: {source_path}  size={src.size} mode={src.mode}")
        master = make_master(src, crop)
    if crop:
        print(f"crop:   {crop}  ({crop[2]-crop[0]}x{crop[3]-crop[1]})  upscaled to {master.size}")
    else:
        print(f"crop:   none  master={master.size}")

    brand_dir = app / "tool" / "brand"
    master_path = brand_dir / "icon_master.png"
    icon_1024_path = brand_dir / "icon_1024.png"
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
