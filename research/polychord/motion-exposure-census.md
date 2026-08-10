# POP909 rigid-layer motion-exposure census

Status: preregistered measurement contract for
`pop909-sample-accompaniment-channel-blind-timestamp-terminal-rigid-motion/1`,
emitted as `polychord-motion-exposure-census/1`. The first corpus run must use
the committed version of this contract and its canonical implementation without
changing endpoint selection, corpus projection, the register generator, or the
`rigid-layers-oblique-or-contrary/1` ablation.

The canonical implementation is `tool/polychord/motion_exposure_census.py`. This
document defines a label-free exposure measurement, not an accuracy evaluation,
temporal-layer tracker, product display rule, or adoption gate.

## Question

The census asks:

> In the previously exposed POP909 accompaniment sample, how often do adjacent
> timestamp-terminal observation states both contain register candidates, and
> how often does the fixed rigid-layer ablation provide positive motion support
> for an explicit source-candidate, target-candidate, and correspondence
> hypothesis?

POP909 has no verified polychord or layer-motion annotations. A positive result
may still describe an integrated harmonic progression, pedal artifact,
serialization artifact, arrangement texture, or chance set relation. The result
measures model exposure and concentrates later disposition; it cannot measure
precision, recall, perceptual streaming, compositional intent, or product
correctness.

## Frozen corpus and input projection

The source is the same 101-song `sample` field of
`research/performed-input/data/pop909-held-pool.json` used by the onset census.
The 808-song `held` field is not selectable and remains untouched. The tool
hard-fails unless the roster retains its frozen SHA-256 digest.

The census reuses the exact corpus projection and normalization fixed in
`onset-exposure-census.md` and implemented by
`tool/polychord/onset_exposure_census.py`:

- select named `BRIDGE` and `PIANO` tracks and exclude `MELODY`;
- discard channel identity after track selection to match WhatChord's current
  pitch-set and global-pedal semantics;
- normalize note-on, note-off, sustain, repeated messages, cross-track pitch
  collisions, and same-timestamp order identically; and
- hard-fail on unsupported reset controllers.

The report repeats the source commit, dirty status, song roster, per-file and
aggregate MIDI hashes, track/channel projection, normalization diagnostics,
runtime versions, exact command, working directory, and cryptographic pins for
every measurement contract and implementation. It records `labelsRead: false`.

The full report contains exact corpus event windows and remains a local artifact
under `build/`. The tool refuses any other output location. It also refuses to
run when polychord research, the roster, or polychord tool inputs are dirty
before execution, and refuses to write a result if they become dirty during the
run.

## Fixed endpoint enumeration

MIDI files serialize simultaneous messages, while the replay contract correctly
retains a frame after every message. Using every raw frame as a motion endpoint
would turn the order of note-offs and note-ons within one timestamp into many
different musical predecessor choices. Skipping backward to an arbitrary prior
candidate would create the opposite problem: a measurement could bridge rests,
partial constructions, or unrelated states.

The census therefore fixes `adjacent-timestamp-terminal-frames/1`:

1. Partition normalized events by exact `timestampMs`.
2. Select the frame after the final event in each timestamp group. This is the
   timestamp-terminal frame.
3. Pair each terminal frame only with the immediately preceding terminal frame.
   These adjacent pairs are `observationTransitions`.
4. Never form an endpoint pair within one timestamp and never skip a terminal
   frame. A positive-duration noncandidate state therefore breaks the chain.
5. Preserve every event and intermediate frame after the source endpoint through
   the target endpoint in the detailed transition window.
6. Apply no minimum or maximum elapsed-time threshold. Adjacency is fixed by the
   observed state sequence, and elapsed time remains a reported diagnostic.

The first timestamp-terminal frame in a piece has no predecessor. Any candidate
there is explicitly counted as motion-unavailable; the census does not invent a
virtual source candidate. A piece with no normalized events has no endpoints or
transitions.

All same-timestamp nonterminal frames are excluded from endpoint selection, but
the report separately counts every such frame and every candidate-bearing one.
It retains the complete candidate-bearing excluded frames for audit. This keeps
zero-dwell live-generator exposure visible without allowing serialization order
to choose a motion window.

## Candidate entry, exit, and evaluability

Every observation transition receives exactly one endpoint class:

- `neither-candidate-endpoint`;
- `candidate-entry`, when only the target has candidates;
- `candidate-exit`, when only the source has candidates; or
- `candidate-to-candidate`, when both endpoints have candidates.

Only `candidate-to-candidate` transitions are motion-evaluable. Candidate entry
and the first terminal candidate state remain motion-unavailable rather than
neutral: there is no source candidate to interpret. Candidate exit has no target
candidate instance to support. A same-sounding-set candidate-to-candidate
transition remains evaluable and receives the fixed ablation's static neutral
result; these transitions are reported separately from pitch-changing ones.

For every evaluable window, the census takes the Cartesian product of all source
and target register candidates. It interprets both unranked correspondence
hypotheses for every pair. It does not select a source candidate, target
candidate, or correspondence.

## Fixed analysis stack

