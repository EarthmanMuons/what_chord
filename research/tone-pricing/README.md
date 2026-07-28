# Tone Pricing

What should a chord name pay for a tone it cannot explain, and what discount
should an honest incomplete reading get? The two questions are one
explanation-cost tolerance dial viewed from opposite sides, and both were
surfaced and priced by the performed-input initiative
([../performed-input/](../performed-input/README.md)):

- **Superset absorption**: the ranker prefers folding an extra sounding tone
  into a bigger name (a held C# over D minor displays as Dm(maj7)) over naming
  the base chord and leaving the tone unexplained. The base-plus-unexplained
  reading is not merely ranked second; it is priced out of the near-tie surface
  entirely (performed-input log 2026-07-27-11). Ceiling on the live ruler: at
  most 7 exact points (the whole added-tone family), realistically less.
- **Shell omission**: no-third seventh shells have no honest label priced
  competitively (D-A-C names Am/D at 0.95 with D7 behind at 1.7 paying a
  missing-third penalty; D7(no3) or D5add(b7) does not exist). About 1.8% of
  observed playing time, split by idiom: jazz shell voicing expects the seventh
  reading, folk supports the slash (performed-input log 2026-07-28-05).

Status: open; scoping.

## Why this shape

The instruments are unusually ready: the exposure-weight table ranks every
change by real playing time instead of enumeration rows, the performed-input
development ruler and its frozen adoption bar provide the live check, the ChoCo
common-name priors carry the name-frequency signal, and the oracle-comparison
machinery provides the blast-radius tooling. The risk is not measurement but
taste: both dials sit directly on the musician-expected naming philosophy, so
the guards (revised below in PROTOCOL) carry the load.

## Build order

1. **Arm C simultaneity refinement** (prerequisite): the BC arm is this
   initiative's residual-isolating instrument, and its span-union voicings
   currently inflate the superset bucket with tones that never sounded together
   (performed-input log 2026-07-27-07). Fix the construction before aiming an
   engine change at the residual it measures.
2. **Baselines**: the 8-plus pitch-class self-consistency census over existing
   fixture events (the dense-set stress check reserved in performed-input log
   2026-07-28-05); the post-refinement BC residual; the exposure-weighted
   inventory of the standing evaluation rows (the high-mass soft-verdict
   entries, led by the 0-2-9 and 0-1-8 shell family).
3. **Experiment mechanism**: how pricing variants are prototyped (engine-side
   research profile or debug pricing overrides), scoped before any lever moves.
4. **Levers, each with pre-declared expectations**: the unexplained-tone price
   for base readings; the missing-essential discount and shell vocabulary forms;
   evaluated against the live ruler, the census suite, and the standing rows.

## Contents

- [Protocol](PROTOCOL.md): inherited discipline, the revised oracle guard
  (review-on-flip), and the adoption bar.
- [Log](log/): dated, append-only record of every experiment and decision.
