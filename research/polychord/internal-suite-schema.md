# Polychord internal-suite schema

Status: active contract for `polychord-internal-suite/2`. This schema records an
author-adjudicated product-policy suite. It is not an independently annotated
ruler and does not authorize generalized accuracy claims. The representation,
metrics, and adoption threshold are now fixed by
`output-evaluation-contract.md`, but the active seed remains non-scorable until
its source coverage satisfies `adoption-suite-plan.md` and the adoption suite is
explicitly frozen.

The canonical validator is `tool/polychord/internal_suite.py`. The active seed
suite is `data/internal-suite/suite-v0.json`.

## Separation of claims

Each case keeps four questions separate:

1. What was the musical construction?
2. What secondary polychord reading, if any, does the maintainer expect?
3. Which machine-input conditions contain enough evidence to evaluate that
   expectation?
4. What must the register-only structural generator emit before any ranking or
   display policy is applied?

A literature-attested construction may therefore be a positive musical case
while remaining ineligible for the contiguous-register baseline. Conversely, a
structural candidate may be required from the baseline while the product policy
classifies the case as a boundary or negative guard. Neither result is silently
converted into an accuracy judgment.

## Suite object

The top-level object contains:

- `schema`: `polychord-internal-suite/2`;
- `status`: `active-author-adjudicated-seed`;
- `scoringAllowed`: `false` until the complete adoption suite is explicitly
  frozen;
- `authority`: `product-policy-only-not-independent-ground-truth`;
- `noteConvention`: `MIDI 60 is C4; spellings are case-specific`;
- `dependencies`: SHA-256 pins for the framework, output/evaluation contract,
  adoption-suite plan, this schema, register candidate schema, frame-replay
  manifest, and validator; and
- `cases`: cases ordered by stable identifier.

The validator resolves every dependency from the repository root and rejects a
digest mismatch. The suite cannot silently move to a changed framework,
candidate contract, replay substrate, or validator.

## Case object

Every case contains exactly:

- `id` and `title`;
- `epistemicStatus`: one label from `FRAMEWORK.md`;
- `scopeFeatures`: the specific rule or boundary exercised;
- `source`: an explicit synthetic generation recipe or a stable score record;
- `observation`: one exact snapshot, one exact replay frame, or one bounded
  replay window from the pinned manifest;
- `construction`: the author-adjudicated musical construction and exhaustive
  note-to-unit assignment;
- `productExpectation`: positive, boundary, or negative-guard policy;
- `inputEligibility`: separate judgments for adjacent-register snapshots,
  general pitch-and-register snapshots, and timestamped event streams; and
- `registerBaseline`: the exact unranked JSON candidate output required from
  `polychord-register-candidates/1`, either once for a snapshot or separately at
  every frame in a replay window.

Unknown fields are rejected.

Five scope features carry executable claims rather than descriptive tags:

- `disjoint-pitch-class-layers` requires a two-unit polychord whose unit
  pitch-class sets do not intersect;
- `multiple-structural-identities` requires the exact observation to produce at
  least two distinct ordered chord identities, not merely two exact assignments
  of one identity;
- `moving-arpeggiated-layers` requires a replay window spanning more than one
  timestamp in which no frame contains both complete construction units; and
- `one-sounded-note-overlap` requires a two-unit polychord in which exactly one
  observed MIDI note is assigned to both units. Such a case must carry the
  `boundary` product class under Framework v0; and
- `doubled-integrated-accompaniment` requires an integrated-chord negative guard
  with at least two pitch classes doubled as separate observed notes and at
  least one register candidate that shares two or more of those pitch classes
  across its proposed units.

The validator rejects any feature when its claim is false. Source spellings
remain authoritative even when the register generator serializes the same pitch
class with a neutral sharp spelling.

## Human-readable observations

Every observed MIDI note has a parallel scientific-pitch spelling such as `C4`,
`F#3`, or `Bb2`. The validator resolves accidentals across octave boundaries, so
spellings such as `Cb3` and `Fb2` must sound at the recorded MIDI pitch.

A snapshot stores `soundingMidiNotes` and `spelledNotes` directly. A
single-frame replay observation stores a pinned `fixtureId`, `afterEventIndex`,
and `spelledNotes`. A window observation instead stores `firstEventIndex` and
`lastEventIndex`, inclusive. Its spellings describe the sorted union of distinct
MIDI notes actually sounding in those frames, not a simultaneous sonority.

