#!/usr/bin/env python3
"""
Logical Mirror Logic level generator (handcrafted_v2 style).

Design rules (from original handcrafted pack):
  - Axis-aligned bounce paths (H/V only) with 45° / 135° solutions
  - Mirrors spaced ≥350px apart (prefer 400–750) — NEVER clustered
  - Walls are thin 48px stone bars (wall_h_cut / wall_h_cut_rotated)
  - Pillars (wall_v_cut) sit on every hinge post
  - Corridor stoppers block the wrong continuation past each mirror
  - Light wall-mounted; crystal far from last hinge (≥350px)
  - Beam-validated: solvable at solution, unsolved at initial

Mirror bands (every 5 levels +2):
  1–5 → 2, 6–10 → 4, 11–15 → 6, 16–20 → 8, then cap at 8
  After cap: more walls / rooms / locked / snap for hardness

Usage:
  python3 tool/generate_levels_logical.py
  python3 tool/generate_levels_logical.py --count 1000 --output assets/levels/levels.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple

# ---------------------------------------------------------------------------
# Constants matching the game + handcrafted pack
# ---------------------------------------------------------------------------

ROOM_W = 1080.0
ROOM_H = 1920.0
T = 48.0  # wall / pillar thickness
MIRROR_LEN = 145.0
WALL_INSET = 52.0
MAX_BOUNCES = 24

MIN_HINGE_GAP = 350.0
PREF_SEG_MIN = 400.0
PREF_SEG_MAX = 700.0
MIN_CRYSTAL_GAP = 380.0
EDGE_MARGIN = 140.0
STOPPER_GAP = 95.0  # hinge → wall near end
STOPPER_LEN = 220.0

DEFAULT_COUNT = 1000
DEFAULT_OUTPUT = "assets/levels/levels.json"


# ---------------------------------------------------------------------------
# Math
# ---------------------------------------------------------------------------


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
        if l < 1e-9:
            return V(0.0, 0.0)
        return V(self.x / l, self.y / l)

    def dot(self, o: "V") -> float:
        return self.x * o.x + self.y * o.y

    def distance_to(self, o: "V") -> float:
        return (self - o).length

    def snap10(self) -> "V":
        return V(round(self.x / 10) * 10, round(self.y / 10) * 10)


def dir_deg(deg: float) -> V:
    r = math.radians(deg)
    return V(math.cos(r), math.sin(r))


def normal(mirror_deg: float) -> V:
    return dir_deg(mirror_deg + 90).normalized()


def face_normal(mirror_deg: float, incoming: V) -> V:
    n = normal(mirror_deg)
    return V(-n.x, -n.y) if n.dot(incoming) > 0 else n


def reflect(d: V, n: V) -> V:
    dn = d.dot(n)
    return V(d.x - n.x * 2 * dn, d.y - n.y * 2 * dn)


def axis_angle(incoming: V, outgoing: V) -> Optional[float]:
    """Exact 45/135 for axis-aligned turns; else scan."""
    i = incoming.normalized()
    o = outgoing.normalized()
    # Cardinal check
    for a in (45.0, 135.0, 90.0, 0.0, 180.0):
        r = reflect(i, face_normal(a, i)).normalized()
        if r.dot(o) > 0.999:
            return a
    a = 5.0
    while a <= 175.0:
        r = reflect(i, face_normal(a, i)).normalized()
        if r.dot(o) > 0.9995:
            return round(a * 4) / 4
        a += 0.25
    return None


# ---------------------------------------------------------------------------
# Wall / pillar helpers (handcrafted schema)
# ---------------------------------------------------------------------------


def wall_h(wid: str, x0: float, x1: float, cy: float, t: float = T) -> dict:
    if x1 < x0:
        x0, x1 = x1, x0
    return {
        "id": wid,
        "polygon": [
            [x0, cy - t / 2],
            [x1, cy - t / 2],
            [x1, cy + t / 2],
            [x0, cy + t / 2],
        ],
        "isDecorative": False,
        "renderAsset": "wall_h_cut",
        "orientation": "horizontal",
        "thickness": t,
    }


def wall_v(wid: str, cx: float, y0: float, y1: float, t: float = T) -> dict:
    if y1 < y0:
        y0, y1 = y1, y0
    return {
        "id": wid,
        "polygon": [
            [cx - t / 2, y0],
            [cx + t / 2, y0],
            [cx + t / 2, y1],
            [cx - t / 2, y1],
        ],
        "isDecorative": False,
        "renderAsset": "wall_h_cut_rotated",
        "orientation": "vertical",
        "thickness": t,
    }


def pillar(x: float, y: float) -> dict:
    return {"position": [x, y], "asset": "wall_v_cut", "size": T}


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def in_play(p: V) -> bool:
    return (
        EDGE_MARGIN <= p.x <= ROOM_W - EDGE_MARGIN
        and EDGE_MARGIN <= p.y <= ROOM_H - EDGE_MARGIN
    )


# ---------------------------------------------------------------------------
# Beam simulator (validation)
# ---------------------------------------------------------------------------


@dataclass
class Hit:
    point: V
    dist: float
    kind: str
    id: Optional[str] = None
    normal: Optional[V] = None
    relay: bool = False


def mounted_origin(pos: List[float], dir_deg_val: float) -> V:
    rad = math.radians(dir_deg_val)
    dx, dy = math.cos(rad), math.sin(rad)
    y = clamp(pos[1], WALL_INSET, ROOM_H - WALL_INSET)
    x = clamp(pos[0], WALL_INSET, ROOM_W - WALL_INSET)
    if abs(dx) >= abs(dy):
        return V(WALL_INSET, y) if dx >= 0 else V(ROOM_W - WALL_INSET, y)
    return V(x, WALL_INSET) if dy >= 0 else V(x, ROOM_H - WALL_INSET)


def ray_segment(origin: V, direction: V, a: V, b: V) -> Optional[Hit]:
    ox, oy = origin.x, origin.y
    dx, dy = direction.x, direction.y
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

    def consider(
        h: Optional[Hit],
        kind: str,
        id_: str = "",
        normal_v: Optional[V] = None,
        relay: bool = False,
    ):
        nonlocal best
        if h is None or h.dist < 1e-6:
            return
        cand = Hit(h.point, h.dist, kind, id_ or None, normal_v, relay)
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
            consider(
                ray_segment(origin, direction, poly[i], poly[(i + 1) % len(poly)]),
                "wall",
                obs["id"],
            )

    for m in level["mirrors"]:
        mid = m["id"]
        ang = angles.get(mid, m["initialAngle"])
        hinge = V(m["hingePosition"][0], m["hingePosition"][1])
        half = dir_deg(ang) * (m["length"] / 2)
        h = ray_segment(origin, direction, hinge - half, hinge + half)
        if h:
            n = normal(ang)
            if n.dot(direction) > 0:
                n = V(-n.x, -n.y)
            consider(h, "mirror", mid, n)

    for c in level["targetCrystals"]:
        center = V(c["position"][0], c["position"][1])
        h = ray_circle(origin, direction, center, c.get("hitRadius", 44))
        consider(h, "crystal", c["id"], relay=c.get("relay", False))

    return best


def simulate(level: dict, angles: Dict[str, float]) -> Tuple[Set[str], int]:
    lit: Set[str] = set()
    hits = 0
    for ls in level["lightSources"]:
        tip = mounted_origin(ls["position"], ls["direction"])
        pos = tip
        d = dir_deg(ls["direction"]).normalized()
        for _ in range(MAX_BOUNCES):
            hit = nearest_hit(level, pos, d, angles)
            if hit is None:
                break
            if hit.kind == "crystal":
                lit.add(hit.id)  # type: ignore
                if hit.relay:
                    pos = hit.point + d * 0.5
                    continue
                break
            if hit.kind in ("wall", "bounds"):
                break
            if hit.kind == "mirror":
                hits += 1
                d = reflect(d, hit.normal).normalized()  # type: ignore
                pos = hit.point + d * 0.5
                continue
            break
    return lit, hits


def validate(level: dict) -> bool:
    mirrors = level["mirrors"]
    sol = {k: float(v) for k, v in level["intendedSolution"]["mirrorAngles"].items()}
    angles = {m["id"]: m["initialAngle"] for m in mirrors}
    angles.update(sol)

    lit, hits = simulate(level, angles)
    if "c1" not in lit:
        return False
    if hits != len(mirrors):
        return False
    required = level.get("requiredMirrorBounces")
    if required is not None and hits != required:
        return False

    # Groups
    for grp in level["crystalGroups"]:
        members = [
            c["id"] for c in level["targetCrystals"] if c["groupId"] == grp["groupId"]
        ]
        if sum(1 for m in members if m in lit) < grp["requiredCount"]:
            return False

    # Not solved at initial
    initial = {m["id"]: m["initialAngle"] for m in mirrors}
    lit0, _ = simulate(level, initial)
    if "c1" in lit0:
        ok = True
        for grp in level["crystalGroups"]:
            members = [
                c["id"] for c in level["targetCrystals"] if c["groupId"] == grp["groupId"]
            ]
            if sum(1 for m in members if m in lit0) < grp["requiredCount"]:
                ok = False
        if ok:
            return False

    # Mirrors must not overlap (hinge distance)
    for i in range(len(mirrors)):
        a = V(mirrors[i]["hingePosition"][0], mirrors[i]["hingePosition"][1])
        for j in range(i + 1, len(mirrors)):
            b = V(mirrors[j]["hingePosition"][0], mirrors[j]["hingePosition"][1])
            if a.distance_to(b) < MIN_HINGE_GAP - 1:
                return False

    return True


# ---------------------------------------------------------------------------
# Path / room construction
# ---------------------------------------------------------------------------


@dataclass
class Spec:
    mirrors: int
    extra_walls: int
    locked: int
    snap: bool
    room_style: str


ROOM_STYLES = [
    "west_corridor",
    "ceiling_drop",
    "zigzag_hall",
    "square_keep",
    "south_ascent",
    "east_gallery",
    "twin_wing",
    "labyrinth",
]


def spec_for(index: int) -> Spec:
    band = (index - 1) // 5
    mirrors = min(2 * (band + 1), 8)
    extra = min(band // 2, 4)
    locked = 1 if mirrors >= 6 and index > 30 else 0
    snap = mirrors >= 6 and index > 40
    style = ROOM_STYLES[index % len(ROOM_STYLES)]
    return Spec(mirrors, extra, locked, snap, style)


def light_for_style(style: str, rng: random.Random) -> Tuple[V, float]:
    """Return authored light position + direction (wall-mounted)."""
    if style in ("ceiling_drop", "south_ascent") and rng.random() < 0.55:
        x = rng.choice([300, 400, 540, 700, 800])
        return V(float(x), 130.0), 90.0
    if style == "east_gallery":
        y = rng.choice([300, 480, 700, 960, 1200, 1500])
        return V(ROOM_W - 130.0, float(y)), 180.0
    # default west / left sconce
    y = rng.choice([300, 400, 480, 600, 760, 960, 1200, 1400, 1536])
    return V(130.0, float(y)), 0.0


def cardinals_from(incoming: V) -> List[V]:
    """Preferred turn directions (perpendicular first, then forward)."""
    i = incoming.normalized()
    # Perpendiculars
    left = V(-i.y, i.x)
    right = V(i.y, -i.x)
    forward = i
    return [left, right, forward]


def build_axis_path(
    rng: random.Random,
    light_pos: V,
    light_dir: float,
    mirror_count: int,
) -> Optional[Tuple[List[V], V, List[float], List[V]]]:
    """
    Build axis-aligned path: hinges + crystal + solution angles.
    Uses DFS so 6–8 mirror labyrinths still fit with ≥350px gaps.
    """
    tip = mounted_origin([light_pos.x, light_pos.y], light_dir)
    incoming = dir_deg(light_dir).normalized()

    first_dist = rng.uniform(PREF_SEG_MIN, min(PREF_SEG_MAX, 620))
    first = (tip + incoming * first_dist).snap10()
    if not in_play(first):
        first = (tip + incoming * PREF_SEG_MIN).snap10()
        if not in_play(first):
            return None

    seg_lo = PREF_SEG_MIN if mirror_count <= 4 else MIN_HINGE_GAP
    seg_hi = PREF_SEG_MAX if mirror_count <= 6 else 620.0

    def try_crystal(hinges: List[V], d_in: V) -> Optional[Tuple[V, float]]:
        last = hinges[-1]
        cry_dirs = cardinals_from(d_in)
        rng.shuffle(cry_dirs)
        for out in cry_dirs:
            if abs(out.dot(d_in) - 1) < 0.01:
                continue
            a = axis_angle(d_in, out)
            if a is None:
                continue
            for _ in range(12):
                dist = rng.uniform(MIN_CRYSTAL_GAP, seg_hi + 100)
                c = (last + out * dist).snap10()
                if not in_play(c):
                    continue
                if any(c.distance_to(h) < MIN_CRYSTAL_GAP - 30 for h in hinges):
                    continue
                return c, a
        return None

    best: Optional[Tuple[List[V], V, List[float]]] = None

    def dfs(hinges: List[V], angles: List[float], cur_in: V, depth: int) -> bool:
        nonlocal best
        if depth == mirror_count:
            cry = try_crystal(hinges, cur_in)
            if cry is None:
                return False
            crystal, last_ang = cry
            best = (hinges[:], crystal, angles + [last_ang])
            return True

        cur = hinges[-1]
        options = cardinals_from(cur_in)
        rng.shuffle(options)
        options = [d for d in options if abs(d.dot(cur_in)) < 0.5] + [
            d for d in options if abs(d.dot(cur_in)) >= 0.5
        ]
        for out_dir in options:
            if abs(out_dir.dot(cur_in) - 1) < 0.01:
                continue
            a = axis_angle(cur_in, out_dir)
            if a is None:
                continue
            lengths = [rng.uniform(seg_lo, seg_hi) for _ in range(8)]
            lengths.sort(reverse=True)
            for seg in lengths:
                nxt = (cur + out_dir * seg).snap10()
                if not in_play(nxt):
                    continue
                if any(nxt.distance_to(h) < MIN_HINGE_GAP for h in hinges):
                    continue
                if abs(nxt.x - cur.x) > 1 and abs(nxt.y - cur.y) > 1:
                    continue
                hinges.append(nxt)
                angles.append(a)
                if dfs(hinges, angles, out_dir, depth + 1):
                    return True
                hinges.pop()
                angles.pop()
        return False

    if not dfs([first], [], incoming, 1):
        return None
    assert best is not None
    hinges, crystal, angles = best
    return hinges, crystal, angles, []



def stopper_for_hinge(
    wid: str,
    hinge: V,
    incoming: V,
    outgoing: V,
    rng: random.Random,
) -> Optional[dict]:
    """
    Place a corridor stopper that blocks continuing past the hinge in the
    WRONG direction (typically the blocked forward along incoming, or the
    opposite of outgoing — matching handcrafted 'force the bounce' walls).
    """
    # Block the side opposite to the intended outgoing (so wrong tilt hits stone)
    # Handcrafted often places wall on the side the player might wrongly aim.
    block = V(-outgoing.x, -outgoing.y)  # opposite of correct leave
    # Prefer wall perpendicular to block direction (bar across the blocked lane)
    if abs(block.x) >= abs(block.y):
        # block left/right → vertical wall offset in block direction
        cx = hinge.x + block.x * STOPPER_GAP
        if not (80 <= cx <= ROOM_W - 80):
            cx = hinge.x - block.x * STOPPER_GAP
        y0 = hinge.y - STOPPER_LEN / 2
        y1 = hinge.y + STOPPER_LEN / 2
        y0 = clamp(y0, 80, ROOM_H - 80)
        y1 = clamp(y1, 80, ROOM_H - 80)
        if abs(y1 - y0) < 120:
            return None
        return wall_v(wid, cx, y0, y1)
    else:
        # block up/down → horizontal wall
        cy = hinge.y + block.y * STOPPER_GAP
        if not (80 <= cy <= ROOM_H - 80):
            cy = hinge.y - block.y * STOPPER_GAP
        x0 = hinge.x - STOPPER_LEN / 2
        x1 = hinge.x + STOPPER_LEN / 2
        # Handcrafted often offsets wall to one side of hinge (not centered)
        if rng.random() < 0.6:
            if outgoing.x > 0.5:
                x0, x1 = hinge.x + 80, hinge.x + 80 + STOPPER_LEN
            elif outgoing.x < -0.5:
                x0, x1 = hinge.x - 80 - STOPPER_LEN, hinge.x - 80
            elif outgoing.y > 0.5:
                # keep horizontal but shift in x randomly
                shift = rng.choice([-80, 80])
                x0, x1 = hinge.x + shift, hinge.x + shift + (STOPPER_LEN if shift > 0 else -STOPPER_LEN)
                if x1 < x0:
                    x0, x1 = x1, x0
        x0 = clamp(x0, 40, ROOM_W - 40)
        x1 = clamp(x1, 40, ROOM_W - 40)
        if abs(x1 - x0) < 120:
            return None
        return wall_h(wid, x0, x1, cy)


def room_divider_walls(
    hinges: List[V],
    crystal: V,
    style: str,
    extra: int,
    rng: random.Random,
) -> List[dict]:
    """Extra walls that form rooms / wings without blocking the solution corridor."""
    walls: List[dict] = []
    if extra <= 0:
        return walls

    xs = sorted({h.x for h in hinges} | {crystal.x})
    ys = sorted({h.y for h in hinges} | {crystal.y})

    for i in range(extra):
        wid = f"rx{i}"
        if style in ("square_keep", "twin_wing", "labyrinth") or rng.random() < 0.5:
            # Vertical divider between columns
            if len(xs) >= 2:
                gap_pairs = [(xs[j], xs[j + 1]) for j in range(len(xs) - 1)]
                a, b = rng.choice(gap_pairs)
                if b - a < 200:
                    continue
                cx = (a + b) / 2
                # Place away from hinge Y rows
                y0 = rng.uniform(EDGE_MARGIN, ROOM_H * 0.35)
                y1 = y0 + rng.uniform(250, 450)
                y1 = min(y1, ROOM_H - EDGE_MARGIN)
                # Ensure not covering any hinge x closely AND y overlapping hinge
                ok = True
                for h in hinges:
                    if abs(h.x - cx) < 60 and y0 - 40 <= h.y <= y1 + 40:
                        ok = False
                        break
                if not ok:
                    continue
                walls.append(wall_v(wid, cx, y0, y1))
            else:
                continue
        else:
            # Horizontal divider between rows
            if len(ys) >= 2:
                gap_pairs = [(ys[j], ys[j + 1]) for j in range(len(ys) - 1)]
                a, b = rng.choice(gap_pairs)
                if b - a < 200:
                    continue
                cy = (a + b) / 2
                x0 = rng.uniform(EDGE_MARGIN, ROOM_W * 0.3)
                x1 = x0 + rng.uniform(180, 320)
                x1 = min(x1, ROOM_W - EDGE_MARGIN)
                ok = True
                for h in hinges:
                    if abs(h.y - cy) < 60 and x0 - 40 <= h.x <= x1 + 40:
                        ok = False
                        break
                if not ok:
                    continue
                walls.append(wall_h(wid, x0, x1, cy))
    return walls


def segment_clear_of_walls(
    a: V, b: V, walls: List[dict], pad: float = 8.0
) -> bool:
    """Conservative check: solution segment shouldn't cross wall AABBs."""
    xmin, xmax = min(a.x, b.x), max(a.x, b.x)
    ymin, ymax = min(a.y, b.y), max(a.y, b.y)
    # thicken segment slightly
    xmin -= pad
    xmax += pad
    ymin -= pad
    ymax += pad
    for w in walls:
        poly = w["polygon"]
        wx0 = min(p[0] for p in poly)
        wx1 = max(p[0] for p in poly)
        wy0 = min(p[1] for p in poly)
        wy1 = max(p[1] for p in poly)
        # AABB overlap of segment bbox with wall — for axis segments this is OK
        # but reject if wall fully crosses the thin corridor
        if xmax < wx0 or xmin > wx1 or ymax < wy0 or ymin > wy1:
            continue
        # If segment is horizontal
        if abs(a.y - b.y) < 1:
            if wy0 < a.y < wy1 and not (wx1 < xmin or wx0 > xmax):
                # wall crosses the y of the beam within x span
                return False
        elif abs(a.x - b.x) < 1:
            if wx0 < a.x < wx1 and not (wy1 < ymin or wy0 > ymax):
                return False
    return True


