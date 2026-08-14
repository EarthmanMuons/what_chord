# Automatic polychord product suite v1

Status: frozen author-adjudicated conformance ruler for
`polychord-product-suite/1`. The isolated 19-fixture manifest, 20-case and
108-checkpoint machine suite, strict validator, independent exact scorer, and
synthetic pass/failure controls were frozen on 2026-08-14. No
`polychord-onset-register-policy/1` implementation, product prediction,
prior-art output, development output, or held output had been produced or read
at freeze.

This is an author-adjudicated conformance ruler. It tests whether the product
implements its declared policy. It is not an independently annotated dataset, a
listener study, an estimate of musical accuracy, or publication evidence.

## Separation from the construction ruler

The product suite pins, but does not copy or relabel,
`data/internal-suite/suite-v0.json`. Its 17 cases continue to record musical
construction, product expectation, input eligibility, and the register-only
structural baseline under `polychord-internal-suite/2`.

The automatic suite adds a different question: what must happen when an exact
timestamped-MIDI history is processed under `polychord-output/3`? A static case
without event history remains a static comparison and construction reference. It
does not acquire invented timing. An authored event realization based on its
pitches receives a new product-case identifier and is labeled as authored rather
than source-derived performance evidence.

The frozen 17-case roster and its automatic role are:

| Inherited case ID                                | Automatic-suite role                                      |
| ------------------------------------------------ | --------------------------------------------------------- |
| `hancock-maiden-voyage-a-minor-seven-over-d`     | static construction and named-snapshot comparison only    |
| `herrmann-pass-first-a-flat-minor-attack`        | static construction and named-snapshot comparison only    |
| `ives-psalm-67-opening`                          | static construction and named-snapshot comparison only    |
| `strauss-elektra-chord-overlap`                  | static construction and named-snapshot comparison only    |
| `stravinsky-augurs-r13`                          | static construction and named-snapshot comparison only    |
| `stravinsky-petrushka-r49-arpeggios`             | source-derived replay; automatic structural abstention    |
| `stravinsky-shrovetide-second-attack`            | source-derived replay; automatic integrated abstention    |
| `stravinsky-three-movements-g-over-a-flat-seven` | static construction and named-snapshot comparison only    |
| `synthetic-c-major-nine-assignment-ambiguity`    | static guard plus separately authored timing case         |
| `synthetic-c-major-seven-accompaniment`          | static guard plus separately authored timing case         |
| `synthetic-d-over-c-major-seven`                 | static boundary plus separately authored timing case      |
| `synthetic-d-over-c-seven-shell`                 | static construction and named-snapshot comparison only    |
| `synthetic-d-sharp-seven-over-e`                 | static positive plus separately authored timing case      |
| `synthetic-integrated-d-six`                     | static construction and named-snapshot comparison only    |
| `synthetic-layered-c-over-g-minor`               | authored replay; automatic positive and display lifecycle |
| `synthetic-same-root-c-major-registers`          | static construction and named-snapshot comparison only    |
| `synthetic-separated-f-sharp-over-c`             | static construction and named-snapshot comparison only    |

The machine-readable suite must contain this ordered roster and the exact
SHA-256 of the inherited suite. A missing, extra, reordered, or
digest-mismatched case is invalid.

## Machine-readable suite object

The canonical file will be `data/product-suite/suite-v0.json`. It contains
exactly:

- `schema`: `polychord-product-suite/1`;
- `status`: `preregistered-author-adjudicated` with `scoringAllowed: false`, or
  `frozen-author-adjudicated` with `scoringAllowed: true` only after the dated
  implementation freeze;
- `authority`: `product-policy-only-not-independent-ground-truth`;
- `noteConvention`: `MIDI 60 is C4; case spellings are authoritative`;
- `versionIds`: the exact output, tracker, candidate-generator, cue, selector,
  and display identities;
