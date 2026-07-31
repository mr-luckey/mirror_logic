"""Make the hand-made catalogue more interesting without changing any solution.

Three things are wrong with the shipped levels as puzzles:

  * 985 of the 1000 are the same shape -- eight mirrors, eight bounces, nine
    moves -- so there is no curve after the first twenty.
  * Every mirror on the board is part of the answer, so there is nothing to
    work out. You turn all eight and you are done.
  * Most mirrors carry `snapIncrement: 5`, and the engine skips magnetic
    alignment detents whenever a mirror snaps, so the assist never fires.

The fix keeps every existing mirror, obstacle, crystal and solution angle
exactly where it is and only adds to the board:

  * Decoy mirrors, ramping from none to a handful as the catalogue goes on.
    A decoy is placed so its hinge is further from every solution beam segment
    than the mirror is long, which means no rotation of it can ever touch the
    winning path. It is close enough to look like it belongs, though, so the
    player has to reason about which mirrors are in the chain.
  * Free rotation instead of 5-degree steps, which hands those mirrors over to
    the alignment detents.
  * A slightly wider three-star move budget where decoys were added, since
    grabbing a wrong mirror now costs a move.

Every level is replayed through tool/beam_sim.py afterwards and is only kept if
it still solves, still does not start solved, and still reaches the crystal on
the same bounce count.

Usage:
    python tool/enrich_levels.py --dry-run
    python tool/enrich_levels.py
"""

from __future__ import annotations

import argparse
import json
import math
import random
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import beam_sim

# A decoy hinge must clear the winning beam by more than the mirror's own
# reach, so no angle it can be turned to will ever intercept the solution.
BEAM_CLEARANCE = 18.0
MIRROR_CLEARANCE = 26.0
CRYSTAL_CLEARANCE = 30.0
EMITTER_CLEARANCE = 90.0
OBSTACLE_CLEARANCE = 14.0
ROOM_MARGIN = 110.0

# Decoys are off by default. A level's rule is "bounce through every mirror",
# so any mirror that is not in the chain makes that rule impossible to satisfy
# and the target reads as a wrong answer even when the player did everything
# right. Pass --max-decoys to experiment with them anyway.
DEFAULT_MAX_DECOYS = 0
TUTORIAL_LEVELS = 20      # left clean so the basics stay readable
PLACEMENT_TRIES = 260


def wanted_decoys(index: int, total: int, cap: int) -> int:
    if cap <= 0 or index <= TUTORIAL_LEVELS:
        return 0
    span = max(1, total - TUTORIAL_LEVELS)
    return 1 + (index - TUTORIAL_LEVELS - 1) * (cap - 1) // span


def point_in_polygon(px: float, py: float, poly: list[list[float]]) -> bool:
    inside = False
    for i, (ax, ay) in enumerate(poly):
        bx, by = poly[(i - 1) % len(poly)]
        if (ay > py) != (by > py):
            if px < (bx - ax) * (py - ay) / (by - ay) + ax:
                inside = not inside
    return inside


def placement_ok(
    px: float,
    py: float,
    level: dict,
    segments: list[tuple[float, float, float, float]],
    length: float,
    mirrors: list[dict],
) -> bool:
    reach = length / 2.0
    w = level["roomBounds"]["width"]
    h = level["roomBounds"]["height"]

    if not (ROOM_MARGIN <= px <= w - ROOM_MARGIN):
        return False
    if not (ROOM_MARGIN <= py <= h - ROOM_MARGIN):
        return False

    for ax, ay, bx, by in segments:
        if beam_sim.point_to_segment(px, py, ax, ay, bx, by) < reach + BEAM_CLEARANCE:
            return False

    for mirror in mirrors:
        mx, my = mirror["hingePosition"]
        if math.hypot(px - mx, py - my) < length + MIRROR_CLEARANCE:
            return False

    for crystal in level["targetCrystals"]:
        cx, cy = crystal["position"]
        if math.hypot(px - cx, py - cy) < crystal["hitRadius"] + reach + CRYSTAL_CLEARANCE:
            return False

    for source in level["lightSources"]:
        sx, sy = beam_sim.mounted_origin(source, w, h)
        if math.hypot(px - sx, py - sy) < reach + EMITTER_CLEARANCE:
            return False
        lx, ly = source["position"]
        if math.hypot(px - lx, py - ly) < reach + EMITTER_CLEARANCE:
            return False

    for obstacle in level["obstacles"]:
        poly = obstacle["polygon"]
        if point_in_polygon(px, py, poly):
            return False
        for i, (ax, ay) in enumerate(poly):
            bx, by = poly[(i + 1) % len(poly)]
            if beam_sim.point_to_segment(px, py, ax, ay, bx, by) < reach + OBSTACLE_CLEARANCE:
                return False

    return True


