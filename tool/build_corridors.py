#!/usr/bin/env python3
"""
Rebuild the wall layout of a level range as connected stone corridors.

Instead of scattered stopper bars, every level in the range gets a single
continuous passage: two parallel walls hug the beam path the whole way from the
emitter to the crystal, turning at each mirror post and dead-ending behind the
crystal. Straight runs render with wall_h_cut, the turns and vertical runs with
wall_v_cut. Long runs also get blind side pockets so the room reads as a maze.

Only levels in the requested range are touched; every other level in the
catalog is written back byte-identical.

Usage:
  python tool/build_corridors.py --from 5 --to 10
"""

from __future__ import annotations

import argparse
import json
import math
from typing import List, Optional, Sequence, Tuple

ROOM_W = 1080.0
ROOM_H = 1920.0
WALL_INSET = 52.0

T = 48.0            # wall thickness, matches the generator + sprite art
HALF = 84.0         # clear space between the beam and each corridor wall
MOUTH = 90.0        # how far the corridor runs past emitter / behind crystal
BRANCH_DEPTH = 240.0  # depth of a blind side pocket
MIN_BRANCH_RUN = 470.0  # only carve a pocket off runs at least this long
MIN_DIVIDER = 18.0  # thinnest divider worth drawing between two close lanes

Pt = Tuple[float, float]


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------


def mounted_origin(pos: Sequence[float], direction_deg: float) -> Pt:
    """Mirrors LightSource.mountedOrigin in level_model.dart."""
    rad = math.radians(direction_deg)
    dx, dy = math.cos(rad), math.sin(rad)
    y = min(max(pos[1], WALL_INSET), ROOM_H - WALL_INSET)
    x = min(max(pos[0], WALL_INSET), ROOM_W - WALL_INSET)
    if abs(dx) >= abs(dy):
        return (WALL_INSET, y) if dx >= 0 else (ROOM_W - WALL_INSET, y)
    return (x, WALL_INSET) if dy >= 0 else (x, ROOM_H - WALL_INSET)


def rectilinear_path(level: dict) -> List[Pt]:
    """Emitter -> each mirror post -> crystal, forced onto exact H/V runs.

    Generated hinges sit within a few pixels of the true beam, so snapping each
    leg to its dominant axis keeps the corridor centred on the real path.
    """
    src = level["lightSources"][0]
    pts: List[Pt] = [mounted_origin(src["position"], src["direction"])]

    targets = [tuple(m["hingePosition"]) for m in level["mirrors"]]
    targets.append(tuple(level["targetCrystals"][0]["position"]))

    for tx, ty in targets:
        cx, cy = pts[-1]
        if abs(tx - cx) >= abs(ty - cy):
            pts.append((float(tx), cy))
        else:
            pts.append((cx, float(ty)))
    return pts


def unit(a: Pt, b: Pt) -> Pt:
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    if length < 1e-9:
        return (0.0, 0.0)
    return (dx / length, dy / length)


def dist(a: Pt, b: Pt) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def perpendiculars(d: Pt) -> Tuple[Pt, Pt]:
    return (-d[1], d[0]), (d[1], -d[0])


def same_way(a: Pt, b: Pt) -> bool:
    return a[0] * b[0] + a[1] * b[1] > 0.5


def subtract_gaps(
    t0: float, t1: float, gaps: Sequence[Tuple[float, float]]
) -> List[Tuple[float, float]]:
    spans = [(t0, t1)]
    for g0, g1 in gaps:
        nxt: List[Tuple[float, float]] = []
        for s0, s1 in spans:
            if g1 <= s0 or g0 >= s1:
                nxt.append((s0, s1))
                continue
            if g0 > s0:
                nxt.append((s0, g0))
            if g1 < s1:
                nxt.append((g1, s1))
        spans = nxt
    return spans


def bbox(p0: Pt, p1: Pt) -> Tuple[float, float, float, float]:
    return (min(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[0], p1[0]), max(p0[1], p1[1]))


