# Polychord development exposure v1

Status: preregistered measurement contract for
`polychord-development-exposure/1`. This document fixes the corpus roles, replay
adapters, analyzer context, selector profiles, stable-display timing, reporting
units, fire dispositions, and stopping rules before any development corpus is
passed through `polychord-register-policy/1`.

The first measurement must use a committed implementation of this contract and
write `polychord-development-exposure-report/1` to a new local directory under
`build/`. This is an implementation-exposure and safety study, not an accuracy
evaluation. None of the corpora has verified polychord labels.

## Question

The measurement asks:

> When the fixed register selector is applied to development material through
> the evidence each source actually preserves, what proposals does it make,
> which exact selections could survive the frozen display gate, and are any
> resulting annotations outside the constructional scope fixed by the polychord
> framework?

The study does not estimate recall, precision, perceptual separation,
compositional intent, or population-level accuracy. A stable display may be an
in-scope polychord, an ordinary integrated harmony, a pedal accumulation, or
another artifact. Every full-selector display must be reviewed before it can
support a safety claim.

## Corpus roles

The three sources have different evidence and therefore different measurement
roles. Their results are never pooled.

### ASAP x When in Rome development performances

Measurement ID: `asap-wir-development-raw-midi-register-selector-display/1`.

Use only the 23 entries in `splits.development` of
`research/performed-input/data/splits/asap-wir-nc-v2.json`. Resolve each entry's
`title` to `<ASAP root>/<title>.mid`. The 12 test entries and the gate-excluded
movement are not opened.

The source is raw performed-piano MIDI, so it supports ordered note, release,
and sustain events, exact sounding states, state duration, and timer-driven
stable-display replay. The detailed report is license-gated by ASAP's CC
BY-NC-SA 4.0 terms and remains local under `build/`. The adapter reads no ASAP
annotation, score-alignment, or When in Rome harmony file.

### Frozen POP909 sample

Measurement ID: `pop909-sample-accompaniment-register-selector-display/1`.

Use only the 101 identifiers in the `sample` field of
`research/performed-input/data/pop909-held-pool.json`. The adapter has no flag
for another roster field or path and must hard-fail unless the committed roster
has SHA-256 `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`.
The 808 identifiers in `held` are not opened.

Reuse the previously frozen accompaniment projection: select the named `BRIDGE`
and `PIANO` tracks, exclude `MELODY`, merge the selected messages in source
order, and discard channel identity after track selection. Read only
`<songId>/<songId>.mid`; do not open the corpus's chord, key, beat, alignment,
or audio-derived text files. The exact event replay and stable-display study is
valid only for this channel-blind accompaniment condition, not for full-song
MIDI or channel-scoped playback.

The detailed report retains copyrighted musical event data and remains local
under `build/`.

### When in Rome development fixtures

Measurement ID:
`when-in-rome-development-committed-event-register-selector-proposals/1`.

Use only the 59 entries in `splits.development` of
`research/whatkey/data/splits/when-in-rome-v1.json` and their committed
`whatkey-fixture/1` files. Supply only the event identifier, timestamp,
duration, and a sorted, distinct projection of `midiNotes` to the analysis path.
The fixtures may retain multiple voice occurrences of the same MIDI pitch, but
WhatChord's channel-blind live observation contains one sounding instance of
each pitch. Count and report every occurrence collapsed by this projection.
Reference keys, figures, expected harmonies, and stored candidate lists are not
selector inputs.

These fixtures snapshot a voicing at committed chord-identity onset and omit
same-identity revoicing. Their `durationMs` describes the committed primary
identity, not proof that the exact snapshot or polychord assignment persisted
for that duration. They therefore support event-level proposal counts and
duration-attributed diagnostics only. They do not support frame counts,
appearance latency, stable-display episodes, or adoption-bar display safety. The
harness must not synthesize repeated frames or treat `durationMs` as an
unchanged exact assignment.

## Source and isolation checks

Before analysis, the harness must:

1. verify the two split-file hashes, roster hash, corpus commits, and every raw
   MIDI or fixture hash used;