Every endpoint window uses the already fixed contracts, in this order:

1. `polychord-frame-replay/1`;
2. the POP909 projection and normalization from the onset census;
3. `polychord-register-candidates/1` at every raw and terminal frame;
4. `polychord-release-pedal-evidence/1` for exact sounding-instance identity;
5. `polychord-frame-transition-evidence/1` for each endpoint candidate pair; and
6. `rigid-layers-oblique-or-contrary/1`, emitted through
   `polychord-motion-support/1`, for each correspondence hypothesis.

The CLI exposes no endpoint, elapsed-time, layer-vocabulary, register-gap,
motion-class, roster-field, or roster-path option. A future alternative requires
a new measurement identity and must not replace this result.

## Denominators

The report keeps four units separate. Pooled totals accompany, but never
replace, the same per-piece metrics.

### Endpoint frames

Report:

- all normalized event frames and those with register candidates;
- all timestamp-terminal frames, sounding terminal frames, and candidate-bearing
  terminal frames;
- terminal frames with a motion-evaluable predecessor;
- the pitch-changing subset of those evaluable terminal frames;
- terminal frames with at least one positively supported target candidate; and
- excluded same-timestamp nonterminal frames, with and without candidates.

Candidate-frame shares use sounding terminal frames. Motion-evaluable and
positive shares use candidate-bearing terminal frames or the explicitly named
motion-evaluable subset.

### Observation transitions

Every adjacent pair of timestamp-terminal frames is one transition. Report all
transitions, same-sounding-set and pitch-changing transitions, all four endpoint
classes, same-sounding-set and pitch-changing candidate-to-candidate subsets,
and transitions with any positive interpretation.

The primary transition-level positive share uses all candidate-to-candidate
transitions. Also report the share among pitch-changing candidate-to-candidate
transitions so pedal-only or state-only changes cannot hide in that denominator.

### Terminal dwell time

Each terminal frame's dwell is the time until the next distinct normalized event
timestamp or, for the last terminal frame, MIDI end. Report sounding,
candidate-bearing, motion-evaluable, pitch-changing motion-evaluable, and
positively supported milliseconds.

Positive duration is the **target terminal state's dwell**, not the elapsed time
between source and target endpoints. It describes how long the resulting
observation state remains exposed. Candidate-time and positive-time shares use
the same explicitly named terminal-state denominators. They are not stable
display durations.

### Candidate and hypothesis instances

Every register candidate on every timestamp-terminal frame is one target
candidate instance. Report:

- total, motion-evaluable, and motion-unavailable target candidates;
- evaluable target candidates with and without any positive incoming hypothesis;
- all source-target candidate pairs;
- pairs with any positive hypothesis and pairs with both hypotheses positive;
- all correspondence-hypothesis interpretations, split into positive and
  neutral; and
- every neutral reason-code count.

`withAnyPositiveIncomingHypothesis` is an exposure aggregation, not a selected
correspondence or accepted candidate. The report preserves the underlying pair
and hypothesis counts so this disjunction cannot be mistaken for independent
evidence or accuracy.

### Latency and multiplicity distributions

Report minimum, nearest-rank median, nearest-rank p90, maximum, and sample count
for endpoint elapsed milliseconds across all observation transitions,
candidate-to-candidate transitions, and positively supported transitions. Report
the same summaries for source candidates, target candidates, candidate pairs,
hypothesis interpretations, positive hypotheses, and positively supported target
candidates per evaluable window.

For `n` ordered observations, nearest-rank percentile `p` is the value at
one-indexed rank `ceil(p * n)`. An empty distribution reports count zero and
`null` extrema and percentiles. Elapsed time remains diagnostic; it is not a
filter or the duration attributed to a positive target state.

## Evidence trail and concentration

Every piece retains identical metrics plus MIDI projection and normalization
diagnostics. The detailed report retains:

- any candidate-bearing first endpoint without a predecessor;
- every endpoint window with a candidate at either end, including complete
  source and target frames, target dwell, every ordered transition step,
  structural candidates, pair interpretations, and positive target indices; and
- every candidate-bearing same-timestamp nonterminal frame excluded from
  endpoint selection.

The summary reports pieces with terminal candidates, motion-evaluable endpoints,
and positive support, plus the top 20 pieces by positively supported target
dwell and their share of the corpus total. Every positive window must be
dispositioned before the result informs a later product claim.

## Interpretation boundary

This census does not rank or deduplicate candidates, infer monophonic voices,
choose a correspondence, apply onset support as a gate, reject pedal-carried
notes, inspect corpus labels, run the current chord analyzer, or simulate stable
display. It applies the motion ablation independently; comparisons with the
register-only, onset, and release/pedal surfaces must use the same eligible
frames in a later registered analysis.

The result must be described as timestamp-terminal proposal and rigid-motion
support exposure. It is not accuracy, perception, intent, confidence, product
safety, or a reason to tune the frozen profile.

## Reproduction

After committing this contract and implementation, run:

```sh
./.venv/bin/python tool/polychord/motion_exposure_census.py \
  --out \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
```

The command must not be run before the preregistration commit is fixed.