def boxes_overlap(
    a: Tuple[float, float, float, float],
    b: Tuple[float, float, float, float],
    eps: float = 1.0,
) -> bool:
    return not (
        a[2] <= b[0] + eps
        or b[2] <= a[0] + eps
        or a[3] <= b[1] + eps
        or b[3] <= a[1] + eps
    )


# ---------------------------------------------------------------------------
# Corridor construction
# ---------------------------------------------------------------------------


def corridor_clear_boxes(pts: Sequence[Pt]) -> List[Tuple[float, float, float, float]]:
    """The walkable lane of every leg, used to keep pockets from cutting in."""
    boxes = []
    for a, b in zip(pts, pts[1:]):
        x0, y0, x1, y1 = bbox(a, b)
        boxes.append((x0 - HALF, y0 - HALF, x1 + HALF, y1 + HALF))
    return boxes


def overlap(a0: float, a1: float, b0: float, b1: float, eps: float = 1.0):
    lo, hi = max(min(a0, a1), min(b0, b1)), min(max(a0, a1), max(b0, b1))
    return (lo, hi) if hi - lo > eps else None


def crossing_gaps(
    index: int, a: Pt, d: Pt, s: Pt, pts: Sequence[Pt]
) -> List[Tuple[float, float]]:
    """Open a junction wherever a non-adjacent leg crosses this wall.

    Longer paths double back over themselves, so the wall of one leg can sit
    across the lane of another. Those spots become four-way openings.
    """
    horizontal = abs(d[0]) > abs(d[1])
    band = sorted(
        (
            (a[1] if horizontal else a[0]) + (s[1] if horizontal else s[0]) * HALF,
            (a[1] if horizontal else a[0])
            + (s[1] if horizontal else s[0]) * (HALF + T),
        )
    )

    gaps: List[Tuple[float, float]] = []
    for j, (aj, bj) in enumerate(zip(pts, pts[1:])):
        if abs(j - index) <= 1:
            continue
        x0, y0, x1, y1 = bbox(aj, bj)
        lane_fixed = (y0 - HALF, y1 + HALF) if horizontal else (x0 - HALF, x1 + HALF)
        if overlap(band[0], band[1], *lane_fixed) is None:
            continue
        lane_move = (x0 - HALF, x1 + HALF) if horizontal else (y0 - HALF, y1 + HALF)
        step = d[0] if horizontal else d[1]
        origin = a[0] if horizontal else a[1]
        t_a = (lane_move[0] - origin) / step
        t_b = (lane_move[1] - origin) / step
        gaps.append((min(t_a, t_b), max(t_a, t_b)))
    return gaps


def cut_band(
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    pts: Sequence[Pt],
    out: List[Tuple[Pt, Pt]],
) -> None:
    """Emit an axis-aligned band, split open wherever a lane runs through it."""
    horizontal = (x1 - x0) >= (y1 - y0)
    short = (y0, y1) if horizontal else (x0, x1)
    span = (x0, x1) if horizontal else (y0, y1)

    gaps: List[Tuple[float, float]] = []
    for aj, bj in zip(pts, pts[1:]):
        bx0, by0, bx1, by1 = bbox(aj, bj)
        lane_short = (by0 - HALF, by1 + HALF) if horizontal else (bx0 - HALF, bx1 + HALF)
        if overlap(short[0], short[1], *lane_short) is None:
            continue
        gaps.append(
            (bx0 - HALF, bx1 + HALF) if horizontal else (by0 - HALF, by1 + HALF)
        )

    for s0, s1 in subtract_gaps(span[0], span[1], gaps):
        out.append(((s0, y0), (s1, y1)) if horizontal else ((x0, s0), (x1, s1)))


