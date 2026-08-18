#!/usr/bin/env python3
"""Harden exactly one Mirror Logic level. Sequential. Unique family+light+path."""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))
from generate_levels_extreme import (  # noqa: E402
    V, simulate, validate, solve_angle, wall_h, wall_v, filter_clear,
)

XS = [220.0, 600.0, 980.0]
YS = [90.0, 440.0, 790.0, 1140.0, 1490.0, 1840.0]


def set_lattice(chapter: str, idx: int):
    global XS, YS
    cn = int(str(chapter).replace("ch", "") or 1)
    dx = (cn - 1) * 16 + (idx % 4) * 6
    dy = ((cn - 1) % 3) * 10 + (idx % 3) * 8
    xs = [220.0 + dx, 600.0 + dx, 980.0 + dx]
    if xs[-1] > 970:
        s = xs[-1] - 970
        xs = [x - s for x in xs]
    if xs[0] < 190:
        s = 190 - xs[0]
        xs = [x + s for x in xs]
    ys = [90.0 + dy, 440.0 + dy, 790.0 + dy, 1140.0 + dy, 1490.0 + dy, 1840.0 + dy]
    if ys[-1] > 1860:
        s = ys[-1] - 1860
        ys = [y - s for y in ys]
    if ys[0] < 80:
        s = 80 - ys[0]
        ys = [y + s for y in ys]
    XS, YS = xs, ys
    return xs, ys
KEEP, OFFSET, INSET = 165.0, 160.0, 110.0
ROOM = (16.0, 16.0, 1064.0, 1904.0)
MIN_GAP = 350.0
MEM = ROOT / ".cursor/level_core_memory.json"

FAMILIES = [
    "phantom_grid", "vertical_switchback", "woven_lattice", "matrix_spiral",
    "hourglass_helix", "split_yoke", "nested_frames", "funnel_drop",
    "island_hop", "ridge_climb", "orbit_ring", "mirror_cathedral",
    "zigzag_basin", "double_loop", "cross_weave", "spiral_helix",
    "switchback_delta", "ladder_ascent", "cascade_chamber", "prism_fan",
    "pillar_maze", "serpentine_ridge", "corridor_gauntlet", "diagonal_stair",
]

TITLE_HINTS = [
    ("gallery", "pillar_maze"), ("maze", "pillar_maze"),
    ("vault", "funnel_drop"), ("funnel", "funnel_drop"),
    ("wing", "hourglass_helix"), ("hourglass", "hourglass_helix"),
    ("keep", "cascade_chamber"), ("passage", "cascade_chamber"),
    ("hall", "nested_frames"), ("frame", "nested_frames"),
    ("stair", "diagonal_stair"), ("switch", "switchback_delta"),
    ("bounce", "zigzag_basin"), ("zigzag", "zigzag_basin"),
    ("loop", "double_loop"), ("orbit", "orbit_ring"), ("ring", "orbit_ring"),
    ("ridge", "serpentine_ridge"), ("serpent", "serpentine_ridge"),
    ("gauntlet", "corridor_gauntlet"), ("cloister", "corridor_gauntlet"),
    ("prism", "prism_fan"), ("fan", "prism_fan"),
    ("cathedral", "mirror_cathedral"), ("nave", "mirror_cathedral"),
    ("island", "island_hop"), ("alcove", "island_hop"),
    ("ladder", "ladder_ascent"), ("helix", "spiral_helix"),
    ("spiral", "spiral_helix"), ("yoke", "split_yoke"),
    ("weave", "cross_weave"), ("braid", "cross_weave"),
    ("climb", "ridge_climb"), ("delta", "switchback_delta"),
    ("matrix", "matrix_spiral"), ("woven", "woven_lattice"),
    ("phantom", "phantom_grid"), ("nexus", "vertical_switchback"),
]

