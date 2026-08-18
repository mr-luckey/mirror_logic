#!/usr/bin/env python3
"""Scan all ch*.json levels for light→mirror hinge gaps."""
from __future__ import annotations

import json
import math
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS = ROOT / "assets" / "levels"
OUT = ROOT / ".cursor" / "_light_gap_scan.txt"
THRESHOLDS = (50, 80, 100, 120, 150, 170, 200, 250)


def dist(a, b) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def first_mirror_id(level: dict) -> str | None:
    sol = level.get("intendedSolution") or {}
    angles = sol.get("mirrorAngles") if isinstance(sol, dict) else None
    if isinstance(angles, dict) and angles:
        # Prefer m1, else lowest mN
        if "m1" in angles:
            return "m1"
        keys = sorted(
            (k for k in angles if isinstance(k, str) and k.startswith("m")),
            key=lambda k: int(k[1:]) if k[1:].isdigit() else 10**9,
        )
        if keys:
            return keys[0]
    mirrors = level.get("mirrors") or []
    if mirrors:
        return mirrors[0].get("id") or "m1"
    return None


def hinge_for(level: dict, mid: str):
    for m in level.get("mirrors") or []:
        if m.get("id") == mid:
            hp = m.get("hingePosition")
            if hp and len(hp) >= 2:
                return (float(hp[0]), float(hp[1]))
    return None


def nearest_hinge(level: dict, light_xy):
    best = None
    best_d = float("inf")
    best_id = None
    for m in level.get("mirrors") or []:
        hp = m.get("hingePosition")
        if not hp or len(hp) < 2:
            continue
        h = (float(hp[0]), float(hp[1]))
        d = dist(light_xy, h)
        if d < best_d:
            best_d = d
            best = h
            best_id = m.get("id")
    return best_id, best, best_d