def build_level(index: int, spec: Spec, rng: random.Random) -> Optional[dict]:
    light_pos, light_dir = light_for_style(spec.room_style, rng)
    path = build_axis_path(rng, light_pos, light_dir, spec.mirrors)
    if path is None:
        return None
    hinges, crystal, angles, _dirs = path

    # Reconstruct incoming dirs for stoppers
    tip = mounted_origin([light_pos.x, light_pos.y], light_dir)
    incoming = dir_deg(light_dir).normalized()
    incomings = [incoming]
    d = incoming
    for i in range(len(hinges) - 1):
        aim = (hinges[i + 1] - hinges[i]).normalized()
        d = reflect(d, face_normal(angles[i], d)).normalized()
        incomings.append(d)

    outgoings: List[V] = []
    d = incoming
    for i, hinge in enumerate(hinges):
        if i < len(hinges) - 1:
            out = (hinges[i + 1] - hinge).normalized()
        else:
            out = (crystal - hinge).normalized()
        outgoings.append(out)
        d = reflect(d, face_normal(angles[i], d)).normalized()

    walls: List[dict] = []
    for i, hinge in enumerate(hinges):
        w = stopper_for_hinge(f"w{i}", hinge, incomings[i], outgoings[i], rng)
        if w is not None:
            walls.append(w)

    walls.extend(room_divider_walls(hinges, crystal, spec.room_style, spec.extra_walls, rng))

    # Ensure solution corridor clear — drop walls that block
    corridor_pts = [tip] + hinges + [crystal]
    clean: List[dict] = []
    for w in walls:
        ok = True
        for i in range(len(corridor_pts) - 1):
            if not segment_clear_of_walls(corridor_pts[i], corridor_pts[i + 1], [w]):
                ok = False
                break
        if ok:
            clean.append(w)
    walls = clean

    # Remap wall ids
    for i, w in enumerate(walls):
        w["id"] = f"w{i}"

    pillars = [pillar(h.x, h.y) for h in hinges]
    # Optional joint pillar on a wall tip
    if walls and rng.random() < 0.45:
        w = walls[0]
        poly = w["polygon"]
        if w["orientation"] == "horizontal":
            px = (poly[0][0] + poly[1][0]) / 2
            py = (poly[0][1] + poly[2][1]) / 2
        else:
            px = (poly[0][0] + poly[1][0]) / 2
            py = (poly[0][1] + poly[2][1]) / 2
        if all(V(px, py).distance_to(h) > 80 for h in hinges):
            pillars.append(pillar(px, py))

    locked_ids: Set[str] = set()
    if spec.locked > 0 and len(hinges) >= 2:
        # Lock an early mirror (handcrafted Fixed Glass style)
        locked_ids.add("m1")

    mirrors = []
    solution = {}
    for i, (hinge, ang) in enumerate(zip(hinges, angles)):
        mid = f"m{i + 1}"
        locked = mid in locked_ids
        initial = ang + rng.choice([-1, 1]) * rng.uniform(18, 28)
        min_a, max_a, snap = 5.0, 175.0, 0.0
        if spec.snap and not locked:
            min_a = max(5.0, ang - 18)
            max_a = min(175.0, ang + 18)
            snap = 5.0
        mirrors.append(
            {
                "id": mid,
                "hingePosition": [hinge.x, hinge.y],
                "length": MIRROR_LEN,
                "initialAngle": clamp(initial, min_a, max_a),
                "minAngle": min_a,
                "maxAngle": max_a,
                "snapIncrement": snap,
                "isLocked": locked,
                "type": "locked" if locked else "standard",
            }
        )
        solution[mid] = float(ang)

    titles = [
        "Stone Bounce",
        "Corridor Turn",
        "Hall Reflection",
        "Keep Passage",
        "Wing Route",
        "Vault Bend",
        "Gallery Path",
        "Bastion Echo",
        "Cloister Chain",
        "Atrium Loop",
    ]

    level = {
        "levelId": f"ch1_{index:03d}" if index < 1000 else f"ch1_{index}",
        "chapterId": "ch1",
        "schemaVersion": 1,
        "levelIndex": index,
        "title": f"{titles[index % len(titles)]} {index}",
        "roomBounds": {"width": ROOM_W, "height": ROOM_H},
        "lightSources": [
            {
                "id": "ls1",
                "position": [light_pos.x, light_pos.y],
                "direction": light_dir,
                "locked": True,
            }
        ],
        "mirrors": mirrors,
        "obstacles": walls,
        "targetCrystals": [
            {
                "id": "c1",
                "position": [crystal.x, crystal.y],
                "hitRadius": 44,
                "groupId": "g1",
            }
        ],
        "crystalGroups": [{"groupId": "g1", "requiredCount": 1}],
        "doorPortals": [],
        "requiredMirrorBounces": len(mirrors),
        "intendedSolution": {"mirrorAngles": solution, "toleranceDegrees": 5.0},
        "starThresholds": {
            "threeStarMoveCount": len(mirrors) + 1,
            "threeStarTimeSeconds": 35 + len(mirrors) * 18 + len(walls) * 3,
        },
        "metadata": {
            "designer": "logical_v2",
            "difficultyBand": "ch1",
            "newConceptsIntroduced": ["reflection"]
            + (["multi_mirror"] if len(mirrors) >= 3 else [])
            + (["locked_mirror"] if locked_ids else [])
            + (["angle_limits"] if spec.snap else []),
            "objective": (
                f"Bounce the beam through all {len(mirrors)} mirrors — "
                "stone walls block every shortcut."
            ),
            "hints": [
                "Follow the open corridor — walls close the wrong turns.",
                "Each pillar marks a mirror post you must use.",
                "Wrong tilt hits stone; correct tilt reaches the next post.",
            ],
            "roomType": spec.room_style,
            "globalIndex": index,
            "pillars": pillars,
            "wallAssetNote": (
                "obstacles render with renderAsset (wall_h_cut tiled horizontally, "
                "or wall_h_cut_rotated for vertical); pillars use wall_v_cut at posts."
            ),
        },
    }
    return level