SLUG_TITLES = {
    "pillar_maze": "Gallery Path",
    "funnel_drop": "Vault Bend",
    "hourglass_helix": "Wing Route",
    "cascade_chamber": "Keep Passage",
    "nested_frames": "Hall Reflection",
    "diagonal_stair": "Spiral Keep",
    "switchback_delta": "Iron Switchback",
    "zigzag_basin": "Stone Bounce",
    "double_loop": "Twin Loop",
    "orbit_ring": "Orbit Ring",
    "serpentine_ridge": "Serpentine Ridge",
    "corridor_gauntlet": "Cloister Gauntlet",
    "prism_fan": "Prism Fan",
    "mirror_cathedral": "Mirror Cathedral",
    "island_hop": "Island Hop",
    "ladder_ascent": "Ladder Ascent",
    "spiral_helix": "Spiral Helix",
    "split_yoke": "Split Yoke",
    "cross_weave": "Cross Weave",
    "ridge_climb": "Ridge Climb",
    "matrix_spiral": "Matrix Spiral",
    "woven_lattice": "Woven Lattice",
    "phantom_grid": "Phantom Grid",
    "vertical_switchback": "Nexus Switch",
}


def turn90(inc: V, chir: str) -> V:
    return V(-inc.y, inc.x) if chir == "L" else V(inc.y, -inc.x)


def gap_ok(a: V, b: V) -> bool:
    return math.hypot(a.x - b.x, a.y - b.y) >= MIN_GAP - 1.0


def ray_targets(cur, d, occupied):
    out = []
    if abs(d.x) > 0.5:
        xs = sorted([x for x in XS if (x - cur.x) * d.x > 1.0], key=lambda x: (x - cur.x) * d.x)
        for x in xs:
            if (x, cur.y) in occupied:
                break
            out.append(V(x, cur.y))
    else:
        ys = sorted([y for y in YS if (y - cur.y) * d.y > 1.0], key=lambda y: (y - cur.y) * d.y)
        for y in ys:
            if (cur.x, y) in occupied:
                break
            out.append(V(cur.x, y))
    return out


def collect_paths(n, first, first_inc, first_turn, limit=80):
    occupied = {(first.x, first.y)}
    path, chirs, found = [first], [], []

    def rec(cur, inc):
        if len(found) >= limit:
            return
        if len(path) == n:
            found.append((list(path), list(chirs), inc))
            return
        last = chirs[-1] if chirs else first_turn
        for chir in ("R" if last == "L" else "L", last):
            d = turn90(inc, chir)
            for nxt in ray_targets(cur, d, occupied):
                if not gap_ok(cur, nxt):
                    continue
                key = (nxt.x, nxt.y)
                occupied.add(key)
                path.append(nxt)
                chirs.append(chir)
                rec(nxt, d)
                path.pop()
                chirs.pop()
                occupied.discard(key)
                if len(found) >= limit:
                    return

    d0 = turn90(first_inc, first_turn)
    for nxt in ray_targets(first, d0, occupied):
        if not gap_ok(first, nxt):
            continue
        occupied.add((nxt.x, nxt.y))
        path.append(nxt)
        chirs.append(first_turn)
        rec(nxt, d0)
        path.pop()
        chirs.pop()
        occupied.discard((nxt.x, nxt.y))
        if len(found) >= limit:
            break
    return found


def collinear_between(a, b, pts, skip=()):
    for i, p in enumerate(pts):
        if i in skip:
            continue
        if abs(a.x - b.x) < 1.0 and abs(p.x - a.x) < 1.0:
            if min(a.y, b.y) + 1 < p.y < max(a.y, b.y) - 1:
                return True
        if abs(a.y - b.y) < 1.0 and abs(p.y - a.y) < 1.0:
            if min(a.x, b.x) + 1 < p.x < max(a.x, b.x) - 1:
                return True
    return False


def path_clean(pts):
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        if collinear_between(a, b, pts, skip={i, i + 1}):
            return False
    return True


