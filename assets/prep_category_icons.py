#!/usr/bin/env python3
"""
Derives red/green duotone-tinted versions of assets/extracted/icon_*.png
for use as category icons (see lib/models/category.dart, STYLE_GUIDE.md
§ Category management).

The extracted icons are drawn as a two-color duotone on a solid near-cream
background: a dark ink-green outline plus a lighter sage fill (no alpha
channel). This script:

1. Estimates each icon's background color from its corner pixels and maps
   per-pixel distance from it to an alpha channel (background -> fully
   transparent, glyph -> fully opaque, smooth ramp between for antialiased
   edges).
2. Reclassifies the glyph's two duotone shades by luminance and remaps them
   onto a target color's own dark/light pair (full-strength for what was
   ink, a white-lightened tint for what was sage) — preserving the original
   art's shading instead of flattening it to one flat silhouette color.

Output goes to assets/extracted/tinted/{green,red}/, one pre-baked pair per
icon, matching AppColors.darkGreen (income) and AppColors.clay (expense) in
lib/theme/app_colors.dart. Baking both variants ahead of time avoids
runtime tinting, which can only apply a single flat color and would lose
the duotone shading. Deterministic — re-running regenerates the same
output from the source PNGs.
"""

from pathlib import Path

import numpy as np
from PIL import Image

SRC_DIR = Path(__file__).parent / "extracted"
OUT_DIR = SRC_DIR / "tinted"

# Distance-from-background band (Euclidean, 0-441 range) over which alpha
# ramps from fully transparent to fully opaque.
ALPHA_LOW = 12.0
ALPHA_HIGH = 45.0

# Luminance band separating the source art's ink outline from its sage
# fill, empirically measured across the extracted set.
DARK_LUM = 55.0
LIGHT_LUM = 180.0

# How far toward white the "fill" shade sits, relative to each target
# color's full strength — mirrors the source art's ink-to-sage contrast.
LIGHT_MIX = 0.62

# Must match lib/theme/app_colors.dart.
TARGETS = {
    "green": (0x24, 0x4F, 0x3A),  # AppColors.darkGreen — income
    "red": (0xC8, 0x78, 0x65),  # AppColors.clay — expense
}


def duotone_tint(path: Path, target: tuple[int, int, int]) -> Image.Image:
    im = Image.open(path).convert("RGB")
    arr = np.array(im).astype(float)

    corners = np.array([arr[0, 0], arr[0, -1], arr[-1, 0], arr[-1, -1]])
    bg = corners.mean(axis=0)
    dist = np.sqrt(((arr - bg) ** 2).sum(axis=2))
    alpha = np.clip((dist - ALPHA_LOW) / (ALPHA_HIGH - ALPHA_LOW), 0.0, 1.0)

    lum = arr.mean(axis=2)
    fill_fraction = np.clip((lum - DARK_LUM) / (LIGHT_LUM - DARK_LUM), 0.0, 1.0)[..., None]

    target_arr = np.array(target, dtype=float)
    light_arr = target_arr + (255 - target_arr) * LIGHT_MIX
    rgb = target_arr * (1 - fill_fraction) + light_arr * fill_fraction

    rgba = np.dstack([rgb.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    return Image.fromarray(rgba, mode="RGBA")


def main():
    count = 0
    for color_name, target in TARGETS.items():
        out_dir = OUT_DIR / color_name
        out_dir.mkdir(parents=True, exist_ok=True)
        for src in sorted(SRC_DIR.glob("icon_*.png")):
            duotone_tint(src, target).save(out_dir / src.name)
            count += 1
    print(f"{count} tinted icons -> {OUT_DIR}")


if __name__ == "__main__":
    main()
