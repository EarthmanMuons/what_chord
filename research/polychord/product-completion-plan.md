# Polychord product completion plan

Status: active product-development plan. The exact product output contract and
first onset-licensed selector are frozen by log 2026-08-13-09. The product
suite, scorer, and baseline adapter contract remain the next prospective unit.
This plan permits an author-adjudicated product-policy experiment and delivery
path. It does not claim independent annotation, perceptual validity, generalized
detection accuracy, or publication-ready source coverage.

The decision is recorded in log 2026-08-13-08. The stricter `polychord-output/2`
source-admission route remains preserved in `automatic-selection-v2-plan.md` and
`automatic-suite-v2-plan.md` for any later independent-validation or publication
claim. Product work will use a new output and selector identity rather than
weakening that frozen route in place.

## Product outcome

Complete a conservative automatic polychord annotation for timestamped MIDI,
compare it with WhatChord's register-only experiment and the executable
prior-art baselines, validate it against author-adjudicated product policy and
development-corpus exposure, and integrate it only if every product gate passes.

The product claim is deliberately narrow:

> Under a named timestamped-MIDI policy, WhatChord can optionally display a
> two-layer chordal decomposition when the registered sonority and its observed
> attack history satisfy conservative author-adjudicated conditions.

Passing this plan means conformance with that product policy and the declared
safety checks. It does not mean that the system recovers every musical
polychord, that listeners hear independent streams, or that an accuracy estimate
generalizes beyond the maintained ruler.

## Fixed product scope

The first product experiment retains these existing decisions:

- two layers under the symmetric `complete-common` vocabulary: complete major
  and minor triads and complete dominant, major, and minor seventh chords are
  available to both the upper and lower layer;
- adjacent-register structural candidates from
  `polychord-register-candidates/1`, with different recognized roots and exact
  sounded-note assignment;
- upper-chord-first pipe notation, such as `D|C7`;
- an optional secondary annotation that cannot change the primary chord,
  ranking, history segmentation, key inference, or Explore result;
- automatic input only from ordered timestamped note-on, note-off, and sustain
  events with exact sounding-instance identity and reset behavior; and
- the existing presentation, accessibility, diagnostic, and performance
  boundaries unless a later versioned product contract changes them explicitly.

This is not an upper-triad-only design. The narrower `bichord-triads`,
`upper-structure-triads`, and `upper-structure-common` census profiles remain
exposure comparisons, not the product's definition.

Explicit manual entry of upper and lower units remains a separate future input
condition. It is not required to finish this automatic feature.

## Initial product hypothesis

The first exact product contract will receive a new output identity, planned as
`polychord-output/3`, and the selector will receive its own policy identity. A
new version number records a changed adoption claim; it does not imply stronger
scientific validation than `polychord-output/2`.

The selector specification will freeze the following conservative hypothesis
before implementation or evaluation:

1. Generate the unchanged symmetric complete-common register candidates.
2. Retain the v1 static integrated-tertian and exact-assignment safety checks,
   with their exact order and ambiguity behavior restated in the new selector
   rather than inherited implicitly.
3. Require candidate-bound positive onset support with a 50-millisecond maximum
   within each layer and an 80-millisecond minimum between the two layer onset
   intervals.
4. Treat neutral, incomplete, unavailable, stale, or differently bound onset
   evidence as automatic abstention.
5. Resolve multiple supported candidates only by a rule frozen before results;
   no primary-chord label, source label, corpus annotation, or case identity may
   be used as a tie-breaker.
6. Require 200 milliseconds of continuous authorization before display and clear
   immediately when authorization or sounding-instance binding is lost.

The 80-millisecond onset value is a conservative product hypothesis, not a
perceptual boundary. It is the stricter of the two lower profiles already
guarded by the Liszt boundary, has a literature-motivated timing region, and did
not create development POP909 fires in the completed sensitivity measurement.
The 50-millisecond within-layer value likewise remains a named product
parameter, not an established musical constant. Both require a new selector
version if changed.

Motion, release, and pedal records remain diagnostic in the first product
selector. Motion still lacks a frozen application-facing endpoint and
correspondence policy. Release and pedal state has no justified categorical
interpretation. Neither is needed to complete an onset-licensed first version.

## Product ruler

Build a new author-adjudicated automatic product suite rather than presenting
the source-incomplete scientific suite as ground truth. The suite must be
committed with its schema, scorer, acceptance rule, and exact dependencies
before the selector produces predictions.

The product suite must:

- pin and preserve all 17 cases in `data/internal-suite/suite-v0.json`;
- retain construction label, input eligibility, expected product behavior, and
  epistemic status as separate fields;
- add complete timestamped event windows for onset-positive product cases,
  ordinary integrated controls, boundaries, and contract mechanics;
- label authored or score-normalized event timing honestly rather than calling
  it captured performance or independent evidence;
- cover both layer orders, shared-tone and disjoint candidates, triad and
  seventh-chord layers, assignment and identity ambiguity, simultaneous and
  incomplete onsets, exact 50/80-millisecond timing boundaries, sustain,
  reattack, release, reset, and display transitions; and
- score construction, cue interpretation, selector decision, and display
  behavior separately.

The suite is allowed to encode the maintainers' intended product behavior. It
may not support an accuracy or reproducibility claim beyond that
author-adjudicated specification.