2. require clean ASAP and POP909 source checkouts at the pinned commits;
3. resolve the declared development rosters completely and reject duplicates,
   missing files, or an accidental test or held identifier;
4. record every opened source path and prove its membership in the permitted
   roster;
5. keep all detailed artifacts under `build/`; and
6. record that no corpus label was supplied to candidate generation, selector
   policy, primary availability, or stable-display state.

The report records the exact command, working directory, repository commit and
measurement-input dirtiness, Python and Dart runtimes, Mido version, contract
hashes, split and roster hashes, source commits, per-file hashes, and aggregate
content hashes. A source mismatch aborts before a report is written.

## Raw MIDI observation model

ASAP uses every note and sustain message in the selected performance. POP909
uses the fixed named-track projection above. In both cases, Mido merges tracks
in deterministic source order and converts elapsed time to integer milliseconds
with the same rounding policy as the existing performed-input adapters.

The replay mirrors WhatChord's current channel-blind `MidiNoteState` behavior:

- positive-velocity note-on adds the note to `pressed` and removes it from
  `sustained`;
- note-on with velocity zero is note-off;
- note-off removes the note from `pressed`, then adds it to `sustained` while
  sustain is down or removes it from `sustained` while sustain is up;
- controller 64 changes the single global sustain state at value 64;
- pedal release clears every sustained note;
- controller 123 clears pressed and sustained notes without changing the pedal
  state, matching the app's current all-notes-off handling;
- controller 120 and unrelated messages do not affect current app note state and
  are counted but ignored; and
- channel identity never preserves multiple ownership of the same MIDI note.

The adapter retains raw-message and no-observable-change counts. It emits one
analysis frame after every observable note-state or pedal-state transition,
including transitions whose sounding-note union is unchanged. Messages at the
same timestamp retain source order and may create zero-dwell intermediate
frames. The stream begins empty with sustain up at time zero. The observation
ends at the final merged MIDI timestamp, including trailing delta time.

This is an exposure test of WhatChord's current input semantics. It is not a
claim that those semantics reconstruct independent channels or instrumental
sources correctly.

## Analysis path and primary availability

Every normalized frame is sent through the pure-Dart implementation shipped by
the later premeasurement implementation commit:

1. construct `ChordInput` and `ObservedVoicing` exactly as the live providers
   do;
2. run the unchanged `ChordAnalyzer` with `ChordAnalysisProfile.current`;
3. run `PolychordRegisterSelector` separately for each preregistered profile;
   and
4. feed each profile's raw selection to its own secondary stable-display gate.

No corpus label, source track, channel, previous primary result, or reference
chord enters the selector. The primary analyzer and polychord selector remain
parallel; neither changes the other's result.

The main replay uses the app's label-blind default context: C major, matching C
major key signature and spelling preference, in solo mode. This is a fixed
product configuration, not a claim that the music is in C major. A raw primary
is displayable when the live chord path would produce a `CaptureFrame`: at least
three sounding MIDI notes and a nonempty analyzer result. It does not wait for
the primary card's separate identity-stability timer.

On every frame selected by any selector profile, the harness also audits primary
availability under all 24 major/minor tonalities in both solo and ensemble
modes. This audit cannot change a selection or choose a favorable primary name.
Any availability disagreement across supported contexts is a
measurement-validity warning and prevents this run from satisfying the
development-display adoption item until its effect is addressed. Each full
stable fire retains the default-context primary and the distinct top-ranked
primary identities observed in that context audit.

## Selector profiles

Run the full selector and all three already-preregistered diagnostics on every
eligible observation:

- `polychord-register-policy/1`;
- `polychord-register-policy-without-integrated-tertian-veto/1`;
- `polychord-register-policy-without-assignment-veto/1`; and
- `polychord-register-policy-without-gap-resolution/1`.

Each profile has independent display state. Only the full selector is eligible
to satisfy the v1 adoption path. Ablations remain comparisons and may not
replace it after results are read.

## Stable-display replay