def fingerprint(level: dict) -> str:
    payload = {
        "mirrors": [
            (round(m["hingePosition"][0]), round(m["hingePosition"][1]))
            for m in level["mirrors"]
        ],
        "walls": [
            (
                o.get("orientation"),
                round(o["polygon"][0][0]),
                round(o["polygon"][0][1]),
                round(o["polygon"][2][0]),
                round(o["polygon"][2][1]),
            )
            for o in level["obstacles"]
        ],
        "light": [
            round(level["lightSources"][0]["position"][0]),
            round(level["lightSources"][0]["position"][1]),
            level["lightSources"][0]["direction"],
        ],
        "crystal": [
            round(level["targetCrystals"][0]["position"][0]),
            round(level["targetCrystals"][0]["position"][1]),
        ],
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def generate_one(
    index: int, seen: Set[str], max_attempts: int = 600
) -> Optional[dict]:
    spec = spec_for(index)
    for attempt in range(max_attempts):
        rng = random.Random(index * 100003 + attempt * 7919 + 17)
        # Vary style a bit on retries
        if attempt > 0 and attempt % 40 == 0:
            spec = Spec(
                spec.mirrors,
                max(0, spec.extra_walls - 1),
                0 if attempt > 200 else spec.locked,
                False if attempt > 200 else spec.snap,
                ROOM_STYLES[(index + attempt) % len(ROOM_STYLES)],
            )
        level = build_level(index, spec, rng)
        if level is None:
            continue
        if not validate(level):
            continue
        fp = fingerprint(level)
        if fp in seen:
            continue
        seen.add(fp)
        return level

    # Soften mirrors only as last resort (keep band as close as possible)
    soft = Spec(max(2, spec.mirrors - 2), 0, 0, False, ROOM_STYLES[index % len(ROOM_STYLES)])
    for attempt in range(400):
        rng = random.Random(index * 910019 + attempt * 4999)
        level = build_level(index, soft, rng)
        if level is None or not validate(level):
            continue
        fp = fingerprint(level)
        if fp in seen:
            continue
        seen.add(fp)
        return level
    return None


def print_progress(done: int, total: int, start: float) -> None:
    pct = done / total * 100
    elapsed = time.time() - start
    rate = done / elapsed if elapsed > 0 else 0
    eta = (total - done) / rate if rate > 0 else 0
    bar_len = 40
    filled = int(bar_len * done / total)
    bar = "#" * filled + "-" * (bar_len - filled)
    sys.stdout.write(
        f"\r[{bar}] {pct:5.1f}%  {done}/{total}  "
        f"elapsed {elapsed:,.0f}s  ETA {eta:,.0f}s   "
    )
    sys.stdout.flush()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT)
    parser.add_argument("--output", type=str, default=DEFAULT_OUTPUT)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    random.seed(args.seed)
    total = args.count
    levels: List[dict] = []
    seen: Set[str] = set()
    start = time.time()

    print(f"Generating {total} LOGICAL levels → {args.output}")
    print(
        "Rules: axis paths, ≥350px mirror gap, wall_h_cut / wall_v pillars, "
        "validated physics"
    )
    print_progress(0, total, start)

    for i in range(1, total + 1):
        level = generate_one(i, seen)
        if level is None:
            print(f"\nFATAL: could not generate level {i}", file=sys.stderr)
            return 1
        levels.append(level)
        if i % 5 == 0 or i == total:
            print_progress(i, total, start)

    # Final uniqueness + spacing report
    gaps = []
    for L in levels:
        ms = L["mirrors"]
        for a in range(len(ms)):
            for b in range(a + 1, len(ms)):
                pa = V(ms[a]["hingePosition"][0], ms[a]["hingePosition"][1])
                pb = V(ms[b]["hingePosition"][0], ms[b]["hingePosition"][1])
                gaps.append(pa.distance_to(pb))
    min_gap = min(gaps) if gaps else 0

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump({"schemaVersion": 1, "levels": levels}, f, indent=2)

    print(
        f"\nDone in {time.time() - start:.1f}s — {len(levels)} levels, "
        f"{len(seen)} unique, min mirror gap {min_gap:.0f}px"
    )
    print(f"Wrote {args.output}")
    # Sample mirror counts
    for idx in (1, 5, 6, 10, 11, 15, 16, 20, 50, 100, 500, 1000):
        if idx <= len(levels):
            L = levels[idx - 1]
            print(
                f"  L{idx:4d}: mirrors={len(L['mirrors'])} walls={len(L['obstacles'])} "
                f"pillars={len(L['metadata']['pillars'])} style={L['metadata']['roomType']}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
