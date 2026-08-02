# Polychord

Should WhatChord name polychords (two or more chordal units combined in one
sonority, like the Petrushka chord), and when should that reading appear instead
of, or beside, the single-symbol name?

Status: scoping. No engine lever has been proposed or evaluated.

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

The first annotation-method pilot is encoded in `pilot-ruler-v0.json`, with its
draft rubric in `pilot-annotation.md`. It is deliberately not scorable: every
case awaits independent review. Score verification has already shown why the
pilot is necessary. The Petrushka rehearsal-49 construction is made from
concurrent arpeggiated streams rather than one complete six-note snapshot, and
the Augurs chord's component chords overlap in register. The ruler must
therefore annotate construction truth separately from eligibility for each input
representation instead of selecting only cases the current adjacent-split
detector can recover.

`pilot-review-template-v0.json` is a reproducible independent-review packet. It
uses neutral shuffled IDs and contains only raw MIDI/onset evidence or pinned
score locations, not the initial labels or rationales. Returned annotations are
validated and stored separately under `reviews/`; agreement and adjudication do
not begin until the independent responses are frozen. The formative pilot
targets three qualified independent reviewers, with two as its minimum usable
panel. A guided, version-pinned annotation instrument should export the existing
validated response schema; it improves consistency of data entry but must not
lead or normalize the reviewers' theoretical judgments. Log 2026-08-02-09
records the staged review and publication progression.

After the independent pilot, the proposed direction remains a hand-authored
frozen ruler, then a presentation-side decomposition annotation (secondary
label, single-chord identity unchanged), with alternatives-tier composite
candidates only if the ruler justifies them. The 32 sourced candidates in
`golden-candidates.md` remain a review queue. Corpora serve as negative-exposure
guards, not accuracy rulers.
