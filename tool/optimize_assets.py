#!/usr/bin/env python3
"""Shrink shipped assets without changing what the game loads.

1. Minify every level/catalog JSON (identical data, whitespace removed).
2. Recompress the theme preview thumbnails, which were exported near-lossless.

Both steps are byte-safe for the app: JSON is consumed via `jsonDecode`, and the
thumbnails keep their pixel dimensions so layout is unchanged.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEVELS = ROOT / "assets" / "levels"
THEMES = ROOT / "assets" / "images" / "themes"

# Thumbnails were saved near-lossless; 82 is visually indistinguishable at this
# size but an order of magnitude smaller.
THUMB_QUALITY = 82


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f}{unit}" if unit != "B" else f"{n}B"
        n /= 1024


def minify_json() -> tuple[int, int]:
    before = after = 0
    for path in sorted(LEVELS.glob("*.json")):
        raw = path.read_bytes()
        before += len(raw)
        data = json.loads(raw)
        packed = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
        packed_bytes = packed.encode("utf-8")
        # Sanity: round-trips to identical data before we overwrite.
        assert json.loads(packed_bytes) == data, f"mismatch in {path.name}"
        path.write_bytes(packed_bytes)
        after += len(packed_bytes)
    return before, after


def recompress_thumbs() -> tuple[int, int]:
    from PIL import Image

    before = after = 0
    for thumb in sorted(THEMES.glob("*/thumb.webp")):
        before += thumb.stat().st_size
        with Image.open(thumb) as im:
            im = im.convert("RGB")
            im.save(thumb, "WEBP", quality=THUMB_QUALITY, method=6)
        after += thumb.stat().st_size
    return before, after


def main() -> None:
    jb, ja = minify_json()
    print(f"levels JSON: {human(jb)} -> {human(ja)}  (saved {human(jb - ja)})")

    tb, ta = recompress_thumbs()
    print(f"thumbnails:  {human(tb)} -> {human(ta)}  (saved {human(tb - ta)})")

    print(f"total saved: {human((jb - ja) + (tb - ta))}")


if __name__ == "__main__":
    main()
