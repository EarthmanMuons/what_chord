# POP909 onset-exposure census

Status: preregistered measurement contract for
`pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1`, emitted
as `polychord-onset-exposure-census/1`. The first corpus run must use the
committed version of this contract and its canonical implementation without
changing the register generator or the `coherent-separated-onsets-50-200ms/1`
ablation.

The canonical implementation is `tool/polychord/onset_exposure_census.py`. This
document defines an exposure measurement, not an accuracy evaluation or a
product adoption gate.

## Question

The census asks:

> In a previously exposed sample of performed pop-accompaniment MIDI, how often
> does the fixed register generator propose a candidate, and how often does the
> fixed onset ablation provide positive support for one?

POP909 has no verified polychord annotations. A proposal or positively supported
proposal may still be an integrated extended chord, an upper structure, held
melody over accompaniment, sequential harmony, or pedal wash. The results can
measure exposure and concentrate later review; they cannot measure precision,
recall, correctness, perceptual independence, or compositional intent.

## Corpus boundary

The source is the raw MIDI for the 101 song identifiers in the `sample` field of
`research/performed-input/data/pop909-held-pool.json`. That roster was already
used for descriptive stability and exposure scoping before this initiative. The
808 identifiers in `held` are not selectable by the tool and remain untouched.
The CLI exposes no roster override, and the implementation hard-fails unless the
committed roster matches its preregistered SHA-256 digest.

The 808 songs are a clean reserve, not a declared final test set or a claim that
an 11/89 development/test ratio is intrinsically desirable. If POP909 later
gains a labeled or formal corroboration role, a new dated decision may freeze an
appropriate development and final-test allocation from that reserve before any
outcome-dependent tuning. This census does not spend or partition it.

