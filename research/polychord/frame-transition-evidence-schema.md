# Polychord frame-transition-evidence schema

Status: active research contract for `polychord-frame-transition-evidence/1`.
This schema preserves exact facts between two caller-selected replay frames and
enumerates possible two-layer correspondences. It deliberately stops before
voice assignment, motion coherence, confidence, ranking, eligibility, display
gating, or stable-display behavior.

The canonical implementation is `tool/polychord/transition_evidence.py`. It
consumes one validated `polychord-frame-replay/1` fixture, two exact derived
frames, release/pedal sounding-instance provenance, and the fixed register-only
candidate generator.

## Why this is a transition contract

The term **voice** is not a neutral synonym for a register group. In the
symbolic-music literature, voice separation or voice segregation is a distinct
inference task: it links notes through time into musicological voices or
perceptual streams. Cambouropoulos distinguishes these meanings and builds a
parameterized perceptual-stream model; Gray and Bunescu train note-to-voice
assignments on manually labeled music; Hsiao and Su learn contextual
note-to-note affinity; and Karystinaios, Foscarin, and Widmer formulate
successive-note linking as multi-trajectory tracking:

- [Cambouropoulos 2008](https://doi.org/10.1525/mp.2008.26.1.75), _Voice and
  Stream: Perceptual and Computational Modeling of Voice Separation_;
- [Gray and Bunescu 2016](https://archives.ismir.net/ismir2016/paper/000296.pdf),
  _A Neural Greedy Model for Voice Separation in Symbolic Music_;
- [Hsiao and Su 2021](https://archives.ismir.net/ismir2021/paper/000035.pdf),
  _Learning Note-to-Note Affinity for Voice Segregation and Melody Line
  Identification of Symbolic Music Data_; and
- [Karystinaios, Foscarin, and Widmer 2023](https://doi.org/10.24963/ijcai.2023/430),
  _Musical Voice Separation as Link Prediction: Modeling a Musical Perception
  Task as a Multi-Trajectory Tracking Problem_.

WhatChord's channel-blind note event stream does not supply those links. If one
pitch stops and another begins, pitch proximity, order-preserving matching,
minimum-distance matching, noncrossing rules, and learned affinity are possible
voice-assignment models, not observations. Even a musically persuasive pairing
must not enter a threshold-free evidence record as a fact.

Accordingly, schema 1 describes a **frame transition**. It records current
sounding instances that demonstrably persist, every source-to-target layer
relation, and all pairwise pitch deltas. It does not claim that a departed pitch
moved to an arrived pitch. A later motion-coherence experiment must name and pin
its voice-assignment model, parameters or learned weights, training and
annotation provenance when applicable, and treatment of crossings, overlaps,
divergence, convergence, entry, and exit.

## Endpoint window

The command requires `--from-after-event-index` and `--to-after-event-index`.
Both must identify exact derived replay frames and the source event index must
be strictly smaller. Equal timestamps are valid because event-array order is
authoritative. Schema 1 imposes no minimum elapsed time, maximum gap, dwell
threshold, stable-frame requirement, or rule for choosing a previous frame. The
caller chooses the endpoints and must disclose that choice in any experiment.

The `window` object contains:

- the complete `sourceFrame` and `targetFrame`;
- nonnegative `elapsedMs`, derived from their timestamps;
- `transitionEventCount`;
- `interveningFrameCount`, which excludes the source and target endpoints; and
- every ordered `transitionStep` after the source through the target, pairing
  the exact event with its complete derived frame.

The final transition-step frame is therefore identical to `targetFrame`.
Retaining every step prevents zero-dwell note-off, note-on, and pedal order from
being erased. The output does not decide whether any intermediate frame is a
musical observation, a transient input state, or a displayable chord.

## Candidate surface

`sourceCandidates` and `targetCandidates` independently contain every exact
`polychord-register-candidates/1` result at their respective endpoints, in
generator order. `candidateTransitions` is the Cartesian product of those two
lists, with explicit source and target indices. If either endpoint has no
candidate, the product is empty. The tool does not choose a predecessor,
successor, path, or best candidate.

For each candidate pair, `sameSymbol` compares the current neutral research
symbols and `sameExactCandidate` compares the complete candidate records. These
are equality facts, not persistence or identity decisions. Two equal symbols may
arise from different sounded notes, and two changed symbols may still share
sounding instances.

## Sounding-instance continuity

A sounding instance is identified within one replay fixture by:

- its `midiNote`; and
- the `onsetEventIndex` of the note-on that established the current instance.

The onset timestamp is repeated for readability. A carried-in instance has
`null` onset fields. It remains the same observed instance across selected
frames only while the replay contains no event that ends or reattacks that MIDI
note. A note-on after silence, or a note-on that reattacks a pedal-sustained
note, creates a new instance even when the MIDI number is unchanged.

`instanceContinuity` partitions the endpoint instances into:

- `retainedInstances`, with exact source and target layer membership and
  pressed-versus-sustained state at both endpoints;
- `departedInstances`, with source membership and state; and
- `arrivedInstances`, with target membership and state.

These are causal replay facts. `retained` means that the same sounding instance
continues; it does not mean that a listener hears one stable voice. `departed`
and `arrived` do not assert a connection to each other.

## Layer relations

Every candidate pair contains all four endpoint relations:

1. lower to lower;
2. lower to upper;
3. upper to lower; and
4. upper to upper.

Each relation records the endpoint MIDI notes, roots, qualities, pitch-class
sets, exact equality flags, and the target-minus-source root-class delta
modulo 12. `allPairTargetMinusSourceSemitones` is a complete matrix: rows follow
the source MIDI-note order and columns follow the target MIDI-note order. Every
cell is `target - source` in semitones. The matrix enumerates possible endpoint
relations; it is not a bipartite matching, voice assignment, or claim that any
pitch moved by that interval.

The relation also lists retained sounding instances whose observed source and
target layer memberships match that exact relation. This is the only note-level
link schema 1 treats as observed.

## Correspondence hypotheses

Two layers have exactly two bijective endpoint correspondences, so both are
reported without a score or ranking:

- `register-role-preserving`: lower to lower and upper to upper; and
- `register-role-exchanging`: lower to upper and upper to lower.

Each hypothesis lists retained instances that follow or fall outside its two
relations and reports both counts. The names describe endpoint register roles,
not musical-layer truth. Exact retained instances may supply evidence for a
later correspondence rule, but schema 1 does not accept or reject either
hypothesis. Departures and arrivals provide no correspondence evidence until a
separate voice-assignment model links them.

## Explicit nonclaims

Schema 1 contains no:

- selected note-to-note link for changed pitches;
- inferred voice, stream, or musical-layer identity;
- motion direction, parallelism, contrary motion, or coherence label;
- window-selection, lookback, dwell, or stability rule;
- tolerance, cost, penalty, confidence, support, eligibility, or abstention
  field; or
- product display or history decision.

The raw facts may later support those analyses, but their rules must not be
retrofitted into this schema.

## Synthetic control

`two-register-inner-motion` creates a source `C|Gm` candidate from MIDI notes
43, 46, 50 and 60, 64, 67. It releases 46 and 64, then attacks 47 and 63,
yielding a target `Cm|G` candidate from 43, 47, 50 and 60, 63, 67.

Four sounding instances persist: 43 and 50 remain in the lower register group,
and 60 and 67 remain in the upper group. Instances 46 and 64 depart; 47 and 63
arrive. The register-role-preserving hypothesis therefore contains four retained
instances and the exchanging hypothesis contains none. The contract does not say
that 46 moved to 47 or that 64 moved to 63, even though that is an obvious
synthetic generation recipe. This intentional refusal is the control's main
invariant.

## Reproduction

```sh
python3 tool/polychord/transition_evidence.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-inner-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 9
```
