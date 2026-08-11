# Polychord frame-replay schema

Status: active evidence contract for `polychord-frame-replay/1`. This schema
defines exact symbolic event windows for temporal grouping research. It does not
define a polychord detector, layer assignment, or expected chord name.

The canonical executable validator and state transition model are in
`tool/polychord/frame_replay.py`. Committed examples and their manifest live in
`data/frame-replay/`.

## Purpose

A frame-replay fixture preserves everything needed to reconstruct what the
snapshot analyzer could have observed after each normalized MIDI event:

- event order, including order among events with the same timestamp;
- note-on velocity and note-off release velocity;
- sustain-pedal transitions;
- physically pressed notes;
- notes sounding only because of the sustain pedal;
- the complete sounding-note union; and
- the time at which the final state stops being observed.

The fixture deliberately excludes chord labels, proposed splits, source
instrument or channel, and detector output. Those are later evidence or scoring
layers and must not contaminate the replay substrate.

## Top-level object

Every fixture contains exactly these fields:

| Field            | Type            | Meaning                                              |
| ---------------- | --------------- | ---------------------------------------------------- |
| `schema`         | string          | Must be `polychord-frame-replay/1`.                  |
| `id`             | string          | Stable nonempty fixture identifier.                  |
| `description`    | string          | Plain-language account of the event window.          |
| `timeBase`       | string          | Must be `milliseconds`.                              |
| `initialState`   | state object    | State immediately before the first event.            |
| `events`         | array of events | Ordered normalized events.                           |
| `frames`         | array of frames | Expected state immediately after every event.        |
| `endTimestampMs` | integer         | Exclusive end of the final state's observation span. |

Unknown fields are rejected so a fixture cannot silently acquire evidence that
the validator ignores.

`endTimestampMs` must be at least the final event timestamp. A final state with
positive dwell has the interval from its event timestamp to `endTimestampMs`.
Intermediate dwell is measured from one event timestamp to the next; events at
the same timestamp create zero-duration intermediate states but remain recorded
because live delivery order can expose them.

The observation window begins at timestamp zero. `initialState` therefore
describes the interval from zero until the first event. Source timestamps may be
retained separately in provenance, but fixture event times are relative to this
window origin.

### Score-derived normalization

A score-derived replay is a normalized symbolic observation, not a captured MIDI
performance. Its consuming suite case and dated log must pin the score, identify
the exact passage, record any transposition into sounding pitch, and explain the
time conversion. When the score supplies a tempo, use it rather than an
arbitrary scale; otherwise declare the chosen normalization.

Notation does not determine a unique MIDI velocity. A score-derived fixture may
therefore use a fixed valid velocity only when the description and provenance
state that velocity is non-evidentiary. Note releases must still follow the
notated durations and articulation as closely as the selected excerpt permits.

Musically simultaneous events require an explicit deterministic serialization
because this schema records one frame after every event. The fixture description
and log must state that ordering. Any intermediate state at the same timestamp
has zero duration and is a normalization artifact, but it remains visible to
frame-level checks exactly like same-timestamp delivery from live MIDI.

## State object

`initialState` contains exactly:

```json
{
  "pressedMidiNotes": [],
  "sustainedMidiNotes": [],
  "pedalDown": false
}
```

Note lists are strictly increasing integers from 0 through 127. Pressed and
sustained sets are disjoint. Sustained notes require `pedalDown: true`.

An explicit initial state permits a replay window to begin inside a longer
performance without pretending that carried notes were attacked at time zero.
Synthetic fixtures should normally begin empty with the pedal up.

## Event objects

Every event has a consecutive zero-based `index`, a nonnegative integer
`timestampMs`, and a `type`. Timestamps are nondecreasing. Array order is the
authoritative tie-break for events at the same timestamp.

### Note on

```json
{
  "index": 0,
  "timestampMs": 0,
  "type": "noteOn",
  "midiNote": 60,
  "velocity": 96
}
```

`midiNote` is 0 through 127 and `velocity` is 1 through 127. MIDI note-on with
velocity zero must be normalized to `noteOff` before entering this schema. A
note-on is invalid when the same note is already physically pressed. Repressing
a pedal-sustained note is valid and moves it from sustained to pressed.

### Note off

```json
{
  "index": 1,
  "timestampMs": 500,
  "type": "noteOff",
  "midiNote": 60,
  "velocity": 0
}
```

`velocity` records release velocity from 0 through 127. A note-off is valid only
for a physically pressed note. With the pedal up it removes the note from the
sounding state. With the pedal down it moves the note from pressed to sustained.

### Sustain pedal

```json
{
  "index": 2,
  "timestampMs": 750,
  "type": "pedal",
  "down": false
}
```

The raw controller value is normalized at the app's threshold before entering
the fixture. A repeated pedal state is rejected as a no-op. Pedal release clears
all sustained notes and leaves physically pressed notes sounding.

Disconnect resets, all-notes-off controllers, sostenuto, half-pedaling, MIDI
channels, and per-note expression are outside schema 1. A later schema must add
them explicitly rather than encoding them as ordinary note or sustain events.

## Derived frame objects

There is exactly one frame for every event. A frame contains exactly:

```json
{
  "afterEventIndex": 0,
  "timestampMs": 0,
  "pressedMidiNotes": [60],
  "sustainedMidiNotes": [],
  "soundingMidiNotes": [60],
  "pedalDown": false
}
```

`afterEventIndex` and `timestampMs` equal the corresponding event's values.
`soundingMidiNotes` is the sorted union of the pressed and sustained sets. The
validator replays the events from `initialState` and rejects any frame that is
missing, extra, or different from the derived state.

Storing both events and frames is deliberate. Events preserve causal evidence;
frames make the exact analyzer input auditable without requiring a reader to
execute code. The duplicate representation is safe because validation requires
byte-independent semantic equality between them.

## Canonicalization and validation

Fixtures are UTF-8 JSON formatted with two-space indentation and a final
newline. Object key order is presentation-only. Semantic validation is strict:

- no booleans where integers are required;
- no duplicate MIDI notes;
- no unknown or missing fields;
- no invalid or redundant transitions;
- no event after `endTimestampMs`; and
- no mismatch between recorded and replayed frames.

The manifest pins each fixture by SHA-256. Validate the full committed set from
the repository root:

```sh
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
```

Validation does not infer chords, group layers, or consult
`golden-candidates.md`. The replay evidence remains usable by register-only and
future temporal ablations without embedding their expected answers.
