# Polychord pilot response schema

This document is the technical companion to `pilot-annotation.md`. It defines
the stored response, validation, and pre-adjudication procedure. Reviewers use
the guided instrument and do not edit these fields directly.

## Annotation unit and evidence record

The response records `snapshot` for one simultaneous sonority and
`event-window` for a short passage established by arpeggiation, motion, or
successive attacks. Do not verticalize an event window and describe its union as
an observed voicing.

Each source case retains a stable source, edition, printed location, digital
page, and file digest. Each generated case retains its complete octave-specific
notes and any onset cohorts. Those evidence fields are copied unchanged into a
completed response.

## Stored construction values

The musician-facing choices map to the following stored values:

| Reviewer wording                                                 | Stored value     |
| ---------------------------------------------------------------- | ---------------- |
| Polychord reading expected                                       | `positive`       |
| Possible decomposition, but a single-chord reading is preferable | `boundary`       |
| A polychord reading would be misleading                          | `negative-guard` |
| Cannot determine from the instructions or evidence               | `abstain`        |
| One simultaneous sonority                                        | `snapshot`       |
| A short passage unfolding over time                              | `event-window`   |

Tags describe the constructional judgment, not what a detector can observe.

## Layer representation

Each layer uses this shape. `midiNotes` is present for generated note evidence
and absent when a score excerpt establishes only pitch-class membership:

```json
{
  "identity": "C",
  "midiNotes": [60, 64, 67],
  "pitchClasses": [0, 4, 7]
}
```

For generated evidence, assign every observed MIDI note exactly once: to one
layer or to `unassignedMidiNotes`. One MIDI note cannot serve two layers.
Separate notes may share a pitch class. For score sources, a reviewer selects
pitch classes independently rather than copying the initial ruler.
`sharedPitchClasses` is derived from intersections among the layer templates.

Lists are sorted and contain no duplicates. `singleChordAlternatives` contains
only integrated alternatives to the proposed layering. Confidence is `low`,
`medium`, or `high`; it is descriptive and does not replace a recoverability
reason.

## Stored recoverability values

The three input conditions are `adjacentRegisterSnapshot`,
`pitchRegisterSnapshot`, and `timestampedEventStream`. Their musician-facing
statuses map as follows:

| Reviewer wording                            | Stored value         |
| ------------------------------------------- | -------------------- |
| Enough evidence                             | `eligible`           |
| More than one defensible reading            | `ambiguous`          |
| Not enough evidence                         | `ineligible`         |
| Promising, but needs an encoded performance | `research-candidate` |
| Not known from this case                    | `unknown`            |

Every judgment requires a free-text reason. Missing evidence never becomes an
implicit negative label.

## Independent review and validation

The generated packet uses neutral, deterministically shuffled case IDs. It
omits the initial labels, layer assignments, alternatives, eligibility
judgments, rationales, descriptive IDs, and generated-case intent. It retains
only generated note/onset evidence or a pinned score location. A score case
necessarily reveals its work and location, so the procedure is label-blinded,
not work-blinded or double-blinded.

A completed response uses a pseudonymous ID, status `complete`, and an ISO date.
Validate it with:

```sh
python3 tool/polychord/pilot_ruler.py \
  research/polychord/pilot-ruler-v0.json \
  --validate-review path/to/completed-review.json
```

The initial annotations and completed reviews remain separate. If a reviewer
saw the initial ruler or helped make its decisions, record the pass as
non-independent and obtain another review before a publication claim.
The formative pilot succeeds when the procedure exposes disagreements clearly;
it is not required to produce high agreement on its first pass.

## Pre-adjudication reporting

Generate the preregistered panel report after all independent responses are
frozen and before discussing any case. Until that multi-reviewer report is
implemented and frozen, the older one-review diagnostic can be run with:

```sh
python3 tool/polychord/pilot_agreement.py \
  research/polychord/pilot-ruler-v0.json \
  research/polychord/reviews/pilot-v0-<opaque-annotator-id>.json \
  --out build/polychord/pilot-v0-<opaque-annotator-id>-agreement.json
```

The report must include construction tag, observation unit, every input
condition, order-invariant layer pitch-class agreement, matched-layer Jaccard,
shared-pitch-class agreement, and exact generated-note partition agreement.
Identity text remains an unnormalized diagnostic, and alternatives receive
qualitative disposition. Abstentions remain disagreements rather than excluded
rows.

With six cases, do not report kappa, hypothesis tests, confidence intervals, or
a population-level reliability claim. This pilot has no accuracy threshold.
Before adjudication:

- any abstention or disagreement on construction tag or observation unit
  requires a documented rubric review and a new pilot version before the full
  ruler freezes;
- a layer pitch-class or generated-note partition mismatch blocks freezing the
  decomposition representation; and
- a recoverability disagreement blocks using that input condition as an
  accuracy rule until the wording is revised and independently retested.

Report every mismatch. Adjudication produces a later artifact and never replaces
the raw initial or reviewer responses.
