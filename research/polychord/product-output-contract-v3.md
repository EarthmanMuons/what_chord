# Automatic polychord product output contract

Status: preregistered product contract for `polychord-output/3` under the
`automaticTimestampedMidi` input condition. This document is committed before
the exact selector is implemented, before a product suite is scored, and before
new development or held-corpus output is read.

This is an author-adjudicated product contract. Passing it establishes
conformance with WhatChord's declared product behavior, not independent musical
ground truth, perceptual validity, or generalized detection accuracy. No new
source or external annotation is required to implement or evaluate this product
track.

## Product boundary

The output is an optional secondary annotation for two registered chordal units.
It never changes the primary chord identity, ranking, alternatives, history
segmentation, key inference, or Explore behavior.

The supported construction vocabulary is symmetric. Either layer may be a
complete major or minor triad or a complete dominant, major, or minor seventh
chord. The upper layer is not restricted to a triad. Both layers must have
different recognized roots, occupy adjacent nonempty register groups, use
disjoint sounded MIDI-note assignments that exhaust the observation, and may
share a pitch class only when distinct sounded notes supply it in both layers.

`polychord-output/3` governs automatic inference from timestamped MIDI. Explicit
manual entry of upper and lower chordal units is a separate future input
condition and is neither authorized nor rejected here.

## Input condition

`automaticTimestampedMidi` is an ordered stream of normalized note-on, note-off,
and sustain-pedal events plus explicit reset signals. The stream preserves:

- a nondecreasing monotonic elapsed timestamp and authoritative event order;
- the exact pressed, pedal-sustained, and sounding MIDI-note state after every
  musical event;
- the current note-on event identifier for every sounding MIDI note;
- a tracker epoch that changes on every reset; and
- explicit primary-display availability as product state outside the selector.

Musical events with the same timestamp remain ordered and may expose
zero-duration intermediate frames. Redundant controller messages and other input
no-ops do not create normalized musical frames. The product display reducer
additionally receives monotonic timer observations. They can mature a pending
display but cannot alter MIDI state, cue evidence, a raw decision, or an
authorization key.

A tracker reset covers disconnect, transport replacement, an unreconstructed
seek, or restoration from a static snapshot. It clears every sounding-instance
identity, decision authorization, pending timer, and displayed polychord. Notes
restored without their note-on provenance have incomplete onset history and
cannot authorize automatic output.

The snapshot chord analyzer remains pure and stateless. Temporal state belongs
to a separate tracker, selector, and display reducer.

## Product observation

Every normalized musical frame produces one immutable diagnostic observation:

```text
PolychordProductObservation
  schema: polychord-output/3
  inputCondition: automaticTimestampedMidi
  trackerEpoch: reset-scoped identity
  frame: event identity, timestamp, pressed, sustained, sounding, pedal
  candidates: every structural candidate in canonical order
  candidateRecords: one complete trace per exact candidate
  rawDecision: selector result independent of primary analysis
  authorization: exact key or one reason
  display: pending, visible, and transition state
  versionIds: tracker, generator, cue, selector, and display profile
```

The exact implementation names may follow Dart conventions without changing
these fields or semantics. Diagnostics and reports must serialize the complete
shape, including abstentions.

## Candidate cue records

Every structural candidate receives one candidate-bound onset record under the
licensing cue named by `onset-register-selector-v1.md`. The record contains:

- the cue and evidence-schema identifiers;
- the complete target frame and exact candidate;
- the lower and upper MIDI-note assignment;
- every assigned note's current `(midiNote, onsetEventIndex)` identity;
- `availability`: `complete` or `incomplete`;
- `support`: `positive`, `neutral`, or `null` for incomplete availability;
- raw layer onset intervals, spans, order, and separation; and
- ordered interpretation reason codes.

An onset result for one assignment cannot transfer to another assignment with
the same chord identities. A later reattack of the same MIDI note creates a new
sounding instance and therefore a different binding.

Release/pedal and motion records may accompany the product observation as
diagnostics. They are not licensing cues, votes, vetoes, tie-breakers, or hidden
confidence inputs in this contract.

Because there is exactly one licensing cue, candidate aggregate support maps
directly from its record:

- complete positive cue -> `positive`;
- complete neutral cue -> `neutral`; and
- incomplete cue or binding -> `unavailable`.

The aggregate retains the cue record and never becomes a scalar confidence.

## Raw automatic decision

The raw selector is `polychord-onset-register-policy/1`, specified completely in
`onset-register-selector-v1.md`. It consumes only the current registered
observation, structural candidates, and their bound onset records. It never
reads the primary chord identity or alternatives, spelling or key context,
source or suite labels, corpus annotations, product presentation state, or a
prior displayed polychord.

A raw decision contains:

- the complete original candidate list and candidate records;
- all per-candidate policy predicates and removals;
- zero or one exact selected candidate;
- a complete sounding-instance binding when selected;
- no reason on selection, or exactly one reason on abstention; and
- the ordered frame-level terminal predicates used to verify reason precedence.

The selector's exact reason vocabulary is:

