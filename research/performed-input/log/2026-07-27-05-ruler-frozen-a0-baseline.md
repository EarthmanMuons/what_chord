# 2026-07-27: Ruler v1 frozen, split frozen, first A0 baseline

**Goal.** Execute the approved freeze (log -04): fix the ruler definition into
PROTOCOL.md, freeze the split, build the scorer, and record the first
live-identity baseline.

**Setup.**

```sh
.venv/bin/python tool/whatkey/asap_wir_extract.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --bench-root build/whatkey-corpora/contrapunctus-bench \
  --analysis-profile whatKeyPaper2026     # timeline entries now carry beatMs
.venv/bin/python tool/performed-input/freeze_split.py
.venv/bin/python tool/performed-input/identity_score.py \
  --split development --arm A0 --out build/performed-input/a0-dev.json
```

**What happened.**

Freeze executed as approved. PROTOCOL.md now carries ruler v1 (scoring unit,
tiers, boundary tolerance, arms, split rule) and the frozen adoption bar. The
split manifest is committed at `data/splits/asap-wir-nc-v2.json`: all 32 sonata
numbers ranked by seeded hash, 10 held out, movements inherit their sonata's
side. Realized over the 32 gate-passing movements: development 21 movements /
5,973 events (66% of event mass), test 11 / 3,064 (34%). The four gate-excluded
movements are recorded in the manifest with reasons and inherit a side
automatically if rescued. Timeline entries gained `beatMs` (the interpolated
beat duration at that point) so the scorer's boundary tolerance is data-driven;
fixtures regenerated.

The scorer (`tool/performed-input/identity_score.py`) implements the frozen
semantics: per-event display intervals intersected with analyst spans, the three
tiers via a shared (third, fifth, seventh) family classifier over member
interval sets, the app side from a closed 25-quality interval table plus
extensions, augmented-sixth spans scored by member set, and one-beat boundary
tolerance crediting either neighbor. Sanity: zero unparsed analyst spans across
the development split, per-piece values in plausible ranges, pooled and
mean-per-piece within half a point of each other.

The first live-identity numbers (A0: app segmentation, neutral context,
development split, mean per piece):

| coverage | exact | root  | members |
| -------- | ----- | ----- | ------- |
| 0.493    | 0.595 | 0.737 | 0.525   |

Per-piece spread: coverage 0.13 to 0.77 (tracking texture density; sparse
arpeggiated movements produce few segmenter events), exact 0.39 to 0.73.

**Plain-English reading.** This is the number the whole initiative was built to
surface, and it is nothing like the synthesized-voicing story (DCML solo 98.8%,
held-out jazz ensemble 94.2%). While a real person plays a real sonata, the app
is showing a chord at all for about half of the harmonically labeled time, and
when it does show one, it agrees with the analyst's root and quality family
about 60% of the time, with the root right about 74% of the time. The gap
between 99% and this is the product surface nobody had measured: not the ranking
engine being wrong about clean chords, but segmentation sparsity, partial
arrivals, ornamental tones, and missing key context. Which of those buckets owns
how much of the gap is exactly what the attribution arms exist to answer.

**Decisions.**

- Ruler v1 and the split are frozen as approved; the test side stays untouched
  until a pre-declared result set spends it.
- The A0 baseline is a recording, not a headline: per the protocol, no adoption
  decisions happen against this ruler until the attribution decomposition (arms
  B and C at minimum) exists to explain what moves.
- Key behavior modes, clarified in PROTOCOL.md item 4: A0, B, and C have no key
  detector in the loop, so the three presets do not apply to them; arm A1
  reports all three presets (stable, balanced, reactive), since the preset
  changes the context stream the analyzer sees.

**Next.** Build arm B (annotated analyst key as analysis context) and arm C
(annotation-boundary segmentation), then read the first decomposition: how much
of the 40-point exact gap belongs to key context versus segmentation versus
ranking.