Window construction assignments attach to distinct MIDI notes across the whole
window. Schema 2 must therefore not encode a passage in which the same MIDI
pitch changes construction units during the selected window. The frame replay
continues to omit instrument and channel labels: a source-backed construction
assignment is adjudicated evidence, not an observed MIDI source assignment.

## Construction and notation

Construction kinds are:

- `polychord`: two complete source or generated chordal units;
- `integrated-chord`: one chordal unit explaining the entire observation; and
- `upper-structure`: a performance decomposition whose integrated reading is
  preferred under Framework v0.

Every unit records an identifier, musician-facing identity, root pitch class,
quality, MIDI notes, spellings, and pitch classes. Units together assign every
observed note, or every distinct observed note for a replay window. They are
normally disjoint at the MIDI-note level, and shared pitch classes remain
possible through separate note instances. A case carrying
`one-sounded-note-overlap` instead assigns exactly one observed MIDI note to
both complete polychord units. Unit-specific spellings may record the distinct
enharmonic role of that physical note.

The overlapping assignment records a constructional or analytical proposal; it
does not widen the v0 generator. Framework v0 requires distinct sounded-note
instances, so a case using the exception must carry the `boundary` product
class, not `positive` or `negative-guard`. Reusing a note without the feature,
claiming the feature without exactly one reused note, or using it on another
construction kind is rejected.

Schema 2 validates each quality against its root-relative pitch classes. The
supported unit qualities are major, minor, dominant seventh, major seventh,
minor seventh, major sixth, and root-third-seventh shell. The last two exist for
integrated and boundary constructions; they do not widen the Framework-v0
polychord generator.

Polychord notation is either:

- `resolved`, with a verified `upper|lower` symbol and identifiers for both
  roles; or
- `unresolved`, with a reason that the available source does not establish a
  safe order.

Non-polychord constructions use `not-applicable`. Unresolved order is retained
instead of manufacturing a symbol from register or root pitch.

A resolved construction symbol records how the source-established units are
ordered; it does not itself authorize a product annotation. A boundary or
negative case may therefore retain a resolved construction symbol while its
`expectedPolychords` list remains empty.

## Product expectation and eligibility

`productExpectation.class` is `positive`, `boundary`, or `negative-guard`.
Positive cases identify the expected pair of construction units and include a
symbol only when notation order is resolved. Boundary and negative cases expect
no polychord annotation even when the source construction has resolved layer
order. Primary single-chord alternatives are retained rather than treated as
annotation errors.

Eligibility statuses are `eligible`, `ineligible`, `ambiguous`, and
`not-available`, each with a reason. They describe whether the named input
condition supplies the evidence needed for this case; they do not alter the
construction record.

## Register baseline

The register baseline is deliberately mechanical. For a snapshot or a
single-frame replay, `expectedCandidates` is the complete serialized output of
the fixed candidate generator for that exact state. For a replay window,
`expectedCandidateFrames` lists only frames with nonempty output; every omitted
frame is asserted to have no candidate. Each listed frame records
`afterEventIndex`, `timestampMs`, and its complete `candidates` array. The
validator runs the generator independently on every selected frame and requires
byte-independent JSON equality. It never runs the generator on the window's
aggregate note union.

This produces two essential regression patterns:

- a constructional positive can correctly have no register candidate when its
  layers overlap or unfold over time; and
- an integrated negative guard can correctly have a structural candidate that a
  later evidence or display policy must reject.

The doubled-accompaniment feature makes the second pattern executable for a
generated accompaniment-form texture rather than only for an abstract chord
collection. It does not assert that every doubled chord is accompaniment, that
doubling alone determines musical function, or that the exact voicing is common
in a measured population.

The baseline list is not a product prediction and is not scored as one.

## Admission policy

Synthetic cases require a complete generation recipe. Literature cases require a
stable score or analytical source record; a discovery webpage alone is not
sufficient. No moving score passage enters until its exact event window has been
transcribed into the frame-replay schema. Petrushka rehearsal 49 demonstrates
the admissible form: its construction is assigned over a bounded replay window,
while its register baseline is evaluated frame by frame and remains empty.

Validate the active seed from the repository root:

```sh
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
```