- `dependencies`: repository-relative paths and SHA-256 digests for the output
  contract, selector, this schema, inherited suite, existing replay manifest,
  product fixture manifest, validator, scorer, and baseline contract;
- `inheritedCases`: the ordered 17-case roster above with its automatic role;
- `cases`: the ordered automatic cases frozen below; and
- `baselineTargets`: named-snapshot and adapted-stream targets without expected
  labels in the adapter input record.

Unknown fields are rejected. JSON is UTF-8, two-space indented, and terminated
by a newline. The validator resolves every dependency from the repository root
and rejects a digest mismatch.

## Fixture isolation

Do not add product fixtures to `data/frame-replay/manifest.json`. The frozen
internal suite pins that manifest, so changing it would invalidate an earlier
ruler for unrelated new data.

The product suite instead owns `data/product-suite/fixture-manifest.json`. It
may reference existing replay files by path and digest and may pin new files
under `data/product-suite/fixtures/`. Every referenced fixture still conforms to
`polychord-frame-replay/1` and is validated by the unchanged replay state
machine. Product controls do not enter the musical fixture because timer,
primary availability, and reset are not MIDI notes or sustain events.

The implemented manifest pins four inherited replays and fifteen authored
product realizations. The 20-case inventory reuses the basic positive
realization for two cases whose difference is entirely in product-control
actions. `tool/polychord/product_suite.py` validates both this substrate and the
complete strict suite schema. Scoring is enabled only for the frozen suite and a
digest- and version-matched prediction document.

## Case and action objects

Every automatic case contains exactly:

- `id`, `title`, and `stratum`, where the stratum is `inherited-source`,
  `authored-musical-policy`, or `authored-contract-mechanics`;
- `purpose`: the exact policy branch or transition exercised;
- `provenance`: an inherited case reference or an honest authored recipe;
- `constructionExpectation`: a positive ordered composite, a boundary or
  negative guard, or a construction-coverage exclusion;
- `fixtureId`: one fixture in the product fixture manifest;
- `initialPrimaryDisplayable`;
- `actions`: the complete ordered product-observation script;
- `expectedCandidates`: stable identifiers for every exact structural candidate
  referenced by an expectation; and
- `baselineTargetIds`: zero or more declared static-comparison checkpoints.

An action is one of:

- `musicalEvent`, referencing the next consecutive fixture event index;
- `timer`, at a nondecreasing timestamp and without changing MIDI or raw
  selection state;
- `primaryAvailability`, setting the outer authorization input without changing
  MIDI, cue, or raw selection state; or
- `trackerReset`, clearing tracker, authorization, and display state.

Actions are authoritative when musical and product controls share a timestamp.
Musical event references must begin at event zero and remain consecutive. A case
may stop before the fixture ends but cannot skip an earlier event. No action may
follow `trackerReset` in suite v1; a later case starts a fresh tracker instead.

Each action carries either a complete expected checkpoint or
`checkpoint: false`. All actions are executed and retained. At a checkpoint, the
expectation contains the applicable portions of:

```text
construction: expected composite, expected abstention, or coverage exclusion
frame: exact epoch, event identity, timestamp, and sounding state
candidates: complete canonical candidate list
cueRecords: complete candidate-bound onset records
rawDecision: exact selected candidate or one selector reason
authorization: exact authorization key or one reason
display: absent/pending/visible, transition, displayed key, deadline, and reason
```

Timer and primary-availability checkpoints retain the latest immutable frame,
candidates, cue records, and raw decision. They may change only authorization or
display fields as the output contract permits. A reset checkpoint has no carried
authorization or displayed identity.

The validator independently regenerates every musical frame and structural
candidate list. Expected candidate identity uses root pitch class and quality;
exact candidate identity additionally includes ordered MIDI assignments.
Expected authorization keys also include the tracker epoch and every current
note-on event identity. Human-readable symbols never substitute for these
machine fields.

### Machine normalization

