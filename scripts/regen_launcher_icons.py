#!/usr/bin/env python3
"""
Regenerate launcher-icon source assets from assets/icon/arkad-icon.png.

Root cause being fixed: arkad-icon.png is a fully pre-composed rounded-squircle
(solid green body + yellow leaf glyph, transparent outside) that gets reused for
BOTH image_path and adaptive_icon_foreground in pubspec.yaml's
flutter_launcher_icons config. That defeats Android's adaptive-icon
background/foreground layering (which is supposed to apply proper corner
rounding via the OS mask) and produces jagged corners at small legacy mipmap
sizes.

This script produces two new source images:
  - arkad-icon-foreground.png: leaf glyph ONLY, transparent everywhere else,
    for use as adaptive_icon_foreground.
  - arkad-icon-square.png: the original squircle flattened onto an opaque
    #244F3A background of the same canvas size, producing a plain square with
    no transparent corners, for use as image_path (legacy/iOS icon source).
"""

import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_PATH = REPO_ROOT / "assets" / "icon" / "arkad-icon.png"
FOREGROUND_OUT = REPO_ROOT / "assets" / "icon" / "arkad-icon-foreground.png"
SQUARE_OUT = REPO_ROOT / "assets" / "icon" / "arkad-icon-square.png"

# Exact colors sampled from the source image (most-common-pixel histogram):
#   (36, 79, 58, 255)   -> #244F3A  green body      (824878 px)
#   (245, 214, 107, 255)-> #F5D66B  leaf glyph       (85360 px)
#   (0, 0, 0, 0)                    transparent exterior (131765 px)
GREEN = (36, 79, 58)
LEAF = (245, 214, 107)

# Pixels whose computed foreground alpha falls below this are snapped to 0.
# The squircle's outer green-to-transparent anti-aliasing ring introduces tiny
# (~1-20) stray alpha values purely from PNG re-encoding noise, even though
# those pixels are nowhere near the leaf glyph. Empirically (checked across
# floors 4/8/16/24/32/48) the real leaf-glyph edge sits on the far side of a
# clean gap from this noise -- the resulting glyph bbox is identical at every
# floor in that range, so 16 is a safe cutoff that only removes noise.
ALPHA_FLOOR = 16

CANVAS = 1024
# Android adaptive-icon safe zone: centered ~66% of the canvas.
SAFE_MIN = 174
SAFE_MAX = 850


def color_dist(px, color):
    return (
        (px[0] - color[0]) ** 2
        + (px[1] - color[1]) ** 2
        + (px[2] - color[2]) ** 2
    ) ** 0.5


def build_foreground(src: Image.Image) -> Image.Image:
    w, h = src.size
    src_px = src.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = src_px[x, y]
            if a == 0:
                continue  # already-transparent exterior stays transparent
            px = (r, g, b)
            d_leaf = color_dist(px, LEAF)
            d_green = color_dist(px, GREEN)
            denom = d_leaf + d_green
            if denom == 0:
                continue
            # Fraction of "leaf-ness" for this pixel. Pixels that are a
            # blend between leaf and green (anti-aliased edge of the glyph)
            # get a proportional alpha, giving a soft edge instead of a hard
            # cutoff. Pixels that are pure green (or a green/transparent
            # blend from the squircle's outer edge) collapse to ~0 because
            # d_leaf stays large relative to d_green.
            t = d_green / denom
            alpha = int(round(a * t))
            if alpha < ALPHA_FLOOR:
                continue
            out_px[x, y] = (LEAF[0], LEAF[1], LEAF[2], alpha)

    return out


