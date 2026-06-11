"""Batch App Store screenshot framing for FaceBaby."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# App Store 6.5" portrait (matches correct/iphone templates).
CANVAS_W = 1242
CANVAS_H = 2688
MARGIN = 56
SHADOW_OFFSET = (0, 16)
SHADOW_BLUR = 32
SHADOW_ALPHA = 90
CORNER_RADIUS = 32

COLOR_PURPLE = (0x8A, 0x2B, 0xE2)
COLOR_PINK = (0xFF, 0x69, 0xB4)
COLOR_LIGHT_PURPLE = (0xC8, 0xA2, 0xFF)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}


def _lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def _lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (_lerp(c1[0], c2[0], t), _lerp(c1[1], c2[1], t), _lerp(c1[2], c2[2], t))


def make_premium_background(width: int, height: int) -> Image.Image:
    """Vertical gradient: purple -> pink -> light purple."""
    img = Image.new("RGB", (width, height))
    px = img.load()
    mid = (height - 1) / 2
    for y in range(height):
        if y <= mid:
            t = y / mid if mid else 0.0
            color = _lerp_color(COLOR_PURPLE, COLOR_PINK, t)
        else:
            t = (y - mid) / mid if mid else 0.0
            color = _lerp_color(COLOR_PINK, COLOR_LIGHT_PURPLE, t)
        for x in range(width):
            px[x, y] = color
    return img


def round_corners_rgba(image: Image.Image, radius: int) -> Image.Image:
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, image.size[0], image.size[1]), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def fit_size(src_w: int, src_h: int, max_w: int, max_h: int) -> tuple[int, int]:
    scale = min(max_w / src_w, max_h / src_h)
    return max(1, int(round(src_w * scale))), max(1, int(round(src_h * scale)))


def make_shadow(size: tuple[int, int], radius: int) -> Image.Image:
    w, h = size
    pad = SHADOW_BLUR * 2
    layer = Image.new("RGBA", (w + pad, h + pad), (0, 0, 0, 0))
    shape = Image.new("RGBA", (w, h), (0, 0, 0, SHADOW_ALPHA))
    shape = round_corners_rgba(shape, radius)
    layer.paste(shape, (pad // 2, pad // 2), shape)
    return layer.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))


def process_screenshot(src: Path, dst: Path) -> None:
    with Image.open(src) as raw:
        screenshot = raw.convert("RGBA")

    max_w = CANVAS_W - MARGIN * 2
    max_h = CANVAS_H - MARGIN * 2
    new_w, new_h = fit_size(screenshot.width, screenshot.height, max_w, max_h)
    screenshot = screenshot.resize((new_w, new_h), Image.Resampling.LANCZOS)
    screenshot = round_corners_rgba(screenshot, CORNER_RADIUS)

    canvas = make_premium_background(CANVAS_W, CANVAS_H).convert("RGBA")
    x = (CANVAS_W - new_w) // 2
    y = (CANVAS_H - new_h) // 2

    shadow = make_shadow((new_w, new_h), CORNER_RADIUS)
    shadow_x = x + SHADOW_OFFSET[0] - SHADOW_BLUR
    shadow_y = y + SHADOW_OFFSET[1] - SHADOW_BLUR
    canvas.alpha_composite(shadow, (shadow_x, shadow_y))
    canvas.alpha_composite(screenshot, (x, y))

    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dst, format="PNG", optimize=True)


def safe_output_name(src: Path) -> str:
    stem = re.sub(r"[^\w\-]+", "_", src.stem).strip("_")
    if not stem:
        stem = "screenshot"
    return f"{stem}.png"


def main() -> int:
    src_dir = Path(r"C:\Users\Dell\Downloads\IPHONE_Screenshots")
    out_dir = src_dir / "AppStore_Ready"

    if not src_dir.is_dir():
        print(f"ERROR: Source folder not found: {src_dir}")
        return 1

    files = sorted(
        p for p in src_dir.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )

    if not files:
        print(f"No images found in {src_dir}")
        return 1

    ok: list[Path] = []
    failed: list[tuple[Path, str]] = []

    for src in files:
        dst = out_dir / safe_output_name(src)
        try:
            process_screenshot(src, dst)
            ok.append(dst)
            print(f"OK  {src.name} -> {dst.name}")
        except Exception as exc:  # noqa: BLE001
            failed.append((src, str(exc)))
            print(f"FAIL {src.name}: {exc}")

    print()
    print(f"Processed: {len(ok)} / {len(files)}")
    print(f"Output folder: {out_dir}")
    if failed:
        print(f"Failures: {len(failed)}")
        for src, err in failed:
            print(f"  - {src.name}: {err}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
