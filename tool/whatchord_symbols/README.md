# WhatChord Symbols tooling

This folder contains the scripts used to regenerate the bundled WhatChord
Symbols fonts from local copies of the Leland font files.

The upstream source fonts are not committed. Download `LelandText.otf` and
`Leland.otf` from the Leland project and place them in this folder:

- <https://github.com/MuseScoreFonts/Leland>

Regenerate the app font assets:

```sh
mise run symbols:build
```

Generate a local SVG specimen sheet for inspecting sidebearings and bold weight:

```sh
mise run symbols:specimen
```

Generated outputs:

- `../../assets/fonts/WhatChordSymbols-Regular.otf` (Flutter app)
- `../../assets/fonts/WhatChordSymbols-Bold.otf` (Flutter app)
- `../../docs/site/public/fonts/WhatChordSymbols-Regular.woff2` (website)
- `../../docs/site/public/fonts/WhatChordSymbols-Bold.woff2` (website)
- `specimen.svg`

The website self-hosts the woff2 copies; `docs/site/public/css/style.css`
declares them via `@font-face` and prepends the family to `--font`.

`LelandText.otf`, `Leland.otf`, and `specimen.svg` are intentionally ignored by
git.

## Glyph proportions

The quality marks are tuned to modern engraving practice rather than copied at
Leland's default proportions. The relevant knobs live near the top of
`build_font.py`:

- **Diminished `°` and half-diminished `ø`** source Leland's small-alternate
  rings (`U+F4D7`/`U+F4D8`) rather than the full-size glyphs, so they read as
  raised quality marks instead of a letter-height circle that looks like an O or
  a notehead. `RAISE` lifts both into the upper "degree" register;
  `CENTERED_PAIR` centers them on a shared advance and ink center so the rings
  coincide exactly and only the slash distinguishes them (no horizontal jump
  when toggling between the two).
- **Stroke weight**: the small alternates ship with a thin stroke meant for tiny
  superscript use. `RING_WEIGHT` thickens the rings (both weights) up to the
  full-size `csymMajorSeventh` delta's wall so the set looks cohesive; the Bold
  instance then stacks `BOLD_STRENGTH` on top.
- **Major seventh `Δ`** stays at cap height on the baseline (a triangle is not
  confusable with a letter), and the augmented `+` and minor `−` keep Leland's
  drawn proportions.

Regenerate and check `specimen.svg` after changing any of these.
