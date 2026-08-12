# Automatic polychord output contract v2

Status: active research contract for `polychord-output/2` under the
`automaticTimestampedMidi` input condition. It defines the evidence and display
boundary that an exact version-2 selector must obey. It does not choose that
selector, score a new suite, authorize held-reserve use, or authorize product
integration.

The decision and its provenance are recorded in log 2026-08-11-14.

## Scope

Version 2 preserves the v1 composite identity, upper-first notation,
presentation wording, primary-analysis isolation, accessibility requirements,
diagnostic separation, and 200-millisecond appearance duration from
`output-evaluation-contract.md`. This document changes only the automatic
selection contract for timestamped raw MIDI.

The frozen `polychord-output/1` contract remains the normative record for the
completed register-only experiment. Its static-input eligibility and one-sided
temporal semantics are not rewritten after that result. A v2 report must name
`polychord-output/2`; it must not serialize a v2 abstention as though it had
been produced under v1.

## Input condition

`automaticTimestampedMidi` means an ordered stream of normalized note-on,
note-off, and sustain-pedal events with:

- a nondecreasing timestamp and authoritative order for every event;
- the exact pressed, pedal-sustained, and sounding MIDI-note state after each
  event;
- a current sounding-instance identifier for every note, consisting of its MIDI
  note and the event identifier of the note-on that established that instance,
  unique within one tracker epoch; and
- an explicit reset whenever connection, transport, or replay continuity is
  lost.

`polychord-frame-replay/1` is the normative research representation. A product
implementation may use immutable Dart values rather than its JSON spelling, but
it must preserve the same information and transition semantics. The snapshot
chord analyzer remains pure and stateless; temporal evidence belongs to a
separate tracker.

Pitch-class-only lookup still returns `missing-register-evidence`. Registered
static MIDI can still generate structural candidates and reproduce the v1
experiment, but it is not eligible for v2 automatic display because it lacks the
required event provenance. Explicitly entered upper and lower units are a
separate future manual-input condition in which the user supplies the grouping;
this contract neither authorizes nor rejects that design.

## Decision shape

The conceptual pure-Dart output is:

```text
PolychordAutomaticDecision
  schema: polychord-output/2
  inputCondition: automaticTimestampedMidi
  trackerEpoch: opaque identity changed by every reset
  observation: exact event/frame identity and sounding state
  candidates: every structural candidate
  candidateSupport: one bound aggregate per exact candidate
  selected: zero or one exact candidate
  authorizationKey: selected candidate plus target instances, or null
  selectorId: versioned selector identity
  reasonCodes: empty on selection, exactly one on abstention
  abstentionPredicates: every true predicate in deterministic order
```

The eventual Dart names may follow package conventions without changing these
semantics. The tracker epoch is not persisted as musical data; it prevents an
event identifier reused after reset from matching an earlier sounding instance.
Candidate serialization retains the v1 composite identity and exact MIDI-note
assignment.

## Exact candidate and instance binding

Every support interpretation is bound to one exact target candidate, including
its ordered layer identities and complete lower and upper MIDI-note assignments.
A symbol or pair of root pitch classes is not a sufficient binding.

A licensing interpretation must also bind every assigned note to its current
sounding instance. The binding is the sorted set of
`(midiNote, onsetEventIdentifier)` pairs that exhausts the target candidate. A
carried-in note with unknown onset identity makes that binding incomplete and
cannot authorize automatic display.

Motion evidence additionally records the exact source observation, target
observation, source and target candidates, and correspondence hypothesis. Onset
evidence records the exact current note-on provenance. A positive result for one
candidate or assignment cannot be transferred to another candidate, another
assignment with the same identity, or a later reattack of the same MIDI note.

## Cue record and aggregate support

Each cue considered by a selector produces a record with:

- a versioned `cueId` and evidence-schema identifier;
- the exact target candidate and target-instance binding, preserving `null`
  identifiers when that binding is incomplete;
- `availability`: `complete`, `incomplete`, or `unavailable`;
- `support`: `positive`, `neutral`, or `null` when no interpretation is
  available;
- exact source and target frame references required by that cue; and
- ordered machine-readable reason codes from the named interpretation.

The selector preregistration names which cue IDs are **licensing cues**. Cue
records not named there remain diagnostics and cannot affect selection.
Release/pedal facts are not a licensing cue under this contract. Channel,
source, or timbre grouping requires a later transport-specific evidence contract
before it may be named.

For each exact candidate, licensing cues combine into one
`layerSeparationSupport` result:

- `positive` when at least one licensing cue has complete availability, a
  complete target-instance binding, and positive support;
- `neutral` when no cue qualifies as positive and at least one licensing cue has
  complete availability with neutral support; or
- `unavailable` when no cue qualifies as positive and every licensing cue is
  incomplete or unavailable.

Positive therefore has precedence over neutral and unavailable; neutral has
precedence over unavailable. The aggregate retains every contributing cue and
never collapses them into a scalar confidence, vote total, or hidden weight.
Neutral means that the named rule supplied no positive support, not that the
candidate was disproved.

The exact selector must preregister whether one onset cue, one motion cue, or
some other allowed combination can license a candidate. The aggregate is an OR
over the named licensing cue records. If two atomic cues must both succeed, that
AND rule is registered as one versioned composite cue; the atomic records remain
separate diagnostics. This contract does not silently promote the existing onset
and motion construct probes into product gates.

## Automatic selection and abstention

An exact candidate is eligible for v2 automatic selection only while its
`layerSeparationSupport` is `positive`. Register structure remains necessary and
cannot be created by temporal evidence. Temporal evidence cannot change the
candidate's identities or note assignment.

