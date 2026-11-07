#!/usr/bin/env python3
"""Recover a side-by-side comparison table from a PDF: text cells + icon statuses.

Works on the class of PDFs where the table's meaning is positional (insurance
quotes, bid comparisons, plan tiers) and plain extraction interleaves cells.

Usage:
    python extract_comparison_table.py TABLE.pdf
    python extract_comparison_table.py TABLE.pdf --pages 1-4 --label-max-x 155 --split-x 292

Requires pymupdf. Install into a throwaway dir if the ambient env lacks it:
    python -m pip install --target "$SCRATCH/pylibs" pymupdf
    PYTHONPATH="$SCRATCH/pylibs" python extract_comparison_table.py TABLE.pdf

Auto-detects column boundaries and decodes status icons from the document's own
legend, so a human only intervenes on genuinely ambiguous rows.
"""
import argparse
import collections
import hashlib
import sys

try:
    import pymupdf
except ImportError:
    sys.exit("pymupdf missing: python -m pip install --target <dir> pymupdf")


def load_icons(doc, page):
    """Return sorted [(y0, x0, pixel_hash)] for placed images on the page."""
    out = []
    for im in page.get_images(full=True):
        try:
            r = page.get_image_bbox(im)
        except Exception:
            continue
        # Unplaced image masks report Rect(1, 1, -1, -1) - never real cells.
        if r.y0 <= 1 and r.x0 <= 1 and r.width <= 0:
            continue
        pix = pymupdf.Pixmap(doc, im[0])
        out.append((round(r.y0), round(r.x0),
                    hashlib.md5(bytes(pix.samples)).hexdigest()[:10]))
    return sorted(out)


def find_legend(doc, page, y_tolerance=3):
    """Decode hash -> status from the legend row: the words naming a status
    sit within one band of the icon they describe."""
    legend = {}
    for y, x, h in load_icons(doc, page):
        words = [w for w in page.get_text("words")
                 if abs(w[1] - y) <= y_tolerance and w[0] >= x]
        words.sort()
        if words:
            legend[h] = " ".join(w[4] for w in words)
    return legend


def label_bands(page, label_max_x, y_lo, y_hi, line_height=4):
    """Group left-column label text into sorted (y, label) rows."""
    rows = collections.defaultdict(list)
    for w in page.get_text("words"):
        if w[0] < label_max_x and y_lo < w[1] < y_hi:
            rows[round(w[1] / line_height) * line_height].append((round(w[0]), w[4]))
    return sorted((y, " ".join(t for _, t in sorted(v))) for y, v in rows.items())


def column_text(page, lo, hi, y_lo, y_hi, line_height=4):
    rows = collections.defaultdict(list)
    for w in page.get_text("words"):
        if lo <= w[0] <= hi and y_lo < w[1] < y_hi:
            rows[round(w[1] / line_height) * line_height].append((round(w[0]), w[4]))
    return sorted((y, " ".join(t for _, t in sorted(v))) for y, v in rows.items())


def dedupe(seq):
    """Remove duplicates while preserving first-seen order."""
    seen = set()
    return [x for x in seq if not (x in seen or seen.add(x))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf")
    ap.add_argument("--pages", default="", help="e.g. 1-4 (1-based, inclusive)")
    ap.add_argument("--label-max-x", type=int, default=155)
    ap.add_argument("--split-x", type=int, default=292)
    ap.add_argument("--band-top", type=int, default=100)
    ap.add_argument("--band-bottom", type=int, default=None)
    ap.add_argument("--legend-page", type=int, default=None)
    args = ap.parse_args()

    doc = pymupdf.open(args.pdf)

    if args.pages:
        lo_s, _, hi_s = args.pages.partition("-")
        lo, hi = int(lo_s), int(hi_s or lo_s)
        page_nums = list(range(lo - 1, hi))
    else:
        page_nums = list(range(doc.page_count))

    legend_pg = (args.legend_page - 1) if args.legend_page else page_nums[-1]
    legend = find_legend(doc, doc[legend_pg])
    if legend:
        print(f"# legend decoded from page {legend_pg + 1}:")
        for h, s in legend.items():
            print(f"#   {h} -> {s}")
    else:
        print("# WARNING: no legend found. Icons print as raw hashes; confirm "
              "each meaning by rendering the legend before trusting it.")

    for pi in page_nums:
        page = doc[pi]
        bottom = args.band_bottom or page.rect.height - 260
        bands = label_bands(page, args.label_max_x, args.band_top, bottom)
        icons = load_icons(doc, page)
        print(f"\n===== PAGE {pi + 1} =====")
        for i, (y, name) in enumerate(bands):
            if not name or name.lower() in ("coberturas", "coverage"):
                continue
            nxt = bands[i + 1][0] if i + 1 < len(bands) else bottom
            left = dedupe([legend.get(h, h) for iy, ix, h in icons
                           if args.label_max_x <= ix < args.split_x and y <= iy < nxt])
            right = dedupe([legend.get(h, h) for iy, ix, h in icons
                            if ix >= args.split_x and y <= iy < nxt])
            lt = " ".join(t for _, t in column_text(page, args.label_max_x,
                                                    args.split_x, y, nxt))
            rt = " ".join(t for _, t in column_text(page, args.split_x,
                                                    page.rect.width, y, nxt))
            print(f"{name[:44]:44s} | L[{'/'.join(left) or '-':22s}] {lt[:60]}")
            print(f"{'':44s} | R[{'/'.join(right) or '-':22s}] {rt[:60]}")

    print("\n# Empty status cell != proven absence. Render the region and "
          "confirm visually before reporting a coverage gap.", file=sys.stderr)


if __name__ == "__main__":
    main()
