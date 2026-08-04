"""Process generated theme floors/walls/atmospheres into bundled WebP assets."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\engin\.cursor\projects\d-Playstore-mirror-logic\assets")
OUT = Path(r"d:\Playstore\mirror_logic\assets\images\themes")
OUT.mkdir(parents=True, exist_ok=True)

THEMES = [
    "golden_sun",
    "moonlight_castle",
    "lava_forge",
    "frozen_kingdom",
    "mystic_forest",
    "neon_cyber",
    "celestial_heaven",
]

# Map theme id -> generated file stems in SRC
FLOOR = {
    "golden_sun": "golden_floor.png",
    "moonlight_castle": "moonlight_floor.png",
    "lava_forge": "lava_floor.png",
    "frozen_kingdom": "frozen_floor.png",
    "mystic_forest": "forest_floor.png",
    "neon_cyber": "neon_floor.png",
    "celestial_heaven": "celestial_floor.png",
}
WALL_H = {
    "moonlight_castle": "moonlight_wall_h.png",
    "lava_forge": "lava_wall_h.png",
    "frozen_kingdom": "frozen_wall_h.png",
    "mystic_forest": "forest_wall_h.png",
    "neon_cyber": "neon_wall_h.png",
    "celestial_heaven": "celestial_wall_h.png",
}
ATM = {
    "moonlight_castle": "moonlight_atm2.png",
    "lava_forge": "lava_atm2.png",
    "frozen_kingdom": "frozen_atm2.png",
    "mystic_forest": "forest_atm2.png",
    "neon_cyber": "neon_atm2.png",
    "celestial_heaven": "celestial_atm2.png",
}


def remove_bg(img: Image.Image, thresh: int = 42) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    br = sum(c[0] for c in corners) // 4
    bg = sum(c[1] for c in corners) // 4
    bb = sum(c[2] for c in corners) // 4
    visited = [[False] * h for _ in range(w)]
    q = deque(
        [
            (0, 0),
            (w - 1, 0),
            (0, h - 1),
            (w - 1, h - 1),
            (w // 2, 0),
            (0, h // 2),
            (w - 1, h // 2),
            (w // 2, h - 1),
        ]
    )
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or visited[x][y]:
            continue
        r, g, b, a = px[x, y]
        if abs(r - br) + abs(g - bg) + abs(b - bb) > thresh * 3:
            continue
        visited[x][y] = True
        px[x, y] = (r, g, b, 0)
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            dist = abs(r - br) + abs(g - bg) + abs(b - bb)
            if dist < thresh * 2:
                na = max(0, min(255, int(a * (dist / (thresh * 2)))))
                px[x, y] = (r, g, b, na)
    return img


def crop_content(img: Image.Image, pad: int = 6) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        return img
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(img.width, r + pad)
    b = min(img.height, b + pad)
    return img.crop((l, t, r, b))


def save_webp(img: Image.Image, path: Path, size: tuple[int, int] | None = None):
    if size:
        img = img.copy()
        img.thumbnail(size, Image.Resampling.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "WEBP", quality=86, method=6)
    print(f"  {path.name} {img.size}")


def process_floor(theme: str, src_name: str):
    src = SRC / src_name
    if not src.exists():
        print("MISSING floor", src)
        return
    img = Image.open(src).convert("RGB").convert("RGBA")
    # Floors stay opaque — just resize square
    img = img.resize((512, 512), Image.Resampling.LANCZOS)
    save_webp(img, OUT / theme / "floor.webp")


def process_wall_h(theme: str, src_name: str):
    src = SRC / src_name
    if not src.exists():
        print("MISSING wall", src)
        return
    cleaned = remove_bg(Image.open(src), thresh=36)
    cleaned = crop_content(cleaned)
    # Target roughly similar proportions to wall_h_cut
    cleaned.thumbnail((768, 256), Image.Resampling.LANCZOS)
    save_webp(cleaned, OUT / theme / "wall_h.webp")
    # Vertical = rotated
    vert = cleaned.transpose(Image.Transpose.ROTATE_90)
    save_webp(vert, OUT / theme / "wall_v.webp")


def process_atm(theme: str, src_name: str):
    src = SRC / src_name
    if not src.exists():
        print("MISSING atm", src)
        return
    cleaned = remove_bg(Image.open(src), thresh=40)
    cleaned = crop_content(cleaned, pad=4)
    cleaned.thumbnail((512, 512), Image.Resampling.LANCZOS)
    save_webp(cleaned, OUT / theme / "atmosphere.webp")


def main():
    for theme in THEMES:
        print("==", theme)
        if theme in FLOOR:
            process_floor(theme, FLOOR[theme])
        if theme in WALL_H:
            process_wall_h(theme, WALL_H[theme])
        if theme in ATM:
            process_atm(theme, ATM[theme])
        # golden_sun: copy medieval walls as theme walls for uniform paths
        if theme == "golden_sun":
            med = Path(r"d:\Playstore\mirror_logic\assets\images\medieval")
            for name in ("wall_h_cut.webp", "wall_v_cut.webp"):
                src = med / name
                dst_name = "wall_h.webp" if "wall_h" in name else "wall_v.webp"
                img = Image.open(src).convert("RGBA")
                save_webp(img, OUT / theme / dst_name, size=(768, 768))
            # simple sun-ray atmosphere: reuse vine as optional; skip if none
    print("done")


if __name__ == "__main__":
    main()
