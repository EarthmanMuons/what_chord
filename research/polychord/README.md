# Polychord

Should WhatChord name polychords (two or more chordal units combined in one
sonority, like the Petrushka chord), and when should that reading appear instead
of, or beside, the single-symbol name?

Status: framework development. `FRAMEWORK.md` is the active theory-derived v0
specification. No engine lever has been proposed or evaluated, and no result is
independently validated.

## What is known so far

- Not currently supported: the chord-recognition article lists polychords under
  what the algorithm does not handle (the best single-chord description of the
  combined note set wins), and the Petrushka pitch set is a golden that resolves
  to C7(b9,#11) as a complete single-symbol explanation. This initiative is what
  could change that.
- Exposure census (logs 2026-08-02-01, -03, -04, and -06): the initial detector
  was an asymmetric jazz upper-structure screen, not a sound operationalization
  of the general definition. Its 32 wide-tier fires remain useful boundary
  evidence: 29 have an incomplete lower shell or power dyad, and none was judged
  a positive polychord. Schema 3 replaces the triad/seventh switch with named
  profiles. The primary `complete-common` profile treats both layers
  symmetrically as complete major/minor triads or common seventh chords,
  requires different roots, permits a shared pitch class only when separate
  notes support it, and reports every qualifying register boundary. At the
  liberal three-semitone gap it fires on 0.051% of When in Rome dev mass (4
  events), 0.157% of ASAP dev (12), and 1.221% of the POP909 sample (372);
  almost every candidate uses shared tones and the inspected examples are
  ordinary integrated sixth, seventh, or extended chords. The narrower symmetric
  `bichord-triads` ablation reaches 0.051%, 0.047%, and 0.728%. Register-blind
  exposure under the primary profile is 0.20%, 1.77%, and 12.80%. These are
  committed-event scoping bounds, not safety or accuracy results; frame-level
  generator and stable-display exposure remain unmeasured.
- External landscape (logs 2026-08-02-02 and -05): no published computational
  method or evaluated dataset for automatic polychord naming was found within
  the documented search scope. That is a provisional, scoped novelty claim, not
  a claim that no software exists. Three implementations require comparison:
  mingus, ChordRecGen, and the actively released musicpy 7.15, whose documented
  detector uses a fixed register-order split. Ground truth must be
  hand-authored. The field's sanctioned term for what WhatChord would name is
  "polychord" as a notational/constructional claim; "bitonal" and "polytonal"
  assert contested key percepts and are avoided. Dorico supports polychord
  symbols, and MuseScore Studio 4.6 added them in June 2025, a real demand
  signal. The exact search queries, claim boundary, sources, and limitations are
  in `prior-art-search.md`.
- External review (log 2026-08-02-04): corrected the shared-tone audit (the
  initial disjoint detectors excluded four positives: Ives, Copland, Holst, and
  Milhaud), made the protocol self-contained, replaced the census-based guard
  with a generator-instrumented one, and identified the scope decisions that
  must precede the ruler freeze. Schema 3 measures the separate-note shared-tone
  case but does not settle whether those readings belong in the product.

## Direction

`FRAMEWORK.md` now records the active product hypothesis. WhatChord initially
considers a polychord to be a two-layer constructional or notational
decomposition, displayed only as a secondary annotation while the primary
single-chord identity remains unchanged. The conservative generator scope is
symmetric: each layer is a complete major or minor triad or a complete dominant,
major, or minor seventh chord with a different root. Shared pitch classes are
allowed when distinct sounded notes can be assigned to the layers. Bass-only,
fifth-only, shell, upper-structure, same-root, and three-or-more-layer cases are
outside the initial positive generator.

Construction evidence remains separate from detector eligibility. Scores and
analytical literature can establish a construction, but the live detector may
use only information present in its input. A contiguous register split is the
required baseline. Onset, release, pedal, and motion are incremental research
evidence and require frame-accurate event state; an aggregate note set plus
attack times is insufficient.

The first six-case annotation pilot and its static `review-instrument/` are now
deferred without collecting responses. Their exact pinned artifacts remain in
the repository as provenance for logs 2026-08-02-07 through -11, but they must
not be distributed. The score crops cannot identify the focal musical material
without revealing the proposed decomposition, and the generated temporal cases
do not show complete duration, release, pedal, or held-note evidence. Log
2026-08-10-01 records this correction.

External annotation is no longer a gate for framework development, score
verification, temporal infrastructure, corpus exposure measurement, or an
author-adjudicated internal regression suite. Without a redesigned external
study, those results must not be described as independent ground truth,
reproducibility, or generalized accuracy.

The exact event substrate is now fixed in `frame-replay-schema.md`, with four
byte-pinned fixtures under `data/frame-replay/` and an executable validator in
`tool/polychord/frame_replay.py`. It preserves ordered note events, velocity,
pedal transitions, carried-in state, pressed versus sustained notes, every
derived frame, and the terminal observation time without embedding chord labels
or proposed splits.

The next active work is the conservative register-only candidate generator,
followed by a provenance-rich internal suite drawn from the 32 cases in
`golden-candidates.md`. Corpora remain negative-exposure guards, not accuracy
rulers. Pinned comparisons with musicpy, mingus, and, if reproducible,
ChordRecGen remain required before adoption.
