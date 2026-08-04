"""Compose premium portrait theme thumbnails from floor + atmosphere art."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(r"d:\Playstore\mirror_logic\assets\images\themes")

THEMES = [
    ("golden_sun", (64, 200, 255), (243, 207, 122)),
    ("moonlight_castle", (80, 128, 224), (208, 228, 255)),
    ("frozen_kingdom", (64, 208, 255), (200, 240, 255)),
    ("lava_forge", (255, 64, 16), (255, 180, 80)),
    ("celestial_heaven", (255, 232, 160), (255, 248, 220)),
]

W, H = 720, 960


def _cover(img: Image.Image, tw: int, th: int) -> Image.Image:
    img = img.convert("RGBA")
    scale = max(tw / img.width, th / img.height)
    nw, nh = int(img.width * scale), int(img.height * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))


def _vignette(size: tuple[int, int], strength: float = 0.72) -> Image.Image:
    w, h = size
    alpha = Image.new("L", size, 0)
    draw = ImageDraw.Draw(alpha)
    max_inset = min(w, h) // 2 - 2
    steps = 40
    for i in range(steps):
        t = i / (steps - 1)
        a = int(255 * strength * (t**1.55))
        inset = int(max_inset * t)
        if w - 1 - inset <= inset or h - 1 - inset <= inset:
            break
        draw.rectangle(
            [inset, inset, w - 1 - inset, h - 1 - inset],
            outline=a,
            width=2,
        )
    alpha = alpha.filter(ImageFilter.GaussianBlur(22))
    black = Image.new("RGB", size, (0, 0, 0))
    return Image.merge("RGBA", (*black.split(), alpha))


def _beam(draw: ImageDraw.ImageDraw, glow: tuple[int, int, int]) -> None:
    # Diagonal laser streak for premium puzzle feel.
    cx, cy = W * 0.22, H * 0.78
    for width, alpha in ((28, 40), (14, 90), (5, 200)):
        draw.line(
            [(cx - 40, cy + 120), (cx + 260, cy - 420)],
            fill=(*glow, alpha),
            width=width,
        )


def _frame(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    margin = 28
    for i, alpha in enumerate((90, 160, 220)):
        inset = margin - i * 3
        draw.rounded_rectangle(
            [inset, inset, W - 1 - inset, H - 1 - inset],
            radius=42 - i * 2,
            outline=(*accent, alpha),
            width=3 if i == 2 else 2,
        )


def compose(theme_id: str, glow: tuple[int, int, int], accent: tuple[int, int, int]) -> None:
    folder = ROOT / theme_id
    floor = Image.open(folder / "floor.webp")
    base = _cover(floor, W, H)
    base = ImageEnhance.Contrast(base).enhance(1.12)
    base = ImageEnhance.Color(base).enhance(1.08)

    atmos_path = folder / "atmosphere.webp"
    if atmos_path.exists():
        atmos = Image.open(atmos_path).convert("RGBA")
        aw = int(W * 0.62)
        ah = int(aw * atmos.height / max(atmos.width, 1))
        atmos = atmos.resize((aw, ah), Image.Resampling.LANCZOS)
        # Soft glow behind atmosphere
        glow_blob = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(glow_blob)
        gdraw.ellipse(
            [W - aw - 40, -40, W + 40, ah + 40],
            fill=(*glow, 70),
        )
        glow_blob = glow_blob.filter(ImageFilter.GaussianBlur(40))
        base = Image.alpha_composite(base, glow_blob)
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        overlay.paste(atmos, (W - aw + 12, -8), atmos)
        base = Image.alpha_composite(base, overlay)

    # Bottom cinematic wash
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wdraw = ImageDraw.Draw(wash)
    for y in range(H // 2, H):
        t = (y - H // 2) / (H // 2)
        wdraw.line([(0, y), (W, y)], fill=(0, 0, 0, int(150 * t * t)))
    base = Image.alpha_composite(base, wash)
    base = Image.alpha_composite(base, _vignette((W, H)))

    draw = ImageDraw.Draw(base, "RGBA")
    _beam(draw, glow)
    _frame(draw, accent)

    # Inner highlight edge
    draw.rounded_rectangle(
        [40, 40, W - 41, H - 41],
        radius=34,
        outline=(255, 255, 255, 35),
        width=2,
    )

    out = folder / "thumb.webp"
    base.convert("RGB").save(out, "WEBP", quality=92, method=6)
    print(f"wrote {out}")


def main() -> None:
    for theme_id, glow, accent in THEMES:
        compose(theme_id, glow, accent)


if __name__ == "__main__":
    main()