def place_decoys(level: dict, count: int, rng: random.Random) -> list[dict]:
    """Scatter decoys that hug the winning beam without ever touching it."""
    if count <= 0:
        return []

    segments = beam_sim.trace(level, beam_sim.reachable_solution(level)).segments
    if not segments:
        return []

    length = level["mirrors"][0]["length"]
    template = level["mirrors"][0]
    reach = length / 2.0
    placed: list[dict] = []
    occupied = list(level["mirrors"])

    for _ in range(PLACEMENT_TRIES):
        if len(placed) == count:
            break

        ax, ay, bx, by = rng.choice(segments)
        span = math.hypot(bx - ax, by - ay)
        if span < 1:
            continue
        t = rng.uniform(0.12, 0.88)
        nx, ny = -(by - ay) / span, (bx - ax) / span
        side = rng.choice((1, -1))
        # Sit just outside the exclusion band so the decoy reads as part of
        # the layout rather than as scenery pushed into a corner.
        offset = reach + BEAM_CLEARANCE + rng.uniform(6, 120)
        px = ax + (bx - ax) * t + nx * side * offset
        py = ay + (by - ay) * t + ny * side * offset

        if not placement_ok(px, py, level, segments, length, occupied):
            continue

        decoy = {
            "id": f"d{len(placed) + 1}",
            "hingePosition": [round(px, 2), round(py, 2)],
            "length": length,
            "initialAngle": round(rng.uniform(12.0, 168.0), 2),
            "minAngle": template["minAngle"],
            "maxAngle": template["maxAngle"],
            "snapIncrement": 0.0,
            "isLocked": False,
            "type": "standard",
        }
        placed.append(decoy)
        occupied.append(decoy)

    return placed


def healthy(level: dict, required: int | None) -> bool:
    """The level still behaves exactly as it did before it was touched."""
    if not beam_sim.solves(level, beam_sim.reachable_solution(level)):
        return False
    if beam_sim.solves(level, {}):
        return False
    result = beam_sim.trace(level, beam_sim.reachable_solution(level))
    for crystal in level["targetCrystals"]:
        if result.bounces.get(crystal["id"]) != required:
            return False
    return True


def enrich(level: dict, index: int, total: int, cap: int = DEFAULT_MAX_DECOYS) -> tuple[dict, int]:
    original = json.loads(json.dumps(level))
    required = level.get("requiredMirrorBounces")
    if not healthy(original, required):
        return original, 0

    # Free rotation hands these mirrors to the magnetic alignment detents,
    # which are skipped for anything that snaps to fixed steps.
    for mirror in level["mirrors"]:
        mirror["snapIncrement"] = 0.0

    solution_mirrors = len(level["mirrors"])
    rng = random.Random(level["levelId"])
    decoys = place_decoys(level, wanted_decoys(index, total, cap), rng)

    while decoys:
        level["mirrors"] = original["mirrors"] + decoys
        for mirror in level["mirrors"]:
            mirror["snapIncrement"] = 0.0
        if healthy(level, required):
            break
        decoys.pop()

    if not decoys:
        level["mirrors"] = [dict(m, snapIncrement=0.0) for m in original["mirrors"]]

    if decoys:
        # Reaching for a decoy now costs a move, so widen the budget a little.
        level["starThresholds"]["threeStarMoveCount"] = (
            solution_mirrors + 1 + len(decoys) // 2
        )
        level["metadata"]["decoyCount"] = len(decoys)

    if not healthy(level, required):
        return original, 0
    return level, len(decoys)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalogue", default=str(root / "assets/levels/levels.json"))
    parser.add_argument("--max-decoys", type=int, default=DEFAULT_MAX_DECOYS)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    path = Path(args.catalogue)
    data = json.loads(path.read_text(encoding="utf-8"))
    levels = data["levels"]
    total = len(levels)

    enriched: list[dict] = []
    decoy_total = 0
    untouched: list[str] = []
    histogram: dict[int, int] = {}

    for i, level in enumerate(levels, start=1):
        result, decoys = enrich(level, i, total, args.max_decoys)
        enriched.append(result)
        decoy_total += decoys
        histogram[decoys] = histogram.get(decoys, 0) + 1
        if decoys == 0 and i > TUTORIAL_LEVELS:
            untouched.append(result["levelId"])

    print(f"levels: {total}")
    print(f"decoy mirrors added: {decoy_total}")
    print("decoys per level: " + ", ".join(
        f"{k}->{v}" for k, v in sorted(histogram.items())
    ))
    print(f"levels past the tutorial with no room for a decoy: {len(untouched)}")
    print("snap-free mirrors: " + str(
        sum(1 for l in enriched for m in l["mirrors"] if m["snapIncrement"] == 0)
    ))

    broken = [
        l["levelId"] for l in enriched
        if not healthy(l, l.get("requiredMirrorBounces"))
    ]
    print(f"levels failing verification: {len(broken)} {broken[:5]}")
    if broken:
        print("refusing to write", file=sys.stderr)
        return 1

    if args.dry_run:
        print("dry run: no file written")
        return 0

    backups = root / ".level-backups"
    backups.mkdir(exist_ok=True)
    backup = backups / f"levels.pre-enrich.{time.strftime('%Y%m%d-%H%M%S')}.json"
    shutil.copy2(path, backup)
    print(f"backed up to .level-backups/{backup.name}")

    payload = {"schemaVersion": data.get("schemaVersion", 1), "levels": enriched}
    path.write_text(
        json.dumps(payload, indent=1) if args.pretty
        else json.dumps(payload, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"wrote {path} ({path.stat().st_size / 1_048_576:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