def on_corridor(c, pts, light, tol=50.0):
    nodes = [light] + pts
    for a, b in zip(nodes, nodes[1:]):
        if abs(a.x - b.x) < 1.0:
            if abs(c.x - a.x) < tol and min(a.y, b.y) + 20 < c.y < max(a.y, b.y) - 20:
                return True
        elif abs(a.y - b.y) < 1.0:
            if abs(c.y - a.y) < tol and min(a.x, b.x) + 20 < c.x < max(a.x, b.x) - 20:
                return True
    return False


def near_banned(c, banned, pad=28.0):
    for b in banned:
        if math.hypot(c.x - b[0], c.y - b[1]) < pad:
            return True
    return False


def crystal_slots(last, inc, occupied, pts, light, banned):
    out, seen = [], set()
    for chir in ("L", "R"):
        d = turn90(inc, chir)
        dist = 350.0
        while dist <= 820.0:
            c = V(last.x + d.x * dist, last.y + d.y * dist)
            dist += 40.0
            key = (round(c.x, 1), round(c.y, 1))
            if key in seen:
                continue
            if not (80 <= c.x <= 1000 and 80 <= c.y <= 1840):
                continue
            if (c.x, c.y) in occupied:
                continue
            if banned and near_banned(c, banned, pad=18.0):
                continue
            if not gap_ok(last, c) or on_corridor(c, pts, light):
                continue
            if collinear_between(last, c, pts, skip={len(pts) - 1}):
                continue
            if abs(c.y - pts[0].y) < 55 and abs(c.x - pts[0].x) >= 1:
                if (pts[0].x >= 900 and c.x >= 880) or (pts[0].x <= 280 and c.x <= 300):
                    continue
            if abs(c.x - pts[0].x) < 55 and abs(c.y - pts[0].y) >= 1:
                if (pts[0].y <= 120 and c.y <= 180) or (pts[0].y >= 1700 and c.y >= 1700):
                    continue
            seen.add(key)
            out.append(c)
    return out


def axis_revs(vals):
    deltas = [b - a for a, b in zip(vals, vals[1:]) if abs(b - a) > 1.0]
    n = 0
    for d0, d1 in zip(deltas, deltas[1:]):
        if (d0 > 0) != (d1 > 0):
            n += 1
    return n


def family_score(pts, chirs, family, idx):
    xr = axis_revs([p.x for p in pts])
    yr = axis_revs([p.y for p in pts])
    xs = {p.x for p in pts}
    hops = sum(1 for a, b in zip(pts, pts[1:]) if abs(a.x - b.x) >= 700)
    both = XS[0] in xs and XS[-1] in xs
    mixed = len(set(chirs)) == 2
    rows = len({p.y for p in pts})
    if not both:
        return -10
    if family == "ladder_ascent":
        if yr > 1 or xr < 3:
            return -10
        return hops * 1.2 + xr * 0.8 + 0.3 * len(pts)
    if yr < 2 or xr < 2:
        return -10
    early_span = max(p.x for p in pts[:4]) - min(p.x for p in pts[:4])
    sc = hops * 1.1 + yr * 0.9 + xr * 0.7 + (0.8 if mixed else 0) + 0.15 * rows
    if family in ("funnel_drop", "hourglass_helix") and early_span >= 700:
        sc += 1.6
    if family in ("orbit_ring", "mirror_cathedral") and rows >= 5:
        sc += 1.2
    if family in ("zigzag_basin", "serpentine_ridge", "cross_weave") and xr >= 3:
        sc += 1.3
    if family in ("double_loop", "nested_frames") and yr >= 3:
        sc += 1.1
    # diversity spice from level index so neighboring levels prefer different folds
    sc += 0.07 * ((xr * 3 + yr * 5 + hops * 7 + idx) % 11)
    return sc


def fully_in_room(poly):
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    return min(xs) >= ROOM[0] and max(xs) <= ROOM[2] and min(ys) >= ROOM[1] and max(ys) <= ROOM[3]


