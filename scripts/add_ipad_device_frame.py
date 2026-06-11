"""Wrap screenshots in an iPad-style device frame on App Store canvas (2064×2752, PNG transparent)."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

CANVAS_W = 2064
CANVAS_H = 2752
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}


def round_corners_rgba(image: Image.Image, radius: int) -> Image.Image:
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, image.size[0] - 1, image.size[1] - 1), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def outer_round_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def fit_size(src_w: int, src_h: int, max_w: int, max_h: int) -> tuple[int, int]:
    scale = min(max_w / src_w, max_h / src_h)
    return max(1, int(round(src_w * scale))), max(1, int(round(src_h * scale)))


def apply_ipad_frame(image: Image.Image) -> Image.Image:
    """iPad Pro-style bezel; canvas 2064×2752, transparent outside device."""
    w, h = CANVAS_W, CANVAS_H
    src = image.convert("RGB")

    bezel_side = max(48, int(round(w * 0.028)))
    bezel_top = max(54, int(round(w * 0.032)))
    bezel_bottom = max(48, int(round(w * 0.026)))
    outer_radius = max(96, int(round(w * 0.055)))
    inner_radius = max(64, int(round(w * 0.038)))

    inner_w = w - bezel_side * 2
    inner_h = h - bezel_top - bezel_bottom

    sw, sh = fit_size(src.width, src.height, inner_w, inner_h)
    screen = src.resize((sw, sh), Image.Resampling.LANCZOS)
    screen = round_corners_rgba(screen, inner_radius)

    sx = bezel_side + (inner_w - sw) // 2
    sy = bezel_top + (inner_h - sh) // 2

    body = (28, 28, 30)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    device = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body_layer = Image.new("RGBA", (w, h), body + (255,))

    device.paste(body_layer, (0, 0))
    device.paste(screen, (sx, sy), screen)

    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    draw.rounded_rectangle(
        (1, 1, w - 2, h - 2),
        radius=outer_radius,
        outline=(100, 100, 106, 210),
        width=3,
    )
    draw.rounded_rectangle(
        (5, 5, w - 6, h - 6),
        radius=max(12, outer_radius - 4),
        outline=(0, 0, 0, 100),
        width=2,
    )

    draw.rounded_rectangle(
        (sx - 2, sy - 2, sx + sw + 1, sy + sh + 1),
        radius=inner_radius + 1,
        outline=(0, 0, 0, 150),
        width=2,
    )
    draw.rounded_rectangle(
        (sx, sy, sx + sw - 1, sy + sh - 1),
        radius=inner_radius,
        outline=(255, 255, 255, 40),
        width=1,
    )

    # iPad front camera dot
    cam_r = max(6, int(round(w * 0.0045)))
    cam_x = w // 2
    cam_y = bezel_top // 2
    draw.ellipse(
        (cam_x - cam_r, cam_y - cam_r, cam_x + cam_r, cam_y + cam_r),
        fill=(20, 20, 22, 255),
    )
    draw.ellipse(
        (cam_x - cam_r + 2, cam_y - cam_r + 2, cam_x + cam_r - 2, cam_y + cam_r - 2),
        fill=(45, 45, 50, 255),
    )

    # Top power button (right)
    btn_w = max(4, int(round(w * 0.005)))
    btn_h = max(36, int(round(h * 0.045)))
    draw.rounded_rectangle(
        (w - btn_w, int(h * 0.12), w, int(h * 0.12) + btn_h),
        radius=2,
        fill=(42, 42, 46, 255),
    )

    device = Image.alpha_composite(device, overlay)

    mask = outer_round_mask((w, h), outer_radius)
    canvas.paste(device, (0, 0), mask)
    return canvas


def process_folder(folder: Path, *, out_dir: Path | None = None) -> int:
    target = out_dir or folder
    target.mkdir(parents=True, exist_ok=True)

    ok = 0
    failed: list[tuple[str, str]] = []

    for src in sorted(folder.iterdir()):
        if src.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        if src.parent.name == "framed" and out_dir is None:
            continue

        dst = target / f"{src.stem}.png"
        try:
            with Image.open(src) as raw:
                framed = apply_ipad_frame(raw)
                if framed.size != (CANVAS_W, CANVAS_H):
                    raise ValueError(f"expected {CANVAS_W}x{CANVAS_H}, got {framed.size}")
                framed.save(dst, format="PNG", optimize=True)

            ok += 1
            kb = dst.stat().st_size / 1024
            print(f"OK  {src.name} -> {dst.name} ({kb:.0f} KB)")
        except Exception as exc:  # noqa: BLE001
            failed.append((src.name, str(exc)))
            print(f"FAIL {src.name}: {exc}")

    print()
    print(f"Processed: {ok}")
    print(f"Output: {target} ({CANVAS_W}x{CANVAS_H} PNG)")
    if failed:
        for name, err in failed:
            print(f"  - {name}: {err}")
        return 2
    return 0


def main() -> int:
    folder = Path(r"C:\Users\Dell\Downloads\IPAD")
    if len(sys.argv) > 1:
        folder = Path(sys.argv[1])
    if not folder.is_dir():
        print(f"Folder not found: {folder}")
        return 1
    return process_folder(folder)


if __name__ == "__main__":
    sys.exit(main())
