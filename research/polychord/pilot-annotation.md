# Polychord pilot annotation guide

Status: draft for an independent-method pilot. This guide and
`pilot-ruler-v0.json` are not a frozen ruler and must not be used to report
accuracy.

## Why the pilot has two labels

A score can establish that a passage was constructed from two chordal units
without establishing that a pitch-and-register snapshot contains enough evidence
to recover those units. The pilot therefore keeps two questions separate:

1. **Construction label:** does the source or the deliberately generated control
   support a positive, boundary, or negative-guard reading?
2. **Input eligibility:** can the proposed reading be evaluated from an
   adjacent-register snapshot, a general pitch-and-register snapshot, or a
   timestamped event stream?

An ineligible case is not a detector false negative. Conversely, source
knowledge must not be smuggled into an input condition that does not carry it.

## Annotation unit

Annotate the smallest source passage that establishes the construction. Use a
single snapshot only when all assigned notes actually sound together. Use an
event window when the chordal units are established by arpeggiation, motion, or
successive attacks. Do not verticalize a passage and describe the resulting
pitch set as an observed voicing.

For each case record:

- the expected tag and exact layer identities;
- an octave-specific note assignment when a simultaneous snapshot exists;
- shared pitch classes and any unassigned notes;
- a stable source, edition, printed location, digital page, and file digest, or
  a complete synthetic-generation description;
- admissible single-chord alternatives;
- a separate eligibility judgment and reason for each input condition;
- verification and independent-review status.

## Tag rubric

- **positive:** the source or generated construction explicitly combines two
  conventional chordal units, and a polychord reading is expected at least as an
  alternative.
- **boundary:** a decomposition is descriptively available, but an integrated
  chord, slash chord, or established upper-structure reading is preferred.
- **negative guard:** a polychord reading would be misleading; the notes form
  one integrated harmony or a duplicated statement of one rooted chord.

Tags describe the constructional judgment, not what a particular detector can
observe.

## Input-eligibility rubric

Use `eligible`, `ambiguous`, `ineligible`, `research-candidate`, or `unknown`.

- `adjacentRegisterSnapshot` is eligible only when one boundary in the sorted
  sounded notes yields the complete assigned layers.
- `pitchRegisterSnapshot` may consider non-contiguous assignments, but is
  ambiguous when the snapshot alone cannot justify one construction over a
  common integrated-chord reading.
- `timestampedEventStream` may use onset cohorts, releases, pedal state, and
  coherent layer motion. Mark it `research-candidate` when the score shows such
  evidence but no frame-accurate MIDI replay has yet been encoded.

Unknown or absent evidence never becomes an implicit negative label.

## Response representation

Each layer uses the following shape. `midiNotes` is required for synthetic MIDI
evidence and omitted when a score event window establishes only pitch-class
membership:

```json
{
  "identity": "C",
  "midiNotes": [60, 64, 67],
  "pitchClasses": [0, 4, 7]
}
```

Use two or more layers for `positive` and `boundary`. For `negative-guard`, use
one layer for the preferred integrated chord or no layer if no conventional
identity is defensible. `abstain` may leave the layer list empty. Lists are
sorted and contain no duplicates.

For synthetic evidence, assign every observed MIDI note exactly once: either to
one layer or to `unassignedMidiNotes`. A single MIDI note cannot serve two
layers. Separate notes may share a pitch class; record every pitch class shared
by two layer templates in `sharedPitchClasses`. For score sources, independently
transcribe the relevant notes or pitch classes rather than copying an analysis
from the initial ruler.

`singleChordAlternatives` contains only integrated alternatives to the proposed
layering. Confidence is `low`, `medium`, or `high`; it is descriptive and does
not replace an eligibility reason.

## Independent review

The independent annotator receives this guide and the generated review packet,
but not `pilot-ruler-v0.json`. The packet uses neutral, deterministically
shuffled case IDs. It omits the first annotator's labels, layer assignments,
alternatives, eligibility judgments, rationales, descriptive IDs, and synthetic
generation intent. It retains only raw MIDI/onset evidence or a pinned score
location.

This is label-blinding, not work-blinding or double-blinding. A score-source
case necessarily reveals its work, edition, and location so the annotator can
verify the musical evidence. Report that limitation directly; familiarity with a
canonical example may influence the judgment even when the initial annotation is
hidden.

The annotator records the observation unit, construction tag, layer assignment,
shared pitch classes, alternatives, all three eligibility judgments, confidence,
and notes. `abstain` is allowed as a construction tag; uncertainty must not be
forced into one of the three ruler tags. Every eligibility judgment still needs
a reason, including `unknown`.

The annotator uses a pseudonymous ID rather than a name or email. They change
the packet status from `template` to `complete`, fill the completion date and
every response, and return the file without changing the evidence fields.
Validate a returned review with:

```sh
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json \
  --validate-review path/to/completed-review.json
```

The initial annotations and completed review remain separate. Compute agreement
before revealing the mapping or discussing disagreements. Adjudication produces
a later artifact and never overwrites either input. If an annotator saw the
initial ruler or participated in its decisions, record the pass as
non-independent and obtain another review before making a publication claim.

The pilot is successful if the procedure exposes disagreements clearly; it is
not required to produce high agreement on the first pass.

## Pre-adjudication reporting and decision rule

Generate the fixed report before discussing any case with the independent
annotator:

```sh
python3 tool/polychord/pilot_agreement.py \
  research/polychord/pilot-ruler-v0.json \
  research/polychord/reviews/pilot-v0-<opaque-annotator-id>.json \
  --out build/polychord/pilot-v0-<opaque-annotator-id>-agreement.json
```

The report includes:

- raw exact agreement and confusion tables for construction tag, observation
  unit, and each input-eligibility condition;
- reviewer abstentions as disagreements, never as excluded rows;
- order-invariant exact layer pitch-class agreement and maximum-matched Jaccard;
- exact shared-pitch-class agreement;
- exact order-invariant note-partition agreement for synthetic MIDI cases,
  including unassigned notes; and
- raw, unnormalized layer-identity text agreement as a diagnostic only.

Chord-identity text and free-form alternatives have no frozen normalizer, so
identity-text agreement is not a reliability metric and alternatives receive
qualitative disposition. With six cases, do not report kappa, hypothesis tests,
confidence intervals, or a general annotator-reliability claim.

This pilot has no accuracy threshold. Instead, apply these predeclared blocking
rules:

- any abstention or disagreement on construction tag or observation unit
  requires a documented rubric review and a new pilot version before the full
  ruler freezes;
- a layer pitch-class or synthetic note-partition mismatch blocks freezing the
  decomposition representation; and
- an eligibility disagreement blocks using that input condition as an accuracy
  eligibility rule until the wording is revised and independently retested.

Report every mismatch even if adjudication later resolves it. Adjudicated values
never replace the pre-adjudication report.
