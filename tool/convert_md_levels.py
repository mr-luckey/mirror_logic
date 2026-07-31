"""Convert the `laser_1000_hard.md` grid puzzles into Mirror Logic's levels.json.

The markdown describes each puzzle on an N x N character grid: a laser on the
border, `/` and `\\` mirrors, `*` targets, and P/W/B obstacles. The game instead
works in continuous world coordinates, so every cell is mapped to a square of
side `cell` inside a 960x960 board centred in the 1080x1920 room.

Two facts make the mapping exact rather than approximate:

  * Cells are square, so a mirror at 45 deg sends a beam travelling down one
    lane centre into the perpendicular lane centre.
  * Every mirror is shorter than one cell, so a mirror can only ever touch
    beams passing through its own cell -- exactly the grid's rule.

Nothing is emitted on trust. Each puzzle is replayed on the grid first, and the
level is only written if the beam follows the markdown's solution path mirror
for mirror and lights every target.

Usage:
    python tool/convert_md_levels.py
    python tool/convert_md_levels.py --dry-run
    python tool/convert_md_levels.py --out assets/levels/levels_hard.json
    python tool/convert_md_levels.py --per-chapter 1000
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

# --- Room geometry -----------------------------------------------------------

ROOM_W = 1080.0
ROOM_H = 1920.0
BOARD = 960.0                      # square play area, in world units
BOARD_X = (ROOM_W - BOARD) / 2.0
BOARD_Y = (ROOM_H - BOARD) / 2.0

MIRROR_LEN_RATIO = 0.80            # < 1.0 keeps a mirror inside its own cell
CRYSTAL_RADIUS_RATIO = 0.30        # < 0.5 keeps a crystal out of neighbour lanes
PILLAR_RATIO = 0.46
BOX_RATIO = 0.62
WALL_RATIO = 0.84

MIN_ANGLE = 5.0
MAX_ANGLE = 175.0
ANGLE_TOLERANCE = 4.0              # GameConstants.angleToleranceDegrees
MAX_BOUNCES = 24                   # GameConstants.maxBounces

# `/` runs bottom-left to top-right; with y pointing down that is 135 deg.
ANGLE_OF = {"/": 135.0, "\\": 45.0}

# (row delta, col delta) per heading, and the world heading in degrees.
STEP = {"UP": (-1, 0), "DOWN": (1, 0), "LEFT": (0, -1), "RIGHT": (0, 1)}
HEADING_DEGREES = {"UP": 270.0, "DOWN": 90.0, "LEFT": 180.0, "RIGHT": 0.0}

# How far an unsolved mirror is parked from its solution angle. Cycled so
# neighbouring mirrors do not all start on the same tilt.
SCRAMBLE = (
    52.0, -34.0, 68.0, -47.0, 39.0, -61.0, 25.0, -28.0,
    44.0, -55.0, 31.0, -41.0, 76.0, -72.0, 59.0, -23.0,
)

TITLE_HEAD = (
    "Mirror", "Prism", "Lantern", "Obsidian", "Crystal", "Amber", "Iron",
    "Silver", "Ember", "Frost", "Sunken", "Hollow", "Gilded", "Shattered",
)
TITLE_TAIL = (
    "Hall", "Vault", "Atrium", "Cloister", "Gallery", "Spire", "Chamber",
    "Rotunda", "Crypt", "Foundry", "Observatory", "Sanctum", "Bastion",
)


# --- Parsing -----------------------------------------------------------------


@dataclass
class Puzzle:
    number: int
    grid: int
    difficulty: int
    laser: tuple[int, int]
    heading: str
    targets: list[tuple[int, int]]
    solution: list[tuple[int, int, str]] = field(default_factory=list)
    decoys: list[tuple[int, int, str]] = field(default_factory=list)
    obstacles: list[tuple[int, int, str]] = field(default_factory=list)


_HEADER = re.compile(
    r"\*\*Grid:\*\*\s*(\d+)[x\u00d7](\d+).*?\*\*Difficulty:\*\*\s*(\d+)",
    re.S,
)
_LASER = re.compile(r"\*\*Laser:\*\*\s*\((\d+),\s*(\d+)\)\s*\S*\s*`?(UP|DOWN|LEFT|RIGHT)`?")
_CELL_ANGLED = re.compile(r"\((\d+),\s*(\d+)\)\s*`([/\\])`")
_CELL_KIND = re.compile(r"\((\d+),\s*(\d+)\)\s*([PWB])\b")
_CELL_PLAIN = re.compile(r"\((\d+),\s*(\d+)\)")


def _line(block: str, label: str) -> str:
    match = re.search(rf"^- \*\*{label}[^*]*\*\*(.*)$", block, re.M)
    return match.group(1) if match else ""


def parse_markdown(path: Path) -> list[Puzzle]:
    text = path.read_text(encoding="utf-8")
    puzzles: list[Puzzle] = []

    for block in text.split("\n## Level ")[1:]:
        number = int(block.split("\n", 1)[0].strip())
        header = _HEADER.search(block)
        laser = _LASER.search(block)
        if not header or not laser:
            raise ValueError(f"Level {number}: unreadable header or laser line")

        rows, cols, difficulty = (int(g) for g in header.groups())
        if rows != cols:
            raise ValueError(f"Level {number}: non-square {rows}x{cols} grid")

        puzzles.append(
            Puzzle(
                number=number,
                grid=rows,
                difficulty=difficulty,
                laser=(int(laser.group(1)), int(laser.group(2))),
                heading=laser.group(3),
                targets=[
                    (int(r), int(c))
                    for r, c in _CELL_PLAIN.findall(_line(block, "Targets"))
                ],
                solution=[
                    (int(r), int(c), g)
                    for r, c, g in _CELL_ANGLED.findall(
                        _line(block, "Solution Path Mirrors")
                    )
                ],
                decoys=[
                    (int(r), int(c), g)
                    for r, c, g in _CELL_ANGLED.findall(
                        _line(block, "Decoy Mirrors")
                    )
                ],
                obstacles=[
                    (int(r), int(c), k)
                    for r, c, k in _CELL_KIND.findall(_line(block, "Obstacles"))
                ],
            )
        )

    return puzzles


# --- Grid replay -------------------------------------------------------------


@dataclass
class Replay:
    """What the beam did on the grid, in the order it happened."""

    mirrors_hit: list[tuple[int, int]]
    targets_lit: list[tuple[int, int]]
    bounces_at_target: dict[tuple[int, int], int]
    segments: int
    blocked_by_decoy: tuple[int, int] | None


def replay(puzzle: Puzzle, decoys: list[tuple[int, int, str]]) -> Replay:
    """Trace the beam exactly the way the engine will.

    The engine mounts the emitter on the room wall, so the beam enters the
    board at the edge of the laser's lane rather than at the laser's cell. This
    walks the same lane, which is what makes the check meaningful.
    """
    n = puzzle.grid
    mirrors = {(r, c): g for r, c, g in puzzle.solution}
    solution_cells = set(mirrors)
    decoy_cells = {(r, c): g for r, c, g in decoys}
    mirrors.update(decoy_cells)
    blockers = {(r, c) for r, c, _ in puzzle.obstacles}
    targets = set(puzzle.targets)

    dr, dc = STEP[puzzle.heading]
    row, col = puzzle.laser
    # Back up to the board edge the emitter fires from.
    while 0 <= row - dr < n and 0 <= col - dc < n:
        row, col = row - dr, col - dc

    mirrors_hit: list[tuple[int, int]] = []
    targets_lit: list[tuple[int, int]] = []
    bounces: dict[tuple[int, int], int] = {}
    segments = 1

    for _ in range(n * n * 4):
        if not (0 <= row < n and 0 <= col < n):
            break
        cell = (row, col)

        if cell in blockers:
            segments += 1
            break

        if cell in mirrors:
            glyph = mirrors[cell]
            dr, dc = (-dc, -dr) if glyph == "/" else (dc, dr)
            mirrors_hit.append(cell)
            segments += 1
            if cell not in solution_cells:
                return Replay(mirrors_hit, targets_lit, bounces, segments, cell)

        if cell in targets and cell not in bounces:
            targets_lit.append(cell)
            bounces[cell] = len(mirrors_hit)
            segments += 1
            # The last crystal absorbs the beam, so the trace ends here just as
            # it will in the engine.
            if len(targets_lit) == len(targets):
                break

        row, col = row + dr, col + dc

    return Replay(mirrors_hit, targets_lit, bounces, segments, None)


def verify(puzzle: Puzzle) -> tuple[Replay, list[tuple[int, int, str]], str | None]:
    """Replay the puzzle, dropping decoys that sit on the solution path.

    A decoy parked on a transit cell would deflect the beam and destroy the
    intended route, so it cannot be carried over to the world level.
    """
    decoys = list(puzzle.decoys)
    wanted = [(r, c) for r, c, _ in puzzle.solution]

    for _ in range(len(decoys) + 1):
        result = replay(puzzle, decoys)
        if result.blocked_by_decoy is not None:
            hit = result.blocked_by_decoy
            decoys = [d for d in decoys if (d[0], d[1]) != hit]
            continue
        if result.mirrors_hit != wanted:
            return result, decoys, "beam does not follow the stated solution path"
        if len(result.targets_lit) != len(set(puzzle.targets)):
            return result, decoys, "beam misses at least one target"
        return result, decoys, None

    return replay(puzzle, decoys), decoys, "decoys could not be reconciled"


# --- World replay ------------------------------------------------------------
#
# A port of lib/domain/beam/beam_simulator.dart, faithful down to the epsilon
# and the nudge distances. The grid replay proves the puzzle is coherent; this
# proves the level we are about to emit behaves the same once it is geometry.

EPS = 1e-6
MAX_RAY = 5000.0


def _ray_segment(ox, oy, dx, dy, ax, ay, bx, by):
    v1x, v1y = ox - ax, oy - ay
    v2x, v2y = bx - ax, by - ay
    v3x, v3y = -dy, dx
    dot = v2x * v3x + v2y * v3y
    if abs(dot) < EPS:
        return None
    t1 = (-v2y * v1x + v2x * v1y) / dot     # v2.perp dot v1
    t2 = (v1x * v3x + v1y * v3y) / dot
    if t1 >= EPS and 0 <= t2 <= 1:
        return t1
    return None


def _ray_circle(ox, oy, dx, dy, cx, cy, r):
    ocx, ocy = ox - cx, oy - cy
    a = dx * dx + dy * dy
    b = 2 * (ocx * dx + ocy * dy)
    c = ocx * ocx + ocy * ocy - r * r
    disc = b * b - 4 * a * c
    if disc < 0:
        return None
    root = disc ** 0.5
    t0 = (-b - root) / (2 * a)
    t1 = (-b + root) / (2 * a)
    t = t0 if t0 >= EPS else (t1 if t1 >= EPS else -1.0)
    return t if t >= EPS else None


def simulate_world(level: dict, angles: dict[str, float]) -> set[str]:
    """Return the ids of every crystal the beam lights."""
    import math

    w = level["roomBounds"]["width"]
    h = level["roomBounds"]["height"]
    walls = [(0.0, 0.0, w, 0.0), (0.0, h, w, h), (0.0, 0.0, 0.0, h), (w, 0.0, w, h)]
    edges = list(walls)
    for obstacle in level["obstacles"]:
        poly = obstacle["polygon"]
        for i, (ax, ay) in enumerate(poly):
            bx, by = poly[(i + 1) % len(poly)]
            edges.append((ax, ay, bx, by))

    lit: set[str] = set()

    for source in level["lightSources"]:
        rad = math.radians(source["direction"])
        dx, dy = math.cos(rad), math.sin(rad)
        # LightSource.mountedOrigin
        inset = 52.0
        px, py = source["position"]
        if abs(dx) >= abs(dy):
            ox = inset if dx >= 0 else w - inset
            oy = min(max(py, inset), h - inset)
        else:
            oy = inset if dy >= 0 else h - inset
            ox = min(max(px, inset), w - inset)

        for _ in range(MAX_BOUNCES):
            best_t = MAX_RAY
            best_kind = None
            best_id = None
            best_angle = 0.0

            for ax, ay, bx, by in edges:
                t = _ray_segment(ox, oy, dx, dy, ax, ay, bx, by)
                if t is not None and t < best_t:
                    best_t, best_kind, best_id = t, "wall", None

            for mirror in level["mirrors"]:
                angle = angles.get(mirror["id"], mirror["initialAngle"])
                mrad = math.radians(angle)
                hx, hy = mirror["hingePosition"]
                half = mirror["length"] / 2.0
                ax, ay = hx - math.cos(mrad) * half, hy - math.sin(mrad) * half
                bx, by = hx + math.cos(mrad) * half, hy + math.sin(mrad) * half
                t = _ray_segment(ox, oy, dx, dy, ax, ay, bx, by)
                if t is not None and t < best_t:
                    best_t, best_kind = t, "mirror"
                    best_id, best_angle = mirror["id"], angle

            for crystal in level["targetCrystals"]:
                cx, cy = crystal["position"]
                t = _ray_circle(ox, oy, dx, dy, cx, cy, crystal["hitRadius"])
                if t is not None and t < best_t:
                    best_t, best_kind, best_id = t, "crystal", crystal["id"]

            if best_kind is None or best_kind == "wall":
                break

            hx, hy = ox + dx * best_t, oy + dy * best_t

            if best_kind == "crystal":
                lit.add(best_id)
                crystal = next(
                    c for c in level["targetCrystals"] if c["id"] == best_id
                )
                if not crystal["relay"]:
                    break
                step = 2 * crystal["hitRadius"] + 1
                ox, oy = hx + dx * step, hy + dy * step
                continue

            nrad = math.radians(best_angle + 90.0)
            nx, ny = math.cos(nrad), math.sin(nrad)
            if nx * dx + ny * dy > 0:
                nx, ny = -nx, -ny
            d = 2 * (dx * nx + dy * ny)
            dx, dy = dx - nx * d, dy - ny * d
            length = (dx * dx + dy * dy) ** 0.5
            ox, oy = hx + dx * 0.5, hy + dy * 0.5
            dx, dy = dx / length, dy / length

    return lit


def solved(level: dict, angles: dict[str, float]) -> bool:
    lit = simulate_world(level, angles)
    return all(c["id"] in lit for c in level["targetCrystals"])


# --- World emission ----------------------------------------------------------


def mirror_distance(a: float, b: float) -> float:
    """Angle between two mirror surfaces. A mirror is a line, so 175 and 5 are
    ten degrees apart, not a hundred and seventy."""
    d = abs(a - b) % 180.0
    return min(d, 180.0 - d)


def scramble(solution_angle: float, seed: int) -> float:
    """Park a mirror away from its answer without leaving its rotation range.

    Offsets fold around 180 rather than clamping, which keeps the opening
    board from lining every mirror up against the same two rotation stops.
    """
    gap = max(20.0, ANGLE_TOLERANCE * 4)
    for step in range(len(SCRAMBLE)):
        angle = (solution_angle + SCRAMBLE[(seed + step) % len(SCRAMBLE)]) % 180.0
        if not (MIN_ANGLE + 5 <= angle <= MAX_ANGLE - 5):
            continue
        if mirror_distance(angle, solution_angle) > gap:
            return round(angle, 1)
    return round((solution_angle + 90.0) % 180.0, 1)


def square(cx: float, cy: float, side: float) -> list[list[float]]:
    half = side / 2.0
    return [
        [round(cx - half, 2), round(cy - half, 2)],
        [round(cx + half, 2), round(cy - half, 2)],
        [round(cx + half, 2), round(cy + half, 2)],
        [round(cx - half, 2), round(cy + half, 2)],
    ]


def title_for(number: int, mirrors: int) -> str:
    head = TITLE_HEAD[(number * 7) % len(TITLE_HEAD)]
    tail = TITLE_TAIL[(number * 5 + mirrors) % len(TITLE_TAIL)]
    return f"{head} {tail}"


def build_level(
    puzzle: Puzzle,
    result: Replay,
    decoys: list[tuple[int, int, str]],
    chapter: str,
    index: int,
    salt: int = 0,
) -> dict:
    n = puzzle.grid
    cell = BOARD / n
    mirror_len = round(cell * MIRROR_LEN_RATIO, 2)
    radius = round(cell * CRYSTAL_RADIUS_RATIO, 2)

    def centre(row: int, col: int) -> tuple[float, float]:
        return (
            round(BOARD_X + (col + 0.5) * cell, 2),
            round(BOARD_Y + (row + 0.5) * cell, 2),
        )

    laser_x, laser_y = centre(*puzzle.laser)

    mirrors: list[dict] = []
    solution_angles: dict[str, float] = {}

    for i, (row, col, glyph) in enumerate(puzzle.solution):
        hx, hy = centre(row, col)
        angle = ANGLE_OF[glyph]
        mid = f"m{i + 1}"
        mirrors.append(
            {
                "id": mid,
                "hingePosition": [hx, hy],
                "length": mirror_len,
                "initialAngle": scramble(angle, puzzle.number + i + salt),
                "minAngle": MIN_ANGLE,
                "maxAngle": MAX_ANGLE,
                "snapIncrement": 0.0,
                "isLocked": False,
                "type": "standard",
            }
        )
        solution_angles[mid] = angle

    # Decoys are deliberately left out of intendedSolution: they sit off the
    # beam's route, so no angle of theirs is ever "correct".
    for i, (row, col, glyph) in enumerate(decoys):
        hx, hy = centre(row, col)
        mirrors.append(
            {
                "id": f"d{i + 1}",
                "hingePosition": [hx, hy],
                "length": mirror_len,
                "initialAngle": scramble(
                    ANGLE_OF[glyph], puzzle.number + i + 3 + salt
                ),
                "minAngle": MIN_ANGLE,
                "maxAngle": MAX_ANGLE,
                "snapIncrement": 0.0,
                "isLocked": False,
                "type": "standard",
            }
        )

    shape_of = {"P": ("pillar", PILLAR_RATIO), "B": ("wall", BOX_RATIO),
                "W": ("wall", WALL_RATIO)}
    obstacles = []
    for i, (row, col, kind) in enumerate(puzzle.obstacles):
        shape, ratio = shape_of[kind]
        ox, oy = centre(row, col)
        obstacles.append(
            {
                "id": f"o{i + 1}",
                "polygon": square(ox, oy, cell * ratio),
                "isDecorative": False,
                "shape": shape,
            }
        )

    # Only the final crystal stops the beam; the ones it passes through on the
    # way have to relay or the later targets would never light.
    last_lit = result.targets_lit[-1]
    crystals = []
    for i, pos in enumerate(puzzle.targets):
        cx, cy = centre(*pos)
        crystals.append(
            {
                "id": f"c{i + 1}",
                "position": [cx, cy],
                "hitRadius": radius,
                "groupId": "g1",
                "relay": pos != last_lit,
            }
        )

    level: dict = {
        "levelId": f"{chapter}_{index:03d}",
        "chapterId": chapter,
        "schemaVersion": 1,
        "levelIndex": index,
        "title": title_for(puzzle.number, len(puzzle.solution)),
        "roomBounds": {"width": ROOM_W, "height": ROOM_H},
        "lightSources": [
            {
                "id": "ls1",
                "position": [laser_x, laser_y],
                "direction": HEADING_DEGREES[puzzle.heading],
                "locked": True,
            }
        ],
        "mirrors": mirrors,
        "obstacles": obstacles,
        "targetCrystals": crystals,
        "crystalGroups": [{"groupId": "g1", "requiredCount": len(crystals)}],
        "doorPortals": [],
        "intendedSolution": {
            "mirrorAngles": solution_angles,
            "toleranceDegrees": ANGLE_TOLERANCE,
        },
        "starThresholds": {
            "threeStarMoveCount": len(puzzle.solution),
            "threeStarTimeSeconds": 25 + 6 * len(puzzle.solution),
        },
        "metadata": {
            "designer": "laser_1000_hard",
            "difficultyBand": chapter,
            "objective": (
                f"Steer the beam through all {len(puzzle.solution)} mirrors "
                f"and light {'both' if len(crystals) == 2 else 'the'} "
                f"{'crystals' if len(crystals) > 1 else 'crystal'}."
            ),
            "hints": [
                "Trace the route backwards from the crystal to the emitter.",
                "Not every mirror on the board belongs to the answer.",
                "A mirror only bends light that crosses its own square.",
            ],
            "gridSize": puzzle.grid,
            "sourceLevel": puzzle.number,
            "difficulty": puzzle.difficulty,
            "decoyCount": len(decoys),
        },
    }

    # A single crystal ends the beam, so its bounce count is fixed and can be
    # policed. With several crystals the count differs per crystal, and a
    # level-wide number would wrongly reject the early ones.
    if len(crystals) == 1:
        level["requiredMirrorBounces"] = result.bounces_at_target[last_lit]

    return level


# --- Entry point -------------------------------------------------------------


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=str(root / "laser_1000_hard.md"))
    parser.add_argument("--out", default=str(root / "assets/levels/levels.json"))
    parser.add_argument("--per-chapter", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="indent the output; roughly doubles the size of the bundled asset",
    )
    args = parser.parse_args()

    source = Path(args.source)
    if not source.exists():
        print(f"source not found: {source}", file=sys.stderr)
        return 1

    puzzles = parse_markdown(source)
    print(f"parsed {len(puzzles)} puzzles from {source.name}")

    levels: list[dict] = []
    rejected: list[str] = []
    dropped_decoys = 0
    worst_segments = 0

    for puzzle in puzzles:
        result, decoys, problem = verify(puzzle)
        if problem:
            rejected.append(f"level {puzzle.number}: {problem}")
            continue

        index = len(levels) + 1
        chapter = f"ch{(index - 1) // args.per_chapter + 1}"
        level_index = (index - 1) % args.per_chapter + 1

        # Re-park the mirrors until the opening position is genuinely unsolved.
        # A scramble can, once in a while, line the beam up by accident.
        level = None
        for salt in range(len(SCRAMBLE) * 3):
            candidate = build_level(
                puzzle, result, decoys, chapter, level_index, salt
            )
            if not solved(candidate, {}):
                level = candidate
                break
        if level is None:
            rejected.append(f"level {puzzle.number}: every scramble starts solved")
            continue

        if not solved(level, level["intendedSolution"]["mirrorAngles"]):
            rejected.append(f"level {puzzle.number}: geometry does not solve")
            continue

        dropped_decoys += len(puzzle.decoys) - len(decoys)
        worst_segments = max(worst_segments, result.segments)
        levels.append(level)

    print(f"converted {len(levels)} levels, rejected {len(rejected)}")
    print(f"decoys dropped for sitting on the solution path: {dropped_decoys}")
    print(f"longest beam: {worst_segments} segments (engine allows {MAX_BOUNCES})")
    if worst_segments > MAX_BOUNCES:
        print("  WARNING: raise GameConstants.maxBounces or those beams die early")
    for note in rejected[:20]:
        print(f"  - {note}")
    if len(rejected) > 20:
        print(f"  ... and {len(rejected) - 20} more")

    if not levels:
        print("nothing to write", file=sys.stderr)
        return 1

    if args.dry_run:
        print("dry run: no file written")
        return 0

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        # Kept out of assets/ so a stale copy can never be bundled by mistake.
        backups = root / ".level-backups"
        backups.mkdir(exist_ok=True)
        backup = backups / f"{out.stem}.{time.strftime('%Y%m%d-%H%M%S')}.json"
        shutil.copy2(out, backup)
        print(f"backed up existing catalogue to .level-backups/{backup.name}")

    payload = {"schemaVersion": 1, "levels": levels}
    out.write_text(
        json.dumps(payload, indent=1) if args.pretty
        else json.dumps(payload, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"wrote {out} ({out.stat().st_size / 1_048_576:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
