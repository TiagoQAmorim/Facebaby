"""Add App Store marketing captions to FaceBaby screenshot composites."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# App Store 6.5" — same as correct/iphone templates (i1_pt … i8_pt).
CANVAS_W = 1242
CANVAS_H = 2688
TOP_MARGIN = 48
TEXT_AREA_H = 500
SIDE_PAD = 82
MARGIN = 24
SHADOW_OFFSET = (0, 22)
SHADOW_BLUR = 42
SHADOW_ALPHA = 105
SCREEN_RADIUS_RATIO = 0.058
SCREEN_BORDER_ALPHA = 110
MAX_FILE_BYTES = 350 * 1024

COLOR_PURPLE = (0x8A, 0x2B, 0xE2)
COLOR_PINK = (0xFF, 0x69, 0xB4)
COLOR_LIGHT_PURPLE = (0xC8, 0xA2, 0xFF)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}


@dataclass(frozen=True)
class Caption:
    title: str
    subtitle: str = ""
    bullets: tuple[str, ...] = ()


CAPTIONS: dict[str, Caption] = {
    "i1_pt": Caption(
        "Controle Tudo e receba alertas",
        "Acesso fácil para registrar e para ser lembrada sobre os horários certos.",
    ),
    "i1_en": Caption(
        "Total control and receive alerts",
        "Easy access to register and be reminded of the right times to do so.",
    ),
    "i2_pt": Caption(
        "Capture seus momentos",
        "Compartilhe memórias com outras mamães.",
    ),
    "i3_pt": Caption(
        "Registre e monitore o sono",
        "Saiba quando dormir, quando acordar e a qualidade do sono do bebê.",
    ),
    "i4_pt": Caption(
        "Curiosidades e Espiritualidade",
        "Todos são Bem-Vindos, Escolha suas curiosidades e crenças para mensagens diárias personalizadas",
    ),
    "i5_pt": Caption(
        "Amamentação e desenvolvimento",
        "Seja avisada caso o seu bebê saia da curva ideal de cresimento e saiba os melhores momentos para mamar.",
    ),
    "i6_pt": Caption(
        "Albúm de Memórias",
        "Transforme as memórias do bebê em um lindo albúm pronto para ser impresso.",
    ),
    "i7_pt": Caption(
        "Relatórios Completos",
        "Relatórios completos e inteligentes (IA). Leve um relatório completo ao pediatra",
    ),
    "i8_pt": Caption(
        "IA Babá",
        bullets=(
            "Informações ao longo do dia",
            "Mensagens personalizadas",
            "Uma babá e psicóloga virtual",
            "Faz os registros com um comando.",
            "Alertas e avaliações",
        ),
    ),
}

# WhatsApp source filename -> caption key
SCREEN_MAP: dict[str, str] = {
    "WhatsApp Image 2026-06-09 at 10.43.07 (3).jpeg": "i1_pt",
    "WhatsApp Image 2026-06-09 at 10.43.07 (2).jpeg": "i1_en",
    "WhatsApp Image 2026-06-09 at 10.43.00.jpeg": "i2_pt",
    "WhatsApp Image 2026-06-09 at 10.43.05 (3).jpeg": "i3_pt",
    "WhatsApp Image 2026-06-09 at 10.43.07 (1).jpeg": "i4_pt",
    "WhatsApp Image 2026-06-09 at 10.43.07.jpeg": "i4_pt",
    "WhatsApp Image 2026-06-09 at 10.43.06 (4).jpeg": "i4_pt",
    "WhatsApp Image 2026-06-09 at 10.43.06.jpeg": "i5_pt",
    "WhatsApp Image 2026-06-09 at 10.43.06 (1).jpeg": "i5_pt",
    "WhatsApp Image 2026-06-09 at 10.43.06 (2).jpeg": "i5_pt",
    "WhatsApp Image 2026-06-09 at 10.43.04.jpeg": "i6_pt",
    "WhatsApp Image 2026-06-09 at 10.43.04 (1).jpeg": "i6_pt",
    "WhatsApp Image 2026-06-09 at 10.43.05.jpeg": "i7_pt",
    "WhatsApp Image 2026-06-09 at 10.43.05 (1).jpeg": "i7_pt",
    "WhatsApp Image 2026-06-09 at 10.43.05 (2).jpeg": "i7_pt",
    "WhatsApp Image 2026-06-09 at 10.43.06 (3).jpeg": "i8_pt",
}


def _lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def _lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (_lerp(c1[0], c2[0], t), _lerp(c1[1], c2[1], t), _lerp(c1[2], c2[2], t))


def make_premium_background(width: int, height: int) -> Image.Image:
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


def screen_corner_radius(width: int) -> int:
    return max(48, int(round(width * SCREEN_RADIUS_RATIO)))


def to_iphone_screen(screenshot: Image.Image) -> tuple[Image.Image, int]:
    """Rounded screen + subtle glass edge like iPhone captures in reference art."""
    w, h = screenshot.size
    radius = screen_corner_radius(w)
    screen = round_corners_rgba(screenshot, radius)

    framed = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    framed.alpha_composite(screen)

    stroke = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(stroke)
    inset = 1
    draw.rounded_rectangle(
        (inset, inset, w - inset - 1, h - inset - 1),
        radius=max(8, radius - inset),
        outline=(255, 255, 255, SCREEN_BORDER_ALPHA),
        width=2,
    )
    framed.alpha_composite(stroke)
    return framed, radius


def save_png_under_limit(img: Image.Image, dst: Path, max_bytes: int = MAX_FILE_BYTES) -> int:
    rgb = img.convert("RGB")
    attempts: list[tuple[int, str]] = [
        (256, "png-q256"),
        (192, "png-q192"),
        (160, "png-q160"),
        (128, "png-q128"),
    ]

    best: tuple[int, bytes] | None = None
    for colors, _label in attempts:
        quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
        buf = BytesIO()
        quantized.save(buf, format="PNG", optimize=True, compress_level=9)
        data = buf.getvalue()
        size = len(data)
        if best is None or size < best[0]:
            best = (size, data)
        if size <= max_bytes:
            dst.write_bytes(data)
            return size

    assert best is not None
    dst.write_bytes(best[1])
    return best[0]


def load_fonts() -> tuple[ImageFont.FreeTypeFont, ImageFont.FreeTypeFont, ImageFont.FreeTypeFont]:
    win = Path(r"C:\Windows\Fonts")
    title = ImageFont.truetype(str(win / "segoeuib.ttf"), 54)
    body = ImageFont.truetype(str(win / "segoeui.ttf"), 30)
    bullet = ImageFont.truetype(str(win / "segoeui.ttf"), 27)
    return title, body, bullet


def wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int, draw: ImageDraw.ImageDraw) -> list[str]:
    words = text.split()
    if not words:
        return []
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        if draw.textlength(trial, font=font) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def draw_caption(draw: ImageDraw.ImageDraw, caption: Caption, fonts: tuple) -> None:
    title_font, body_font, bullet_font = fonts
    x = SIDE_PAD
    max_w = CANVAS_W - SIDE_PAD * 2
    y = CANVAS_H - TEXT_AREA_H + 48

    draw.text((x, y), caption.title, font=title_font, fill=(255, 255, 255))
    y += 68

    if caption.bullets:
        for line in caption.bullets:
            draw.text((x, y), f"- {line}", font=bullet_font, fill=(255, 255, 255))
            y += 36
        return

    for line in wrap_text(caption.subtitle, body_font, max_w, draw):
        draw.text((x, y), line, font=body_font, fill=(255, 255, 255))
        y += 40


def safe_output_name(src: Path) -> str:
    stem = re.sub(r"[^\w\-]+", "_", src.stem).strip("_")
    return f"{stem or 'screenshot'}.png"


def compose_with_caption(src: Path, caption_key: str, dst: Path, fonts) -> None:
    caption = CAPTIONS[caption_key]
    with Image.open(src) as raw:
        screenshot = raw.convert("RGBA")

    shot_max_w = CANVAS_W - MARGIN * 2
    shot_max_h = CANVAS_H - TOP_MARGIN - TEXT_AREA_H - 12
    new_w, new_h = fit_size(screenshot.width, screenshot.height, shot_max_w, shot_max_h)
    screenshot = screenshot.resize((new_w, new_h), Image.Resampling.LANCZOS)
    screenshot, radius = to_iphone_screen(screenshot)

    canvas = make_premium_background(CANVAS_W, CANVAS_H).convert("RGBA")
    x = (CANVAS_W - new_w) // 2
    y = TOP_MARGIN

    shadow = make_shadow((new_w, new_h), radius)
    canvas.alpha_composite(shadow, (x + SHADOW_OFFSET[0] - SHADOW_BLUR, y + SHADOW_OFFSET[1] - SHADOW_BLUR))
    canvas.alpha_composite(screenshot, (x, y))

    draw = ImageDraw.Draw(canvas)
    draw_caption(draw, caption, fonts)

    dst.parent.mkdir(parents=True, exist_ok=True)
    if canvas.size != (CANVAS_W, CANVAS_H):
        canvas = canvas.resize((CANVAS_W, CANVAS_H), Image.Resampling.LANCZOS)

    size = save_png_under_limit(canvas, dst)
    with Image.open(dst) as check:
        if check.size != (CANVAS_W, CANVAS_H):
            raise ValueError(f"Output size {check.size}, expected {(CANVAS_W, CANVAS_H)}")
    if size > MAX_FILE_BYTES:
        print(f"WARN {dst.name}: {size / 1024:.1f} KB (target {MAX_FILE_BYTES / 1024:.0f} KB)")


def main() -> int:
    src_dir = Path(r"C:\Users\Dell\Downloads\IPHONE_Screenshots")
    out_dir = src_dir / "AppStore_Ready"

    fonts = load_fonts()
    ok: list[Path] = []
    failed: list[tuple[str, str]] = []
    skipped: list[str] = []

    for src_name, caption_key in sorted(SCREEN_MAP.items()):
        src = src_dir / src_name
        if not src.is_file():
            skipped.append(src_name)
            continue
        dst = out_dir / safe_output_name(src)
        try:
            compose_with_caption(src, caption_key, dst, fonts)
            ok.append(dst)
            kb = dst.stat().st_size / 1024
            print(f"OK  {src.name} [{caption_key}] -> {dst.name} ({kb:.1f} KB)")
        except Exception as exc:  # noqa: BLE001
            failed.append((src_name, str(exc)))
            print(f"FAIL {src_name}: {exc}")

    print()
    print(f"Processed: {len(ok)} / {len(SCREEN_MAP)}")
    print(f"Output: {out_dir}")
    if skipped:
        print(f"Skipped (missing source): {len(skipped)}")
        for name in skipped:
            print(f"  - {name}")
    if failed:
        print(f"Failures: {len(failed)}")
        for name, err in failed:
            print(f"  - {name}: {err}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
