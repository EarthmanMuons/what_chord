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

## Independent review

The independent annotator receives the guide, blinded case observations, and
source excerpts, but not the first annotator's rationale or labels. They record
the tag, layer assignment, alternatives, and all three eligibility judgments.
Disagreements remain visible and are adjudicated only after the independent
pass. The pilot is successful if the procedure exposes disagreements clearly; it
is not required to produce high agreement on the first pass.