- `no-structural-candidate`;
- `ambiguous-exact-assignment`;
- `integrated-tertian-reading`;
- `layer-separation-not-supported`; and
- `missing-layer-separation-history`; and
- `multiple-unresolved-identities`.

These are diagnostic tokens, not user-facing messages.

## Product authorization

Raw musical selection and product authorization remain separate. The
authorization reducer consumes `primaryDisplayable` plus the raw decision:

1. When the primary result is not displayable, emit no key and
   `primary-not-displayable`, while retaining the unchanged raw decision.
2. When the raw selector abstains, emit no key and its exact abstention reason.
3. Otherwise emit the selected authorization key and no reason.

The authorization key is:

```text
tracker epoch
+ ordered upper/lower identities
+ exact upper/lower MIDI-note assignments
+ every assigned note's onset-event identifier
```

Identity alone, assignment alone, or an unscoped event number is not sufficient.
The key is valid only while the selected assignment exhausts the sounding notes,
every bound sounding instance remains current, and its bound onset cue remains
positive.

A note-off under sustain may preserve the key because the same note instance
continues sounding. Reattack of a sustained note changes its note-on identifier
and invalidates the key. Any normalized event revalidates the complete key; no
boolean authorization is carried forward without checking the current frame.

## Stable display profile

The first product display profile is
`polychord-continuous-authorization-200ms/1`. It requires one authorization key
to remain continuously valid for at least 200 milliseconds. Equality is
inclusive. The duration is a product-stability baseline, not a polychord or
perception threshold.

The reducer has `absent`, `pending`, and `visible` states:

- A new valid key enters `pending` at its authorization timestamp.
- The same key remains pending until a musical or timer observation reaches its
  inclusive 200-millisecond deadline, then becomes `visible`.
- The same visible key remains visible without a new timer or repeated
  appearance event.
- Loss of authorization clears pending or visible state immediately.
- A different valid key clears the old visible state, starts a new pending
  interval at the current timestamp, and cannot inherit elapsed time.
- Silence, primary-display loss, support loss, changed assignment or instance,
  and tracker reset clear immediately.
- A timer observation at the pending deadline promotes only when the latest
  product observation still carries the same valid key.

The transition vocabulary is `none`, `pending`, `appearance`, `stable`, and
`clear`. This first profile does not keep an invalid old annotation visible
while a different key matures, and it does not emit a direct `change`
transition.

Stable-display diagnostic reasons are:

- `awaiting-display-stability` while pending;
- `raw-selector-abstention` when a former authorization is lost because the raw
  selector abstains;
- `primary-not-displayable`;
- `silence`;
- `layer-separation-support-lost` when the exact candidate and instance binding
  remain but its onset record is no longer positive;
- `invalidated-support-binding` when the candidate assignment remains equal but
  an onset-event identity changes;
- `authorization-key-changed` for any other new valid key; and
- `tracker-reset`.

When several descriptions apply, reset precedes silence, primary loss,
invalidated binding, support loss, raw abstention, and key change. The complete
product observation retains the underlying facts so this transition reason does
not hide the selector reason.

## Presentation and feature isolation

Canonical plain text is `upper|lower` with ASCII `|` and the upper chord first.
For C major above G minor:

- canonical: `C|Gm`;
- long form: `Polychord: C major above G minor`; and
- semantic/spoken: `Polychord. Upper chord: C major. Lower chord: G minor.`

The visual uses a labeled secondary region after the primary result and before
ordinary alternatives. A stacked visual or pipe fallback may be used, but a
screen reader always receives the explicit upper/lower wording. Text scaling
must not introduce horizontal scrolling, truncation, overlap, or reliance on
color alone. User-facing wording does not expose cue thresholds, diagnostic
reasons, confidence, bitonality, polytonality, or a claim of independent
perceptual streams.

Enharmonic spelling uses the existing presentation context without changing the
pitch-class identity or selection. Diagnostics retain both identity and rendered
spelling.

Polychord appearance, change, or clearing does not create, end, relabel, or
persist a primary `ChordEvent`. Recent history and key inference remain
single-chord-only. Explore continues from the primary chord. Existing share
links remain input/primary-only until a later register-preserving grammar is
versioned.

## Evaluation and change control

Evaluation reports separate:

- structural candidate exposure;
- cue-positive, neutral, and unavailable records;
- raw automatic selections and abstentions;
- product authorizations;
- stable appearances, visible time, and clear transitions; and
- construction, decision, and display coverage exclusions.

The product suite is an author-adjudicated conformance ruler. Development and
held POP909 runs are false-display exposure, not labeled accuracy. Every stable
display receives a disposition.

Changing the supported layer vocabulary, cue identity or parameters, static
vetoes, selection order, reason precedence, authorization key, reset semantics,
display duration, or transition behavior requires a new versioned selector, cue,
output, or display profile as appropriate. A defect correction must record the
affected artifact and rerun boundary before any result is replaced.

This contract authorizes specification and implementation work only. Product
integration and the held POP909 run remain gated by
`product-completion-plan.md`.
