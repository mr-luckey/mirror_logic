"""Cut the flat white background out of generated UI art.

`cut_sprites.py` only flood-fills inward from the border, which leaves the
white trapped inside a shape (the gap under a padlock shackle, the middle of a
wreath). This labels every white region instead and drops the ones that either
touch the border or are too big to be a specular highlight on metal.
"""

from collections import deque
import os
import sys

from PIL import Image

ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'assets', 'images', 'ui',
)

SOURCES = {
    'crest_raw.png': 'crest.png',
    'tome_raw.png': 'tome.png',
    'wreath_raw.png': 'wreath.png',
    'padlock_raw.png': 'padlock.png',
    **{f'tome_ch{i}_raw.png': f'tome_ch{i}.png' for i in range(1, 11)},
}

# A highlight on polished bronze can be near-white; a background region cannot
# be this small. Anything bigger that is not touching the border is a hole.
MIN_ENCLOSED_AREA = 900


def is_white(r, g, b, a):
    if a < 8:
        return True
    bright = (r + g + b) / 3.0
    sat = max(r, g, b) - min(r, g, b)
    return bright >= 232 and sat < 18


def cut(path):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()

    label = bytearray(w * h)  # 0 unseen, 1 queued/seen
    removed = 0

    for sy in range(h):
        for sx in range(w):
            if label[sy * w + sx]:
                continue
            if not is_white(*px[sx, sy]):
                label[sy * w + sx] = 1
                continue

            component = []
            touches_border = False
            q = deque([(sx, sy)])
            label[sy * w + sx] = 1
            while q:
                x, y = q.popleft()
                component.append((x, y))
                if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                    touches_border = True
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    i = ny * w + nx
                    if label[i] or not is_white(*px[nx, ny]):
                        continue
                    label[i] = 1
                    q.append((nx, ny))

            if touches_border or len(component) >= MIN_ENCLOSED_AREA:
                for x, y in component:
                    px[x, y] = (0, 0, 0, 0)
                removed += len(component)

    # The generator leaves a pale halo one or two pixels wide. Fade the alpha
    # of near-white pixels that sit against a hole instead of cutting them, so
    # the edge stays smooth at small sizes.
    for _ in range(2):
        edge = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                bright = (r + g + b) / 3.0
                sat = max(r, g, b) - min(r, g, b)
                if bright < 205 or sat >= 30:
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] < 40:
                        edge.append((x, y, r, g, b, a))
                        break
        for x, y, r, g, b, a in edge:
            px[x, y] = (r, g, b, a // 3)

    bbox = im.getbbox()
    if bbox:
        l, t, r, b = bbox
        pad = 4
        im = im.crop(
            (max(0, l - pad), max(0, t - pad), min(w, r + pad), min(h, b + pad))
        )

    # These are drawn no larger than a few hundred logical pixels.
    if max(im.size) > 512:
        scale = 512 / max(im.size)
        im = im.resize(
            (round(im.width * scale), round(im.height * scale)),
            Image.LANCZOS,
        )
    return im, removed


def main():
    if not os.path.isdir(ROOT):
        print('missing dir', ROOT)
        return 1
    for src, dst in SOURCES.items():
        sp = os.path.join(ROOT, src)
        if not os.path.exists(sp):
            print('missing', src)
            continue
        out, removed = cut(sp)
        out.save(os.path.join(ROOT, dst), 'PNG')
        opaque = sum(1 for p in out.getdata() if p[3] > 10)
        print(f'{dst}: {out.size} cut={removed} opaque={opaque} '
              f'corner={out.getpixel((0, 0))}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