def keepout(poly, hinges):
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    for h in hinges:
        qx, qy = min(max(h.x, minx), maxx), min(max(h.y, miny), maxy)
        if math.hypot(h.x - qx, h.y - qy) < KEEP:
            return False
    return True


def aabb_overlap(a, b, pad=40.0):
    ax, ay = [p[0] for p in a], [p[1] for p in a]
    bx, by = [p[0] for p in b], [p[1] for p in b]
    return not (
        max(ax) + pad < min(bx) or max(bx) + pad < min(ax)
        or max(ay) + pad < min(by) or max(by) + pad < min(ay)
    )


def try_keep(raw, w, hinges):
    if not fully_in_room(w["polygon"]) or not keepout(w["polygon"], hinges):
        return
    if any(aabb_overlap(w["polygon"], k["polygon"]) for k in raw):
        return
    raw.append(w)


def rail_for(a, b, sign):
    dx, dy = b.x - a.x, b.y - a.y
    dist = math.hypot(dx, dy)
    if dist < 280:
        return None
    ux, uy = dx / dist, dy / dist
    px, py = -uy * OFFSET * sign, ux * OFFSET * sign
    x0, y0 = a.x + ux * INSET + px, a.y + uy * INSET + py
    x1, y1 = b.x - ux * INSET + px, b.y - uy * INSET + py
    if abs(dx) >= abs(dy):
        return wall_h("w", *sorted((x0, x1)), (y0 + y1) / 2.0)
    return wall_v("w", (x0 + x1) / 2.0, *sorted((y0, y1)))


def build_rails(pts, crystal, light):
    hinges = list(pts) + [crystal]
    segs = [(light, pts[0])] + list(zip(pts, pts[1:])) + [(pts[-1], crystal)]
    raw = []
    for a, b in segs:
        for sign in (1.0, -1.0):
            w = rail_for(a, b, sign)
            if w is not None:
                try_keep(raw, w, hinges)
    nodes = list(pts) + [crystal]
    consec = set()
    for s, t in zip(nodes, nodes[1:]):
        consec.add(((s.x, s.y), (t.x, t.y)))
        consec.add(((t.x, t.y), (s.x, s.y)))
    lids = 0
    for i, a in enumerate(nodes):
        for b in nodes[i + 1 :]:
            if lids >= 2:
                break
            if ((a.x, a.y), (b.x, b.y)) in consec:
                continue
            if math.hypot(a.x - b.x, a.y - b.y) < 280:
                continue
            if abs(a.x - b.x) < 1.0:
                lo, hi = sorted((a.y, b.y))
                if any(abs(p.x - a.x) < 1.0 and lo + 1 < p.y < hi - 1 for p in pts):
                    continue
                before = len(raw)
                try_keep(raw, wall_h("w", a.x - 90.0, a.x + 90.0, (a.y + b.y) / 2.0), hinges)
                if len(raw) > before:
                    lids += 1
            elif abs(a.y - b.y) < 1.0:
                lo, hi = sorted((a.x, b.x))
                if any(abs(p.y - a.y) < 1.0 and lo + 1 < p.x < hi - 1 for p in pts):
                    continue
                before = len(raw)
                try_keep(raw, wall_v("w", (a.x + b.x) / 2.0, a.y - 90.0, a.y + 90.0), hinges)
                if len(raw) > before:
                    lids += 1
        if lids >= 2:
            break
    return [{**w, "id": f"w{i}"} for i, w in enumerate(raw)]


def unit(a, b):
    dx, dy = b.x - a.x, b.y - a.y
    mag = math.hypot(dx, dy)
    return V(dx / mag, dy / mag)