The source projection selects the named `BRIDGE` and `PIANO` tracks and excludes
`MELODY`. The
[POP909 paper](https://archives.ismir.net/ismir2020/paper/000089.pdf) defines
`MELODY` as the lead vocal transcription and says that `BRIDGE`, which contains
secondary melodies or lead instruments, together with `PIANO`, the main
accompaniment body, forms the piano accompaniment arrangement. The tool requires
exactly that named-track layout instead of inferring a role from a channel
number. This is a fixed input definition, not an outcome-dependent filter.

The tool reads only each selected `<songId>/<songId>.mid` file and the roster.
It does not read POP909 chord, key, beat, audio-alignment, or version files. The
report records `labelsRead: false`, the corpus commit, roster hash, song list,
per-file hashes, an aggregate MIDI-content hash, checkout status, and the exact
command, working directory, Python version, and Mido version used to merge
tracks. It records the selected and excluded track names, channel mapping, and
relevant-message counts for every piece. Per-piece projection diagnostics
include note and pedal message counts by selected source channel and the
milliseconds for which those channels' raw pedal states disagree. That
disagreement does not change the fixed channel-blind replay rule, but it exposes
where the result should not be mistaken for channel-scoped MIDI playback. The
report also aggregates those projection diagnostics and counts the affected
pieces; they do not enter any candidate or duration denominator.

POP909 contains copyrighted compositions despite its dataset repository license.
The full report retains exact event frames and therefore must remain a local
artifact under `build/`. The tool refuses output anywhere else. Only aggregate
findings and cryptographic pins may enter a dated log.

## MIDI normalization

The selected tracks are merged in source order and then projected to the strict
`polychord-frame-replay/1` contract. WhatChord's MIDI message and note-state
surfaces discard channel identity and maintain one pressed pitch set and one
global sustain state. The census deliberately applies that same
channel-collapsed observation model:

- positive-velocity note-on becomes `noteOn` with its raw velocity;
- note-on velocity zero becomes `noteOff`;
- note-off retains its raw release velocity;
- sustain controller 64 is normalized at the app's value-64 threshold;
- repeated pedal states are omitted and counted;
- a repeated attack of an already pressed pitch and a release of a pitch that is
  not pressed are state no-ops, so they are omitted and counted;
- channel identity does not preserve multiple ownership of one pitch: the first
  state-changing release removes it from the pressed set, matching the app's
  current channel-blind input semantics;
- conflicting same-timestamp pedal values retain merged source order and create
  auditable zero-dwell intermediate frames; and
- all-sound-off or all-notes-off controllers are a hard failure because reset
  behavior is outside frame replay schema 1 and the census will not silently
  choose between MIDI channel semantics and current app behavior.

An additional attack of an already pressed MIDI note does not replace its onset
in this census. This is conservative for onset support and reflects that it did
not change the app's pressed pitch set. Every omitted-message category is
reported globally and per piece so cross-track pitch collisions and pedal
ordering can be audited before interpreting exposure. This channel-blind
projection is an implementation exposure condition, not a claim that it
reconstructs channel-scoped MIDI playback or source-instrument intent.

The event stream begins from an empty, pedal-up state at MIDI time zero. It ends
at the MIDI file's final timestamp. Every normalized event has a derived frame,
including intermediate frames among messages sharing a timestamp.

## Fixed configurations

Every frame is evaluated by the already fixed contracts, in this order:

1. `polychord-frame-replay/1`;
2. `polychord-register-candidates/1`, using the symmetric complete-common
   vocabulary and every contiguous register boundary;
3. `polychord-onset-evidence/1`; and
4. `coherent-separated-onsets-50-200ms/1`, emitted through
   `polychord-onset-support/1`.

The census exposes no flags for alternate layer vocabularies, register gaps,
onset spans, separation thresholds, shared tones, roster fields, or roster
paths. A future comparison must receive a new measurement and ablation identity.

## Denominators

Three units remain separate.

### Event frames

An event frame is the state immediately after every normalized note or sustain
transition. Same-timestamp intermediate frames count because live sequential
delivery can expose them. Report:

- all event frames;
- zero-dwell event frames;
- sounding event frames;
- frames with at least one register candidate;
- zero-dwell candidate frames;
- frames with at least one positively supported candidate; and
- zero-dwell positively supported frames.

The candidate-frame share uses sounding event frames as its denominator. The
positive-support share uses candidate frames. Event-frame counts measure
generator exposure, not visible duration.

### Dwell time

Each event frame's dwell is the time until the next normalized event or, for the
last event, MIDI end. Same-timestamp intermediate frames therefore have zero
dwell. Report sounding milliseconds, milliseconds with at least one candidate,
and milliseconds with at least one positively supported candidate.

Candidate-time share uses sounding milliseconds. Positive-support time is
reported both as a share of candidate time and sounding time. Silence is not a
share denominator. These are raw observation-state durations, not the app's
stable-display output.

### Candidate instances

Every candidate on every event frame is one instance. Report total instances,
complete and incomplete onset evidence, positive and neutral interpretations,
and all neutral reason codes. Candidate-instance totals may exceed
candidate-frame totals when a frame has multiple register splits.

No configuration ranks or deduplicates candidates by symbol.

## Per-piece reporting and evidence trail

Every song reports the same event-frame, dwell, candidate-instance, and MIDI
normalization fields as the corpus aggregate. The report also gives:

- pieces with any candidate and any positive support;
- the top 20 pieces by positively supported milliseconds and each one's share of
  all positive-support time; and
- every candidate-bearing frame with song ID, event index, timestamp, dwell,
  complete observation frame, structural candidates, raw onset evidence, and
  onset interpretation.

Pooled totals never replace per-piece output. The detailed evidence trail is
required to disposition concentration and artifacts before any safety claim.

## Interpretation boundary

This first census measures the proposal generator and onset ablation directly.
It does not run the current chord analyzer, simulate a stable display, assign a
primary chord name, inspect corpus labels, or apply an adoption threshold. A
later stable-display measurement must be reported separately before product
safety can be discussed.

The fixed profile must not be tuned in response to this report. Any exploratory
alternate threshold belongs in a separately named comparison and cannot replace
the preregistered result.

## Reproduction

After committing this contract and implementation, run:

```sh
./.venv/bin/python tool/polychord/onset_exposure_census.py \
  --out build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
```

The command must not be run before the preregistration commit is fixed.