The machine suite assigns case-local `candidate-N` identifiers in first-seen
order. Each identifier resolves once to the exact ordered upper/lower root pitch
class and quality plus both complete MIDI-note assignments. Checkpoint candidate
and stage lists contain these identifiers in canonical generator order. A
candidate identifier is only a compact reference inside one case; it is never a
musical label, cross-case identity, or selector input.

Every cue binding and authorization key lists all assigned sounding notes in
ascending MIDI order as `(midiNote, onsetEventIndex)`. The candidate reference
supplies the ordered identities and assignments, and `trackerEpoch` scopes the
event identifiers. The first tracker version used by the suite is
`polychord-onset-tracker/1`.

The display projection uses `key` for the current pending or visible
authorization key and uses `deadlineMs` only while pending. Entering pending
emits `pending`; a repeated observation before the deadline emits `none` while
retaining `awaiting-display-stability`; equality at the deadline emits
`appearance`; and a repeated visible observation emits `stable`. A different
valid key enters a new pending state with `authorization-key-changed`. Losing an
active pending or visible key emits `clear`; an already absent display remains
`none` with no display reason. These are diagnostic transition semantics and do
not create primary history events.

A reset checkpoint retains the case-level construction expectation but has null
frame, raw-decision, and authorization fields, empty candidate and cue lists,
and an absent display with `tracker-reset`. No action follows reset in suite v1.

## Frozen automatic case inventory

All pitches below use scientific pitch first and MIDI in parentheses. Multiple
notes at one timestamp are serialized in ascending MIDI order. Unless a case
says otherwise, velocity is the non-evidentiary constant 96, pedal begins up,
primary output is displayable, positive layers are held through their declared
timer checkpoints, and a positive case checks pending at deadline minus 1 ms and
appearance at the inclusive deadline.

### Inherited replay cases

- `petrushka-r49-structural-abstention`: existing
  `stravinsky-petrushka-r49-arpeggios` events 0-23. Preserve the
  literature-attested construction, but expect `no-structural-candidate`, no
  authorization, and no display at every frame.
- `shrovetide-integrated-boundary`: existing
  `stravinsky-shrovetide-oblique-motion` events 0-17. Candidate frames after
  events 5 and 17 must abstain as integrated-tertian readings; no frame
  authorizes or displays a polychord.
- `shared-lower-first-positive-and-release`: existing
  `two-register-held-cohorts`. After event 5 at 400 ms select `C|Gm`; pending at
  599, appearance at 600, stable at 601, clear on event 6 by raw abstention, and
  end absent in silence.

The Petrushka case is a construction-positive but automatic-coverage-excluded
case. Its correct automatic abstention is not a false negative. The other two
retain their inherited synthetic or score-normalized provenance.

### Authored musical-policy cases

- `disjoint-upper-first-80-positive`: upper C major C4-E4-G4 (60,64,67) at 0 ms;
  lower F-sharp major F#2-A#2-C#3 (42,46,49) at 80 ms. Select `C|F#`; this is
  the reverse onset order and exact inclusive 80 ms boundary.
- `upper-seventh-positive`: lower E major E1-E2-G#2-B2 (28,40,44,47) at 0; upper
  D#7 D#3-F##3-A#3-C#4 (51,55,58,61) at 80. Select `D#7|E`; this proves the
  upper layer is not triad-only.
- `lower-seventh-multiple-identities-positive`: A-flat 7 Ab2-C3-Eb3-Gb3
  (44,48,51,54) at 0; G major G4-B4-D5 (67,71,74) at 80. Select `G|Ab7`; retain
  the alternate `Gmaj7|Ab` structural candidate with neutral bound onset
  support. Machine scoring uses root pitch class 8 and `dominant7`; the neutral
  structural serializer may render the lower root as G-sharp while the pinned
  construction spelling remains A-flat.
