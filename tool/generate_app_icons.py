"""Generate the Android and iOS launcher icons from the master app icon art.

The master is a rounded-square badge sitting on a transparent 1024px canvas, so
it already *is* an icon shape and has to be used full bleed. Two things get in
the way of that and both are handled here:

  * iOS artwork may not carry an alpha channel, and Android 8+ gives a bare
    mipmap the legacy-icon treatment, which shrinks it onto a white rounded
    plate. Flattening onto white or black would show as a border around the
    badge, so every transparent pixel is instead filled with the colour of the
    nearest opaque one. The system mask trims most of that fill away and what
    survives reads as more stone rather than a flat wedge.
  * An adaptive icon only shows the inner 72dp of its 108dp layers; the outer
    18dp ring exists for the launcher's parallax. The badge is therefore placed
    in that inner viewport and the ring gets the same extended fill, so the mask
    frames the whole badge and no pass over it can reveal a gap.
"""

import os
import sys

from PIL import Image, ImageChops, ImageMath

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = os.path.join(ROOT, 'assets', 'branding', 'app_icon_master.png')
ANDROID_RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
IOS_ICONS = os.path.join(
    ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset',
)
PLAY_STORE_ICON = os.path.join(ROOT, 'assets', 'branding', 'play_store_512.png')

# The faint glow the generator sprays outside the badge fades to a couple of
# alpha steps; cropping to that would keep a wide invisible margin and shrink
# the badge, so the crop follows the solid shape instead.
SOLID_ALPHA = 200

# Legacy launcher icon, in px per density bucket.
LEGACY_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

# Adaptive layers are 108dp square.
ADAPTIVE_SIZES = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
}

ADAPTIVE_VIEWPORT = 72 / 108

IOS_SIZES = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}

ADAPTIVE_XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@android:color/transparent" />
</adaptive-icon>
'''


def solid_bounds(alpha):
    """Bounding box of the pixels that are actually part of the badge."""
    w, h = alpha.size
    data = alpha.tobytes()
    left, right, top, bottom = w, -1, h, -1
    for y in range(h):
        row = data[y * w:(y + 1) * w]
        hit = False
        for x, value in enumerate(row):
            if value > SOLID_ALPHA:
                hit = True
                if x < left:
                    left = x
                if x > right:
                    right = x
        if hit:
            if y < top:
                top = y
            bottom = y
    if right < 0:
        raise SystemExit('master art has no opaque pixels')
    return left, top, right + 1, bottom + 1


def square_crop(im):
    """Crop the master down to its badge, kept square so nothing stretches."""
    left, top, right, bottom = solid_bounds(im.getchannel('A'))
    side = max(right - left, bottom - top)
    cx = (left + right) / 2
    cy = (top + bottom) / 2
    box = (
        round(cx - side / 2),
        round(cy - side / 2),
        round(cx - side / 2) + side,
        round(cy - side / 2) + side,
    )
    # A badge that runs to the edge of the master needs the canvas grown rather
    # than the crop clamped, or the square turns into a rectangle again.
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(im.crop(box), (0, 0))
    return canvas


def _unpremultiply(premultiplied, alpha):
    # Dividing by alpha + 1 keeps fully transparent pixels from blowing up; the
    # one-step bias is invisible and those pixels are replaced anyway.
    return Image.merge('RGB', [
        ImageMath.lambda_eval(
            lambda args: args['convert'](args['c'] * 255 / (args['a'] + 1), 'L'),
            c=channel,
            a=alpha,
        )
        for channel in premultiplied.split()
    ])


def extend_fill(im):
    """Push the badge's colours outward over every transparent pixel.

    Averaging colours down a mip pyramid and pulling them back up spreads the
    nearest opaque colour into the holes. Premultiplying first is what keeps the
    transparent pixels from dragging black into those averages.
    """
    alpha = im.getchannel('A')
    flat = Image.merge('RGB', (alpha, alpha, alpha))
    levels = [(ImageChops.multiply(im.convert('RGB'), flat), alpha)]
    while max(levels[-1][0].size) > 1:
        colour, mask = levels[-1]
        half = (max(1, colour.width // 2), max(1, colour.height // 2))
        levels.append((colour.resize(half, Image.BOX), mask.resize(half, Image.BOX)))

    filled = _unpremultiply(*levels[-1])
    for colour, mask in reversed(levels[:-1]):
        coarse = filled.resize(colour.size, Image.BILINEAR)
        filled = Image.composite(_unpremultiply(colour, mask), coarse, mask)
    return filled


def resize_rgba(filled, alpha, size):
    """Scale the badge without the dark fringe an RGBA resize would leave."""
    out = filled.resize((size, size), Image.LANCZOS).convert('RGBA')
    out.putalpha(alpha.resize((size, size), Image.LANCZOS))
    return out


def adaptive_background(badge):
    """The badge inside the 72dp viewport, its colours bled into the ring."""
    side = round(badge.width / ADAPTIVE_VIEWPORT)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(badge, ((side - badge.width) // 2, (side - badge.height) // 2))
    return extend_fill(canvas)


def main():
    if not os.path.exists(MASTER):
        print('missing master art', MASTER)
        return 1

    badge = square_crop(Image.open(MASTER).convert('RGBA'))
    filled = extend_fill(badge)
    alpha = badge.getchannel('A')
    print(f'badge: {badge.size} from master {Image.open(MASTER).size}')

    for bucket, size in LEGACY_SIZES.items():
        path = os.path.join(ANDROID_RES, bucket, 'ic_launcher.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        resize_rgba(filled, alpha, size).save(path, 'PNG')
        print(f'{bucket}/ic_launcher.png: {size}px')

    background = adaptive_background(badge)
    for bucket, size in ADAPTIVE_SIZES.items():
        path = os.path.join(ANDROID_RES, bucket, 'ic_launcher_background.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        background.resize((size, size), Image.LANCZOS).save(path, 'PNG')
        print(f'{bucket}/ic_launcher_background.png: {size}px')

    xml_dir = os.path.join(ANDROID_RES, 'mipmap-anydpi-v26')
    os.makedirs(xml_dir, exist_ok=True)
    with open(os.path.join(xml_dir, 'ic_launcher.xml'), 'w') as handle:
        handle.write(ADAPTIVE_XML)
    print('mipmap-anydpi-v26/ic_launcher.xml')

    for name, size in IOS_SIZES.items():
        path = os.path.join(IOS_ICONS, name)
        if not os.path.exists(path):
            print('unexpected: no such iOS slot', name)
        filled.resize((size, size), Image.LANCZOS).save(path, 'PNG')
        print(f'{name}: {size}px opaque')

    filled.resize((512, 512), Image.LANCZOS).save(PLAY_STORE_ICON, 'PNG')
    print('assets/branding/play_store_512.png: 512px opaque')
    return 0


if __name__ == '__main__':
    sys.exit(main())
