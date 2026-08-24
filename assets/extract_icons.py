#!/usr/bin/env python3
"""
Deterministic extraction of individual icons from assets/raw/*.

- icons_raw.jpeg, icons_raw_2.jpeg: each a grid of icon+label cells.
  Detects row bands, splits each row into an icon sub-band and a label
  sub-band via whitespace-gap projection, detects icon columns within
  the icon sub-band, and crops each icon (label text excluded).
- raw_arkad_face_icon.jpeg: a single icon on a white background. Crops
  tightly to the non-white content bounding box.

Detection is purely geometric (background-color distance + projection
gap-finding) so re-running on the same source images always yields the
same output. Row label text (used only for output filenames) is a
transcription of the fixed header text in icons_raw.jpeg, since no OCR
dependency is assumed to be installed.
"""

import re
from pathlib import Path

import numpy as np
from PIL import Image

RAW_DIR = Path(__file__).parent / "raw"
OUT_DIR = Path(__file__).parent / "extracted"

# Text labels for each of the 10 columns in each of the 4 rows of
# icons_raw.jpeg, transcribed left-to-right, top-to-bottom from the
# image header text.
ROW_LABELS = [
    ["Income", "Groceries", "Dining", "Investments", "Stocks",
     "Savings 1", "Savings 2", "Goals", "Credit Cards", "Crypto"],
    ["Subscriptions", "Transport", "Housing", "Settings", "Profile",
     "Bills Up", "Debts 1", "Debts 2", "Taxes", "Transfer"],
    ["General", "Wallet", "Chat", "Search", "Notifications", "Export",
     "Add", "Filter", "Sort", "Security"],
    ["Cash", "Balance", "Receipts", "Rewards", "Advisor",
     "Categories", "Transactions", "Trend", "Analysis"],
]

# Text labels for each of the 5 columns in each of the 4 rows of
# icons_raw_2.jpeg, transcribed left-to-right, top-to-bottom from the
# image header text. "Subscriptions Alt" is renamed from the sheet's
# actual "Subscriptions" label to avoid colliding with the icon_subscriptions
# key already extracted from icons_raw.jpeg.
ROW_LABELS_2 = [
    ["Bills", "Business", "Cable", "Car", "Educational"],
    ["Electricity", "Events", "Gas", "Gym", "Shopping"],
    ["Home", "Hobbies", "Internet", "Medical", "Self-care"],
    ["Tech gear", "Supplies", "Subscriptions Alt", "Tolls", "Water"],
]


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")


def ink_mask(arr: np.ndarray, threshold: float = 30.0) -> np.ndarray:
    corners = np.array([arr[0, 0], arr[0, -1], arr[-1, 0], arr[-1, -1]])
    bg = corners.mean(axis=0)
    dist = np.sqrt(((arr.astype(int) - bg) ** 2).sum(axis=2))
    return dist > threshold, bg


def find_bands(proj: np.ndarray, gap_thresh: int, min_gap_run: int, min_size: int):
    """Find contiguous index ranges where proj > gap_thresh, tolerating
    gaps of up to min_gap_run consecutive low-value samples (so small
    intra-glyph gaps, e.g. between a fork and knife icon, don't split
    a single icon into two bands)."""
    bands = []
    in_band = False
    start = 0
    gap_run = 0
    n = len(proj)
    for i, v in enumerate(proj):
        is_gap = v <= gap_thresh
        if not is_gap:
            if not in_band:
                in_band = True
                start = i
            gap_run = 0
        else:
            if in_band:
                gap_run += 1
                if gap_run > min_gap_run:
                    end = i - gap_run
                    if end - start >= min_size:
                        bands.append((start, end))
                    in_band = False
    if in_band:
        bands.append((start, n - 1))
    return bands


