#!/usr/bin/env python3
"""
Seat every locked mirror at the angle the intended solution needs.

A locked mirror can never be dragged, so if it ships at an angle other than the
one the solution requires, the level simply cannot be won. The generator marked
mirrors locked but left them at their scrambled starting angle, which made most
of the catalog unwinnable. Locking is still a valid mechanic — the mirror just
has to already be pointing the right way, acting as a fixed bounce post the
player has to route around.

Usage:
  python tool/fix_locked_mirrors.py
"""

from __future__ import annotations

import argparse
import json


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/levels/levels.json")
    parser.add_argument(
        "--unlock-missing",
        action="store_true",
        help="Unlock locked mirrors the solution says nothing about.",
    )
    args = parser.parse_args()

    with open(args.catalog, "r", encoding="utf-8") as fh:
        root = json.load(fh)

    seated = 0
    unlocked = 0
    touched_levels = 0

    for level in root["levels"]:
        solution = level.get("intendedSolution", {}).get("mirrorAngles", {})
        changed = False
        for mirror in level["mirrors"]:
            if not mirror.get("isLocked"):
                continue
            target = solution.get(mirror["id"])
            if target is None:
                # Nothing pins this mirror down; leaving it locked at a random
                # angle is just dead geometry.
                if args.unlock_missing:
                    mirror["isLocked"] = False
                    unlocked += 1
                    changed = True
                continue
            if mirror["initialAngle"] != target:
                mirror["initialAngle"] = target
                seated += 1
                changed = True
        if changed:
            touched_levels += 1

    with open(args.catalog, "w", encoding="utf-8") as fh:
        json.dump(root, fh, indent=2)

    print(f"locked mirrors seated at their solution angle: {seated}")
    print(f"locked mirrors unlocked (no solution angle): {unlocked}")
    print(f"levels changed: {touched_levels}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