def main() -> int:
    files = sorted(LEVELS.glob("ch*.json"))
    rows = []
    skipped = []

    for path in files:
        try:
            level = json.loads(path.read_text())
        except Exception as e:
            skipped.append((path.name, f"json:{e}"))
            continue
        lights = level.get("lightSources") or []
        if not lights:
            skipped.append((path.name, "no lightSources"))
            continue
        pos = lights[0].get("position")
        if not pos or len(pos) < 2:
            skipped.append((path.name, "bad light position"))
            continue
        light_xy = (float(pos[0]), float(pos[1]))
        light_dir = float(lights[0].get("direction", 0))

        mid = first_mirror_id(level)
        m1_hinge = hinge_for(level, mid) if mid else None
        d_m1 = dist(light_xy, m1_hinge) if m1_hinge else None

        nid, nh, d_near = nearest_hinge(level, light_xy)
        if d_near == float("inf"):
            skipped.append((path.name, "no mirrors"))
            continue

        # Primary metric: intended first bounce (m1) if available, else nearest
        primary = d_m1 if d_m1 is not None else d_near
        primary_label = "m1" if d_m1 is not None else "nearest"
        primary_id = mid if d_m1 is not None else nid
        primary_hinge = m1_hinge if d_m1 is not None else nh

        rows.append(
            {
                "file": path.name,
                "light": light_xy,
                "dir": light_dir,
                "m1_id": mid,
                "m1_hinge": m1_hinge,
                "d_m1": d_m1,
                "near_id": nid,
                "near_hinge": nh,
                "d_near": d_near,
                "primary": primary,
                "primary_label": primary_label,
                "primary_id": primary_id,
                "primary_hinge": primary_hinge,
                "m1_is_nearest": (mid == nid) if mid and nid else None,
            }
        )

    # Counts by thresholds on primary distance
    below = {t: 0 for t in THRESHOLDS}
    below_near = {t: 0 for t in THRESHOLDS}
    below_m1 = {t: 0 for t in THRESHOLDS}
    for r in rows:
        for t in THRESHOLDS:
            if r["primary"] < t:
                below[t] += 1
            if r["d_near"] < t:
                below_near[t] += 1
            if r["d_m1"] is not None and r["d_m1"] < t:
                below_m1[t] += 1

    close = [r for r in rows if r["primary"] < 150]
    close.sort(key=lambda r: r["primary"])
    worst = sorted(rows, key=lambda r: r["primary"])[:40]

    # Side distribution for close levels
    side_counter = Counter()
    for r in close:
        d = r["dir"]
        if abs(d - 180) < 1:
            side_counter["east(180)"] += 1
        elif abs(d - 0) < 1:
            side_counter["west(0)"] += 1
        elif abs(d - 90) < 1:
            side_counter["north(90)"] += 1
        elif abs(d - 270) < 1:
            side_counter["south(270)"] += 1
        else:
            side_counter[f"other({d})"] += 1

    m1_ne_near = sum(1 for r in rows if r["m1_is_nearest"] is False)
    no_m1 = sum(1 for r in rows if r["d_m1"] is None)

    lines = []
    lines.append("LIGHT→MIRROR GAP SCAN")
    lines.append("=" * 72)
    lines.append(f"levels scanned: {len(rows)}")
    lines.append(f"skipped: {len(skipped)}")
    lines.append(f"m1 != nearest hinge: {m1_ne_near}")
    lines.append(f"no m1 resolvable: {no_m1}")
    lines.append("")
    lines.append("COUNTS: primary distance (lightSources[0].position → intended m1 hinge,")
    lines.append("         else nearest hinge if m1 missing)")
    for t in THRESHOLDS:
        lines.append(f"  < {t:3d}: {below[t]}")
    lines.append("")
    lines.append("COUNTS: nearest hinge only")
    for t in THRESHOLDS:
        lines.append(f"  < {t:3d}: {below_near[t]}")
    lines.append("")
    lines.append("COUNTS: intended m1 only (levels with resolvable m1)")
    for t in THRESHOLDS:
        lines.append(f"  < {t:3d}: {below_m1[t]}")
    lines.append("")
    lines.append(f"ALL levels with primary distance < 150 ({len(close)}):")
    lines.append("-" * 72)
    for r in close:
        ph = r["primary_hinge"]
        lines.append(
            f"{r['file']:14s}  d={r['primary']:7.1f}  via={r['primary_label']}:{r['primary_id']}"
            f"  light=({r['light'][0]:.0f},{r['light'][1]:.0f})"
            f"  hinge=({ph[0]:.0f},{ph[1]:.0f})"
            f"  dir={r['dir']:.0f}"
            f"  near={r['d_near']:.1f}/{r['near_id']}"
            + (f"  m1={r['d_m1']:.1f}" if r["d_m1"] is not None else "")
        )
    lines.append("")
    lines.append(f"Side distribution among primary<150: {dict(side_counter)}")
    lines.append("")
    lines.append("WORST OFFENDERS (smallest primary gap, top 40):")
    lines.append("-" * 72)
    for r in worst:
        ph = r["primary_hinge"]
        lines.append(
            f"{r['file']:14s}  d={r['primary']:7.1f}  light=({r['light'][0]:.1f},{r['light'][1]:.1f})"
            f"  {r['primary_id']}@({ph[0]:.1f},{ph[1]:.1f})  dir={r['dir']:.0f}"
            f"  d_near={r['d_near']:.1f}  d_m1={r['d_m1'] if r['d_m1'] is not None else 'n/a'}"
        )

    # Gap along beam axis analysis for close levels
    lines.append("")
    lines.append("BEAM-AXIS GAP (for primary<150): signed travel from light to hinge")
    lines.append("along beam direction unit vector (positive = hinge ahead of light):")
    lines.append("-" * 72)
    for r in close[:80]:
        rad = math.radians(r["dir"])
        ux, uy = math.cos(rad), math.sin(rad)
        lx, ly = r["light"]
        hx, hy = r["primary_hinge"]
        axial = (hx - lx) * ux + (hy - ly) * uy
        perp = abs((hx - lx) * (-uy) + (hy - ly) * ux)
        lines.append(
            f"{r['file']:14s}  euclid={r['primary']:7.1f}  axial={axial:7.1f}  perp={perp:6.1f}"
        )

    if skipped:
        lines.append("")
        lines.append(f"SKIPPED ({len(skipped)}):")
        for name, why in skipped[:50]:
            lines.append(f"  {name}: {why}")

    # light_setup reference dump
    lines.append("")
    lines.append("REFERENCE: light_setup(direction, first) in tool/_harden_one.py")
    lines.append("-" * 72)
    lines.append("  dir≈180 → light_xy=(950, first.y), tip/light_m=(1028, first.y), beam=(-1,0), side=east")
    lines.append("  dir≈0   → light_xy=(130, first.y), tip/light_m=(52, first.y),  beam=(1,0),  side=west")
    lines.append("  dir≈90  → light_xy=(first.x, 130), tip/light_m=(first.x, 52),  beam=(0,1),  side=north")
    lines.append("  else270 → light_xy=(first.x, 1790), tip/light_m=(first.x, 1868), beam=(0,-1), side=south")
    lines.append("  Note: lightSources[].position stores light_xy (fixture), simulation uses")
    lines.append("  mounted_origin(pos, direction) which snaps tip to WALL_INSET=52 on the")
    lines.append("  entry wall (matching light_m). Euclidean light_xy→first hinge is therefore")
    lines.append("  |950-first.x| for east starts, |130-first.x| west, |130-first.y| north,")
    lines.append("  |1790-first.y| south — IF first hinge shares the axis coordinate.")
    lines.append("  candidate_starts places first hinge on XS[-1]/XS[0]/YS[0..1]/YS[-1..-2],")
    lines.append("  so gap depends on grid edge vs fixed light fixture coords.")

    text = "\n".join(lines) + "\n"
    OUT.write_text(text)
    print(text)
    print(f"Wrote {OUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
