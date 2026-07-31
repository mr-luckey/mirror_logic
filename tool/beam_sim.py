"""A Python port of lib/domain/beam/beam_simulator.dart.

Level tooling has to be able to answer "does this still work?" without booting
Flutter. This mirrors the engine down to the epsilon, the nudge distances and
the order hits are considered in, so an answer here means the same thing the
game will decide at runtime.

Keep this in step with the Dart original if the physics there ever changes.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

EPS = 1e-6
MAX_RAY = 5000.0
MAX_BOUNCES = 24          # GameConstants.maxBounces
WALL_INSET = 52.0         # LightSource.mountedOrigin


@dataclass
class Trace:
    segments: list[tuple[float, float, float, float]]
    lit: set[str]
    bounces: dict[str, int]


def ray_segment(ox, oy, dx, dy, ax, ay, bx, by):
    """Distance along the ray to a segment, or None."""
    v1x, v1y = ox - ax, oy - ay
    v2x, v2y = bx - ax, by - ay
    v3x, v3y = -dy, dx
    dot = v2x * v3x + v2y * v3y
    if abs(dot) < EPS:
        return None
    t1 = (-v2y * v1x + v2x * v1y) / dot      # v2.perp dot v1
    t2 = (v1x * v3x + v1y * v3y) / dot
    if t1 >= EPS and 0 <= t2 <= 1:
        return t1
    return None


def ray_circle(ox, oy, dx, dy, cx, cy, r):
    ocx, ocy = ox - cx, oy - cy
    a = dx * dx + dy * dy
    b = 2 * (ocx * dx + ocy * dy)
    c = ocx * ocx + ocy * ocy - r * r
    disc = b * b - 4 * a * c
    if disc < 0:
        return None
    root = math.sqrt(disc)
    t0 = (-b - root) / (2 * a)
    t1 = (-b + root) / (2 * a)
    t = t0 if t0 >= EPS else (t1 if t1 >= EPS else -1.0)
    return t if t >= EPS else None


def point_to_segment(px, py, ax, ay, bx, by) -> float:
    vx, vy = bx - ax, by - ay
    span = vx * vx + vy * vy
    if span < EPS:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / span))
    return math.hypot(px - (ax + vx * t), py - (ay + vy * t))


def mounted_origin(source: dict, w: float, h: float) -> tuple[float, float]:
    rad = math.radians(source["direction"])
    dx, dy = math.cos(rad), math.sin(rad)
    px, py = source["position"]
    if abs(dx) >= abs(dy):
        x = WALL_INSET if dx >= 0 else w - WALL_INSET
        return x, min(max(py, WALL_INSET), h - WALL_INSET)
    y = WALL_INSET if dy >= 0 else h - WALL_INSET
    return min(max(px, WALL_INSET), w - WALL_INSET), y


def mirror_endpoints(mirror: dict, angle: float):
    rad = math.radians(angle)
    hx, hy = mirror["hingePosition"]
    half = mirror["length"] / 2.0
    ex, ey = math.cos(rad) * half, math.sin(rad) * half
    return hx - ex, hy - ey, hx + ex, hy + ey


def trace(level: dict, angles: dict[str, float]) -> Trace:
    w = level["roomBounds"]["width"]
    h = level["roomBounds"]["height"]

    edges = [(0.0, 0.0, w, 0.0), (0.0, h, w, h), (0.0, 0.0, 0.0, h), (w, 0.0, w, h)]
    for obstacle in level["obstacles"]:
        if obstacle.get("isDecorative"):
            continue
        poly = obstacle["polygon"]
        for i, (ax, ay) in enumerate(poly):
            bx, by = poly[(i + 1) % len(poly)]
            edges.append((ax, ay, bx, by))

    segments: list[tuple[float, float, float, float]] = []
    lit: set[str] = set()
    bounces: dict[str, int] = {}

    for source in level["lightSources"]:
        rad = math.radians(source["direction"])
        dx, dy = math.cos(rad), math.sin(rad)
        ox, oy = mounted_origin(source, w, h)
        mirror_hits = 0

        for _ in range(MAX_BOUNCES):
            best_t, best_kind, best_id, best_angle = MAX_RAY, None, None, 0.0

            for ax, ay, bx, by in edges:
                t = ray_segment(ox, oy, dx, dy, ax, ay, bx, by)
                if t is not None and t < best_t:
                    best_t, best_kind, best_id = t, "wall", None

            for mirror in level["mirrors"]:
                angle = angles.get(mirror["id"], mirror["initialAngle"])
                ax, ay, bx, by = mirror_endpoints(mirror, angle)
                t = ray_segment(ox, oy, dx, dy, ax, ay, bx, by)
                if t is not None and t < best_t:
                    best_t, best_kind = t, "mirror"
                    best_id, best_angle = mirror["id"], angle

            for crystal in level["targetCrystals"]:
                cx, cy = crystal["position"]
                t = ray_circle(ox, oy, dx, dy, cx, cy, crystal["hitRadius"])
                if t is not None and t < best_t:
                    best_t, best_kind, best_id = t, "crystal", crystal["id"]

            if best_kind is None:
                segments.append((ox, oy, ox + dx * MAX_RAY, oy + dy * MAX_RAY))
                break

            hx, hy = ox + dx * best_t, oy + dy * best_t
            segments.append((ox, oy, hx, hy))

            if best_kind == "wall":
                break

            if best_kind == "crystal":
                lit.add(best_id)
                if best_id not in bounces or mirror_hits < bounces[best_id]:
                    bounces[best_id] = mirror_hits
                crystal = next(
                    c for c in level["targetCrystals"] if c["id"] == best_id
                )
                if not crystal.get("relay"):
                    break
                step = 2 * crystal["hitRadius"] + 1
                ox, oy = hx + dx * step, hy + dy * step
                continue

            mirror_hits += 1
            nrad = math.radians(best_angle + 90.0)
            nx, ny = math.cos(nrad), math.sin(nrad)
            if nx * dx + ny * dy > 0:
                nx, ny = -nx, -ny
            proj = 2 * (dx * nx + dy * ny)
            dx, dy = dx - nx * proj, dy - ny * proj
            span = math.hypot(dx, dy)
            ox, oy = hx + dx * 0.5, hy + dy * 0.5
            dx, dy = dx / span, dy / span

    return Trace(segments, lit, bounces)


def reachable_solution(level: dict) -> dict[str, float]:
    """The angles a player can actually reach, matching LevelValidator.

    A locked mirror keeps whatever the level shipped it at, because no drag
    will ever move it.
    """
    solution = level["intendedSolution"]["mirrorAngles"]
    return {
        m["id"]: m["initialAngle"] if m.get("isLocked")
        else solution.get(m["id"], m["initialAngle"])
        for m in level["mirrors"]
    }


def solves(level: dict, angles: dict[str, float]) -> bool:
    lit = trace(level, angles).lit
    groups = {g["groupId"]: g["requiredCount"] for g in level.get("crystalGroups", [])}
    crystals = level["targetCrystals"]
    if not crystals:
        return False

    required = level.get("requiredMirrorBounces")
    counts = trace(level, angles).bounces
    accepted = {
        c["id"] for c in crystals
        if c["id"] in lit
        and not (required is not None
                 and c["id"] in counts
                 and counts[c["id"]] != required)
    }

    for group_id, need in groups.items():
        members = {c["id"] for c in crystals if c.get("groupId", "g1") == group_id}
        if len(members & accepted) < need:
            return False
    for crystal in crystals:
        if crystal.get("groupId", "g1") in groups:
            continue
        if crystal["id"] not in accepted:
            return False
    return True