The pure-Dart gate must implement the exact candidate-and-assignment semantics
of `polychord-output/1` and be cross-checked against the frozen Python decision
control before any corpus run.

For each selector profile:

1. a new exact selection starts a 200-millisecond pending interval;
2. the same exact selection at or after its deadline appears or replaces the
   previous display;
3. an abstention, silence, or missing raw primary clears immediately;
4. any note change that makes the displayed assignment differ from the complete
   sounding-note set clears immediately;
5. a previous display may remain during a pending change only while its exact
   assignment still equals the sounding-note set; and
6. the MIDI end clears any remaining display at the exclusive observation
   boundary.

Replay inserts timer checkpoints even when no MIDI message arrives. If a timer
deadline equals an input timestamp or the MIDI end, process the deadline first,
then the source event or end boundary. This conservative tie rule records a
possible zero-duration appearance rather than silently treating an exact
200-millisecond selection as unstable. Every such appearance still counts as a
fire requiring disposition.

A stable episode begins on `appearance` or `change` and ends on `change`,
`clear`, or MIDI end. Its duration may be zero. Pending selections that never
appear are suppressed unstable selections, not fires.

## Measurement units

Report ASAP and POP909 separately, per piece and in aggregate, for every
selector profile.

### Frames and time

Retain and report:

- raw relevant MIDI messages and ignored or no-change categories;
- normalized event frames, zero-dwell frames, and timestamp-terminal frames;
- sounding frames and sounding milliseconds;
- frames and milliseconds with structural candidates;
- raw selected frames and milliseconds before primary and stability gating;
- raw selections suppressed by unavailable primary;
- pending selections suppressed before appearance;
- stable display episodes and displayed milliseconds;
- appearances, changes, immediate clears, and clear reasons; and
- appearance latency samples.

Frame-duration attribution runs from a frame to the next normalized event or
MIDI end. Only the final frame at one timestamp can have positive dwell. Stable
display duration comes from timer and input transitions, not from raw frame
duration attribution.

Latency and episode-duration distributions retain sample size, minimum,
nearest-rank median, nearest-rank p90, and maximum. Counts and durations are
reported together; neither substitutes for the other.

### Decisions and identities

Retain complete Dart decisions and report:

- every structural candidate instance;
- distinct ordered identities and exact assignments;
- raw selection and selector-abstention reason counts;
- integrated-tertian and assignment-veto trace counts; and
- every stable episode with piece, source-event range, time range, sounding
  notes, pressed and sustained provenance, pedal state, default primary,
  context-audit primary identities, selected candidate, evidence, latency,
  duration, and terminal transition.

For When in Rome, report event and duration-attributed equivalents for every
profile, plus every full-selector selected event. Label those quantities
`committedEventProposals` and `committedIdentityDurationAttributedMs`; never
call them frame or display exposure.

## Human-readable review packet

Machine JSON is the provenance record, not the sole review surface. The harness
must also generate a local review packet for every full-selector stable fire and
every full-selector When in Rome event proposal. Every item presents:

- the canonical upper-over-lower symbol and plain-language layer names;
- note names with octave numbers, not MIDI numbers alone;
- the exact register boundary and layer assignment; and
- links or identifiers sufficient to locate the source passage without revealing
  a proposed disposition.

For frame-capable ASAP and POP909 items, the packet additionally presents a
time-scaled local event timeline showing attacks, releases, held notes,
sustained notes, pedal changes, the annotation's appearance and clear points,
and surrounding primary-chord identities. The musical judgment must be possible
from ordinary note names and that complete local unfolding state.

The When in Rome proposal companion cannot present a note-event timeline,
appearance point, or clear point because its fixtures do not contain that
evidence. Each such item must state the limitation prominently, show the static
onset snapshot in note names, and label the committed identity duration as
duration-attributed rather than display duration. The harness must not invent a
timeline to make those items resemble stable fires.

The packet may include MIDI numbers in technical details. It is an
author-adjudication aid, not an external survey or an independent-validation
instrument.

## Frozen disposition schema

