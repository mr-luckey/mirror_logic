#!/usr/bin/env python3
"""Batch-fix tip→m1 beam travel < MIN_BEAM by translating geometry inward."""
from __future__ import annotations

import json
import math
import sys
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))
from generate_levels_extreme import mounted_origin, simulate, validate  # noqa: E402

LEVELS = ROOT / "assets" / "levels"
OUT = ROOT / ".cursor" / "_light_gap_fix_report.txt"
MIN_BEAM = 180.0
LIGHT_GAP = 110.0
SAFE = (60.0, 60.0, 1020.0, 1860.0)  # xmin, ymin, xmax, ymax for hinges/crystals
WALL_SOFT = (-40.0, -40.0, 1120.0, 1960.0)  # walls clearly OOB beyond this


def detect_format(raw: str) -> str:
    s = raw.lstrip()
    if "\n" not in raw.rstrip("\n") or raw.count("\n") <= 1:
        return "compact"
    return "indent2"


def dumps(level: dict, fmt: str) -> str:
    if fmt == "compact":
        return json.dumps(level, separators=(",", ":")) + "\n"
    return json.dumps(level, indent=2) + "\n"


def resolve_m1(level: dict):
    mirrors = level.get("mirrors") or []
    for m in mirrors:
        if m.get("id") == "m1":
            return m
    return mirrors[0] if mirrors else None


def tip_m1_travel(level: dict):
    lights = level.get("lightSources") or []
    if not lights:
        return None
    ls = lights[0]
    pos = ls.get("position")
    if not pos or len(pos) < 2:
        return None
    direction = float(ls.get("direction", 0))
    tip = mounted_origin(pos, direction)
    m1 = resolve_m1(level)
    if not m1:
        return None
    hp = m1.get("hingePosition")
    if not hp or len(hp) < 2:
        return None
    rad = math.radians(direction)
    ux, uy = math.cos(rad), math.sin(rad)
    travel = (float(hp[0]) - tip.x) * ux + (float(hp[1]) - tip.y) * uy
    return travel, tip, (float(hp[0]), float(hp[1])), direction, ux, uy


def shift_xy(pt, dx, dy):
    return [float(pt[0]) + dx, float(pt[1]) + dy]


def translate_level(level: dict, dx: float, dy: float) -> dict:
    out = deepcopy(level)
    for m in out.get("mirrors") or []:
        hp = m.get("hingePosition")
        if hp and len(hp) >= 2:
            m["hingePosition"] = shift_xy(hp, dx, dy)
    for c in out.get("targetCrystals") or []:
        pos = c.get("position")
        if pos and len(pos) >= 2:
            c["position"] = shift_xy(pos, dx, dy)
    for o in out.get("obstacles") or []:
        poly = o.get("polygon")
        if poly:
            o["polygon"] = [shift_xy(p, dx, dy) for p in poly]
    for ls in out.get("lightSources") or []:
        pos = ls.get("position")
        if pos and len(pos) >= 2:
            ls["position"] = shift_xy(pos, dx, dy)
    meta = out.get("metadata")
    if isinstance(meta, dict):
        pillars = meta.get("pillars")
        if isinstance(pillars, list):
            for p in pillars:
                if isinstance(p, dict) and p.get("position") and len(p["position"]) >= 2:
                    p["position"] = shift_xy(p["position"], dx, dy)
    return out


def snap_light(level: dict, m1_xy, direction: float) -> None:
    """Place lightSources[0] between tip and m1 with ~110px gap from m1 toward tip."""
    mx, my = m1_xy
    if abs(direction - 180.0) < 1:
        xy = [mx + LIGHT_GAP, my]
    elif abs(direction - 0.0) < 1:
        xy = [mx - LIGHT_GAP, my]
    elif abs(direction - 90.0) < 1:
        xy = [mx, my - LIGHT_GAP]
    else:
        xy = [mx, my + LIGHT_GAP]
    level["lightSources"][0]["position"] = xy


def in_safe(x, y) -> bool:
    return SAFE[0] <= x <= SAFE[2] and SAFE[1] <= y <= SAFE[3]


def geometry_ok(level: dict) -> bool:
    for m in level.get("mirrors") or []:
        hp = m.get("hingePosition")
        if not hp or not in_safe(float(hp[0]), float(hp[1])):
            return False
    for c in level.get("targetCrystals") or []:
        pos = c.get("position")
        if not pos or not in_safe(float(pos[0]), float(pos[1])):
            return False
    for o in level.get("obstacles") or []:
        for p in o.get("polygon") or []:
            x, y = float(p[0]), float(p[1])
            if x < WALL_SOFT[0] or y < WALL_SOFT[1] or x > WALL_SOFT[2] or y > WALL_SOFT[3]:
                return False
    return True


