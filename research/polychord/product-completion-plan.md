# Polychord product completion plan

Status: complete product-development record. The exact product contract,
selector, suite, implementations, development exposure, and prior-art comparison
are complete through log 2026-08-14-06. Log 2026-08-14-07 records integration of
the passing pure-Dart policy into the app's normalized MIDI path and secondary
presentation. Benchmark v1, frozen in log 2026-08-22-01, failed in log
2026-08-22-02. Logs 2026-08-22-03 through -05 record equivalence-guarded
optimization, prospective benchmark v2, and its passing clean-tree result. Log
2026-08-22-06 records acceptable iPhone and Android functional and accessibility
behavior, the product-level device-telemetry amendment, and the prospective
release-candidate and held-exposure freeze. Log 2026-08-27-01 supersedes the
unexecuted v1 held contract after the app adopted CC120 reset semantics. The v2
run then aborted on song 003 due to a historical-normalizer mismatch after song
002 produced no display. Log 2026-08-27-02 retains the failure, and v3 is the
post-abort completion run. Log 2026-08-27-04 records its verified pass with zero
stable displays and zero displayed time across all 808 songs. The product cycle
is complete. This plan permits an author-adjudicated product-policy experiment
and delivery path. It does not claim independent annotation, perceptual
validity, generalized detection accuracy, or publication-ready source coverage.

The decision is recorded in log 2026-08-13-08. The stricter `polychord-output/2`
source-admission route remains preserved in `automatic-selection-v2-plan.md` and
`automatic-suite-v2-plan.md` for any later independent-validation or publication
claim. Product work used a new output and selector identity rather than
weakening that frozen route in place.

## Product outcome

The completed outcome is a conservative automatic polychord annotation for
timestamped MIDI, compared with WhatChord's register-only experiment and the
executable prior-art baselines, validated against author-adjudicated product
policy and development-corpus exposure, and integrated after every product gate
passed.

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
- upper-chord-first canonical text notation, such as `D|C7`, with a stacked
  upper-over-lower symbol separated by a horizontal rule in the visual app;
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
5. Require the onset rule to leave at most one supported adjacent-register
   candidate. Under the fixed 50/80-millisecond parameters, two different split
   points cannot both be positive, so no label, register-gap, or iteration-order
   tie-breaker is permitted.
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
  seventh-chord layers, assignment ambiguity, candidate-bound resolution of
  multiple structural identities, simultaneous and incomplete onsets, exact
  50/80-millisecond timing boundaries, sustain, reattack, release, reset, and
  display transitions; and
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

The 808-song POP909 pool was kept untouched until the exact product candidate,
presentation behavior, tests, performance checks, and development dispositions
all passed. It served as a final false-display safety exposure set, not a
labeled polychord accuracy set or the test side of an ordinary 80/20 supervised
split. The v2 run's technical abort and the post-abort v3 completion are
retained in the dated record; v3 is not described as a fresh held estimate.

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

`product-suite-v1.md` and `prior-art-baseline-contract-v1.md` now fix the exact
product-case inventory, scorer behavior, adapter inputs, versions, invocations,
normalization, and reporting boundaries. They must be implemented and frozen
before the new selector is implemented or any suite or baseline prediction is
read.

## Delivery sequence

Proceed in this order:

1. **Complete:** commit this plan and its dated decision record.
2. **Complete, including pre-implementation corrections:**
   `product-output-contract-v3.md`, `onset-register-selector-v1.md`, and log
   2026-08-13-09 freeze `polychord-output/3`, the onset-only cue, exact selector
   order and reasons, authorization key, and stable-display behavior. Log
   2026-08-13-10 records the reachability correction made before implementation
   or prediction.
3. **Complete:** freeze and implement the product suite, scorer, locks, baseline
   adapters, fixtures, validator, and smoke controls.
4. **Complete:** implement and cross-check the Python and pure-Dart policy paths
   without reading predictions early.
5. **Complete:** run the frozen product suite and prior-art comparison once,
   retaining all case-level outputs.
6. **Complete:** run POP909-sample and ASAP development exposure and disposition
   every stable display.
7. **Complete:** the normal app path now owns the normalized event adapter,
   passing selector, complete diagnostics, stable timer, and accessible
   secondary presentation. Package and app regressions and unchanged-primary
   behavioral guards pass. The dedicated polychord v1 benchmark failed in log
   2026-08-22-02. The optimized path and corrected v2 measurement are recorded
   in logs 2026-08-22-03 and -04; log 2026-08-22-05 records its clean-tree pass.
   Log 2026-08-22-06 records acceptable iPhone and Android functional and
   accessibility behavior and the explicit decision not to require exact frame
   telemetry for this release.
8. **Complete:** V2 stopped on song 003 because its historical normalizer
   emitted an unmatched note-off that the app filters. Its partial result is
   preserved. V3 corrected only replay normalization and passed across all 808
   songs with zero stable displays and zero displayed time, as recorded in log
   2026-08-27-04.
9. **Approved:** every product gate passes. Preserve stronger source validation
   and independent review as an optional later research track.

This sequence completes a useful and testable product without disguising
maintainer judgment as external ground truth.
