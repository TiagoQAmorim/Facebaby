"""Wrap raw phone screenshots in a procedural iPhone device bezel (same canvas size)."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

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


def apply_iphone_frame(image: Image.Image) -> Image.Image:
    """Draw iPhone-style bezel around screenshot; output matches input dimensions."""
    w, h = image.size
    src = image.convert("RGB")

    bezel_side = max(10, int(round(w * 0.024)))
    bezel_top = max(14, int(round(w * 0.038)))
    bezel_bottom = max(10, int(round(w * 0.024)))
    outer_radius = max(36, int(round(w * 0.092)))
    inner_radius = max(24, int(round(w * 0.052)))

    inner_w = w - bezel_side * 2
    inner_h = h - bezel_top - bezel_bottom

    screen = src.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
    screen = round_corners_rgba(screen, inner_radius)

    body = (24, 24, 26)
    canvas = Image.new("RGBA", (w, h), body + (255,))
    canvas.paste(screen, (bezel_side, bezel_top), screen)

    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Metallic edge highlights
    draw.rounded_rectangle(
        (1, 1, w - 2, h - 2),
        radius=outer_radius,
        outline=(92, 92, 98, 200),
        width=2,
    )
    draw.rounded_rectangle(
        (4, 4, w - 5, h - 5),
        radius=max(8, outer_radius - 3),
        outline=(0, 0, 0, 90),
        width=1,
    )

    # Inner screen lip
    sx, sy = bezel_side, bezel_top
    draw.rounded_rectangle(
        (sx - 1, sy - 1, sx + inner_w, sy + inner_h),
        radius=inner_radius,
        outline=(0, 0, 0, 140),
        width=2,
    )
    draw.rounded_rectangle(
        (sx, sy, sx + inner_w - 1, sy + inner_h - 1),
        radius=max(8, inner_radius - 1),
        outline=(255, 255, 255, 35),
        width=1,
    )

    # Dynamic Island
    island_w = int(round(w * 0.27))
    island_h = max(7, int(round(w * 0.036)))
    island_x = (w - island_w) // 2
    island_y = max(4, bezel_top // 2 - island_h // 2)
    draw.rounded_rectangle(
        (island_x, island_y, island_x + island_w, island_y + island_h),
        radius=island_h // 2,
        fill=(0, 0, 0, 255),
    )

    # Side buttons
    btn_h = max(18, int(round(h * 0.07)))
    btn_w = max(2, int(round(w * 0.006)))
    draw.rounded_rectangle(
        (0, int(h * 0.20), btn_w, int(h * 0.20) + btn_h),
        radius=1,
        fill=(40, 40, 44, 255),
    )
    draw.rounded_rectangle(
        (0, int(h * 0.30), btn_w, int(h * 0.30) + btn_h),
        radius=1,
        fill=(40, 40, 44, 255),
    )
    draw.rounded_rectangle(
        (w - btn_w, int(h * 0.24), w, int(h * 0.24) + btn_h),
        radius=1,
        fill=(40, 40, 44, 255),
    )

    canvas = Image.alpha_composite(canvas, overlay)

    # Clip to device outer silhouette
    mask = outer_round_mask((w, h), outer_radius)
    final = Image.new("RGB", (w, h), (255, 255, 255))
    final.paste(canvas.convert("RGB"), mask=mask)
    return final


def process_folder(folder: Path, *, in_place: bool = True) -> int:
    out_dir = folder if in_place else folder / "framed"
    if not in_place:
        out_dir.mkdir(parents=True, exist_ok=True)

    ok = 0
    failed: list[tuple[str, str]] = []

    for src in sorted(folder.iterdir()):
        if src.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        if not in_place and src.parent.name == "framed":
            continue

        dst = out_dir / src.name
        try:
            with Image.open(src) as raw:
                orig_size = raw.size
                framed = apply_iphone_frame(raw)
                if framed.size != orig_size:
                    raise ValueError(f"size changed {orig_size} -> {framed.size}")

                if src.suffix.lower() in {".jpg", ".jpeg"}:
                    framed.save(dst, format="JPEG", quality=92, optimize=True)
                elif src.suffix.lower() == ".png":
                    framed.save(dst, format="PNG", optimize=True)
                else:
                    framed.save(dst)

            ok += 1
            print(f"OK  {src.name} ({orig_size[0]}x{orig_size[1]})")
        except Exception as exc:  # noqa: BLE001
            failed.append((src.name, str(exc)))
            print(f"FAIL {src.name}: {exc}")

    print()
    print(f"Processed: {ok}")
    print(f"Output: {out_dir}")
    if failed:
        for name, err in failed:
            print(f"  - {name}: {err}")
        return 2
    return 0


def main() -> int:
    folder = Path(r"C:\Users\Dell\Downloads\IPHONE_Screenshots\molduradas")
    if len(sys.argv) > 1:
        folder = Path(sys.argv[1])
    if not folder.is_dir():
        print(f"Folder not found: {folder}")
        return 1
    return process_folder(folder, in_place=True)


if __name__ == "__main__":
    sys.exit(main())