def light_setup(direction: float, first: V):
    """Place tip on the wall and fixture between tip and first hinge (~110px from first)."""
    gap = 110.0  # fixture sits ~100–120px from first toward tip
    if abs(direction - 180.0) < 1:
        tip = V(1028.0, first.y)
        return 180.0, (first.x + gap, first.y), tip, V(-1.0, 0.0), "east"
    if abs(direction - 0.0) < 1:
        tip = V(52.0, first.y)
        return 0.0, (first.x - gap, first.y), tip, V(1.0, 0.0), "west"
    if abs(direction - 90.0) < 1:
        tip = V(first.x, 52.0)
        return 90.0, (first.x, first.y - gap), tip, V(0.0, 1.0), "north"
    tip = V(first.x, 1868.0)
    return 270.0, (first.x, first.y + gap), tip, V(0.0, -1.0), "south"


def candidate_starts(side: str, recent):
    """Entry hinge never on outer lattice that makes tip→first < ~180."""
    global XS, YS
    recent_set = set(recent)
    if side == "east":
        # tip@1028; XS[-1]≈970 → ~58px (invisible). Prefer middle column XS[-2].
        opts = [(XS[-2], y) for y in YS]
    elif side == "west":
        # tip@52; need tip→m1 ≥ 180 → XS[0] ≥ 232. Shift the whole lattice
        # (do not bump only the start — that yields 252↔590 = 338 < MIN_GAP).
        need = 52.0 + 180.0
        if XS[0] < need:
            shift = need - XS[0]
            XS = [x + shift for x in XS]
        opts = [(XS[0], y) for y in YS]
    elif side == "north":
        # tip@52; YS[0]≈90 → ~38px. Prefer YS[1]/YS[2].
        opts = [(x, YS[1]) for x in XS] + [(x, YS[2]) for x in XS]
    else:
        # tip@1868; YS[-1]≈1840 → ~28px. Prefer YS[-2]/YS[-3].
        opts = [(x, YS[-2]) for x in XS] + [(x, YS[-3]) for x in XS]
    ranked = [p for p in opts if p not in recent_set] + [p for p in opts if p in recent_set]
    # unique preserve order
    seen, out = set(), []
    for p in ranked:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def scan_history(chapter: str, upto_index: int):
    starts, crystals, prefixes, paths = [], set(), set(), []
    ch_num = int(chapter.replace("ch", "") or 1)
    for cn in range(1, ch_num + 1):
        ch = f"ch{cn}"
        lo, hi = (16, 100) if cn == 1 else (1, 100)
        if cn == ch_num:
            hi = upto_index - 1
        for i in range(lo, hi + 1):
            p = ROOT / "assets/levels" / f"{ch}_{i:03d}.json"
            if not p.exists():
                continue
            lvl = json.loads(p.read_text())
            if not lvl.get("mirrors"):
                continue
            h0 = tuple(lvl["mirrors"][0]["hingePosition"])
            starts.append((float(h0[0]), float(h0[1])))
            c = tuple(lvl["targetCrystals"][0]["position"])
            crystals.add((round(float(c[0])), round(float(c[1]))))
            crystals.add((float(c[0]), float(c[1])))
            sig = tuple((float(m["hingePosition"][0]), float(m["hingePosition"][1])) for m in lvl["mirrors"])
            paths.append(sig)
            prefixes.add(sig[:5])
            prefixes.add(sig[-4:])
    return starts, crystals, prefixes, paths


def pick_family(side, used_pairs, title, idx):
    tl = title.lower()
    for kw, fam in TITLE_HINTS:
        if kw in tl and (fam, side) not in used_pairs:
            return fam
    unused = [f for f in FAMILIES if (f, side) not in used_pairs]
    if unused:
        return unused[(idx * 3) % len(unused)]
    # reuse least-recent family on a new start
    return FAMILIES[idx % len(FAMILIES)]


def pick_catalog(mem, family):
    for p in mem["patterns"]:
        if p.get("family") == family and p.get("status") == "available" and p.get("suggestedMirrors", 0) >= 11:
            return p
    for p in mem["patterns"]:
        if p.get("family") == family and p.get("status") == "available":
            return p
    for p in mem["patterns"]:
        if p.get("status") == "available" and p.get("suggestedMirrors", 0) >= 11:
            return p
    return None