- `assignment-ambiguity-before-cue`: C3-E3-G3 (48,52,55) at 0; G4-B4-D5-G5
  (67,71,74,79) at 80. One `G|C` assignment is positive and one neutral, but
  both are removed before cue selection and the frame abstains
  `ambiguous-exact-assignment`.
- `compact-integrated-before-cue`: C3-E3-G3 (48,52,55) at 0; E4-G4-B4 (64,67,71)
  at 80. The candidate cue is positive, but the Cmaj7 collection abstains
  `integrated-tertian-reading` by the compact predicate.
- `rooted-ninth-before-cue`: C3-E3-G3 (48,52,55) at 0; G4-B4-D5 (67,71,74)
  at 80. The `G|C` cue is positive, but the Cmaj9 collection abstains
  `integrated-tertian-reading` by the lower-root ninth predicate.
- `rooted-seventh-extension-before-cue`: B2-C3-E3-G3 (47,48,52,55) at 0;
  D4-F#4-A4 (62,66,69) at 80. The `D|Cmaj7` cue is positive, but the collection
  abstains `integrated-tertian-reading` by the seventh-extension predicate.
- `synchronous-cohorts-neutral`: existing `synchronous-six-note-cohort`,
  G2-Bb2-D3 below C4-E4-G4. Expect `layer-separation-not-supported`; later timer
  observations cannot create pending or visible state.
- `carried-in-onsets-incomplete`: initial pressed state G2-Bb2-D3-C4-E4-G4
  (43,46,50,60,64,67), then pedal down at 0. Expect
  `missing-layer-separation-history`; later timers cannot create evidence or
  display state.
- `cohort-50-gap-80-positive`: lower G2-Bb2-D3 at 0,25,50; upper C4-E4-G4 at
  130,155,180. Select `C|Gm`: both within-layer spans equal 50 ms and the
  interval gap equals 80 ms.
- `cohort-51-neutral`: lower G2-Bb2-D3 at 0,25,51; upper C4-E4-G4 at
  131,156,181. The interval gap remains 80 ms, but abstain
  `layer-separation-not-supported` with only `lower-span-exceeds-maximum`.
- `gap-79-neutral`: lower G2-Bb2-D3 at 0; upper C4-E4-G4 at 79. Both cohorts are
  coherent, but abstain `layer-separation-not-supported` with only
  `between-layer-separation-below-minimum`.

The G-over-A-flat-seven event times are authored to exercise candidate-bound
policy. They are not attributed to Stravinsky's performance or score timing;
only the pinned pitch/register construction comes from the inherited case.
Likewise, static inherited synthetic cases supply pitches and intended
construction to their new authored event realizations, not captured temporal
evidence.

### Authored contract-mechanics cases

These cases use G minor G2-Bb2-D3 at 0 ms and C major C4-E4-G4 at 80 ms unless
another recipe is stated. The exact selected candidate is `C|Gm`.