def divider_walls(pts: Sequence[Pt], out: List[Tuple[Pt, Pt]]) -> None:
    """Split two parallel lanes that run close enough to read as one big room."""
    legs = list(zip(pts, pts[1:]))
    for i in range(len(legs)):
        for j in range(i + 2, len(legs)):
            ai, bi = legs[i]
            aj, bj = legs[j]
            horizontal = abs(bi[0] - ai[0]) > abs(bi[1] - ai[1])
            if horizontal != (abs(bj[0] - aj[0]) > abs(bj[1] - aj[1])):
                continue

            axis = 1 if horizontal else 0
            sep = abs(ai[axis] - aj[axis])
            if not 2 * HALF + MIN_DIVIDER <= sep <= 2 * HALF + 2 * T:
                continue

            move = 0 if horizontal else 1
            shared = overlap(
                min(ai[move], bi[move]),
                max(ai[move], bi[move]),
                min(aj[move], bj[move]),
                max(aj[move], bj[move]),
                160.0,
            )
            if shared is None:
                continue

            thick = min(T, sep - 2 * HALF)
            centre = (ai[axis] + aj[axis]) * 0.5
            if horizontal:
                cut_band(
                    shared[0], centre - thick / 2, shared[1], centre + thick / 2, pts, out
                )
            else:
                cut_band(
                    centre - thick / 2, shared[0], centre + thick / 2, shared[1], pts, out
                )


def plan_branches(pts: Sequence[Pt]) -> List[Tuple[int, float, Pt]]:
    """Pick blind pockets that fit on the board without touching another leg."""
    clear = corridor_clear_boxes(pts)
    reach = HALF + BRANCH_DEPTH + T
    chosen: List[Tuple[int, float, Pt]] = []

    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        run = dist(a, b)
        if run < MIN_BRANCH_RUN:
            continue
        d = unit(a, b)
        t_mid = run * 0.5
        centre = (a[0] + d[0] * t_mid, a[1] + d[1] * t_mid)

        for s in perpendiculars(d):
            near = (centre[0] + s[0] * HALF, centre[1] + s[1] * HALF)
            far = (centre[0] + s[0] * reach, centre[1] + s[1] * reach)
            mouth = HALF + T
            pocket = bbox(
                (near[0] - abs(d[0]) * mouth, near[1] - abs(d[1]) * mouth),
                (far[0] + abs(d[0]) * mouth, far[1] + abs(d[1]) * mouth),
            )
            if pocket[0] < 30 or pocket[1] < 30:
                continue
            if pocket[2] > ROOM_W - 30 or pocket[3] > ROOM_H - 30:
                continue
            if any(boxes_overlap(pocket, c) for c in clear):
                continue
            chosen.append((i, t_mid, s))
            break

    return chosen


def build_walls(pts: Sequence[Pt]) -> List[Tuple[Pt, Pt]]:
    """Two walls per leg, trimmed open at the turns, plus the blind pockets."""
    rects: List[Tuple[Pt, Pt]] = []
    last = len(pts) - 2
    branches = plan_branches(pts)

    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        d = unit(a, b)
        run = dist(a, b)
        d_in = unit(pts[i - 1], pts[i]) if i > 0 else None
        d_next = unit(pts[i + 1], pts[i + 2]) if i + 2 < len(pts) else None

        for s in perpendiculars(d):
            # Near end: room edge at the emitter, otherwise a mirror turn.
            if d_in is None:
                t0 = -MOUTH
            elif same_way(s, (-d_in[0], -d_in[1])):
                t0 = HALF          # open the mouth the beam arrives through
            else:
                t0 = -(HALF + T)   # wrap the outer corner shut

            # Far end: dead end behind the crystal, otherwise a mirror turn.
            if d_next is None:
                t1 = run + MOUTH
            elif same_way(s, d_next):
                t1 = run - HALF    # open the mouth the beam leaves through
            else:
                t1 = run + HALF + T

            gaps = crossing_gaps(i, a, d, s, pts)
            for seg_index, t_branch, side in branches:
                if seg_index == i and same_way(side, s):
                    gaps.append((t_branch - HALF, t_branch + HALF))

            for u0, u1 in subtract_gaps(t0, t1, gaps):
                rects.append(
                    (
                        (a[0] + d[0] * u0 + s[0] * HALF, a[1] + d[1] * u0 + s[1] * HALF),
                        (
                            a[0] + d[0] * u1 + s[0] * (HALF + T),
                            a[1] + d[1] * u1 + s[1] * (HALF + T),
                        ),
                    )
                )

        # Blind pocket walls hanging off this leg.
        for seg_index, t_branch, s in branches:
            if seg_index != i:
                continue
            for sign in (-1.0, 1.0):
                u0 = t_branch + sign * HALF
                u1 = u0 + sign * T
                rects.append(
                    (
                        (a[0] + d[0] * u0 + s[0] * HALF, a[1] + d[1] * u0 + s[1] * HALF),
                        (
                            a[0] + d[0] * u1 + s[0] * (HALF + BRANCH_DEPTH),
                            a[1] + d[1] * u1 + s[1] * (HALF + BRANCH_DEPTH),
                        ),
                    )
                )
            back = HALF + BRANCH_DEPTH
            rects.append(
                (
                    (
                        a[0] + d[0] * (t_branch - HALF - T) + s[0] * back,
                        a[1] + d[1] * (t_branch - HALF - T) + s[1] * back,
                    ),
                    (
                        a[0] + d[0] * (t_branch + HALF + T) + s[0] * (back + T),
                        a[1] + d[1] * (t_branch + HALF + T) + s[1] * (back + T),
                    ),
                )
            )

        # Seal the far end of the last leg so the crystal sits in an alcove.
        if i == last:
            cap = run + MOUTH
            for s in perpendiculars(d):
                rects.append(
                    (
                        (a[0] + d[0] * cap + s[0] * 0.0, a[1] + d[1] * cap + s[1] * 0.0),
                        (
                            a[0] + d[0] * (cap + T) + s[0] * (HALF + T),
                            a[1] + d[1] * (cap + T) + s[1] * (HALF + T),
                        ),
                    )
                )

    divider_walls(pts, rects)
    return rects


