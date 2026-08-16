#!/usr/bin/env python3
"""
Derives a transparent-background version of assets/extracted/arkad_face.png
for use as the Arkad mascot across the app (dashboard greeting, chat avatar,
profile avatar, onboarding). See STYLE_GUIDE.md and lib/models/category.dart's
categoryIconAsset for the sibling category-icon tinting pipeline this mirrors.

arkad_face.png is a flat, multi-color illustration on a solid white
background with no alpha channel. This script keys out that background by
sampling the four corner pixels (assumed background) and mapping per-pixel
distance from that reference to an alpha channel — background fully
transparent, art fully opaque, with a short ramp for antialiased edges.
Unlike prep_category_icons.py, no color remapping is applied: the source
art's original colors are preserved as-is.

Output: assets/extracted/arkad_face_transparent.png. Deterministic —
re-running regenerates the same output from the source PNG.
"""

from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(__file__).parent / "extracted" / "arkad_face.png"
OUT = Path(__file__).parent / "extracted" / "arkad_face_transparent.png"

# Distance-from-background band (Euclidean, 0-441 range) over which alpha
# ramps from fully transparent to fully opaque. Narrower than
# prep_category_icons.py's band since this source art has hard edges.
ALPHA_LOW = 8.0
ALPHA_HIGH = 24.0


def keyed_alpha(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    arr = np.array(im).astype(float)

    corners = np.array([arr[0, 0], arr[0, -1], arr[-1, 0], arr[-1, -1]])
    bg = corners.mean(axis=0)
    dist = np.sqrt(((arr - bg) ** 2).sum(axis=2))
    alpha = np.clip((dist - ALPHA_LOW) / (ALPHA_HIGH - ALPHA_LOW), 0.0, 1.0)

    rgba = np.dstack([arr.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    return Image.fromarray(rgba, mode="RGBA")


def main():
    keyed_alpha(SRC).save(OUT)
    print(f"1 transparent icon -> {OUT}")


if __name__ == "__main__":
    main()