| ID                                       | Additional actions and required outcome                                                                                                                                                                                                 |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pedal-held-release-stable-then-silence` | Appearance at 280; pedal down at 300; release all six notes at 320 while sustained. Binding and display stay stable through every release. Pedal up at 400 clears once with reason `silence`.                                           |
| `reattack-invalidates-binding`           | Appearance at 280; pedal down at 300; release C4 at 320 while sustained; reattack C4 at 330. The same assignment gets a new onset identity, raw support becomes neutral, and display clears `invalidated-support-binding`.              |
| `primary-gate-clears-and-restarts`       | Appearance at 280; set primary unavailable at 300 and clear `primary-not-displayable`; restore it at 310, start a fresh pending interval, remain pending at 509, and appear at 510.                                                     |
| `tracker-reset-clears`                   | Appearance at 280; reset at 300. Clear with `tracker-reset`, invalidate all note-on identities and deadlines, increment the tracker epoch, and retain no musical state after reset.                                                     |
| `pending-key-change-restarts-deadline`   | After the six-note selection begins pending at 80, add C5 (72) at 100. The same ordered identity with a changed upper assignment remains positive, emits `authorization-key-changed`, ignores the old 280 deadline, and appears at 300. |

These cases cover every reachable display diagnostic in version 3:
`awaiting-display-stability`, `raw-selector-abstention`,
`primary-not-displayable`, `silence`, `invalidated-support-binding`,
`authorization-key-changed`, and `tracker-reset`.

There is no case for `layer-separation-support-lost` while an exact binding is
unchanged. Under an onset-only cue with no expiry, the cue record is a pure
function of that binding and cannot change until an onset identity or assignment
changes. There is also no multiple-positive-identity case: the selector
specification proves that such a state is unreachable under the 50/80-ms rule
and exact adjacent splits.

## Named-snapshot and adapted-stream targets

Named-snapshot baseline targets are:

- every inherited case with one exact snapshot or one exact replay target;
- the final complete-sonority checkpoint of each authored musical-policy case;
  and
- no contract-mechanics case, because repeating one sonority under display
  controls would overweight an identical static input.

Petrushka rehearsal 49 has no simultaneous target snapshot representing both
construction units and is an ordered-composite coverage exclusion. Its frames
remain part of adapted-stream output.

Adapted-stream comparison processes every changed sounding-note frame of every
automatic case. Timer, primary, and reset actions are retained for WhatChord's
product result but are never passed to a static third-party detector as though
they were native input.

## Exact scorer

The canonical scorer accepts only a frozen suite with `scoringAllowed: true` and
one prediction document whose version IDs and suite digest match. It must not
import or call the implementation being scored. The validator may use the frozen
frame replayer and structural generator to validate fixture and candidate facts;
expected cue, raw-selection, authorization, and display values remain literal
suite data.

Per applicable checkpoint it records:

- construction outcome: ordered composite exact, correct abstention, or coverage
  exclusion;
- candidate list exact;
- cue record exact, including availability, support, interval endpoints, spans,
  gap, order, note-on identities, and reason order;
- raw decision exact, including every stage survivor list and terminal reason;
- authorization exact, including the complete key or reason; and
- display exact, including state, transition, deadline, displayed key, and
  diagnostic reason.

An omitted checkpoint, extra checkpoint, duplicate action ID, exception,
unparseable prediction, version mismatch, or candidate-order-dependent result is
a failure. Coverage exclusions are listed and never added to a pass denominator.

The report aggregates exact integer numerators and denominators separately for
inherited-source, authored-musical-policy, and authored-contract-mechanics
strata. Partial component or assignment credit may appear only as diagnostic
error analysis. It cannot pass a gate.

`suiteExactGatePass` is true only when:

1. every eligible checkpoint is present;
2. every candidate, cue, raw decision, authorization, and display expectation is
   exact;
3. every positive case selects, authorizes, and displays the declared candidate
   at the declared times;
4. every boundary, negative guard, neutral, incomplete, and structural exclusion
   remains absent from stable display; and
5. every reachable reason and transition listed above is exercised at least
   once.

This flag establishes product-policy conformance only. Python/Dart equivalence,
development dispositions, regressions, performance, accessibility, hands-on MIDI
checks, prior-art reporting, and held safety exposure remain separate
product-completion gates.

## Freeze and change control

The freeze implemented fixtures, validator, scorer, and synthetic control
predictions before the new selector. The controls contain one exact pass plus a
deliberate failure in each scored dimension; the scorer accepts the pass and
rejects every failure. The dated freeze records the final digests, inventory,
coverage, and non-vacuous denominators.

After that freeze, no expected value may change in response to a product or
baseline result. A fixture, expectation, action order, scorer rule, or case
inventory correction requires a new dated entry and suite version or explicitly
documented pre-result defect correction. Once any product prediction has been
read, an outcome-affecting correction creates `polychord-product-suite/2`.