Review every full-selector stable episode individually. Deterministic grouping
may organize repeated material, but every episode keeps its own record and no
sample may stand in for unreviewed fires. Assign exactly one disposition:

- `in-scope-polychord`: the secondary annotation is a useful constructional
  decomposition under `FRAMEWORK.md`;
- `ordinary-integrated-harmony`: an ordinary sixth, seventh, extension,
  alteration, suspension, or upper-structure reading is preferable;
- `slash-or-bass-only-structure`: the lower material functions as a bass or
  incomplete bass structure outside v0 layer scope;
- `same-root-or-duplicated-harmony`: register separation duplicates or
  redistributes one rooted harmony rather than naming two units;
- `pedal-or-release-artifact`: retained or released notes create a displayed
  combination that should not receive the constructional label;
- `transient-or-serialization-artifact`: event ordering or a zero-duration
  boundary creates a possible display that should not be named;
- `other-out-of-scope`: the annotation is outside v0 for another stated reason;
  or
- `unresolved`: available evidence does not support a responsible judgment.

Each disposition records a concise musical rationale, evidence consulted, and
the reviewer and date. Original machine output remains unchanged. Later
correction or adjudication is appended rather than overwriting the first
judgment. The harness emits an immutable review index and a blank disposition
file bound to exactly those item identifiers. A validator must reject missing,
extra, duplicate, incomplete, or non-frozen dispositions while allowing a later
complete judgment to be appended to an item's judgment history.

Only `in-scope-polychord` is compatible with adoption-bar item 5. Any other
stable-fire category, including `unresolved`, leaves that item failed. The same
schema is applied diagnostically to every full-selector When in Rome event
proposal, but those proposal-only judgments neither pass nor fail the stable
display item.

This is author-adjudicated product safety review. It does not turn the corpus
into ground truth or provide independent validation.

## Stopping and change control

The implementation is committed and its synthetic controls pass before the first
corpus command. The official output directory must not already exist. The run
processes every permitted piece and all four selector profiles to completion; it
does not stop after the first fire or after a reassuring partial result.

After the report is generated, verify all hashes and accounting before reading
selector summaries. Preserve every result, including zero fires, unsafe fires,
large fire counts, and adapter warnings. If the number of fires makes complete
review impractical, report that fact and leave adoption incomplete; do not
sample and extrapolate safety.

No result from this run may tune `polychord-register-policy/1`. A newly exposed
counterexample may motivate a separately preregistered version 2. A semantic
implementation defect may be corrected only with a dated record of the defect,
affected artifacts and hashes, and a new output directory. The original failed
or partial artifact is never overwritten.

Zero full-selector stable fires would satisfy the literal complete-disposition
condition for the observed frame-capable corpora, but it would be reported as a
vacuous safety result rather than evidence of accuracy or positive utility. The
internal adoption suite remains the non-vacuous positive conformance check.

## Required premeasurement implementation controls

Before the official corpus run, the committed harness must pass synthetic
controls for:

- raw MIDI state equivalence with current app note, pedal, controller 123, and
  channel-blind behavior;
- source-order and same-timestamp frames;
- timer advancement without an input event and the deadline-equals-event tie;
- delayed appearance and change, immediate clear paths, and MIDI-end flush;
- exact-assignment rather than identity-only stability;
- independent state for all four selector profiles;
- current primary analysis, fixed context, and context-availability audit;
- complete per-piece and aggregate accounting;
- strict roster, split, source-commit, hash, license-output, and
  output-directory guards;
- label-blind selector payloads; and
- human-readable note and event-timeline rendering.

The complete polychord Python suite, pure-Dart package suite, Python formatting
and lint, Dart formatting and analysis, import-order checks, and Markdown
formatting must pass. Synthetic controls may not load a development, test, or
held corpus item.

## First official run

After the implementation and controls are committed from a clean worktree, run
one command with explicit local corpus roots and a new output directory. The
implementation commit will record the exact CLI once it exists. The designated
output directory is:

```text
build/polychord/register-selector-development-exposure-v1
```

Do not run that command from the preregistration worktree.