The exact selector may apply additional preregistered structural or ambiguity
rules, but it must retain every predicate and candidate-specific support result
in diagnostics. It must also freeze one deterministic precedence when several
abstention conditions occur together. Candidate enumeration order is never a
precedence rule.

Version 2 adds two decision reason codes:

- `missing-layer-separation-history`: at least one structural candidate reaches
  the selector, no candidate has positive aggregate support, and all applicable
  candidate aggregates are unavailable; and
- `layer-separation-not-supported`: at least one applicable candidate has
  neutral aggregate support, no applicable candidate has positive support, and
  the selector would otherwise need layer-separation evidence to continue.

If positive support remains but identity or assignment selection is unresolved,
the existing `multiple-unresolved-identities` or a later preregistered
assignment-specific reason applies. `not-selected-by-policy` remains available
for a non-evidence selector rule. `primary-not-displayable`,
`missing-register-evidence`, and `no-structural-candidate` retain their v1
meanings. Exactly one decision reason is emitted for an abstention; all true
predicates remain in diagnostics so precedence cannot hide them.

These tokens are research and diagnostic vocabulary. Ordinary user-facing copy
does not expose them or translate abstention into a confidence claim.

## Evidence lifetime and reset behavior

Positive support is current while all of the following remain true:

1. the exact selected candidate and assignment still exhaust the sounding notes;
2. every target sounding-instance identifier in the support binding still
   identifies the same sounding instance; and
3. at least one named licensing cue remains positive for that binding.

Every normalized event revalidates those conditions. A note-off under sustain
does not by itself end a sounding instance; a reattack of that sustained note
does. A pedal transition or other event may leave a binding valid, but the
implementation must verify it rather than carry a boolean forward implicitly. A
persistent cue retains the original observation that supplied its evidence;
later frames do not rewrite that provenance. It remains current only through
successful candidate and instance-binding revalidation under this section.

There is no elapsed-time expiry while the same target instances continue to
sound. This avoids inventing an unsupported duration threshold and reflects that
the evidence describes how the currently sounding sonority was formed. Any later
wall-clock expiry would be a new named ablation.

Support becomes unavailable immediately when tracker continuity is reset,
including disconnect, transport replacement, replay seek without reconstructed
history, or restoration from a static snapshot. A reset cannot preserve a prior
positive flag. New automatic selection waits until a complete binding and a
licensing cue are observed again.

## Stable-display interaction

The v2 authorization key is the exact candidate plus its complete target
sounding-instance binding. The 200-millisecond appearance timer runs only while
one authorization key remains continuously selected with positive aggregate
support.

- Changing identity, MIDI-note assignment, or any bound sounding instance
  restarts the appearance timer.
- Changing which cue supplies positive support does not restart the timer when
  the authorization key remains unchanged and support stays continuously
  positive.
- Loss of all positive support clears a displayed annotation immediately, even
  if the same MIDI-note assignment remains structurally valid.
- A changed proposed selection may leave the old annotation visible only while
  the old authorization key itself remains valid and positively supported.
- Silence, loss of the primary display, an invalidated assignment, or a history
  reset still clears immediately.

Timer checks do not create new MIDI observations. Between normalized events, the
current frame, sounding instances, evidence records, and authorization key
remain the same, allowing a continuously supported candidate to mature after 200
milliseconds.

Gate diagnostics add:

- `layer-separation-support-lost` when the note assignment and instance binding
  remain valid but aggregate support ceases to be positive; and
- `invalidated-support-binding` when the MIDI-note assignment remains equal but
  one or more sounding instances change.

These are transition reasons, not selector abstention codes or user-facing
messages.

## Diagnostics and reproducibility

Every evaluated event frame and timer transition retains:

- the complete observation and sounding-instance state;
- every structural candidate and exact assignment;
- every cue record, including neutral, incomplete, and unavailable results;
- the aggregate support and authorization key for each candidate;
- the exact selector decision and all true abstention predicates;
- pending, displayed, clear, and support-transition state; and
- schema, cue, selector, tracker, and generator version identifiers.

Corpus reports continue to separate raw candidate, raw selected, and stable
display exposure. Every stable display receives a musical disposition. A report
must not call positive support an accuracy label, independent annotation,
perceptually independent streaming, or compositional intent.

## Evaluation and change control

The frozen suite v0 and its `adjacentRegisterSnapshot` scores remain the v1
record. Version 2 requires a new suite and scorer condition named
`automaticTimestampedMidi`; it may not edit v0 eligibility to manufacture a v2
score. Construction labels and static generator expectations remain preserved
even when a case lacks enough event evidence for automatic temporal scoring.

Every cue branch that can authorize display must have an evidence-complete,
source-attested positive and matched ordinary-integrated controls before the
exact selector is frozen. Synthetic controls can establish mechanics but cannot
be the only positive evidence for a licensing branch.

Previously exposed ASAP, POP909 sample, and When in Rome material remains
development data. Applying this contract retrospectively may be reported as a
development diagnostic but not as independent validation. The 808-song POP909
reserve remains untouched until a selector, new suite, scorer, implementation,
and development measurement are separately preregistered and pass their gates.

Changing the support aggregation, instance-binding rule, reset behavior,
authorization key, reason semantics, or stable-display interaction requires a
new output-contract version. Changing a cue interpretation or selector rule
requires its own version without rewriting this contract.

## Deliberately unfrozen

This contract does not yet choose:

- the exact licensing cue IDs or their logical combination;
- a motion endpoint-enumeration or correspondence-selection rule;
- additional structural vetoes or exact-candidate resolution;
- a version-2 suite, scorer, selector, or implementation;
- a new development source or resampling design; or
- any product presentation or release date.

Those decisions follow only after the required source-attested temporal cases
are admitted under a new versioned suite.
