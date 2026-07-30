from PIL import Image
from collections import deque
import os

root = r'c:\Users\ateeq\Desktop\NaseerRepos\mirror_logic\assets\images\medieval'
sources = {
    'crystal.png': 'crystal_cut.png',
    'emitter.png': 'emitter_cut.png',
    'mirror.png': 'mirror_cut.png',
    'obstacle.png': 'obstacle_cut.png',
    'torch_clear.png': 'torch_cut.png',
    'vine.png': 'vine_cut.png',
    'wall_h.png': 'wall_h_cut.png',
    'wall_v.png': 'wall_v_cut.png',
}


def is_bg(r, g, b, a, seed):
    if a < 8:
        return True
    sr, sg, sb = seed
    bright = (r + g + b) / 3.0
    sat = max(r, g, b) - min(r, g, b)
    # light / gray / near-white / checkerboard
    if bright >= 205 and sat < 40:
        return True
    if bright >= 165 and sat < 24:
        return True
    if sat < 20 and 140 <= bright <= 250:
        return True
    dr = abs(r - sr) + abs(g - sg) + abs(b - sb)
    if dr < 60 and sat < 45 and bright > 110:
        return True
    return False


def remove_bg(path):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()

    seeds = []
    step = max(1, w // 32)
    for x in range(0, w, step):
        seeds.append(px[x, 0][:3])
        seeds.append(px[x, h - 1][:3])
    for y in range(0, h, step):
        seeds.append(px[0, y][:3])
        seeds.append(px[w - 1, y][:3])
    sr = sum(s[0] for s in seeds) // len(seeds)
    sg = sum(s[1] for s in seeds) // len(seeds)
    sb = sum(s[2] for s in seeds) // len(seeds)
    seed = (sr, sg, sb)

    visited = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if visited[i]:
            return
        r, g, b, a = px[x, y]
        if not is_bg(r, g, b, a, seed):
            return
        visited[i] = 1
        q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in (
            (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
            (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1),
        ):
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if visited[i]:
                    continue
                r, g, b, a = px[nx, ny]
                if is_bg(r, g, b, a, seed):
                    visited[i] = 1
                    q.append((nx, ny))

    # fringe cleanup near transparent
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            bright = (r + g + b) / 3.0
            sat = max(r, g, b) - min(r, g, b)
            if bright > 195 and sat < 32:
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        px[x, y] = (0, 0, 0, 0)
                        break

    bbox = im.getbbox()
    if bbox:
        l, t, r, b = bbox
        pad = 6
        l = max(0, l - pad)
        t = max(0, t - pad)
        r = min(w, r + pad)
        b = min(h, b + pad)
        im = im.crop((l, t, r, b))
    return im


def main():
    for src, dst in sources.items():
        sp = os.path.join(root, src)
        if not os.path.exists(sp):
            print('missing', src)
            continue
        out = remove_bg(sp)
        op = os.path.join(root, dst)
        out.save(op, 'PNG')
        opaque = sum(1 for p in out.getdata() if p[3] > 10)
        print(f'{dst}: {out.size} opaque={opaque} corner={out.getpixel((0, 0))}')


if __name__ == '__main__':
    main()
