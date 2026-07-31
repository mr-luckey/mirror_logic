#!/usr/bin/env python3
"""Regenerates the shipped WebP/OGG assets from the PNG/WAV masters.

The masters stay in the repository as the source of truth for the artwork, but
they are not listed in pubspec.yaml and therefore never reach the APK. Only the
files this script writes are bundled. Re-run it after replacing a master:

    python3 tool/optimize_assets.py

Requires Pillow (`pip install Pillow`) and oggenc (`brew install vorbis-tools`).
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Only the artwork the game actually loads. Anything absent from this list is a
# master or an unused variant and stays out of the bundle.
IMAGES = {
    "assets/images/medieval": [
        "crystal_cut",
        "emitter_cut",
        "wall_h_cut",
        "wall_v_cut",
        "torch_cut",
        "torch_base_cut",
        "vine_cut",
    ],
    "assets/images/ui": [
        "crest",
        "tome",
        "wreath",
        "padlock",
        *[f"tome_ch{i}" for i in range(1, 11)],
    ],
}

WEBP_QUALITY = 88

# Vorbis quality per folder. Music loops for minutes so it dominates the budget;
# the one-shots are tiny either way and get a higher setting to keep their
# transients crisp. Every master is mono already.
AUDIO_QUALITY = {
    "assets/audio/music": "2",
    "assets/audio/sfx": "5",
}


def convert_images() -> tuple[int, int]:
    from PIL import Image

    src_total = out_total = 0
    for folder, names in IMAGES.items():
        for name in names:
            src = os.path.join(ROOT, folder, f"{name}.png")
            dst = os.path.join(ROOT, folder, f"{name}.webp")
            image = Image.open(src).convert("RGBA")
            image.save(dst, "WEBP", quality=WEBP_QUALITY, method=6)
            src_size, dst_size = os.path.getsize(src), os.path.getsize(dst)
            src_total += src_size
            out_total += dst_size
            print(
                f"  {folder}/{name}: {src_size / 1024:.0f}K png -> "
                f"{dst_size / 1024:.0f}K webp"
            )
    return src_total, out_total


def convert_audio() -> tuple[int, int]:
    src_total = out_total = 0
    for folder, quality in AUDIO_QUALITY.items():
        directory = os.path.join(ROOT, folder)
        for entry in sorted(os.listdir(directory)):
            if not entry.endswith(".wav"):
                continue
            src = os.path.join(directory, entry)
            dst = os.path.join(directory, entry[: -len(".wav")] + ".ogg")
            subprocess.run(
                ["oggenc", "-Q", "-q", quality, "-o", dst, src],
                check=True,
            )
            src_size, dst_size = os.path.getsize(src), os.path.getsize(dst)
            src_total += src_size
            out_total += dst_size
            print(
                f"  {folder}/{entry}: {src_size / 1024:.0f}K wav -> "
                f"{dst_size / 1024:.0f}K ogg"
            )
    return src_total, out_total


def main() -> int:
    print("images")
    img_src, img_out = convert_images()
    print("audio")
    aud_src, aud_out = convert_audio()

    src = img_src + aud_src
    out = img_out + aud_out
    print(
        f"\nbundled assets: {src / 1048576:.2f} MB of masters -> "
        f"{out / 1048576:.2f} MB shipped "
        f"({(1 - out / src) * 100:.1f}% smaller)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