def build_level(idx, chapter, title, slug, pts, crystal, walls, light_xy, light_dir, angles, family, pattern_id, side):
    decoys = (5.0, 92.0, 175.0, 45.0)
    mirrors = [{
        "id": f"m{i+1}",
        "hingePosition": [p.x, p.y],
        "length": 145.0,
        "initialAngle": decoys[i % 4],
        "minAngle": 5.0,
        "maxAngle": 175.0,
        "snapIncrement": 0.0,
        "isLocked": False,
        "type": "standard",
    } for i, p in enumerate(pts)]
    n = len(pts)
    return {
        "levelId": f"{chapter}_{idx:03d}_hard_{slug}",
        "chapterId": chapter,
        "schemaVersion": 1,
        "levelIndex": idx,
        "title": title,
        "roomBounds": {"width": 1080.0, "height": 1920.0},
        "lightSources": [{
            "id": "ls1",
            "position": [light_xy[0], light_xy[1]],
            "direction": light_dir,
            "locked": True,
        }],
        "mirrors": mirrors,
        "obstacles": walls,
        "targetCrystals": [{
            "id": "c1",
            "position": [crystal.x, crystal.y],
            "hitRadius": 44,
            "groupId": "g1",
        }],
        "crystalGroups": [{"groupId": "g1", "requiredCount": 1}],
        "doorPortals": [],
        "requiredMirrorBounces": n,
        "intendedSolution": {
            "mirrorAngles": {f"m{i+1}": ang for i, ang in enumerate(angles)},
            "toleranceDegrees": 4.91,
        },
        "starThresholds": {
            "threeStarMoveCount": n,
            "threeStarTimeSeconds": 140 + n * 4,
        },
        "metadata": {
            "designer": "canonical_v2",
            "difficultyBand": "ch1",
            "difficultyScore": float(idx),
            "hardness": 0.55 + (idx % 20) * 0.01,
            "newConceptsIntroduced": ["reflection", "multi_mirror", family],
            "objective": f"Thread the {title.lower()} — every post is required.",
            "hints": [
                "Rails fence the mid-spans so you cannot skip a corner.",
                "Wrong angles die in the walls.",
                "The crystal only opens from the last turn.",
            ],
            "roomType": "meander_corridor",
            "pathBias": family,
            "wallStyle": "mid_segment_rails",
            "globalIndex": idx,
            "patternId": pattern_id,
            "pillars": [],
        },
    }


def walls_ok(walls, pts, crystal):
    if not (7 <= len(walls) <= 20):
        return False
    hinges = list(pts) + [crystal]

    def aabb(p):
        xs, ys = [q[0] for q in p], [q[1] for q in p]
        return min(xs), min(ys), max(xs), max(ys)

    for i, a in enumerate(walls):
        A = aabb(a["polygon"])
        for b in walls[i + 1 :]:
            B = aabb(b["polygon"])
            if not (A[2] + 10 < B[0] or B[2] + 10 < A[0] or A[3] + 10 < B[1] or B[3] + 10 < A[1]):
                return False
        minx, miny, maxx, maxy = A
        if minx < ROOM[0] or miny < ROOM[1] or maxx > ROOM[2] or maxy > ROOM[3]:
            return False
        for h in hinges:
            qx, qy = min(max(h.x, minx), maxx), min(max(h.y, miny), maxy)
            if math.hypot(h.x - qx, h.y - qy) < KEEP:
                return False
    return True


