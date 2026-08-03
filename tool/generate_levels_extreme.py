#!/usr/bin/env python3
"""
Write / resume Mirror Logic levels as one JSON file per level.

Output layout:
  assets/levels/manifest.json
  assets/levels/ch1_001.json
  assets/levels/ch1_002.json
  …
  assets/levels/ch10_100.json

Each level is flushed to disk immediately — resume-safe, no giant file.

Usage:
  # Full extreme pack (1000 single-level files):
  python3 tool/generate_levels_extreme.py --count 1000 --outdir assets/levels

  # Resume after interrupt:
  python3 tool/generate_levels_extreme.py --count 1000 --outdir assets/levels --resume

  # Keep levels 1–20, rebuild rest:
  python3 tool/generate_levels_extreme.py --count 1000 --outdir assets/levels --from 21 --resume

  # Quick test:
  python3 tool/generate_levels_extreme.py --count 40 --outdir /tmp/ml_levels
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import sys
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Set, Tuple

ROOM_W, ROOM_H = 1080.0, 1920.0
T, MIRROR_LEN, WALL_INSET = 48.0, 145.0, 52.0
MAX_BOUNCES, MIN_HINGE_GAP, EDGE = 24, 350.0, 150.0
SEG_LENS = (350, 400, 450, 500, 550, 600, 650, 700)
CRYSTAL_LENS = (380, 420, 480, 540, 600, 660, 720)
DESIGNER = "canonical_v3"
CHAPTER_SIZE = 100

LAYOUT_FAMILIES = (
    "open_arena",
    "sparse_stoppers",
    "multi_chamber",
    "decoy_branches",
    "pillar_field",
    "gauntlet_doors",
    "false_gallery",
    "island_blocks",
)
PATH_KINDS = (
    "axis_chirality",
    "freeform_scatter",
    "axis_irregular",
    "freeform_orbit",
    "axis_backtrack",
)


@dataclass(frozen=True)
class V:
    x: float
    y: float

    def __add__(self, o: "V") -> "V":
        return V(self.x + o.x, self.y + o.y)

    def __sub__(self, o: "V") -> "V":
        return V(self.x - o.x, self.y - o.y)

    def __mul__(self, s: float) -> "V":
        return V(self.x * s, self.y * s)

    @property
    def length(self) -> float:
        return math.hypot(self.x, self.y)

    def normalized(self) -> "V":
        l = self.length
        return V(0, 0) if l < 1e-9 else V(self.x / l, self.y / l)

    def dot(self, o: "V") -> float:
        return self.x * o.x + self.y * o.y

    def distance_to(self, o: "V") -> float:
        return (self - o).length

    def snap10(self) -> "V":
        return V(round(self.x / 10) * 10, round(self.y / 10) * 10)


def dir_deg(deg: float) -> V:
    r = math.radians(deg)
    return V(math.cos(r), math.sin(r))


def normal(a: float) -> V:
    return dir_deg(a + 90).normalized()


def face_normal(a: float, incoming: V) -> V:
    n = normal(a)
    return V(-n.x, -n.y) if n.dot(incoming) > 0 else n


def reflect(d: V, n: V) -> V:
    dn = d.dot(n)
    return V(d.x - n.x * 2 * dn, d.y - n.y * 2 * dn)


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def in_play(p: V) -> bool:
    return EDGE <= p.x <= ROOM_W - EDGE and EDGE <= p.y <= ROOM_H - EDGE


def solve_angle(incoming: V, outgoing: V) -> Optional[float]:
    i, o = incoming.normalized(), outgoing.normalized()
    for a in (45.0, 135.0, 90.0):
        if reflect(i, face_normal(a, i)).normalized().dot(o) > 0.999:
            return a
    a = 5.0
    while a <= 175.0:
        if reflect(i, face_normal(a, i)).normalized().dot(o) > 0.9993:
            return round(a * 4) / 4
        a += 0.25
    return None


def left_of(d: V) -> V:
    return V(-d.y, d.x)


def right_of(d: V) -> V:
    return V(d.y, -d.x)


def cardinal(d: V) -> V:
    if abs(d.x) >= abs(d.y):
        return V(1.0 if d.x >= 0 else -1.0, 0.0)
    return V(0.0, 1.0 if d.y >= 0 else -1.0)


def wall_h(wid: str, x0: float, x1: float, cy: float) -> dict:
    if x1 < x0:
        x0, x1 = x1, x0
    return {
        "id": wid,
        "polygon": [[x0, cy - T / 2], [x1, cy - T / 2], [x1, cy + T / 2], [x0, cy + T / 2]],
        "isDecorative": False,
        "renderAsset": "wall_h_cut",
        "orientation": "horizontal",
        "thickness": T,
    }


def wall_v(wid: str, cx: float, y0: float, y1: float) -> dict:
    if y1 < y0:
        y0, y1 = y1, y0
    return {
        "id": wid,
        "polygon": [[cx - T / 2, y0], [cx + T / 2, y0], [cx + T / 2, y1], [cx - T / 2, y1]],
        "isDecorative": False,
        "renderAsset": "wall_h_cut_rotated",
        "orientation": "vertical",
        "thickness": T,
    }


def pillar(x: float, y: float) -> dict:
    return {"position": [x, y], "asset": "wall_v_cut", "size": T}


def renumber(walls: List[dict]) -> List[dict]:
    out = []
    for i, w in enumerate(walls):
        nw = dict(w)
        nw["id"] = f"w{i}"
        out.append(nw)
    return out


def segment_hits_wall(a: V, b: V, wall: dict, pad: float = 12.0) -> bool:
    poly = wall["polygon"]
    wx0, wx1 = min(p[0] for p in poly), max(p[0] for p in poly)
    wy0, wy1 = min(p[1] for p in poly), max(p[1] for p in poly)
    xmin, xmax = min(a.x, b.x) - pad, max(a.x, b.x) + pad
    ymin, ymax = min(a.y, b.y) - pad, max(a.y, b.y) + pad
    if xmax < wx0 or xmin > wx1 or ymax < wy0 or ymin > wy1:
        return False
    if abs(a.y - b.y) < 1.5:
        return wy0 < a.y < wy1
    if abs(a.x - b.x) < 1.5:
        return wx0 < a.x < wx1
    return True


def filter_clear(walls: List[dict], corridor: List[V]) -> List[dict]:
    clean = []
    for w in walls:
        if all(
            not segment_hits_wall(corridor[i], corridor[i + 1], w)
            for i in range(len(corridor) - 1)
        ):
            clean.append(w)
    return clean


@dataclass
class Hit:
    point: V
    dist: float
    kind: str
    id: Optional[str] = None
    normal: Optional[V] = None


def mounted_origin(pos: Sequence[float], direction: float) -> V:
    rad = math.radians(direction)
    dx, dy = math.cos(rad), math.sin(rad)
    y = clamp(pos[1], WALL_INSET, ROOM_H - WALL_INSET)
    x = clamp(pos[0], WALL_INSET, ROOM_W - WALL_INSET)
    if abs(dx) >= abs(dy):
        return V(WALL_INSET, y) if dx >= 0 else V(ROOM_W - WALL_INSET, y)
    return V(x, WALL_INSET) if dy >= 0 else V(x, ROOM_H - WALL_INSET)


def ray_segment(origin: V, direction: V, a: V, b: V) -> Optional[Hit]:
    ox, oy, dx, dy = origin.x, origin.y, direction.x, direction.y
    sx, sy = b.x - a.x, b.y - a.y
    denom = dx * sy - dy * sx
    if abs(denom) < 1e-9:
        return None
    t = ((a.x - ox) * sy - (a.y - oy) * sx) / denom
    u = ((a.x - ox) * dy - (a.y - oy) * dx) / denom
    if t < 1e-6 or u < 0 or u > 1:
        return None
    return Hit(V(ox + dx * t, oy + dy * t), t, "")


def ray_circle(origin: V, direction: V, center: V, radius: float) -> Optional[Hit]:
    oc = V(origin.x - center.x, origin.y - center.y)
    a = direction.dot(direction)
    b = 2 * oc.dot(direction)
    c = oc.dot(oc) - radius * radius
    disc = b * b - 4 * a * c
    if disc < 0:
        return None
    sq = math.sqrt(disc)
    t = (-b - sq) / (2 * a)
    if t < 1e-6:
        t = (-b + sq) / (2 * a)
    if t < 1e-6:
        return None
    return Hit(origin + direction * t, t, "")


def nearest_hit(level: dict, origin: V, direction: V, angles: Dict[str, float]) -> Optional[Hit]:
    best: Optional[Hit] = None

    def consider(h: Optional[Hit], kind: str, id_: str = "", n: Optional[V] = None):
        nonlocal best
        if h is None or h.dist < 1e-6:
            return
        cand = Hit(h.point, h.dist, kind, id_ or None, n)
        if best is None or cand.dist < best.dist:
            best = cand

    for a, b, bid in [
        (V(0, 0), V(ROOM_W, 0), "top"),
        (V(0, ROOM_H), V(ROOM_W, ROOM_H), "bottom"),
        (V(0, 0), V(0, ROOM_H), "left"),
        (V(ROOM_W, 0), V(ROOM_W, ROOM_H), "right"),
    ]:
        consider(ray_segment(origin, direction, a, b), "bounds", bid)
    for obs in level.get("obstacles", []):
        if obs.get("isDecorative"):
            continue
        poly = [V(p[0], p[1]) for p in obs["polygon"]]
        for i in range(len(poly)):
            consider(ray_segment(origin, direction, poly[i], poly[(i + 1) % len(poly)]), "wall", obs["id"])
    for m in level["mirrors"]:
        ang = angles.get(m["id"], m["initialAngle"])
        hinge = V(m["hingePosition"][0], m["hingePosition"][1])
        half = dir_deg(ang) * (m["length"] / 2)
        h = ray_segment(origin, direction, hinge - half, hinge + half)
        if h:
            n = normal(ang)
            if n.dot(direction) > 0:
                n = V(-n.x, -n.y)
            consider(h, "mirror", m["id"], n)
    for c in level["targetCrystals"]:
        consider(
            ray_circle(origin, direction, V(c["position"][0], c["position"][1]), c.get("hitRadius", 44)),
            "crystal",
            c["id"],
        )
    return best


def simulate(level: dict, angles: Dict[str, float]) -> Tuple[Set[str], int]:
    lit: Set[str] = set()
    hits = 0
    for ls in level["lightSources"]:
        tip = mounted_origin(ls["position"], ls["direction"])
        pos, d = tip, dir_deg(ls["direction"]).normalized()
        for _ in range(MAX_BOUNCES):
            hit = nearest_hit(level, pos, d, angles)
            if hit is None:
                break
            if hit.kind == "crystal":
                lit.add(hit.id)  # type: ignore
                break
            if hit.kind in ("wall", "bounds"):
                break
            if hit.kind == "mirror":
                hits += 1
                d = reflect(d, hit.normal).normalized()  # type: ignore
                pos = hit.point + d * 0.5
    return lit, hits


def validate(level: dict) -> bool:
    mirrors = level["mirrors"]
    for m in mirrors:
        if m.get("isLocked") or m.get("snapIncrement", 0) not in (0, 0.0):
            return False
        if m.get("minAngle", 5) > 5.01 or m.get("maxAngle", 175) < 174.99:
            return False
    sol = {k: float(v) for k, v in level["intendedSolution"]["mirrorAngles"].items()}
    angles = {m["id"]: m["initialAngle"] for m in mirrors}
    angles.update(sol)
    lit, hits = simulate(level, angles)
    if "c1" not in lit or hits != len(mirrors):
        return False
    if level.get("requiredMirrorBounces") != len(mirrors):
        return False
    for i in range(len(mirrors)):
        a = V(*mirrors[i]["hingePosition"])
        for j in range(i + 1, len(mirrors)):
            if a.distance_to(V(*mirrors[j]["hingePosition"])) < MIN_HINGE_GAP - 1:
                return False
    lit0, _ = simulate(level, {m["id"]: m["initialAngle"] for m in mirrors})
    return "c1" not in lit0


def progress_t(index: int) -> float:
    return 0.0 if index <= 15 else (index - 15) / (1000 - 15)


def hardness_score(index: int) -> float:
    return float(index) if index <= 15 else 15.0 + (index - 15)


def mirrors_for(index: int) -> int:
    if index <= 5:
        return 2
    if index <= 10:
        return 4
    if index <= 15:
        return 6
    t = progress_t(index)
    if t < 0.10:
        return 7
    if t < 0.25:
        return 8
    if t < 0.50:
        return 9
    return 10


def pattern_for(index: int) -> dict:
    t = progress_t(index)
    mirrors = mirrors_for(index)
    n = max(0, mirrors - 1)
    seed = index * 2654435761 & 0xFFFFFFFF
    chirality = []
    x = seed
    for _ in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        chirality.append(1 if (x >> 16) & 1 else 0)
    if n >= 4:
        if sum(chirality) < 2:
            chirality[0] = chirality[2] = 1
        if sum(chirality) > n - 2:
            chirality[1] = chirality[3] = 0
        chirality[(index * 3) % n] = 1 - chirality[(index * 3) % n]
    lengths = [SEG_LENS[(index * 3 + i * 5 + mirrors) % len(SEG_LENS)] for i in range(n)]
    family = LAYOUT_FAMILIES[(index * 7 + mirrors * 3) % len(LAYOUT_FAMILIES)]
    if index <= 15:
        family = "sparse_stoppers" if index <= 5 else "gauntlet_doors"
        kind = "axis_chirality"
    elif t < 0.20:
        kind = ("axis_chirality", "axis_irregular", "axis_backtrack")[index % 3]
        if family == "open_arena" and index % 2:
            family = "sparse_stoppers"
    else:
        kind = PATH_KINDS[(index * 5 + mirrors) % len(PATH_KINDS)]
    sides = ("west", "east", "north", "south")
    light_side = "west" if index <= 3 else sides[(index * 5 + mirrors) % 4]
    decoy = 0 if index <= 15 else 2 + int(t * 10)
    if family in ("open_arena", "sparse_stoppers"):
        decoy //= 2
    return {
        "mirrors": mirrors,
        "chirality": tuple(chirality),
        "lengths": tuple(lengths),
        "family": family,
        "kind": kind,
        "light_side": light_side,
        "decoy_count": decoy,
        "t": t,
    }


def pick_light(side: str, rng: random.Random) -> Tuple[V, float]:
    ys = [260, 400, 540, 700, 900, 1100, 1300, 1500, 1600]
    xs = [240, 360, 480, 600, 720, 840]
    if side == "east":
        return V(ROOM_W - 130, float(rng.choice(ys))), 180.0
    if side == "north":
        return V(float(rng.choice(xs)), 130.0), 90.0
    if side == "south":
        return V(float(rng.choice(xs)), ROOM_H - 130), 270.0
    return V(130.0, float(rng.choice(ys))), 0.0


def build_axis(rng, tip, incoming, recipe) -> Optional[Tuple[List[V], V, List[float]]]:
    mirrors = recipe["mirrors"]
    chirality = list(recipe["chirality"])
    lengths = recipe["lengths"]
    d = incoming.normalized()
    first = (tip + d * rng.choice([450, 500, 550, 600])).snap10()
    if not in_play(first):
        first = (tip + d * 400).snap10()
        if not in_play(first):
            return None
    hinges = [first]
    angles: List[float] = []
    cur = d
    for step in range(mirrors - 1):
        preferred = cardinal(right_of(cur) if chirality[step] else left_of(cur))
        alt = cardinal(left_of(cur) if chirality[step] else right_of(cur))
        seg = lengths[step] if step < len(lengths) else rng.choice(SEG_LENS)
        placed = False
        for turn in (preferred, alt):
            a = solve_angle(cur, turn)
            if a is None:
                continue
            for scale in (1.0, 0.85, 1.15, 0.7, 1.3, 0.6):
                nxt = (hinges[-1] + turn * (seg * scale)).snap10()
                if not in_play(nxt) or any(nxt.distance_to(h) < MIN_HINGE_GAP for h in hinges):
                    continue
                hinges.append(nxt)
                angles.append(a)
                cur = turn
                placed = True
                break
            if placed:
                break
        if not placed:
            return None
    for bit in (0, 1):
        out = cardinal(right_of(cur) if bit else left_of(cur))
        a = solve_angle(cur, out)
        if a is None:
            continue
        for dist in CRYSTAL_LENS:
            c = (hinges[-1] + out * dist).snap10()
            if in_play(c) and all(c.distance_to(h) >= MIN_HINGE_GAP - 30 for h in hinges):
                angles.append(a)
                return hinges, c, angles
    return None


def build_freeform(rng, tip, incoming, recipe, orbit=False):
    mirrors = recipe["mirrors"]
    d = incoming.normalized()
    first = (tip + d * rng.choice([420, 500, 580])).snap10()
    if not in_play(first):
        return None
    hinges = [first]
    angles: List[float] = []
    cur = d
    center = V(ROOM_W / 2, ROOM_H / 2)
    for _ in range(mirrors - 1):
        cands: List[V] = []
        if orbit:
            ang0 = math.atan2(hinges[-1].y - center.y, hinges[-1].x - center.x)
            for da in (0.7, 1.0, 1.3, -0.7, -1.0):
                r = rng.uniform(280, 420)
                cands.append(V(center.x + math.cos(ang0 + da) * r, center.y + math.sin(ang0 + da) * r).snap10())
        for _ in range(40):
            cands.append(V(rng.uniform(EDGE, ROOM_W - EDGE), rng.uniform(EDGE, ROOM_H - EDGE)).snap10())
        rng.shuffle(cands)
        placed = False
        for nxt in cands:
            if not in_play(nxt) or any(nxt.distance_to(h) < MIN_HINGE_GAP for h in hinges):
                continue
            out = (nxt - hinges[-1]).normalized()
            if abs(out.dot(cur)) > 0.92 or out.dot(cur) < -0.2:
                continue
            a = solve_angle(cur, out)
            if a is None:
                continue
            hinges.append(nxt)
            angles.append(a)
            cur = out
            placed = True
            break
        if not placed:
            return None
    for _ in range(50):
        out = cardinal(right_of(cur) if rng.random() < 0.5 else left_of(cur))
        a = solve_angle(cur, out)
        if a is None:
            continue
        c = (hinges[-1] + out * rng.choice(CRYSTAL_LENS)).snap10()
        if in_play(c) and all(c.distance_to(h) >= MIN_HINGE_GAP - 30 for h in hinges):
            angles.append(a)
            return hinges, c, angles
    return None


def build_path(rng, tip, incoming, recipe):
    kind = recipe["kind"]
    if kind == "axis_backtrack":
        r = dict(recipe)
        ch = list(r["chirality"])
        mid = max(1, len(ch) // 2)
        for i in range(mid, len(ch)):
            ch[i] = 1 - ch[i]
        r["chirality"] = tuple(ch)
        return build_axis(rng, tip, incoming, r)
    if kind in ("axis_chirality", "axis_irregular"):
        return build_axis(rng, tip, incoming, recipe)
    return build_freeform(rng, tip, incoming, recipe, orbit=(kind == "freeform_orbit"))


def stopper_at(hinge, outgoing, rng, wid):
    block = V(-outgoing.x, -outgoing.y)
    gap, length = 105.0, 190.0
    if abs(block.x) >= abs(block.y):
        cx = hinge.x + block.x * gap
        if not (90 <= cx <= ROOM_W - 90):
            cx = hinge.x - block.x * gap
        y0, y1 = clamp(hinge.y - length / 2, 80, ROOM_H - 80), clamp(hinge.y + length / 2, 80, ROOM_H - 80)
        return wall_v(wid, cx, y0, y1) if abs(y1 - y0) >= 120 else None
    cy = hinge.y + block.y * gap
    if not (90 <= cy <= ROOM_H - 90):
        cy = hinge.y - block.y * gap
    x0 = clamp(hinge.x - length / 2 + rng.choice([-50, 0, 50]), 40, ROOM_W - 40)
    x1 = clamp(hinge.x + length / 2, 40, ROOM_W - 40)
    return wall_h(wid, x0, x1, cy) if abs(x1 - x0) >= 120 else None


def build_walls(family, tip, hinges, crystal, incomings, outgoings, decoy, rng):
    corridor = [tip] + hinges + [crystal]
    walls: List[dict] = []
    if family == "open_arena":
        w = stopper_at(hinges[-1], outgoings[-1], rng, "s0")
        if w:
            walls.append(w)
    elif family == "sparse_stoppers":
        for i, h in enumerate(hinges):
            w = stopper_at(h, outgoings[i], rng, f"s{i}")
            if w:
                walls.append(w)
    elif family == "decoy_branches":
        for i, h in enumerate(hinges):
            w = stopper_at(h, outgoings[i], rng, f"s{i}")
            if w:
                walls.append(w)
        for i, hinge in enumerate(hinges):
            if len(walls) >= decoy + len(hinges):
                break
            wrong = cardinal(V(-outgoings[i].x, -outgoings[i].y))
            depth = rng.uniform(200, 300)
            mid = hinge + wrong * (depth * 0.55)
            perp = left_of(wrong)
            if abs(wrong.x) > 0.5:
                batch = [
                    wall_h(f"d{len(walls)}", (mid + perp * 70 - wrong * 80).x, (mid + perp * 70 + wrong * 80).x, (mid + perp * 70).y),
                    wall_h(f"d{len(walls)+1}", (mid - perp * 70 - wrong * 80).x, (mid - perp * 70 + wrong * 80).x, (mid - perp * 70).y),
                ]
            else:
                batch = [
                    wall_v(f"d{len(walls)}", (mid + perp * 70).x, (mid + perp * 70 - wrong * 80).y, (mid + perp * 70 + wrong * 80).y),
                    wall_v(f"d{len(walls)+1}", (mid - perp * 70).x, (mid - perp * 70 - wrong * 80).y, (mid - perp * 70 + wrong * 80).y),
                ]
            if filter_clear(batch, corridor) == batch:
                walls.extend(batch)
    elif family == "multi_chamber":
        for i, h in enumerate(hinges[::2]):
            w = stopper_at(h, outgoings[i * 2 if i * 2 < len(outgoings) else -1], rng, f"s{i}")
            if w:
                walls.append(w)
        xs = sorted({round(h.x) for h in hinges})
        for i in range(min(3 + decoy // 2, max(0, len(xs) - 1))):
            a, b = xs[i], xs[min(i + 1, len(xs) - 1)]
            if b - a < 240:
                continue
            w = wall_v(f"c{i}", (a + b) / 2, EDGE, EDGE + 400)
            if filter_clear([w], corridor):
                walls.append(w)
    elif family == "pillar_field":
        for _ in range(4 + decoy // 2):
            p = V(rng.uniform(EDGE, ROOM_W - EDGE), rng.uniform(EDGE, ROOM_H - EDGE)).snap10()
            if any(p.distance_to(h) < 160 for h in hinges):
                continue
            s = 56.0
            w = {
                "id": f"p{len(walls)}",
                "polygon": [[p.x - s / 2, p.y - s / 2], [p.x + s / 2, p.y - s / 2], [p.x + s / 2, p.y + s / 2], [p.x - s / 2, p.y + s / 2]],
                "isDecorative": False,
                "renderAsset": "wall_h_cut",
                "orientation": "horizontal",
                "thickness": T,
            }
            if filter_clear([w], corridor):
                walls.append(w)
    elif family == "false_gallery":
        for i in range(0, len(hinges) - 1):
            a, b = hinges[i], hinges[i + 1]
            mid = V((a.x + b.x) / 2, (a.y + b.y) / 2)
            along = (b - a).normalized()
            side = left_of(along) if rng.random() < 0.5 else right_of(along)
            offset = mid + side * rng.uniform(140, 220)
            span = a.distance_to(b) * 0.7
            w = wall_h(f"f{len(walls)}", offset.x - span / 2, offset.x + span / 2, offset.y) if abs(along.x) > 0.5 else wall_v(f"f{len(walls)}", offset.x, offset.y - span / 2, offset.y + span / 2)
            if filter_clear([w], corridor):
                walls.append(w)
    elif family == "island_blocks":
        for _ in range(4 + decoy // 2):
            x0, y0 = rng.uniform(80, ROOM_W - 280), rng.uniform(80, ROOM_H - 280)
            ww, hh = rng.uniform(120, 220), rng.uniform(80, 160)
            w = wall_h(f"i{len(walls)}", x0, x0 + ww, y0 + hh / 2) if ww >= hh else wall_v(f"i{len(walls)}", x0 + ww / 2, y0, y0 + hh)
            if filter_clear([w], corridor):
                walls.append(w)
    else:  # gauntlet
        for i, h in enumerate(hinges):
            if i % 2:
                continue
            perp = left_of(outgoings[i])
            for sign in (-1.0, 1.0):
                cx = h.x + perp.x * 95 * sign
                cy = h.y + perp.y * 95 * sign
                w = wall_v(f"g{len(walls)}", cx, h.y - 70, h.y + 70) if abs(outgoings[i].x) > 0.5 else wall_h(f"g{len(walls)}", h.x - 70, h.x + 70, cy)
                if filter_clear([w], corridor):
                    walls.append(w)
        for i, h in enumerate(hinges[1::2]):
            idx = 1 + i * 2
            if idx < len(outgoings):
                w = stopper_at(h, outgoings[idx], rng, f"s{i}")
                if w:
                    walls.append(w)
    return renumber(filter_clear(walls, corridor))


def initial_offset_range(index: int) -> Tuple[float, float]:
    if index <= 15:
        return 22.0, 38.0
    t = progress_t(index)
    return 42.0 + t * 50.0, min(58.0 + t * 58.0, 125.0)


def aim_tolerance(index: int) -> float:
    return 5.0 if index <= 15 else round(5.0 - progress_t(index) * 2.6, 2)


def star_budget(index: int, mirrors: int, walls: int) -> Tuple[int, int]:
    if index <= 15:
        return mirrors + 1, 40 + mirrors * 18 + min(walls, 20) * 2
    t = progress_t(index)
    seconds = int((34 + mirrors * 12) * (1.0 - 0.58 * t) + min(walls, 14) * (1 - 0.5 * t))
    return mirrors, max(16 + mirrors * 3, seconds)


TITLES = ["Mind Trap", "False Passage", "Ghost Gallery", "Pillar Riddle", "Dark Chamber", "Broken Spiral", "Mirror Labyrinth", "Silent Gauntlet", "Orbit Vault", "Echo Keep"]


def chapter_ids(index: int) -> Tuple[str, str, int]:
    ch = (index - 1) // CHAPTER_SIZE + 1
    li = (index - 1) % CHAPTER_SIZE + 1
    return f"ch{ch}", f"ch{ch}_{li:03d}", li


def build_level(index: int, recipe: dict, rng: random.Random) -> Optional[dict]:
    light_pos, light_dir = pick_light(recipe["light_side"], rng)
    tip = mounted_origin([light_pos.x, light_pos.y], light_dir)
    incoming = dir_deg(light_dir).normalized()
    path = build_path(rng, tip, incoming, recipe)
    if path is None:
        return None
    hinges, crystal, angles = path
    if len(hinges) != recipe["mirrors"] or len(angles) != recipe["mirrors"]:
        return None
    incomings = [incoming]
    outgoings: List[V] = []
    d = incoming
    for i, hinge in enumerate(hinges):
        out = (hinges[i + 1] - hinge).normalized() if i < len(hinges) - 1 else (crystal - hinge).normalized()
        outgoings.append(out)
        got = solve_angle(d, out)
        if got is None:
            return None
        angles[i] = got
        d = out
        if i < len(hinges) - 1:
            incomings.append(d)
    walls = build_walls(recipe["family"], tip, hinges, crystal, incomings, outgoings, recipe["decoy_count"], rng)
    lo, hi = initial_offset_range(index)
    mirrors, solution = [], {}
    for i, (hinge, ang) in enumerate(zip(hinges, angles)):
        mid = f"m{i+1}"
        delta = rng.choice([-1, 1]) * rng.uniform(lo, hi)
        initial = clamp(ang + delta, 5.0, 175.0)
        if abs(initial - ang) < lo * 0.7:
            initial = clamp(ang + (hi if ang < 90 else -hi), 5.0, 175.0)
        mirrors.append({
            "id": mid, "hingePosition": [hinge.x, hinge.y], "length": MIRROR_LEN,
            "initialAngle": initial, "minAngle": 5.0, "maxAngle": 175.0,
            "snapIncrement": 0.0, "isLocked": False, "type": "standard",
        })
        solution[mid] = float(ang)
    moves, seconds = star_budget(index, len(mirrors), len(walls))
    chapter_id, level_id, level_in_chapter = chapter_ids(index)
    pid = hashlib.sha256(json.dumps({
        "chirality": recipe["chirality"], "lengths": recipe["lengths"],
        "family": recipe["family"], "kind": recipe["kind"], "light": int(light_dir),
        "m": recipe["mirrors"], "c": (int(crystal.x / 40), int(crystal.y / 40)),
        "topo": sorted((int((h.x - min(x.x for x in hinges)) / 40), int((h.y - min(x.y for x in hinges)) / 40)) for h in hinges),
    }, sort_keys=True).encode()).hexdigest()
    return {
        "levelId": level_id, "chapterId": chapter_id, "schemaVersion": 1,
        "levelIndex": level_in_chapter, "title": f"{TITLES[index % len(TITLES)]} {index}",
        "roomBounds": {"width": ROOM_W, "height": ROOM_H},
        "lightSources": [{"id": "ls1", "position": [light_pos.x, light_pos.y], "direction": light_dir, "locked": True}],
        "mirrors": mirrors, "obstacles": walls,
        "targetCrystals": [{"id": "c1", "position": [crystal.x, crystal.y], "hitRadius": 44, "groupId": "g1"}],
        "crystalGroups": [{"groupId": "g1", "requiredCount": 1}], "doorPortals": [],
        "requiredMirrorBounces": len(mirrors),
        "intendedSolution": {"mirrorAngles": solution, "toleranceDegrees": aim_tolerance(index)},
        "starThresholds": {"threeStarMoveCount": moves, "threeStarTimeSeconds": seconds},
        "metadata": {
            "designer": DESIGNER, "difficultyBand": chapter_id,
            "difficultyScore": hardness_score(index), "hardness": round(recipe["t"], 4),
            "patternId": pid, "patternFamily": recipe["family"], "pathKind": recipe["kind"],
            "objective": "Find the true reflection chain — every mirror, one path." if index > 15 else f"Bounce through all {len(mirrors)} mirrors.",
            "hints": ["Stone can lie.", "Simulate before you turn.", "Obvious paths are often traps."] if index > 15 else ["Every mirror counts.", "Wrong tilt misses.", "Follow the beam."],
            "roomType": f"{recipe['kind']}_{recipe['family']}", "globalIndex": index,
            "pillars": [pillar(h.x, h.y) for h in hinges],
        },
    }


def fingerprint(level: dict) -> str:
    mirrors = [(round(m["hingePosition"][0] / 20), round(m["hingePosition"][1] / 20)) for m in level["mirrors"]]
    mx, my = min(x for x, _ in mirrors), min(y for _, y in mirrors)
    payload = {
        "topo": sorted((x - mx, y - my) for x, y in mirrors),
        "family": level["metadata"].get("patternFamily"),
        "kind": level["metadata"].get("pathKind"),
        "pid": level["metadata"].get("patternId"),
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def generate_one(index: int, seen_fp: Set[str], seen_p: Set[str]) -> Optional[dict]:
    base = pattern_for(index)
    for attempt in range(500):
        recipe = dict(base)
        if attempt > 15:
            recipe["kind"] = ("axis_chirality", "axis_irregular", "axis_backtrack")[attempt % 3]
        if attempt > 40:
            recipe["family"] = LAYOUT_FAMILIES[(index + attempt) % len(LAYOUT_FAMILIES)]
        if attempt > 80:
            recipe["decoy_count"] = max(0, recipe["decoy_count"] - 2)
        if attempt > 150 and recipe["mirrors"] >= 9 and index > 15:
            recipe["mirrors"] -= 1
            n = recipe["mirrors"] - 1
            recipe["chirality"] = recipe["chirality"][:n]
            recipe["lengths"] = recipe["lengths"][:n]
        if index <= 15:
            recipe["family"] = "sparse_stoppers" if index <= 5 else "gauntlet_doors"
            recipe["kind"] = "axis_chirality"
            recipe["decoy_count"] = 0
            recipe["mirrors"] = mirrors_for(index)
            n = recipe["mirrors"] - 1
            recipe["chirality"] = recipe["chirality"][:n]
            recipe["lengths"] = recipe["lengths"][:n]
        rng = random.Random(index * 1_000_003 + attempt * 7919 + 91)
        level = build_level(index, recipe, rng)
        if level is None or not validate(level):
            continue
        pid = level["metadata"]["patternId"]
        if index > 15 and pid in seen_p:
            continue
        fp = fingerprint(level)
        if fp in seen_fp:
            continue
        seen_fp.add(fp)
        seen_p.add(pid)
        return level
    for drop in (1, 2, 3, 4):
        for attempt in range(250):
            recipe = dict(base)
            recipe["mirrors"] = max(6 if index > 15 else 2, base["mirrors"] - drop)
            n = recipe["mirrors"] - 1
            recipe["chirality"] = tuple((base["chirality"][i % len(base["chirality"])] if base["chirality"] else 0) for i in range(n))
            recipe["lengths"] = tuple(SEG_LENS[(index + i + drop) % len(SEG_LENS)] for i in range(n))
            recipe["family"] = LAYOUT_FAMILIES[(attempt + drop) % len(LAYOUT_FAMILIES)]
            recipe["kind"] = ("axis_chirality", "axis_irregular", "axis_backtrack")[attempt % 3]
            recipe["decoy_count"] = 0
            level = build_level(index, recipe, random.Random(index * 910019 + attempt * 4999 + drop))
            if level is None or not validate(level):
                continue
            fp = fingerprint(level)
            if fp in seen_fp:
                continue
            seen_fp.add(fp)
            seen_p.add(level["metadata"]["patternId"])
            return level
    return None


# ---- single-file IO ----

def level_filename(level: dict) -> str:
    return f"{level['levelId']}.json"


def level_path(outdir: str, level: dict) -> str:
    return os.path.join(outdir, level_filename(level))


def write_level(outdir: str, level: dict) -> None:
    os.makedirs(outdir, exist_ok=True)
    path = level_path(outdir, level)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(level, f, indent=2)
    os.replace(tmp, path)


def write_manifest(outdir: str, levels: List[dict]) -> None:
    entries = []
    for i, level in enumerate(levels, start=1):
        entries.append({
            "levelId": level["levelId"],
            "chapterId": level.get("chapterId", "ch1"),
            "levelIndex": level.get("levelIndex", i),
            "file": level_filename(level),
            "globalIndex": level.get("metadata", {}).get("globalIndex", i),
        })
    path = os.path.join(outdir, "manifest.json")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({
            "schemaVersion": 1,
            "mode": "single",
            "totalLevels": len(entries),
            "levels": entries,
        }, f, indent=2)
    os.replace(tmp, path)


def load_existing(outdir: str) -> List[dict]:
    man = os.path.join(outdir, "manifest.json")
    if not os.path.isfile(man):
        return []
    try:
        data = json.load(open(man))
    except Exception:
        return []

    # Prefer single-file manifest; fall back to legacy batch layout.
    if "levels" in data and isinstance(data["levels"], list) and data["levels"]:
        levels: List[dict] = []
        for entry in data["levels"]:
            name = entry.get("file") or f"{entry['levelId']}.json"
            path = os.path.join(outdir, name)
            if not os.path.isfile(path):
                break
            levels.append(json.load(open(path)))
        return levels

    batches = data.get("batches") or []
    levels = []
    for name in batches:
        path = os.path.join(outdir, name)
        if not os.path.isfile(path):
            break
        chunk = json.load(open(path)).get("levels", [])
        levels.extend(chunk)
    return levels


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate extreme levels as one JSON file per level")
    parser.add_argument("--count", type=int, default=1000)
    parser.add_argument("--outdir", type=str, default="assets/levels")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--from", dest="from_index", type=int, default=1)
    args = parser.parse_args()

    random.seed(args.seed)
    total = args.count
    os.makedirs(args.outdir, exist_ok=True)

    levels: List[dict] = []
    seen_fp: Set[str] = set()
    seen_p: Set[str] = set()
    start_index = 1

    if args.resume or args.from_index > 1:
        existing = load_existing(args.outdir)
        keep = min(args.from_index - 1, len(existing)) if args.from_index > 1 else len(existing)
        if args.resume and args.from_index == 1:
            keep = len(existing)
        levels = existing[:keep]
        for L in levels:
            L.setdefault("metadata", {})["designer"] = DESIGNER
            seen_fp.add(fingerprint(L))
            pid = L.get("metadata", {}).get("patternId")
            if pid:
                seen_p.add(pid)
        start_index = len(levels) + 1
        print(f"Keeping {len(levels)} levels, continuing from {start_index}")

    print(f"Generating {start_index}..{total} → {args.outdir}/chX_YYY.json (1/file)")
    t0 = time.time()

    try:
        for i in range(start_index, total + 1):
            level = generate_one(i, seen_fp, seen_p)
            if level is None:
                print(f"\nFATAL at level {i}", file=sys.stderr)
                return 1
            write_level(args.outdir, level)
            levels.append(level)
            if i % 10 == 0 or i == total:
                write_manifest(args.outdir, levels)
            sys.stdout.write(
                f"\r  L{i}/{total}: {level['levelId']} "
                f"{len(level['mirrors'])}m "
                f"{level['metadata']['pathKind']}/{level['metadata']['patternFamily']}   "
            )
            sys.stdout.flush()
    except KeyboardInterrupt:
        print(f"\nInterrupted at {len(levels)}. Finished levels are safe on disk.")
        write_manifest(args.outdir, levels)
        print(f"Resume:\n  python3 tool/generate_levels_extreme.py --count {total} --outdir {args.outdir} --resume")
        return 130

    write_manifest(args.outdir, levels)
    print(f"\nDone in {time.time()-t0:.1f}s — {len(levels)} levels, {len(seen_p)} patterns")
    print(f"Manifest: {args.outdir}/manifest.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
