# Polychord internal-suite schema

Status: active contract for `polychord-internal-suite/1`. This schema records an
author-adjudicated product-policy suite. It is not an independently annotated
ruler, does not authorize generalized accuracy claims, and remains non-scorable
until the output representation, metrics, and adoption threshold are frozen.

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

- `schema`: `polychord-internal-suite/1`;
- `status`: `active-author-adjudicated-seed`;
- `scoringAllowed`: `false` until a later evaluation freeze;
- `authority`: `product-policy-only-not-independent-ground-truth`;
- `noteConvention`: `MIDI 60 is C4; spellings are case-specific`;
- `dependencies`: SHA-256 pins for the framework, this schema, the register
  candidate schema, frame-replay manifest, and validator; and
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
- `observation`: one exact snapshot or one exact frame from the pinned replay
  manifest;
- `construction`: the author-adjudicated musical construction and exhaustive
  note-to-unit assignment;
- `productExpectation`: positive, boundary, or negative-guard policy;
- `inputEligibility`: separate judgments for adjacent-register snapshots,
  general pitch-and-register snapshots, and timestamped event streams; and
- `registerBaseline.expectedCandidates`: the exact unranked JSON candidate list
  required from `polychord-register-candidates/1`.

Unknown fields are rejected.

## Human-readable observations

Every observed MIDI note has a parallel scientific-pitch spelling such as `C4`,
`F#3`, or `Bb2`. The validator resolves accidentals across octave boundaries, so
spellings such as `Cb3` and `Fb2` must sound at the recorded MIDI pitch.

A snapshot stores `soundingMidiNotes` and `spelledNotes` directly. A replay
observation stores a pinned `fixtureId`, `afterEventIndex`, and `spelledNotes`.
The validator resolves that exact frame and does not accept an aggregate note
set copied out of the event window.

## Construction and notation

Construction kinds are:

- `polychord`: two complete source or generated chordal units;
- `integrated-chord`: one chordal unit explaining the entire observation; and
- `upper-structure`: a performance decomposition whose integrated reading is
  preferred under Framework v0.

Every unit records an identifier, musician-facing identity, root pitch class,
quality, MIDI notes, spellings, and pitch classes. Units are disjoint at the
MIDI-note level and together assign every observed note. Shared pitch classes
remain possible through separate note instances.

Schema 1 validates each quality against its root-relative pitch classes. The
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

## Product expectation and eligibility

`productExpectation.class` is `positive`, `boundary`, or `negative-guard`.
Positive cases identify the expected pair of construction units and include a
symbol only when notation order is resolved. Boundary and negative cases expect
no polychord annotation. Primary single-chord alternatives are retained rather
than treated as annotation errors.

Eligibility statuses are `eligible`, `ineligible`, `ambiguous`, and
`not-available`, each with a reason. They describe whether the named input
condition supplies the evidence needed for this case; they do not alter the
construction record.

## Register baseline

The register baseline is deliberately mechanical. Its expected list is the
complete serialized output of the fixed candidate generator for the exact
observation. The validator executes the generator and requires byte-independent
JSON equality with that list.

This produces two essential regression patterns:

- a constructional positive can correctly have no register candidate when its
  layers overlap or unfold over time; and
- an integrated negative guard can correctly have a structural candidate that a
  later evidence or display policy must reject.

The baseline list is not a product prediction and is not scored as one.

## Admission policy

Synthetic cases require a complete generation recipe. Literature cases require a
stable score or analytical source record; a discovery webpage alone is not
sufficient. No moving score passage enters until its exact event window has been
transcribed into the frame-replay schema. In particular, the rehearsal-49
Petrushka passage remains outside the active seed despite its verified
construction because verticalizing its arpeggiated streams would create a false
snapshot.

Validate the active seed from the repository root:

```sh
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
```
