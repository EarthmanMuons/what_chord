# Polychord release/pedal-evidence schema

Status: active research contract for `polychord-release-pedal-evidence/1`. This
schema attaches exact release, held-state, reattack, and sustain-pedal
provenance to candidates from the fixed register-only generator. It defines
observable evidence, not confidence, ranking, eligibility, a display gate, or a
product decision.

The canonical implementation is `tool/polychord/release_pedal_evidence.py`. It
consumes one validated `polychord-frame-replay/1` fixture and one exact derived
frame. The implementation is independent of the completed POP909 audit tool so
the audit's pinned code and report remain unchanged.

## Claim boundary

The release/pedal step asks:

> For each currently sounding candidate note, is it physically pressed or
> sounding through sustain, what event established that state, what release or
> reattack history is known, and how does its current onset relate to the
> observed pedal episode?

It does not ask whether a sustained note is stale, whether releases form a
perceptual cohort, whether pedal use makes a candidate false, or whether a
polychord annotation should be shown. Schema 1 has no age limit, release
tolerance, penalty, confidence weight, support label, or abstention rule. Any
such interpretation requires a later named and pinned ablation.

Pedal and release history are optional evidence. Legitimate polychords may use
sustain, simultaneous or static constructions may have no informative release
pattern, and manual input may provide no event history. Unknown or ungrouped
release facts must not silently reject a candidate.

## Replay state

The implementation replays the validated event stream in array order. For each
sounding MIDI note it retains the current sounding instance's note-on, current
pressed-versus-sustained state, and the event that established that state.

A note-on starts a new sounding instance. If the note was sounding only through
sustain, the new instance records `reattackedFromSustain: true` and preserves
the prior sustained instance's release origin when it was observed. A note-on
for a previously silent note records `false`. Notes carried in through
`initialState` record `null` because their preceding state is unknown.

A note-off while the pedal is down changes a pressed note to sustained. That
note-off becomes both the current release origin and the current-state origin;
the original note-on remains the onset of the sounding instance. A note-off
while the pedal is up removes the note. Pedal release removes all sustained
notes while leaving pressed notes and their histories intact.

The latest observed pedal transition remains the origin of the current pedal
state until another pedal event. An initial pedal state has no invented
transition or age. Event indices remain authoritative when a note and pedal
transition share a timestamp.

## Sounding-note history

Each candidate note contains exactly these causal facts:

- `midiNote` and `soundingState`, which is `pressed` or `sustained`;
- `onsetEventIndex`, `onsetTimestampMs`, `onsetVelocity`, and `onsetAgeMs` for
  the current sounding instance;
- `releaseEventIndex`, `releaseTimestampMs`, `releaseVelocity`, and
  `releaseAgeMs` for the state-changing note-off when the note is currently
  sustained;
- `currentStateSinceEventIndex`, `currentStateSinceTimestampMs`, and
  `currentStateAgeMs` for the event that established the current pressed or
  sustained state;
- `reattackedFromSustain`;
- `priorSustainReleaseEventIndex`, `priorSustainReleaseTimestampMs`,
  `priorSustainReleaseVelocity`, and `priorSustainReleaseAgeMs` when the current
  onset reattacked an observed sustained instance; and
- `onsetBeforeCurrentPedalDown`, a raw order relation described below.

Ages are nonnegative differences from the selected frame timestamp. They do not
imply a threshold. Note origins, ages, reattack status, and prior releases are
JSON `null` when the fixture begins after the relevant event. A pressed note's
current release fields are also `null` because no release currently establishes
its state; that is not missing evidence. The layer summary counts unknown
releases only among sustained notes.

The onset fields must match `polychord-onset-evidence/1` for the same fixture
and frame. This contract repeats them because release, state, reattack, and
pedal relations describe the same sounding-note instance; it does not redefine
onset semantics.

## Pedal evidence and onset relation

The frame-level `pedal` object contains:

- `down`;
- `lastTransitionEventIndex` and `lastTransitionTimestampMs`;
- `lastTransitionDown`; and
- `currentStateAgeMs`.

All transition fields and the age are `null` when the current pedal state was
carried in through `initialState`. When a transition is known,
`lastTransitionDown` equals the current `down` state; retaining both makes the
causal record explicit.

`onsetBeforeCurrentPedalDown` is defined only when the pedal is currently down,
the current pedal-down transition is observed, and the note onset is known. It
is `true` when the onset's `(timestampMs, eventIndex)` pair precedes the pedal
transition pair, and `false` when it is equal or later in event order. It is
`null` when that comparison is unavailable or not applicable. This field states
order only; it does not label a note as stale or accumulated.

## Layer summary

Each exact lower and upper assignment receives its ordered per-note records and
the following threshold-free summaries:

- pressed and sustained note counts;
- known and unknown onset counts, plus the minimum and maximum known onset age;
- known and unknown release counts among sustained notes,
  `allSustainedReleasesKnown`, the distinct known release timestamps, and their
  earliest, latest, and span;
- known and unknown current-state-origin counts, plus the minimum and maximum
  known state age;
- true, false, and unknown reattack counts; and
- onset-before-pedal-down, onset-at-or-after-pedal-down, and unknown pedal
  relation counts.

Age ranges and release spans are descriptive even when some origins are unknown.
Consumers must consult the corresponding counts. An empty sustained set has zero
known and unknown releases and `allSustainedReleasesKnown: true`; this is
vacuous completeness, not evidence of release grouping. Release timestamps may
be equal even though their event indices differ. Schema 1 records that equality
without naming a cohort.

The candidate-level object repeats pressed and sustained totals,
`allSustainedReleasesKnown`, reattack count, and the three pedal-relation counts
across both layers. It does not collapse those facts into a category or score.

## Output document

The command emits:

- `schema`: `polychord-release-pedal-evidence/1`;
- `fixtureId` and the exact lowercase `fixtureSha256`;
- `observationFrame`: the complete selected replay frame; and
- `candidateEvidence`: every register candidate, in generator order, paired with
  its `releasePedalEvidence`.

Frames with no register candidate produce an empty list. The tool never changes
the structural candidate, infers a candidate from temporal history, consults a
corpus annotation or internal-suite expectation, or reads the POP909 audit
report.

Exact-candidate runs, causing and terminating events, causal corpus windows, and
dwell aggregation belong to the completed audit methodology rather than this
single-frame evidence contract. Frame replay retains the event substrate; later
motion and stable-display work must define their own window semantics.

## Synthetic control

`two-register-pedal-history` reaches the same `C|Gm` sounding-note candidate
through an explicit pedal history:

- the lower notes are attacked at 0 milliseconds and the upper notes at 100;
- the pedal goes down at 200;
- the lower layer is released at 300 and the upper layer at 400;
- MIDI note 43 is reattacked at 500 and released again at 600; and
- pedal release clears every sustained note at 700.

After event 12, every candidate note is sustained, both layers have zero release
span at their distinct raw timestamps, and all six onsets precede the observed
pedal-down transition. After event 13, MIDI note 43 is pressed, its current
onset is after the pedal transition, and its prior release remains event 7.
After event 14, its new release is event 14 while the prior release remains
available as reattack history. These are substrate invariants, not accepted or
rejected product examples.

## Reproduction

```sh
python3 tool/polychord/release_pedal_evidence.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-pedal-history.json \
  --after-event-index 12
```
