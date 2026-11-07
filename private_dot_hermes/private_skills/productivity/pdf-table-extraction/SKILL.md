---
name: pdf-table-extraction
description: "Use when a PDF's data is positional: comparison tables."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [pdf, tables, comparison, extraction, coordinates, pymupdf]
    category: productivity
    related_skills: [pdf, docx, xlsx]
---

# PDF Table Extraction

Recover table structure from PDFs where plain text extraction destroys it.
The `pdf` skill owns file manipulation and OCR; this skill owns reading a
table whose MEANING lives in cell POSITION rather than in the text stream.

## When to Use

Load this the moment the user asks you to COMPARE, RANK, or pick a winner
across rows/columns/options in a PDF: insurance quotes, supplier bids, plan
tiers, tariff tables, spec sheets, any multi-column matrix.

Don't use for: linear prose, plain single-column forms, or when `pdf_read.py
--tables` already returns correct cells — try that first.

## The failure this prevents

A comparison table read linearly yields a flat bag of interleaved text. Row A
col 1, then row B col 1, then row A col 2 — all as one blob with no idea which
cell owns which number. Every price, every coverage flag, and every "included
/ optional / excluded" marker is then unattributable. **NEVER compare values
you have not bound to a cell.** If you cannot name the row and column a number
came from, you do not have that number.

## Procedure

1. **Find the column geometry first.** Dump words with coordinates, bucket
   them by y, then print the set of distinct x-starts. Column left edges are
   the giveaway:

   ```python
   pg.get_text("words")   # (x0, y0, x1, y1, word, block, line, word_no)
   ```

   Bucket rows with `round(y0 / line_height) * line_height`, not the page's
   raw y, so wrapped cell text lands on the same band. Identify the label
   column (smallest x range, usually x < 155) and each entity column.
   Confirm your split threshold against the actual x values before trusting
   any downstream comparison.

2. **Split the text by column.** For each band, concatenate only words whose
   x0 falls inside that column's range. This alone recovers most of the table
   and tells you the shape of what you're dealing with.

3. **Recover icons as first-class cells.** Comparison tables encode status as
   small repeated images (included / optional / excluded). `get_drawings()`
   usually finds NOTHING here — these are embedded raster icons. Go through
   `page.get_images(full=True)` + `page.get_image_bbox(im)`, skip
   `rect == (1,1,-1,-1)` (unplaced masks), and keep the rest.

4. **Decode the icons by their legend, not by eyeballing.** Find the legend
   row (it names each status in words next to its icon). Hash each icon's
   pixel buffer:

   ```python
   pix = pymupdf.Pixmap(doc, xref)
   key = hashlib.md5(bytes(pix.samples)).hexdigest()[:10]
   ```

   Build `hash -> status` from the legend, then map every icon in the body.
   Colours and shapes vary per document — the pixel hash is the only reliable
   identifier. Reserve `vision_analyze` for confirming crops, never for the
   systematic pass.

5. **Assign each icon to the row whose label band contains its y.** Bound a
   row as `[label_y, next_label_y)` and collect the icons whose `y0` falls in
   that interval, in x-column order. Dedupe repeated identical statuses
   within a cell while PRESERVING order.

6. **Cross-check what the pipeline cannot see.** A systematically empty cell
   is not a finding — it can mean the row continues, is merged, or is genuinely
   absent. Render the suspicious region (`page.get_pixmap(dpi=260, clip=...)`)
   and confirm with `vision_analyze` before reporting a gap.

7. **Reconcile the brochure against the quote.** Comparison PDFs often append
   per-product "information sheet" pages that describe a DIFFERENT tier than
   the one quoted. Cross-check what the brochure lists as basic vs optional
   against what the comparison grid marks as included, and flag the conflict.
   A broker comparison is also usually disclaimed as "orientative" — quote
   that disclaimer when it matters.

## Pitfalls

- **Interpolated text is not cell text.** A y-bucket of ±1-2 pt splits a
  wrapped line in half and interleaves two cells. Bucket by line height and
  re-tune per page.
- **Unplaced image masks pollute icon extraction.** Filter `y0 == 1 and
  x0 == 1` (a `-1` width) or every row gains a phantom "status".
- **Identical icons repeat within one cell** (a row may legitimately be
  included with several sub-bullets). Dedupe per row-band, not globally.
- **Trusting `vision_analyze` for the full table is slow and lossy** — a
  crop it cannot fully see comes back hedged ("not present in this crop").
  Use it to CONFIRM the coordinate pipeline's output on two or three
  ambiguous spots, then trust the geometry.
- **Assuming the header row is text.** Company/plan names are often logos
  with no text layer. Bind prices to their column by x-position and confirm
  the column identity visually once per document.
- **Reporting a premium difference without confirming both premiums are the
  same kind of number** (annual total vs instalment, with vs without tax).

## Verification

- [ ] Every number in the output is attributable to a named row AND column.
- [ ] The icon legend was decoded from the document itself, not assumed.
- [ ] At least one ambiguous or apparently-empty cell was confirmed by a
      rendered crop.
- [ ] Brochure pages were cross-checked against the quoted tier.
- [ ] Arithmetic (differences, percentages) recomputed from the extracted
      figures, and rounded currency kept in its original format.

## Reporting shape

Give the verdict FIRST, then the figures behind it. For each difference: what
it is, which side has it, and the euro amount. Close with the caveats that
would change the decision (expiry dates, disclaimers, brochure conflicts)
and an offer to draft the follow-up question to the broker. Keep it in the
language the user wrote in.

`scripts/extract_comparison_table.py` implements steps 1-5 end to end:
`python extract_comparison_table.py TABLE.pdf --pages 1-4` prints the legend
it decoded plus one row per label with both columns' text and statuses.
