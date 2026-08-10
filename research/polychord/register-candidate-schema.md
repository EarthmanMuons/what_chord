# Register-only candidate schema

Status: active research contract for the Framework-v0 structural baseline. This
schema defines proposals, not product output, confidence, or display behavior.

## Purpose

The register-only generator answers one narrow and reproducible question:

> Which exact contiguous register splits in this sounding frame satisfy the
> conservative Framework-v0 layer vocabulary?

It consumes only the sorted sounding MIDI notes in one replay frame. It does not
consume event history, onset or release times, pedal provenance, source labels,
corpus annotations, current chord names, or expected readings.

`tool/polychord/register_candidates.py` is the normative implementation.

## Input

The input is a strictly increasing array of distinct MIDI note numbers from 0
through 127. This is the same representation as a replay frame's
`soundingMidiNotes` field. Invalid or silently normalized observations are
rejected.

Pitch-class duplication at different octaves is permitted because the MIDI notes
remain distinct. Empty frames and frames with too few notes are valid and
produce no candidates.

## Enumeration rules

The generator examines every boundary between adjacent sounding notes, from
lowest to highest. A boundary produces a candidate for every pair of exact layer
matches satisfying all of these rules:

- every note below and including the boundary belongs to the lower layer;
- every note above the boundary belongs to the upper layer;
- each layer's pitch-class set exactly matches a complete major triad, minor
  triad, dominant seventh, major seventh, or minor seventh chord;
- the two recognized roots differ; and
- a shared pitch class is permitted only when a distinct sounded MIDI note on
  each side of the boundary supplies it.

Duplicate octaves within one layer do not change its identity. No note may be
ignored, assigned noncontiguously, or used on both sides of the boundary. Layer
identity is pitch-class based, so inversions are permitted and neither layer is
required to place its recognized root in the bass.

There is deliberately no minimum register-gap threshold. The observed gap is
reported as evidence so later ablations can evaluate it. A structural proposal
is not a judgment that a polychord reading is preferable to an integrated chord
name, and it is not permission to display the proposal.

## Output

The command emits a JSON object with schema `polychord-register-candidates/1`:

- `midiNotes`: the exact validated input observation;
- `candidates`: every qualifying decomposition, ordered by `splitAfterIndex`,
  then upper and lower identity;
- `splitAfterIndex`: the zero-based index of the last lower-layer MIDI note;
- `lowerTopMidi` and `upperBottomMidi`: the notes adjacent to the boundary;
- `gapSemitones`: `upperBottomMidi - lowerTopMidi`;
- `lower` and `upper`: each layer's `rootPc`, `quality`, exact `midiNotes`, and
  sorted distinct `pitchClasses`;
- `sharedPitchClasses`: pitch classes supplied by separate notes in both layers;
  and
- `symbol`: neutral sharp-name research notation in `upper|lower` order.

Every distinct qualifying boundary and note assignment remains in the output.
The generator performs no ranking, confidence estimation, deduplication by
symbol, stable-display filtering, or temporal inference.

## Reproduction

For a clean two-triad example:

```sh
python3 tool/polychord/register_candidates.py 48 52 55 66 70 73
```

The historical schema-3 census remains byte-pinned to its result record and is
not rewritten around this generator. Synthetic compatibility tests compare the
new output with the census's `complete-common` registral detector at a
one-semitone minimum gap. This verifies the inherited structural subset without
changing the provenance of earlier measurements.
