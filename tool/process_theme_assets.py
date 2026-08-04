from PIL import Image
from collections import deque
import os

src_dir = r"C:\Users\engin\.cursor\projects\d-Playstore-mirror-logic\assets"
out_dir = r"d:\Playstore\mirror_logic\assets\images\themes"
os.makedirs(out_dir, exist_ok=True)

files = {
    "moonlight_atmosphere.png": "moonlight_atmosphere.webp",
    "lava_atmosphere.png": "lava_atmosphere.webp",
    "frozen_atmosphere.png": "frozen_atmosphere.webp",
    "forest_atmosphere.png": "forest_atmosphere.webp",
    "neon_atmosphere.png": "neon_atmosphere.webp",
    "celestial_atmosphere.png": "celestial_atmosphere.webp",
}


def remove_bg(img: Image.Image) -> Image.Image:
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
    thresh = 38
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


for src_name, out_name in files.items():
    path = os.path.join(src_dir, src_name)
    if not os.path.exists(path):
        print("MISSING", path)
        continue
    img = Image.open(path)
    cleaned = remove_bg(img)
    bbox = cleaned.getbbox()
    if bbox:
        pad = 8
        l, t, r, b = bbox
        l = max(0, l - pad)
        t = max(0, t - pad)
        r = min(cleaned.width, r + pad)
        b = min(cleaned.height, b + pad)
        cleaned = cleaned.crop((l, t, r, b))
    cleaned.thumbnail((512, 512), Image.Resampling.LANCZOS)
    out = os.path.join(out_dir, out_name)
    cleaned.save(out, "WEBP", quality=88, method=6)
    print(out_name, cleaned.size, "saved")

print("done")
