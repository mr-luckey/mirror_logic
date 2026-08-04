from pathlib import Path
from collections import deque
from PIL import Image

src = Path(r"C:\Users\engin\.cursor\projects\d-Playstore-mirror-logic\assets\lava_crystal.png")
out = Path(r"d:\Playstore\mirror_logic\assets\images\themes\lava_forge\crystal.webp")


def remove_bg(img: Image.Image, thresh: int = 36) -> Image.Image:
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


img = remove_bg(Image.open(src))
bbox = img.getbbox()
if bbox:
    pad = 6
    l, t, r, b = bbox
    img = img.crop(
        (
            max(0, l - pad),
            max(0, t - pad),
            min(img.width, r + pad),
            min(img.height, b + pad),
        )
    )
img.thumbnail((512, 768), Image.Resampling.LANCZOS)
out.parent.mkdir(parents=True, exist_ok=True)
img.save(out, "WEBP", quality=90, method=6)
print("saved", out, img.size)
