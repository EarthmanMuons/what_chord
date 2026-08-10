# Polychord onset-evidence schema

Status: active research contract for `polychord-onset-evidence/1`. This schema
attaches exact note-on provenance to candidates from the fixed register-only
generator. It defines observable evidence, not confidence, ranking, a display
gate, or a product decision.

The canonical implementation is `tool/polychord/onset_evidence.py`. It consumes
one validated `polychord-frame-replay/1` fixture and one exact derived frame.

## Claim boundary

The first onset step asks:

> When was the currently sounding instance of each candidate-layer note most
> recently attacked, and how tightly or separately do those raw times cluster?

It does not ask whether a time difference is perceptually meaningful or whether
the polychord annotation should be shown. There is no synchrony tolerance,
cohort threshold, confidence weight, or abstention rule in schema 1. A later
named ablation must pin those decisions before measuring them.

Simultaneous attacks also do not disprove a polychord. Static manual input and
transports without history remain valid conditions under `FRAMEWORK.md`; unknown
or unseparated onsets must not silently reject their candidates.

## Sounding-note onset

For every sounding MIDI note, the implementation records:

- `midiNote`;
- `soundingState`: `pressed` or sustain-pedal `sustained`;
- `onsetEventIndex`: the exact note-on event that created the current sounding
  instance;
- `onsetTimestampMs`: that event's timestamp; and
- `onsetVelocity`: that event's raw MIDI attack velocity.

Notes present in `initialState` have unknown onset event, time, and velocity,
represented by JSON `null`. The cropped window must not invent an attack before
its first recorded event.

A note-off under a down sustain pedal preserves the onset of the sounding note.
Reattacking a pedal-sustained note starts a new instance and replaces its onset
with the new note-on event. Pedal release removes onset records only for notes
that stop sounding. Event indices remain distinct for attacks sharing one
timestamp; timestamp equality, not array adjacency, is the raw synchrony fact.

The current pressed-versus-sustained state and raw attack velocity are carried
for auditability but are not assigned a grouping or confidence weight in this
first contract.

## Layer summary

Each exact lower and upper candidate assignment receives:

- the ordered per-note records;
- `knownOnsetCount` and `unknownOnsetCount`;
- `allOnsetsKnown`;
- `distinctKnownOnsetTimestampsMs`;
- `earliestKnownOnsetMs` and `latestKnownOnsetMs`; and
- `knownOnsetSpanMs`.

The known span is descriptive even when some onsets are unknown. Consumers must
consult the counts and must not treat a partial span as complete evidence.

When every onset in both layers is known, the candidate also receives two signed
raw relations:

- `upperEarliestMinusLowerLatestMs`; and
- `upperLatestMinusLowerEarliestMs`.

Together they locate the upper onset interval relative to the lower interval
without assigning a threshold or categorical label. Both fields are `null` when
either layer contains an unknown onset.

## Output document

The command emits:

- `schema`: `polychord-onset-evidence/1`;
- `fixtureId` and the exact lowercase `fixtureSha256`;
- `observationFrame`: the complete selected replay frame; and
- `candidateEvidence`: every register candidate, in generator order, paired with
  its onset evidence.

Frames with no register candidate produce an empty list. The tool never invents
a candidate from timing, never changes layer assignment, and never consumes an
internal-suite label, source annotation, primary chord name, or expected result.

## Matched-history control

The two committed six-note fixtures reach the same final sounding notes and the
same `C|Gm` register candidate:

- `synchronous-six-note-cohort` has every onset at 0 milliseconds, so both layer
  spans and both signed relations are 0; and
- `two-register-held-cohorts` has the complete lower layer at 0 milliseconds and
  complete upper layer at 400 milliseconds, so both layer spans are 0 and both
  signed relations are 400.

This is a substrate invariant, not evidence that either history must be accepted
or rejected by the product.

## Reproduction

```sh
python3 tool/polychord/onset_evidence.py \
  --fixture research/polychord/data/frame-replay/two-register-held-cohorts.json \
  --after-event-index 5
```
