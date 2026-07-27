#!/usr/bin/env python3
"""Render an SVG specimen sheet for the WhatChord Symbols family.

For every glyph it draws Regular and Bold side by side, each sitting in its
advance-width box with the baseline, the advance edges, and the ink edges
(sidebearings) marked. Dependency-free: uses fontTools' SVGPathPen.

Run with:  mise run symbols:specimen
"""

from html import escape
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parents[1]

FONTS = [
    ("Regular", REPO_ROOT / "assets/fonts/WhatChordSymbols-Regular.otf"),
    ("Bold", REPO_ROOT / "assets/fonts/WhatChordSymbols-Bold.otf"),
]
OUTPUT = TOOL_DIR / "specimen.svg"

SCALE = 0.15  # px per font unit (1000-unit em -> 150px)
ASC, DESC = 900, -300  # framing extents (font units), not real metrics
CELL_W = 200  # px width of one weight's cell
LABEL_W = 230  # px width of the left label column
ROW_GAP = 26  # px between rows
PAD = 30  # px outer margin

CELL_H = round((ASC - DESC) * SCALE)
ROW_H = CELL_H + ROW_GAP


def load():
    """Return [(weight, TTFont, cmap)] and the shared codepoint->glyph map."""
    loaded = []
    for weight, path in FONTS:
        f = TTFont(path)
        loaded.append((weight, f, f.getBestCmap()))
    return loaded


def cell_svg(font: TTFont, gname: str, ox: float, oy: float) -> str:
    """SVG for one glyph in one weight, top-left of the cell at (ox, oy)."""
    adv = font["hmtx"][gname][0]
    gs = font.getGlyphSet()
    bp = BoundsPen(gs)
    gs[gname].draw(bp)
    xmin, xmax = (bp.bounds[0], bp.bounds[2]) if bp.bounds else (0, 0)

    # Center the advance box within the cell horizontally.
    box_px = adv * SCALE
    gx = ox + (CELL_W - box_px) / 2
    baseline = oy + ASC * SCALE  # font y=0 lands here
    g = f"translate({gx:.2f},{baseline:.2f}) scale({SCALE},{-SCALE})"

    pen = SVGPathPen(gs)
    gs[gname].draw(pen)
    d = pen.getCommands()

    def vline(x, cls):
        return f'<line x1="{x}" y1="{DESC}" x2="{x}" y2="{ASC}" class="{cls}"/>'

    parts = [f'<g transform="{g}">']
    # advance box edges + baseline
    parts.append(vline(0, "adv"))
    parts.append(vline(adv, "adv"))
    parts.append(f'<line x1="0" y1="0" x2="{adv}" y2="0" class="base"/>')
    # ink edges (sidebearings)
    parts.append(vline(xmin, "ink"))
    parts.append(vline(xmax, "ink"))
    parts.append(f'<path d="{d}" class="glyph"/>')
    parts.append("</g>")

    # sidebearing readout under the cell
    lsb, rsb = round(xmin), round(adv - xmax)
    parts.append(
        f'<text x="{ox + CELL_W / 2:.1f}" y="{oy + CELL_H + 16:.1f}" '
        f'class="sb">adv {adv}  ·  sb {lsb}/{rsb}</text>'
    )
    return "".join(parts)


def main() -> None:
    fonts = load()
    # Glyph order/cmap from the first font; assume both share it.
    base_font, base_cmap = fonts[0][1], fonts[0][2]
    glyph_to_cp = {g: cp for cp, g in base_cmap.items()}
    glyphs = [g for g in base_font.getGlyphOrder() if g in glyph_to_cp]

    width = LABEL_W + len(fonts) * CELL_W + 2 * PAD
    height = PAD + 40 + len(glyphs) * ROW_H + PAD

    out = [
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
            f'height="{height}" viewBox="0 0 {width} {height}" '
            f'font-family="ui-sans-serif,system-ui,sans-serif">'
        ),
        (
            "<style>"
            ".glyph{fill:#111}"
            ".adv{stroke:#c8c8c8;stroke-width:1;vector-effect:non-scaling-stroke}"
            ".base{stroke:#9bb;stroke-width:1;vector-effect:non-scaling-stroke}"
            ".ink{stroke:#e08;stroke-width:1;stroke-dasharray:3 3;"
            "vector-effect:non-scaling-stroke}"
            ".sb{fill:#888;font-size:11px;text-anchor:middle}"
            ".lbl{fill:#222;font-size:13px}"
            ".sub{fill:#888;font-size:11px}"
            ".hdr{fill:#111;font-size:14px;font-weight:600;text-anchor:middle}"
            "</style>"
        ),
        f'<rect width="{width}" height="{height}" fill="#fff"/>',
    ]

    # Column headers
    for i, (weight, _) in enumerate(FONTS):
        cx = PAD + LABEL_W + i * CELL_W + CELL_W / 2
        out.append(f'<text x="{cx:.1f}" y="{PAD + 22}" class="hdr">{weight}</text>')

    for r, gname in enumerate(glyphs):
        oy = PAD + 40 + r * ROW_H
        cp = glyph_to_cp[gname]
        # label
        out.append(
            f'<text x="{PAD}" y="{oy + CELL_H / 2 - 4:.1f}" class="lbl">'
            f"U+{cp:04X}</text>"
        )
        out.append(
            f'<text x="{PAD}" y="{oy + CELL_H / 2 + 14:.1f}" class="sub">'
            f"{escape(gname)}</text>"
        )
        for i, (_, font, _) in enumerate(fonts):
            ox = PAD + LABEL_W + i * CELL_W
            out.append(cell_svg(font, gname, ox, oy))

    out.append("</svg>")
    OUTPUT.write_text("\n".join(out))
    print(f"Wrote {OUTPUT} ({len(glyphs)} glyphs x {len(fonts)} weights).")


if __name__ == "__main__":
    main()