def to_obstacles(rects: Sequence[Tuple[Pt, Pt]]) -> List[dict]:
    out: List[dict] = []
    for p0, p1 in rects:
        x0, y0, x1, y1 = bbox(p0, p1)
        x0, y0 = max(0.0, x0), max(0.0, y0)
        x1, y1 = min(ROOM_W, x1), min(ROOM_H, y1)
        w, h = x1 - x0, y1 - y0
        # Drop trim slivers: anything shorter than this reads as a stray block
        # rather than a run of wall, and the painter picks its sprite by aspect.
        if min(w, h) < 8.0 or max(w, h) < T * 1.5:
            continue
        horizontal = w >= h
        out.append(
            {
                "id": f"w{len(out)}",
                "polygon": [
                    [round(x0, 1), round(y0, 1)],
                    [round(x1, 1), round(y0, 1)],
                    [round(x1, 1), round(y1, 1)],
                    [round(x0, 1), round(y1, 1)],
                ],
                "isDecorative": False,
                "renderAsset": "wall_h_cut" if horizontal else "wall_h_cut_rotated",
                "orientation": "horizontal" if horizontal else "vertical",
                "thickness": T,
            }
        )
    return out


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/levels/levels.json")
    parser.add_argument("--from", dest="start", type=int, default=5)
    parser.add_argument("--to", dest="end", type=int, default=10)
    args = parser.parse_args()

    with open(args.catalog, "r", encoding="utf-8") as fh:
        root = json.load(fh)

    touched = 0
    for level in root["levels"]:
        index = level.get("levelIndex", 0)
        if not (args.start <= index <= args.end):
            continue

        pts = rectilinear_path(level)
        level["obstacles"] = to_obstacles(build_walls(pts))

        meta = level.setdefault("metadata", {})
        meta["objective"] = (
            "Follow the stone corridor — turn the beam at every post to reach "
            "the crystal."
        )
        meta["hints"] = [
            "The passage only opens where the beam is meant to turn.",
            "Side pockets are dead ends — they never reach the crystal.",
            "Set every mirror before you trace the run to the end.",
        ]
        meta["wallLayout"] = "corridor_v1"
        touched += 1
        print(f"{level['levelId']}: {len(level['obstacles'])} corridor walls")

    # indent=2 with no trailing newline round-trips the catalog byte-for-byte,
    # so untouched levels stay identical in the diff.
    with open(args.catalog, "w", encoding="utf-8") as fh:
        json.dump(root, fh, indent=2)

    print(f"rebuilt {touched} levels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
