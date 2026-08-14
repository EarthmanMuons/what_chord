# Freeze the baseline comparison runner

**Date:** 2026-08-14  
**Status:** complete pre-result freeze; no prior-art detector has received a
product-suite observation

## Why this entry exists

The adapter implementations, native runtimes, normalizers, and per-invocation
result schema were frozen in log entry `2026-08-14-04`. This entry closes the
remaining operational gap before the first baseline result: it fixes how the 29
named targets and 20 adapted streams become neutral observations, how the
already-preregistered metrics are computed, and how complete raw case-level
outputs are retained.

This is a separate dated entry because it defines a measurement procedure. It
does not revise a musical expectation, product policy, adapter option, quality
mapping, or baseline source pin.

## Expectation isolation

`tool/polychord/prior_art_baseline_comparison.py` validates the frozen product
and internal suites, then constructs the exact common observation record from
registered sounding MIDI notes. Only these four fields cross the adapter
boundary:

```text
observationId
orderedMidiNotes
scientificPitchSharps
pitchClassSharps
```

Expected construction, source identity, action identity, stratum, score title,
primary chord, product candidates, onset evidence, and prior product output stay
in the outer evaluator. Tests inspect every prepared adapter record for that
boundary.

The sole named-snapshot coverage exclusion remains Petrushka rehearsal 49. Its
source is an unfolding two-stream passage with no simultaneous complete-layer
snapshot, so it receives no invented static observation. Its actual 24 changed
sounding frames remain in the adapted-stream task.

For each automatic stream, the runner starts with the fixture's declared initial
state and emits a neutral observation only after a musical event changes the
sounding-note set. Timer, primary-availability, and tracker-reset actions are
not sent to static detectors. Known dwell is the interval to the next changed
sounding frame, or to the end of the declared case action window for the final
frame. The carried-in-onset case consequently has zero adapted-stream
invocations: its only musical event does not change its already-sounding initial
state, while its static sonority remains represented by a named target.

The dry preparation produced:

```text
Named targets                         29
Named detector invocations            28
Adapted streams                       20
Changed sounding stream frames       157
Total adapter observations           185
```

## Frozen scoring behavior

Named targets retain native composite emission, ordered identity exactness,
unordered component credit, exact assignment when exposed, guard abstention,
failure states, and every raw and normalized alternative. The three declared
report strata are `inherited`, `authored-positive`, and `authored-guard`.

An unresolved source order, such as the overlapping-register Augurs sonority, is
eligible for unordered component credit but excluded from ordered identity and
ordered assignment scoring. Mingus retains its baseline-wide assignment
capability exclusion. These exclusions are null denominators, never passes or
zeros.

Adapted streams retain every raw invocation record plus identity-change,
composite-frame, known-dwell, exception, failure, and no-output counts. The
optional common 200-ms wrapper is not run in version 1. Its identity-selection
semantics for native systems returning multiple alternatives were not frozen,
and native frame behavior is sufficient for the declared descriptive comparison.
This avoids retrofitting WhatChord's product history rule onto other static
libraries.

## Controls and artifacts

The new comparison controls passed alongside the frozen adapter,
expectation-isolation, and independent scorer controls:

```text
prior_art_baseline_comparison_test.py      10/10
prior_art_baseline_test.py                  11/11
product_prediction_projection_test.py        3/3
product_suite_scorer_test.py                  5/5
complete tool/polychord Python suite       352/352
mise python:format                           pass
mise python:lint                             pass
```

The pure-Dart product prediction was generated from clean commit `ea97d535`
before any prior-art suite output was read. Its 108 frozen checkpoints passed
all seven exact dimensions. That result will be retained with the complete
comparison result rather than interpreted in this pre-result entry.

The comparison freeze is
`research/polychord/baselines/comparison-freeze-v1.json`. Its pinned digests
are:

- product suite:
  `a32b1cf11562dd591a51dd4382dcbfbd472334a5bbc19632ec83fe0583cb214d`;
- baseline contract:
  `4d5766117891254bbf64e54ce4689f380610f53d4b90bad35f4bb1f6cde3e75d`;
- adapter freeze:
  `d2a6f898297badcfb248e47be52ab2022985ee2b67ad93bf7de4e9d268ca3cb4`;
- comparison runner:
  `ef29275f7825b469135f3914482d042985cf1abbfa1aea651622c2491f9b2fbe`;
- runner controls:
  `a1a398c24ab7a41ff6e69ed1a8ddf7296c9e523211fef018f86541ab548dc49a`;
- runtime manifest:
  `67d3c364565e2347a72cf779465b5f52eb7f9a8b3ccd1157b95c464a63ff11d5`; and
- prepared neutral-input document:
  `7af5f387d7ffc5a21791cbfa90740b430d9b3b77f0d02dfa0cda0190b9b57897`.

## Decision

Commit this runner, its controls, and the comparison freeze before invoking any
of the four detectors on a suite observation. The next step is one clean-tree
comparison run, followed by a dated result entry that preserves the complete
machine report and reports product conformance separately from descriptive
prior-art behavior.