def extract_icon_grid(
    src_filename: str,
    row_labels: list[list[str]],
    row_gap: int = 15,
    label_gap: int = 8,
):
    """row_gap and label_gap tolerate up to that many consecutive
    low-ink rows/columns without splitting a band — they must bridge
    the icon-to-label gap and multi-word label gaps (e.g. "Tech gear")
    without merging across separate rows/labels. The right values scale
    with the source image's resolution, so differ per sheet."""
    src = RAW_DIR / src_filename
    im = Image.open(src).convert("RGB")
    arr = np.array(im)
    mask, _bg = ink_mask(arr)

    row_sum = mask.sum(axis=1)
    # Whole-row bands (icon+label together), skipping the title/subtitle
    # header text at the top of the image.
    all_row_bands = find_bands(row_sum, gap_thresh=2, min_gap_run=row_gap, min_size=5)
    grid_row_bands = all_row_bands[-len(row_labels):]

    count = 0
    for row_idx, (rs, re) in enumerate(grid_row_bands):
        sub_row_sum = row_sum[rs:re + 1]
        sub_bands = find_bands(sub_row_sum, gap_thresh=2, min_gap_run=3, min_size=3)
        if len(sub_bands) < 1:
            continue
        icon_rs, icon_re = sub_bands[0]
        icon_rs, icon_re = rs + icon_rs, rs + icon_re
        label_band = None
        if len(sub_bands) >= 2:
            lrs, lre = sub_bands[1]
            label_band = (rs + lrs, rs + lre)

        icon_col_sum = mask[icon_rs:icon_re + 1, :].sum(axis=0)
        icon_cols = find_bands(icon_col_sum, gap_thresh=1, min_gap_run=20, min_size=3)

        label_cols = []
        if label_band is not None:
            lrs, lre = label_band
            label_col_sum = mask[lrs:lre + 1, :].sum(axis=0)
            label_cols = find_bands(label_col_sum, gap_thresh=1, min_gap_run=label_gap, min_size=3)

        labels = row_labels[row_idx]
        names = assign_names(icon_cols, label_cols, labels, row_idx)

        pad = 4
        h, w = arr.shape[:2]
        for (cx0, cx1), name in zip(icon_cols, names):
            top = max(0, icon_rs - pad)
            bottom = min(h, icon_re + 1 + pad)
            left = max(0, cx0 - pad)
            right = min(w, cx1 + 1 + pad)
            crop = im.crop((left, top, right, bottom))
            out_path = OUT_DIR / f"icon_{name}.png"
            crop.save(out_path)
            count += 1
    print(f"{src_filename} -> {count} icons extracted")


def assign_names(icon_cols, label_cols, labels, row_idx):
    """Pair icon columns (by x position) with their label text.
    If there are more icon columns than labels, the icon column(s)
    with the largest distance to any label center are treated as
    unlabeled (named positionally), and the rest are paired in
    left-to-right order."""
    n_icons = len(icon_cols)
    n_labels = len(label_cols)

    if n_icons == n_labels:
        return [slugify(lbl) for lbl in labels[:n_icons]]

    icon_centers = [(a + b) / 2 for a, b in icon_cols]
    label_centers = [(a + b) / 2 for a, b in label_cols]

    if n_icons > n_labels and n_labels > 0:
        deficit = n_icons - n_labels
        dists = []
        for i, ic in enumerate(icon_centers):
            nearest = min(abs(ic - lc) for lc in label_centers)
            dists.append((nearest, i))
        dists.sort(reverse=True)
        unlabeled_idx = {i for _, i in dists[:deficit]}

        names = [None] * n_icons
        label_iter = iter(labels)
        for i in range(n_icons):
            if i in unlabeled_idx:
                names[i] = f"row{row_idx + 1}_extra{list(sorted(unlabeled_idx)).index(i) + 1}"
            else:
                names[i] = slugify(next(label_iter))
        return names

    # Fallback: fewer or equal labels than icons with no label bands at all.
    return [f"row{row_idx + 1}_col{i + 1}" for i in range(n_icons)]


def extract_face_icon():
    src = RAW_DIR / "raw_arkad_face_icon.jpeg"
    im = Image.open(src).convert("RGB")
    arr = np.array(im)

    # The source has a white background and rounded black corner
    # artifacts (from the export tool), both of which are near-
    # grayscale (R == G == B). The illustration itself is colorful, so
    # thresholding on channel spread isolates it from both background
    # elements without hardcoding a background color.
    spread = arr.astype(int).max(axis=2) - arr.astype(int).min(axis=2)
    content = spread > 15

    rows = np.where(content.any(axis=1))[0]
    cols = np.where(content.any(axis=0))[0]
    top, bottom = rows.min(), rows.max()
    left, right = cols.min(), cols.max()

    pad = 6
    h, w = arr.shape[:2]
    top = max(0, top - pad)
    bottom = min(h, bottom + 1 + pad)
    left = max(0, left - pad)
    right = min(w, right + 1 + pad)

    crop = im.crop((left, top, right, bottom))
    crop.save(OUT_DIR / "arkad_face.png")
    print("raw_arkad_face_icon.jpeg -> arkad_face.png extracted")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    extract_icon_grid("icons_raw.jpeg", ROW_LABELS)
    extract_icon_grid("icons_raw_2.jpeg", ROW_LABELS_2, row_gap=40, label_gap=15)
    extract_face_icon()


if __name__ == "__main__":
    main()