def count_short(files) -> int:
    n = 0
    for path in files:
        try:
            level = json.loads(path.read_text())
        except Exception:
            continue
        info = tip_m1_travel(level)
        if info and info[0] < MIN_BEAM:
            n += 1
    return n


def validate_ok(level: dict) -> bool:
    if not validate(level):
        return False
    sol = {k: float(v) for k, v in level["intendedSolution"]["mirrorAngles"].items()}
    lit, hits = simulate(level, sol)
    n = len(level.get("mirrors") or [])
    req = level.get("requiredMirrorBounces")
    return "c1" in lit and hits == n == req


def main() -> int:
    files = sorted(LEVELS.glob("ch*.json"))
    before = count_short(files)
    fixed, needs_reharden, failed, skipped = [], [], [], []

    for path in files:
        try:
            raw = path.read_text()
            level = json.loads(raw)
        except Exception as e:
            skipped.append((path.name, f"json:{e}"))
            continue
        info = tip_m1_travel(level)
        if info is None:
            skipped.append((path.name, "no tip/m1"))
            continue
        travel, tip, m1_xy, direction, ux, uy = info
        if travel >= MIN_BEAM:
            continue
        if travel <= 0:
            needs_reharden.append((path.name, f"nonpositive_travel={travel:.1f}"))
            continue

        needed = MIN_BEAM - travel
        if abs(direction - 180.0) < 1:
            dx, dy = -needed, 0.0
        elif abs(direction - 0.0) < 1:
            dx, dy = needed, 0.0
        elif abs(direction - 90.0) < 1:
            dx, dy = 0.0, needed
        elif abs(direction - 270.0) < 1:
            dx, dy = 0.0, -needed
        else:
            skipped.append((path.name, f"bad_dir={direction}"))
            continue

        snapshot = raw
        fmt = detect_format(raw)
        candidate = translate_level(level, dx, dy)
        # m1 after translate
        m1 = resolve_m1(candidate)
        new_m1 = (float(m1["hingePosition"][0]), float(m1["hingePosition"][1]))
        snap_light(candidate, new_m1, direction)

        if not geometry_ok(candidate):
            needs_reharden.append((path.name, f"oob_after_shift needed={needed:.1f}"))
            continue

        if not validate_ok(candidate):
            # revert — do not write
            failed.append((path.name, f"validate_fail needed={needed:.1f}"))
            # ensure file untouched
            if path.read_text() != snapshot:
                path.write_text(snapshot)
            continue

        path.write_text(dumps(candidate, fmt))
        new_info = tip_m1_travel(candidate)
        fixed.append((path.name, travel, new_info[0] if new_info else None, needed))

    after_files = sorted(LEVELS.glob("ch*.json"))
    after = count_short(after_files)

    lines = []
    lines.append("LIGHT GAP BATCH FIX REPORT")
    lines.append("=" * 72)
    lines.append(f"MIN_BEAM = {MIN_BEAM}")
    lines.append(f"levels scanned: {len(files)}")
    lines.append(f"before tip→m1 < {MIN_BEAM:.0f}: {before}")
    lines.append(f"after  tip→m1 < {MIN_BEAM:.0f}: {after}")
    lines.append(f"fixed: {len(fixed)}")
    lines.append(f"needs_reharden: {len(needs_reharden)}")
    lines.append(f"failed (reverted): {len(failed)}")
    lines.append(f"skipped: {len(skipped)}")
    lines.append("")
    lines.append("FIXED")
    lines.append("-" * 72)
    for name, before_t, after_t, needed in fixed:
        lines.append(
            f"  {name:14s}  before={before_t:7.1f}  after={after_t:7.1f}  shift={needed:.1f}"
        )
    lines.append("")
    lines.append("NEEDS_REHARDEN")
    lines.append("-" * 72)
    for name, why in needs_reharden:
        lines.append(f"  {name:14s}  {why}")
    lines.append("")
    lines.append("FAILED (reverted)")
    lines.append("-" * 72)
    for name, why in failed:
        lines.append(f"  {name:14s}  {why}")
    if skipped:
        lines.append("")
        lines.append("SKIPPED")
        lines.append("-" * 72)
        for name, why in skipped:
            lines.append(f"  {name:14s}  {why}")

    text = "\n".join(lines) + "\n"
    OUT.write_text(text)
    print(text)
    print(f"Wrote {OUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