def clamp_bbox_to_safe_zone(img: Image.Image) -> Image.Image:
    alpha = img.split()[3]
    bbox = alpha.getbbox()
    if bbox is None:
        print("WARNING: foreground image has no non-transparent pixels!")
        return img

    left, top, right, bottom = bbox
    print(f"Foreground glyph bbox before safe-zone check: {bbox}")

    if left >= SAFE_MIN and top >= SAFE_MIN and right <= SAFE_MAX and bottom <= SAFE_MAX:
        print("Glyph bbox already within adaptive-icon safe zone.")
        return img

    print("Glyph bbox outside safe zone -- scaling down and re-centering.")
    glyph_w = right - left
    glyph_h = bottom - top
    safe_size = SAFE_MAX - SAFE_MIN
    scale = min(safe_size / glyph_w, safe_size / glyph_h)

    cropped = img.crop(bbox)
    new_w = max(1, int(round(glyph_w * scale)))
    new_h = max(1, int(round(glyph_h * scale)))
    resized = cropped.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
    paste_x = (img.size[0] - new_w) // 2
    paste_y = (img.size[1] - new_h) // 2
    canvas.paste(resized, (paste_x, paste_y), resized)

    new_bbox = canvas.split()[3].getbbox()
    print(f"Glyph bbox after rescale/recenter: {new_bbox}")
    return canvas


def build_square(src: Image.Image) -> Image.Image:
    bg = Image.new("RGBA", src.size, (*GREEN, 255))
    bg.alpha_composite(src)
    return bg.convert("RGBA")


def main():
    if not SRC_PATH.exists():
        print(f"ERROR: source image not found at {SRC_PATH}", file=sys.stderr)
        sys.exit(1)

    src = Image.open(SRC_PATH).convert("RGBA")
    if src.size != (CANVAS, CANVAS):
        print(f"NOTE: source image is {src.size}, not {CANVAS}x{CANVAS}.")

    print(f"Loaded {SRC_PATH} ({src.size[0]}x{src.size[1]})")

    # --- Foreground (glyph-only, transparent background) ---
    foreground = build_foreground(src)
    foreground = clamp_bbox_to_safe_zone(foreground)
    foreground.save(FOREGROUND_OUT)
    print(f"Wrote {FOREGROUND_OUT}")

    # --- Square (flattened onto opaque green background) ---
    square = build_square(src)
    square.save(SQUARE_OUT)
    print(f"Wrote {SQUARE_OUT}")

    # --- Assertions / sanity checks ---
    fg_px = foreground.load()
    w, h = foreground.size
    corners_fg = {
        "top-left": fg_px[0, 0],
        "top-right": fg_px[w - 1, 0],
        "bottom-left": fg_px[0, h - 1],
        "bottom-right": fg_px[w - 1, h - 1],
    }
    print("Foreground corner pixels (expect alpha ~0):")
    for name, val in corners_fg.items():
        print(f"  {name}: {val}")
    assert all(v[3] <= 2 for v in corners_fg.values()), (
        "Foreground image corners are not transparent!"
    )

    fg_bbox = foreground.split()[3].getbbox()
    assert fg_bbox is not None, "Foreground image has no visible glyph!"
    fw, fh = foreground.size
    print(f"Foreground glyph bbox: {fg_bbox} (canvas {fw}x{fh})")
    assert (
        SAFE_MIN <= fg_bbox[0]
        and SAFE_MIN <= fg_bbox[1]
        and fg_bbox[2] <= SAFE_MAX
        and fg_bbox[3] <= SAFE_MAX
    ), "Foreground glyph bbox is outside the adaptive-icon safe zone!"

    sq_px = square.load()
    w2, h2 = square.size
    corners_sq = {
        "top-left": sq_px[0, 0],
        "top-right": sq_px[w2 - 1, 0],
        "bottom-left": sq_px[0, h2 - 1],
        "bottom-right": sq_px[w2 - 1, h2 - 1],
    }
    print("Square corner pixels (expect alpha 255, color == green bg):")
    for name, val in corners_sq.items():
        print(f"  {name}: {val}")
    assert all(v[3] == 255 for v in corners_sq.values()), (
        "Square image corners are not fully opaque!"
    )

    print("\nAll assertions passed.")


if __name__ == "__main__":
    main()