## Baseline comparison

Compare the frozen product policy on identical eligible observations against:

- `polychord-register-policy/1`;
- musicpy 7.15;
- python-mingus at the already recorded source pin; and
- ChordRecGen at the recorded source pin if its archived toolchain can be made
  reproducible without changing its recognition semantics.

The adapters, versions, input order, options, output normalization, and metrics
must be committed before reading the comparison. Every system receives the same
registered MIDI-note observations; no adapter receives expected labels, layer
assignments, source identities, or temporal cue results.

Report two tasks separately:

1. **Named-snapshot comparison.** At each declared target frame, retain raw
   baseline output and score exact ordered composite identity, component credit,
   abstention, failure, and unparseable output against the author-adjudicated
   expectation.
2. **Adapted stream comparison.** On event-complete windows, rerun each static
   baseline after every changed sounding-note frame. If the common
   200-millisecond display adapter is applied, identify it explicitly as a
   WhatChord evaluation wrapper rather than native baseline behavior. Report raw
   frame output and adapted display output separately.

The baseline comparison is descriptive. Prior-art output is neither truth nor a
reason to change a frozen expected label after results are visible. WhatChord
need not imitate a baseline's vocabulary or unsupported output, but every
difference must remain inspectable.

## Development and held evidence

Run implementation-shaped development exposure only after the product suite,
selector, scorer, and adapters are frozen and Python/Dart equivalence passes.
Use:

- the already exposed 101-song POP909 sample with the same pinned projection;
- the existing raw ASAP development performances; and
- synthetic mechanics only in the product suite, never pooled with corpus
  exposure.

When in Rome committed-event fixtures may supply structural diagnostics but
cannot measure onset decisions or display duration. Corpus labels are not read.
Every authorization and every stable display is retained and dispositioned.

The 808-song POP909 pool remains untouched until the exact product candidate,
presentation behavior, tests, performance checks, and development dispositions
all pass. It is a final false-display safety exposure set, not a labeled
polychord accuracy set and not the test side of an ordinary 80/20 supervised
split.

## Acceptance gates

The product candidate advances only if all of the following hold:

1. Python and pure-Dart implementations produce zero mismatches on the complete
   product suite and declared structural matrix.
2. The selector, cue records, decisions, and display transitions match every
   eligible author-adjudicated suite expectation exactly. Coverage exclusions
   are reported and cannot count as passes.
3. Every stable development-corpus display is dispositioned. Any out-of-scope
   stable display blocks the candidate or requires a new selector version and a
   fresh development run.
4. Primary chord output, ranking, history, key inference, and Explore behavior
   have zero unintended changes across their existing regressions.
5. The comping, oracle-pool, dense-set, performance, and note-storm guards in
   `PROTOCOL.md` pass. Normalized analysis cost remains within the frozen 5%
   budget.
6. User-facing presentation satisfies the frozen semantic, spoken, text-scaling,
   contrast, and diagnostic requirements without adding widget or UI tests
   prohibited by the repository policy.
7. The complete event path produces the intended stable annotation in hands-on
   MIDI checks covering both layer orders and at least one triad and one seventh
   layer, while representative simultaneous, integrated, incomplete-history,
   sustain, reattack, and reset cases abstain or clear as specified. Retain the
   event traces used for reproducible regression where their ownership permits;
   describe this as product acceptance, not independent validation.
8. The complete prior-art comparison is reported with raw outputs and failure
   counts; an unavailable ChordRecGen run is documented rather than silently
   omitted.
9. After every preceding artifact is frozen, the held POP909 run produces no
   out-of-scope stable display. A held failure blocks release and is not tuned
   away on the same pool.

If the held run fails, the current candidate fails and the 808-song pool becomes
exposed. A corrected version may use those dispositions as development evidence,
but no rerun on the same pool may be described as a fresh held result. A later
release decision must either reserve a new untouched safety source or explicitly
accept that only development-exposure evidence remains.

The exact product-suite inventory and selector reason precedence still require
prospective specifications. They are the next work, not optional cleanup after
an implementation exists.

## Delivery sequence

Proceed in this order:

1. **Complete:** commit this plan and its dated decision record.
2. **Output and selector complete; suite and baselines next:**
   `product-output-contract-v3.md`, `onset-register-selector-v1.md`, and log
   2026-08-13-09 freeze `polychord-output/3`, the onset-only cue, exact selector
   order and reasons, authorization key, and stable-display behavior. Freeze the
   automatic product suite schema, complete case inventory, scorer, and baseline
   adapter contract before implementation or prediction.
3. Implement and cross-check Python and pure-Dart policy paths without reading
   predictions from the scorer or development corpora.
4. Run the frozen product suite and prior-art comparison once, retaining all
   case-level outputs.
5. Run POP909-sample and ASAP development exposure, disposition every stable
   display, and version any policy correction.
6. Integrate the passing selector and secondary presentation behind the normal
   product path, then run all engine, app, accessibility, and performance
   guards.
7. Freeze the release candidate and run the untouched 808-song POP909 pool once
   as a false-display safety check.
8. Ship only if every gate passes. Preserve the stronger source-validation and
   independent-review work as an optional later research track.

This sequence completes a useful and testable product without disguising
maintainer judgment as external ground truth.
