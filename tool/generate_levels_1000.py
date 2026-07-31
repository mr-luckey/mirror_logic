#!/usr/bin/env python3
"""
Procedural Mirror Logic level generator.

Generates 1000+ unique, progressively harder levels with:
  - Strictly increasing difficulty (each level harder than the last)
  - No duplicate layouts
  - Obstacles scaled to difficulty
  - requiredMirrorBounces = mirror count (all mirrors must be used)
  - Beam validation matching the Flutter game simulator

Usage (from project root):
  python3 tool/generate_levels_1000.py
  python3 tool/generate_levels_1000.py --count 1200 --output assets/levels/levels_1000.json
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
# Room / grid constants (match Flutter game)
# ---------------------------------------------------------------------------

ROOM_W = 1080.0
ROOM_H = 1920.0
GRID_COLS = 10
GRID_ROWS = 10
MAX_BOUNCES = 24
WALL_INSET = 52.0
DEFAULT_COUNT = 1000
DEFAULT_OUTPUT = "assets/levels/levels_1000.json"

# ---------------------------------------------------------------------------
# Vector math (ported from tool/generate_unique_ch1.dart)
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
            return V(0, 0)
        return V(self.x / l, self.y / l)

    def dot(self, o: "V") -> float:
        return self.x * o.x + self.y * o.y

    def distance_to(self, o: "V") -> float:
        return (self - o).length

    def clamp_room(self) -> "V":
        return V(max(100, min(980, self.x)), max(100, min(1820, self.y)))


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


def grid_cx(col: int) -> float:
    return (col + 0.5) * ROOM_W / GRID_COLS


def grid_cy(row: int) -> float:
    return (row + 0.5) * ROOM_H / GRID_ROWS


def grid_pos(col: int, row: int) -> V:
    return V(grid_cx(col), grid_cy(row))


def cell_key(col: int, row: int) -> Tuple[int, int]:
    return (col, row)


# ---------------------------------------------------------------------------
# Mirror chain solver
# ---------------------------------------------------------------------------


def solve_angle(incoming: V, outgoing: V) -> Optional[float]:
    i = incoming.normalized()
    o = outgoing.normalized()
    a = 5.0
    while a < 175.0:
        r = reflect(i, face_normal(a, i)).normalized()
        if r.dot(o) > 0.9995:
            return a
        a += 0.25
    return None


def solve_chain(hinges: List[V], incoming: V, target: V) -> Optional[List[float]]:
    d = incoming.normalized()
    out: List[float] = []
    for i, hinge in enumerate(hinges):
        if i < len(hinges) - 1:
            aim = (hinges[i + 1] - hinge).normalized()
        else:
            aim = (target - hinge).normalized()
        a = solve_angle(d, aim)
        if a is None:
            return None
        out.append(a)
        d = reflect(d, face_normal(a, d)).normalized()
    return out


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
    y = max(WALL_INSET, min(ROOM_H - WALL_INSET, pos[1]))
    x = max(WALL_INSET, min(ROOM_W - WALL_INSET, pos[0]))
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
    pt = V(ox + dx * t, oy + dy * t)
    return Hit(point=pt, dist=t, kind="")


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
    return Hit(point=origin + direction * t, dist=t, kind="")


def nearest_hit(level: dict, origin: V, direction: V, angles: Dict[str, float]) -> Optional[Hit]:
    best: Optional[Hit] = None

    def consider(h: Optional[Hit], kind: str, id_: str = "", normal_v: Optional[V] = None, relay: bool = False):
        nonlocal best
        if h is None or h.dist < 1e-6:
            return
        candidate = Hit(h.point, h.dist, kind, id_ or None, normal_v, relay)
        if best is None or candidate.dist < best.dist:
            best = candidate

    bounds = [
        (V(0, 0), V(ROOM_W, 0), "top"),
        (V(0, ROOM_H), V(ROOM_W, ROOM_H), "bottom"),
        (V(0, 0), V(0, ROOM_H), "left"),
        (V(ROOM_W, 0), V(ROOM_W, ROOM_H), "right"),
    ]
    for a, b, bid in bounds:
        h = ray_segment(origin, direction, a, b)
        consider(h, "bounds", bid)

    for obs in level.get("obstacles", []):
        if obs.get("isDecorative"):
            continue
        poly = [V(p[0], p[1]) for p in obs["polygon"]]
        for i in range(len(poly)):
            h = ray_segment(origin, direction, poly[i], poly[(i + 1) % len(poly)])
            consider(h, "wall", obs["id"])

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


def trace_beam(level: dict, origin: V, direction: V, angles: Dict[str, float]) -> Tuple[Set[str], int]:
    lit: Set[str] = set()
    mirror_hits = 0
    pos, d = origin, direction.normalized()
    for _ in range(MAX_BOUNCES):
        hit = nearest_hit(level, pos, d, angles)
        if hit is None:
            return lit, mirror_hits
        if hit.kind == "crystal":
            lit.add(hit.id)
            if hit.relay:
                pos = hit.point + d * 0.5
                continue
            return lit, mirror_hits
        if hit.kind in ("wall", "bounds"):
            return lit, mirror_hits
        if hit.kind == "mirror":
            mirror_hits += 1
            reflected = reflect(d, hit.normal)
            pos = hit.point + reflected * 0.5
            d = reflected.normalized()
            continue
        return lit, mirror_hits
    return lit, mirror_hits


def simulate_level(level: dict, angles: Dict[str, float]) -> Tuple[Set[str], int]:
    lit: Set[str] = set()
    total_hits = 0
    for ls in level["lightSources"]:
        tip = mounted_origin(ls["position"], ls["direction"])
        l, h = trace_beam(level, tip, dir_deg(ls["direction"]), angles)
        lit |= l
        total_hits += h
    return lit, total_hits


def validate_level(level: dict) -> bool:
    solution = level["intendedSolution"]["mirrorAngles"]
    mirrors = level["mirrors"]
    angles = {m["id"]: m["initialAngle"] for m in mirrors}
    angles.update({k: float(v) for k, v in solution.items()})

    lit, hits = simulate_level(level, angles)
    if "c1" not in lit:
        return False

    for grp in level["crystalGroups"]:
        gid = grp["groupId"]
        need = grp["requiredCount"]
        members = [c["id"] for c in level["targetCrystals"] if c["groupId"] == gid]
        if sum(1 for m in members if m in lit) < need:
            return False

    required = level.get("requiredMirrorBounces")
    mirror_count = len(mirrors)
    if required is not None and hits != required:
        return False
    if hits != mirror_count:
        return False

    initial = {m["id"]: m["initialAngle"] for m in mirrors}
    lit0, hits0 = simulate_level(level, initial)
    win0 = "c1" in lit0
    for grp in level["crystalGroups"]:
        gid = grp["groupId"]
        need = grp["requiredCount"]
        members = [c["id"] for c in level["targetCrystals"] if c["groupId"] == gid]
        if sum(1 for m in members if m in lit0) < need:
            win0 = False
    if win0:
        return False

    return True


# ---------------------------------------------------------------------------
# Level building helpers
# ---------------------------------------------------------------------------


def cell_wall(wid: str, col: int, row: int, decorative: bool = False) -> dict:
    cw = ROOM_W / GRID_COLS
    ch = ROOM_H / GRID_ROWS
    x, y = col * cw, row * ch
    return {
        "id": wid,
        "polygon": [[x, y], [x + cw, y], [x + cw, y + ch], [x, y + ch]],
        "isDecorative": decorative,
    }


def make_mirror(
    mid: str,
    hinge: V,
    length: float,
    initial: float,
    solution: float,
    locked: bool = False,
    min_a: float = 5,
    max_a: float = 175,
    snap: float = 0,
) -> dict:
    return {
        "id": mid,
        "hingePosition": [hinge.x, hinge.y],
        "length": length,
        "initialAngle": max(min_a, min(max_a, initial)),
        "minAngle": min_a,
        "maxAngle": max_a,
        "snapIncrement": snap,
        "isLocked": locked,
        "type": "locked" if locked else "standard",
    }


def make_light(lid: str, pos: V, direction: float) -> dict:
    return {"id": lid, "position": [pos.x, pos.y], "direction": direction, "locked": True}


ROOM_TEMPLATES = [
    {"name": "west_hall", "light_col": 0, "light_row": 4, "light_dir": 0},
    {"name": "east_hall", "light_col": 9, "light_row": 5, "light_dir": 180},
    {"name": "ceiling_port", "light_col": 5, "light_row": 0, "light_dir": 90},
    {"name": "floor_sconce", "light_col": 4, "light_row": 9, "light_dir": 270},
    {"name": "north_wing", "light_col": 2, "light_row": 1, "light_dir": 0},
    {"name": "south_atrium", "light_col": 7, "light_row": 8, "light_dir": 270},
    {"name": "corner_keep", "light_col": 1, "light_row": 2, "light_dir": 90},
    {"name": "vault_entry", "light_col": 8, "light_row": 3, "light_dir": 180},
]


@dataclass
class DifficultySpec:
    mirror_count: int
    wall_count: int
    relay_count: int
    locked_count: int
    snap_tight: bool
    room_variant: int
    min_score: float


def difficulty_for_index(index: int) -> DifficultySpec:
    """Mirror count: every 5 levels +2 (1-5:2, 6-10:4, 11-15:6, ...).

    Capped at 10 mirrors (10x10 grid / beam solver limit). After the cap,
    walls / relays / locked / snap keep rising so difficulty still grows.
    """
    band = (index - 1) // 5  # 0 for 1-5, 1 for 6-10, 2 for 11-15, ...
    mirrors = min(2 * (band + 1), 10)

    walls = min(2 + band + index // 20, 28)
    if mirrors <= 4:
        relays, locked, snap = 0, 0, False
    elif mirrors <= 6:
        relays, locked, snap = (1 if index > 20 else 0), 0, index > 25
    elif mirrors <= 8:
        relays, locked, snap = 1, (1 if index > 40 else 0), True
    else:
        relays = min(2, 1 + (index > 60))
        locked = min(2, mirrors - 1)
        snap = True

    # After mirror cap, keep stacking walls/relays for hardness
    if band >= 4:  # index >= 21 (mirrors already at 10)
        walls = min(28, walls + (band - 3))
        relays = min(2, relays + (1 if band >= 6 else 0))
        locked = min(mirrors - 1, max(locked, 1 + band // 8))
        snap = True

    score = (
        mirrors * 12
        + walls * 1.8
        + relays * 14
        + locked * 18
        + (8 if snap else 0)
        + index * 0.01
    )
    return DifficultySpec(
        mirror_count=mirrors,
        wall_count=min(walls, 30),
        relay_count=relays,
        locked_count=min(locked, max(0, mirrors - 1)),
        snap_tight=snap,
        room_variant=index % len(ROOM_TEMPLATES),
        min_score=score,
    )


def level_fingerprint(level: dict) -> str:
    mirrors = sorted(
        (
            round(m["hingePosition"][0]),
            round(m["hingePosition"][1]),
            m.get("type", "standard"),
        )
        for m in level["mirrors"]
    )
    walls = sorted(
        tuple(round(c) for c in p)
        for o in level["obstacles"]
        if not o.get("isDecorative")
        for p in o["polygon"][:1]
    )
    ls = level["lightSources"][0]
    crystal = next(c for c in level["targetCrystals"] if not c.get("relay"))
    payload = json.dumps(
        {
            "mirrors": mirrors,
            "walls": walls,
            "light": [round(ls["position"][0]), round(ls["position"][1]), ls["direction"]],
            "crystal": [round(crystal["position"][0]), round(crystal["position"][1])],
        },
        sort_keys=True,
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def difficulty_score(level: dict) -> float:
    mirrors = len(level["mirrors"])
    walls = sum(1 for o in level["obstacles"] if not o.get("isDecorative"))
    relays = sum(1 for c in level["targetCrystals"] if c.get("relay"))
    locked = sum(1 for m in level["mirrors"] if m.get("isLocked"))
    snap = any(m.get("snapIncrement", 0) > 0 for m in level["mirrors"])
    tight = any(m["maxAngle"] - m["minAngle"] < 30 for m in level["mirrors"])
    gidx = level.get("metadata", {}).get("globalIndex", 0)
    complexity = (
        mirrors * 12
        + walls * 1.8
        + relays * 14
        + locked * 18
        + (8 if snap else 0)
        + (6 if tight else 0)
    )
    # Global index dominates so difficulty is strictly monotonic across the pack.
    return gidx * 1000.0 + complexity


def random_mirror_path(rng: random.Random, count: int, template: dict) -> Optional[List[Tuple[int, int]]]:
    """Build a monotonic path of grid cells for mirror placement (with backtracking)."""
    lc, lr = template["light_col"], template["light_row"]
    direction = template["light_dir"]

    if direction == 0:
        starts = [(min(lc + 1, GRID_COLS - 2), lr)]
        preferred = [(1, 0), (0, 1), (0, -1), (-1, 0)]
    elif direction == 180:
        starts = [(max(lc - 1, 1), lr)]
        preferred = [(-1, 0), (0, 1), (0, -1), (1, 0)]
    elif direction == 90:
        starts = [(lc, min(lr + 1, GRID_ROWS - 2))]
        preferred = [(0, 1), (1, 0), (-1, 0), (0, -1)]
    else:
        starts = [(lc, max(lr - 1, 1))]
        preferred = [(0, -1), (1, 0), (-1, 0), (0, 1)]

    rng.shuffle(starts)

    def dfs(path: List[Tuple[int, int]]) -> Optional[List[Tuple[int, int]]]:
        if len(path) == count:
            return path[:]
        col, row = path[-1]
        moves = preferred[:]
        rng.shuffle(moves)
        for dc, dr in moves:
            nc, nr = col + dc, row + dr
            if 1 <= nc <= GRID_COLS - 2 and 1 <= nr <= GRID_ROWS - 2 and (nc, nr) not in path:
                path.append((nc, nr))
                result = dfs(path)
                if result:
                    return result
                path.pop()
        return None

    for start in starts:
        found = dfs([start])
        if found:
            return found

    # Fallback: greedy random walk with many restarts
    for _ in range(40):
        path = [starts[rng.randrange(len(starts))]]
        col, row = path[0]
        dc, dr = preferred[0]
        stuck = 0
        while len(path) < count and stuck < 20:
            options = []
            for ndc, ndr in preferred + [(dr, dc), (-dr, dc), (dc, -dr)]:
                nc, nr = col + ndc, row + ndr
                if 1 <= nc <= GRID_COLS - 2 and 1 <= nr <= GRID_ROWS - 2 and (nc, nr) not in path:
                    options.append((nc, nr, ndc, ndr))
            if not options:
                stuck += 1
                continue
            nc, nr, dc, dr = rng.choice(options)
            path.append((nc, nr))
            col, row = nc, nr
            stuck = 0
        if len(path) >= count:
            return path[:count]
    return None


def pick_crystal(rng: random.Random, last_mirror: Tuple[int, int], incoming_dir: V) -> Tuple[int, int]:
    lc, lr = last_mirror
    candidates = []
    for dc in range(-2, 3):
        for dr in range(-2, 3):
            if dc == 0 and dr == 0:
                continue
            nc, nr = lc + dc, lr + dr
            if 1 <= nc <= GRID_COLS - 2 and 1 <= nr <= GRID_ROWS - 2:
                candidates.append((nc, nr))
    if not candidates:
        return (min(GRID_COLS - 2, lc + 2), lr)
    return rng.choice(candidates)


def cells_along_ray(origin: V, direction: V, max_dist: float = 5000) -> Set[Tuple[int, int]]:
    cells: Set[Tuple[int, int]] = set()
    step = 40.0
    dist = 0.0
    while dist < max_dist:
        p = origin + direction * dist
        if not (0 <= p.x <= ROOM_W and 0 <= p.y <= ROOM_H):
            break
        col = int(p.x / (ROOM_W / GRID_COLS))
        row = int(p.y / (ROOM_H / GRID_ROWS))
        col = max(0, min(GRID_COLS - 1, col))
        row = max(0, min(GRID_ROWS - 1, row))
        cells.add((col, row))
        dist += step
    return cells


def solution_corridor_cells(level: dict, solution_angles: Dict[str, float]) -> Set[Tuple[int, int]]:
    cells: Set[Tuple[int, int]] = set()
    for ls in level["lightSources"]:
        tip = mounted_origin(ls["position"], ls["direction"])
        d = dir_deg(ls["direction"])
        pos = tip
        for _ in range(MAX_BOUNCES):
            hit = nearest_hit(level, pos, d, solution_angles)
            if hit is None:
                break
            cells |= cells_along_ray(pos, d, hit.dist + 20)
            if hit.kind == "crystal":
                break
            if hit.kind in ("wall", "bounds"):
                break
            if hit.kind == "mirror":
                d = reflect(d, hit.normal).normalized()
                pos = hit.point + d * 0.5
                continue
            break
    return cells


def protected_cells(
    path: List[Tuple[int, int]],
    crystal: Tuple[int, int],
    template: dict,
    relay_cells: List[Tuple[int, int]],
) -> Set[Tuple[int, int]]:
    protected = set(path)
    protected.add(crystal)
    protected.add((template["light_col"], template["light_row"]))
    for c in relay_cells:
        protected.add(c)
    for i in range(len(path) - 1):
        a, b = path[i], path[i + 1]
        protected.add(a)
        protected.add(b)
        mc, mr = (a[0] + b[0]) // 2, (a[1] + b[1]) // 2
        protected.add((mc, mr))
    return protected


def build_level(global_index: int, spec: DifficultySpec, rng: random.Random) -> Optional[dict]:
    template = ROOM_TEMPLATES[spec.room_variant]
    path = random_mirror_path(rng, spec.mirror_count, template)
    if path is None or len(path) < spec.mirror_count:
        return None

    hinges = [grid_pos(c, r) for c, r in path]
    incoming = dir_deg(template["light_dir"])
    crystal_cell = pick_crystal(rng, path[-1], incoming)
    crystal = grid_pos(*crystal_cell)

    relay_cells: List[Tuple[int, int]] = []
    if spec.relay_count > 0:
        mid = max(1, len(path) // 2)
        for i in range(spec.relay_count):
            idx = min(len(path) - 1, mid + i)
            relay_cells.append(path[idx])

    angles = solve_chain(hinges, incoming, crystal)
    if angles is None:
        return None

    locked_ids = set()
    if spec.locked_count > 0:
        for i in range(spec.locked_count):
            locked_ids.add(f"m{i + 1}")

    mirrors = []
    solution = {}
    for i, (hinge, ang) in enumerate(zip(hinges, angles)):
        mid = f"m{i + 1}"
        locked = mid in locked_ids
        initial = ang - rng.uniform(12, 28)
        if spec.snap_tight and not locked:
            min_a, max_a, snap = max(5, ang - 15), min(175, ang + 15), 5.0
        elif spec.snap_tight:
            min_a, max_a, snap = 5, 175, 5.0
        else:
            min_a, max_a, snap = 5, 175, 0.0
        mirrors.append(
            make_mirror(mid, hinge, 145, initial, ang, locked=locked, min_a=min_a, max_a=max_a, snap=snap)
        )
        solution[mid] = round(ang, 2)

    protected = protected_cells(path, crystal_cell, template, relay_cells)

    light_pos = grid_pos(template["light_col"], template["light_row"])
    if template["light_dir"] == 0:
        light_pos = V(160, light_pos.y)
    elif template["light_dir"] == 180:
        light_pos = V(ROOM_W - 160, light_pos.y)
    elif template["light_dir"] == 90:
        light_pos = V(light_pos.x, 160)
    else:
        light_pos = V(light_pos.x, ROOM_H - 160)

    draft_mirrors = []
    draft_solution = {}
    for i, (hinge, ang) in enumerate(zip(hinges, angles)):
        mid = f"m{i + 1}"
        draft_mirrors.append(make_mirror(mid, hinge, 145, ang - 20, ang))
        draft_solution[mid] = ang

    draft_obstacles: List[dict] = []
    draft = {
        "mirrors": draft_mirrors,
        "obstacles": draft_obstacles,
        "lightSources": [make_light("ls1", light_pos, template["light_dir"])],
        "targetCrystals": [{"id": "c1", "position": [crystal.x, crystal.y], "hitRadius": 44, "groupId": "g1"}],
    }
    corridor = solution_corridor_cells(draft, draft_solution)
    protected |= corridor

    wall_pool = [
        (c, r)
        for c in range(GRID_COLS)
        for r in range(GRID_ROWS)
        if (c, r) not in protected
        and not (c == template["light_col"] and r == template["light_row"])
    ]
    rng.shuffle(wall_pool)
    max_walls = max(2, len(wall_pool) - 2)
    wall_cells = wall_pool[: min(spec.wall_count, max_walls)]

    obstacles = [cell_wall(f"w{i}", c, r) for i, (c, r) in enumerate(wall_cells)]
    if global_index % 7 == 0 and len(wall_pool) > spec.wall_count:
        extra = wall_pool[spec.wall_count]
        obstacles.append(cell_wall("decor0", extra[0], extra[1], decorative=True))

    crystals = []
    groups = []
    if relay_cells:
        for i, rc in enumerate(relay_cells):
            rid = f"relay{i}"
            rp = grid_pos(*rc)
            crystals.append(
                {
                    "id": rid,
                    "position": [rp.x, rp.y],
                    "hitRadius": 38,
                    "groupId": "relay",
                    "relay": True,
                    "label": "Relay",
                }
            )
        groups.append({"groupId": "relay", "requiredCount": len(relay_cells)})

    crystals.append(
        {"id": "c1", "position": [crystal.x, crystal.y], "hitRadius": 44, "groupId": "g1"}
    )
    groups.append({"groupId": "g1", "requiredCount": 1})

    chapter_num = (global_index - 1) // 50 + 1
    chapter_id = f"ch{chapter_num}"
    level_in_chapter = (global_index - 1) % 50 + 1
    level_id = f"{chapter_id}_{level_in_chapter:03d}"

    room_names = [
        "Hall",
        "Chamber",
        "Vault",
        "Gallery",
        "Atrium",
        "Crypt",
        "Tower",
        "Sanctum",
        "Bastion",
        "Cloister",
    ]
    title = f"{room_names[global_index % len(room_names)]} {global_index}"

    concepts = ["reflection"]
    if spec.mirror_count >= 3:
        concepts.append("multi_mirror")
    if spec.wall_count >= 8:
        concepts.append("wall_maze")
    if spec.relay_count:
        concepts.append("relay")
    if spec.locked_count:
        concepts.append("locked_mirror")
    if spec.snap_tight:
        concepts.append("angle_limits")

    level = {
        "levelId": level_id,
        "chapterId": chapter_id,
        "schemaVersion": 1,
        "levelIndex": level_in_chapter,
        "title": title,
        "roomBounds": {"width": ROOM_W, "height": ROOM_H},
        "lightSources": [make_light("ls1", light_pos, template["light_dir"])],
        "mirrors": mirrors,
        "obstacles": obstacles,
        "targetCrystals": crystals,
        "crystalGroups": groups,
        "doorPortals": [],
        "requiredMirrorBounces": len(mirrors),
        "intendedSolution": {"mirrorAngles": solution, "toleranceDegrees": 5.0},
        "starThresholds": {
            "threeStarMoveCount": min(12, 2 + spec.mirror_count + spec.relay_count),
            "threeStarTimeSeconds": min(240, 35 + spec.mirror_count * 12 + spec.wall_count * 2),
        },
        "metadata": {
            "designer": "procedural_v1",
            "difficultyBand": chapter_id,
            "newConceptsIntroduced": concepts,
            "objective": f"Route the beam through all {len(mirrors)} mirrors to light the crystal.",
            "hints": [
                "Every mirror must reflect the beam — shortcuts will not count.",
                f"This {template['name'].replace('_', ' ')} has {len(obstacles)} stone barriers.",
                "Adjust each mirror until the full chain reaches the crystal.",
            ],
            "roomType": template["name"],
            "globalIndex": global_index,
        },
    }
    level["metadata"]["difficultyScore"] = round(difficulty_score(level), 2)
    return level


def generate_level(
    global_index: int,
    spec: DifficultySpec,
    seen: Set[str],
    prev_score: float,
    max_attempts: int = 400,
) -> Tuple[Optional[dict], float]:
    attempts = max(max_attempts, 200 + spec.mirror_count * 80)
    for attempt in range(attempts):
        rng = random.Random(global_index * 100_003 + attempt * 7919)
        level = build_level(global_index, spec, rng)
        if level is None:
            continue
        if not validate_level(level):
            continue
        fp = level_fingerprint(level)
        if fp in seen:
            continue
        score = difficulty_score(level)
        if score <= prev_score:
            continue
        if score < spec.min_score * 0.75:
            continue
        seen.add(fp)
        return level, score
    return None, prev_score


def chapter_title(ch: int) -> str:
    names = [
        "Stone Gate",
        "Iron Keep",
        "Crystal Caves",
        "Shadow Vault",
        "Golden Spire",
        "Obsidian Hall",
        "Emerald Wing",
        "Sapphire Depths",
        "Ruby Bastion",
        "Diamond Crown",
        "Ancient Ruins",
        "Frozen Citadel",
        "Molten Forge",
        "Whisper Gallery",
        "Thunder Atrium",
        "Silent Crypt",
        "Radiant Tower",
        "Twilight Sanctum",
        "Solar Bastion",
        "Lunar Cloister",
    ]
    return names[(ch - 1) % len(names)]


def print_progress(done: int, total: int, start: float) -> None:
    pct = (done / total) * 100
    elapsed = time.time() - start
    rate = done / elapsed if elapsed > 0 else 0
    eta = (total - done) / rate if rate > 0 else 0
    bar_len = 40
    filled = int(bar_len * done / total)
    bar = "#" * filled + "-" * (bar_len - filled)
    sys.stdout.write(
        f"\r[{bar}] {pct:5.1f}%  {done}/{total} levels  "
        f"elapsed {elapsed:,.0f}s  ETA {eta:,.0f}s   "
    )
    sys.stdout.flush()


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Mirror Logic levels")
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT, help="Number of levels")
    parser.add_argument("--output", type=str, default=DEFAULT_OUTPUT, help="Output JSON path")
    parser.add_argument("--seed", type=int, default=42, help="Base RNG seed")
    args = parser.parse_args()

    random.seed(args.seed)
    total = args.count
    levels: List[dict] = []
    seen: Set[str] = set()
    prev_score = 0.0
    start = time.time()
    failures = 0

    print(f"Generating {total} levels -> {args.output}")
    print_progress(0, total, start)

    for i in range(1, total + 1):
        spec = difficulty_for_index(i)
        level, prev_score = generate_level(i, spec, seen, prev_score)
        if level is None:
            failures += 1
            # Never drop below the intended mirror band — only ease walls / extras.
            relaxed = DifficultySpec(
                mirror_count=spec.mirror_count,
                wall_count=max(2, spec.wall_count - 2 - failures),
                relay_count=max(0, spec.relay_count - 1),
                locked_count=max(0, spec.locked_count - 1),
                snap_tight=spec.snap_tight and failures < 2,
                room_variant=(spec.room_variant + failures) % len(ROOM_TEMPLATES),
                min_score=prev_score + 0.5,
            )
            level, prev_score = generate_level(
                i, relaxed, seen, prev_score, max_attempts=1200 + failures * 200
            )
            # Last resort: drop mirrors only if still impossible (pathfinder limit)
            if level is None and spec.mirror_count > 2:
                emergency = DifficultySpec(
                    mirror_count=max(2, spec.mirror_count - 2),
                    wall_count=max(2, spec.wall_count // 2),
                    relay_count=0,
                    locked_count=0,
                    snap_tight=False,
                    room_variant=(spec.room_variant + failures + 3) % len(ROOM_TEMPLATES),
                    min_score=prev_score + 0.5,
                )
                level, prev_score = generate_level(
                    i, emergency, seen, prev_score, max_attempts=1500
                )
        if level is None:
            print(f"\nFATAL: could not generate level {i}", file=sys.stderr)
            return 1
        levels.append(level)
        if i % 5 == 0 or i == total:
            print_progress(i, total, start)

    elapsed = time.time() - start
    print(f"\nDone in {elapsed:.1f}s — {len(levels)} levels, {failures} relaxed, {len(seen)} unique fingerprints")

    root = {"schemaVersion": 1, "levels": levels}
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(root, f, indent=2)

    print(f"Wrote {args.output} ({len(levels)} levels)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