def update_memory(mem, idx, chapter, family, pattern, side, title, notes):
    pid = pattern["patternId"] if pattern else f"{family}_{side}_{idx}"
    mem["used_patterns"].append({
        "patternId": pid,
        "family": family,
        "pathKind": (pattern or {}).get("pathKind", family),
        "wallStyle": "mid_segment_rails",
        "lightSide": side,
        "suggestedMirrors": (pattern or {}).get("suggestedMirrors", 12),
        "status": "used",
        "levelRef": f"{chapter}_{idx:03d}",
        "title": title,
        "notes": notes,
    })
    if pattern:
        for p in mem["patterns"]:
            if p.get("patternId") == pattern["patternId"]:
                p["status"] = "used"
                p["levelRef"] = f"{chapter}_{idx:03d}"
                break
        stats = mem.setdefault("stats", {})
        stats["usedCount"] = int(stats.get("usedCount", 0)) + 1
        stats["availableCount"] = int(stats.get("availableCount", 0)) - 1
        stats["lastAssigned"] = {"level": f"{chapter}_{idx:03d}", "patternId": pattern["patternId"]}
    mem["last_hardened"] = f"{chapter}_{idx:03d}"
    MEM.write_text(json.dumps(mem, indent=2) + "\n")


def harden(path: Path) -> None:
    raw = json.loads(path.read_text())
    idx = int(raw["levelIndex"])
    chapter = raw.get("chapterId", "ch1")
    orig_title = re.sub(r"\s+\d+$", "", raw.get("title", f"Level {idx}")).strip()
    ls = raw["lightSources"][0]
    direction = float(ls["direction"])
    set_lattice(chapter, idx)
    mem = json.loads(MEM.read_text())
    ref = f"{chapter}_{idx:03d}"
    removed = [u for u in mem.get("used_patterns", []) if u.get("levelRef") == ref]
    if removed:
        mem["used_patterns"] = [u for u in mem["used_patterns"] if u.get("levelRef") != ref]
        for p in mem.get("patterns", []):
            if p.get("levelRef") == ref:
                p["status"] = "available"
                p.pop("levelRef", None)
        stats = mem.setdefault("stats", {})
        stats["usedCount"] = max(0, int(stats.get("usedCount", 0)) - len(removed))
        stats["availableCount"] = int(stats.get("availableCount", 0)) + len(removed)
    used_pairs = {(u["family"], u["lightSide"]) for u in mem.get("used_patterns", [])}
    recent, banned, prefixes, prev_paths = scan_history(chapter, idx)
    prev_set = set(prev_paths)

    # infer side from original direction
    _, _, _, _, side0 = light_setup(direction, V(600, 90))
    family = pick_family(side0, used_pairs, orig_title, idx)
    catalog = pick_catalog(mem, family)
    title = orig_title if orig_title and not orig_title.lower().startswith("level") else SLUG_TITLES.get(family, orig_title)
    slug = re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")

    starts = candidate_starts(side0, recent)
    recent_set = set(recent)
    fresh = [p for p in starts if p not in recent_set]
    start_pool = fresh if fresh else starts[:6]

    def gather(loose: bool, emergency: bool = False):
        scored = []
        ns = (12, 13, 11, 10) if (loose or emergency) else (12, 13, 14, 11)
        for n in ns:
            for sx, sy in start_pool:
                first = V(sx, sy)
                light_dir, light_xy, light_m, first_inc, side = light_setup(direction, first)
                for ft in ("L", "R"):
                    for pts, chirs, last_inc in collect_paths(n, first, first_inc, ft, limit=80 if emergency else 110 if loose else 90):
                        if not path_clean(pts):
                            continue
                        sig = tuple((p.x, p.y) for p in pts)
                        if sig in prev_set:
                            continue
                        if not loose and not emergency and (sig[:5] in prefixes or sig[-4:] in prefixes):
                            continue
                        sc = family_score(pts, chirs, family, idx)
                        if sc < 0 and not loose and not emergency:
                            continue
                        xs = {p.x for p in pts}
                        if loose and not emergency and not (XS[0] in xs and XS[-1] in xs):
                            continue
                        ban = set() if emergency else banned
                        crystals = crystal_slots(pts[-1], last_inc, {(p.x, p.y) for p in pts}, pts, light_m, ban)
                        if not crystals:
                            continue
                        scored.append((sc, n, ft, pts, chirs, crystals, light_dir, light_xy, light_m, first_inc, side))
        scored.sort(key=lambda t: (0 if t[1] == 12 else 1 if t[1] == 13 else 2 if t[1] == 14 else 3, -t[0]))
        seen, uniq = set(), []
        for item in scored:
            sig = tuple((p.x, p.y) for p in item[3])
            if sig in seen:
                continue
            seen.add(sig)
            uniq.append(item)
        return uniq

    def commit(uniq, tag):
        print(f"{chapter}_{idx:03d} {tag} family={family} side={side0} unique={len(uniq)} catalog={(catalog or {}).get('patternId')}")
        if uniq:
            sc, n, ft, pts, chirs, *_ = uniq[0]
            print(
                f"  top sc={sc:.2f} n={n} start=({pts[0].x:.0f},{pts[0].y:.0f}) "
                f"xr={axis_revs([p.x for p in pts])} yr={axis_revs([p.y for p in pts])} ch={''.join(chirs)}"
            )
        tried = 0
        pid = (catalog or {}).get("patternId", f"{family}_{side0}_{idx}")
        for sc, n, ft, pts, chirs, crystals, light_dir, light_xy, light_m, first_inc, side in uniq:
            dirs0 = [first_inc]
            for a, b in zip(pts, pts[1:]):
                dirs0.append(unit(a, b))
            for c in crystals:
                dirs = dirs0 + [unit(pts[-1], c)]
                angles, ok_ang = [], True
                for i in range(len(pts)):
                    ang = solve_angle(dirs[i], dirs[i + 1])
                    if ang is None:
                        ok_ang = False
                        break
                    angles.append(ang)
                if not ok_ang:
                    continue
                probe = build_level(idx, chapter, title, slug, pts, c, [], light_xy, light_dir, angles, family, pid, side)
                sol = {f"m{i+1}": a for i, a in enumerate(angles)}
                lit0, hits0 = simulate(probe, sol)
                if "c1" not in lit0 or hits0 != n:
                    continue
                walls = filter_clear(build_rails(pts, c, light_m), [light_m] + pts + [c])
                if len(walls) < 5:
                    continue
                level = build_level(idx, chapter, title, slug, pts, c, walls, light_xy, light_dir, angles, family, pid, side)
                lit, hits = simulate(level, sol)
                ok = validate(level)
                tried += 1
                if tried <= 6 or (ok and hits == n):
                    print(f"  try#{tried} n={n} walls={len(walls)} lit={lit} hits={hits} ok={ok} c=({c.x:.0f},{c.y:.0f})")
                if ok and lit and "c1" in lit and hits == n:
                    for i, w in enumerate(level["obstacles"]):
                        w["id"] = f"w{i}"
                    path.write_text(json.dumps(level, indent=2) + "\n")
                    notes = (
                        f"{side}-light {n}-mirror {family} "
                        f"({axis_revs([p.x for p in pts])} x-reversals, {axis_revs([p.y for p in pts])} y-folds); "
                        f"start ({pts[0].x:.0f},{pts[0].y:.0f}); crystal ({c.x:.0f},{c.y:.0f}); "
                        f"{len(walls)} rails/skip lids; all required"
                    )
                    update_memory(mem, idx, chapter, family, catalog, side, title, notes)
                    print("WROTE", path)
                    print("path", [(p.x, p.y) for p in pts])
                    print("crystal", c.x, c.y, "walls", len(walls), "chirs", "".join(chirs))
                    return True
                if tried >= 260:
                    return False
        print(f"  {tag} exhausted after {tried} wall-tries")
        return False

    if commit(gather(False), "strict"):
        return
    if commit(gather(True), "loose"):
        return
    if commit(gather(True, True), "emergency"):
        return
    print("FAILED", path)
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    args = ap.parse_args()
    harden(Path(args.file))


if __name__ == "__main__":
    main()
