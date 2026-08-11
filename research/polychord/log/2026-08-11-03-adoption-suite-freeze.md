# 2026-08-11: Freeze the polychord adoption suite

**Goal.** Independently audit the completed coverage plan, record the exact case
and stratum inventory, verify every dependency pin, and enable scoring before
any selector is defined or evaluated.

**Setup.** Work began from clean repository commit `f0bd01ca`. The pre-freeze
suite had SHA-256
`98223e429d792fcb1235f0cf483d4c746e3ea3e3fd74c7fc65aef0e4c8bbf665`, status
`active-author-adjudicated-seed`, and `scoringAllowed: false`. No selector
implementation or output was available or read. No development-corpus result was
consulted, and the held 808-song POP909 reserve remained untouched.

This freeze audit did not add, remove, relabel, or reorder a case. It did not
change an expected decomposition, input-eligibility judgment, register
candidate, metric, winner rule, stability rule, threshold, or adoption
requirement. The only suite-data changes were the paired frozen status and
scoring permission plus refreshed hashes for documents whose status wording
changed. Test changes make the complete scorer control use the exact committed
frozen suite and retain a temporary non-scorable copy for the refusal check.

## Preregistered coverage disposition

The symmetric structural requirement remains satisfied by the pinned
`polychord-register-conformance/1` report: all 3,300 ordered identity and exact
assignment targets passed, all 11 focused controls passed, and the report still
verifies against the unchanged generator and harness.

Every product-policy cell in `adoption-suite-plan.md` has the following fixed
disposition:

| Required cell                                                | Frozen case                                      | Disposition                                          |
| ------------------------------------------------------------ | ------------------------------------------------ | ---------------------------------------------------- |
| Shared-pitch-class source positive                           | `ives-psalm-67-opening`                          | Satisfied                                            |
| Disjoint source positive                                     | `herrmann-pass-first-a-flat-minor-attack`        | Satisfied                                            |
| Source positive with complete seventh layer                  | `stravinsky-three-movements-g-over-a-flat-seven` | Satisfied                                            |
| Literature construction excluded by overlapping register     | `stravinsky-augurs-r13`                          | Satisfied                                            |
| Moving literature construction without false verticalization | `stravinsky-petrushka-r49-arpeggios`             | Satisfied                                            |
| Integrated compact-chord split                               | `synthetic-integrated-d-six`                     | Satisfied                                            |
| Integrated extended-chord split                              | `synthetic-d-over-c-major-seven`                 | Satisfied                                            |
| Moving source endpoint with integrated name                  | `stravinsky-shrovetide-second-attack`            | Satisfied                                            |
| Same-root register groups                                    | `synthetic-same-root-c-major-registers`          | Satisfied                                            |
| Incomplete lower seventh shell                               | `synthetic-d-over-c-seven-shell`                 | Satisfied                                            |
| Source-backed lone-bass or bare-fifth boundary               | `hancock-maiden-voyage-a-minor-seven-over-d`     | Satisfied by the preregistered lone-bass alternative |
| Doubled accompaniment confusion guard                        | `synthetic-c-major-seven-accompaniment`          | Satisfied                                            |
| Multiple structural identities                               | `stravinsky-three-movements-g-over-a-flat-seven` | Satisfied                                            |
| Multiple exact assignments for one identity                  | `synthetic-c-major-nine-assignment-ambiguity`    | Satisfied                                            |
| One-sounded-note overlapping cover                           | `strauss-elektra-chord-overlap`                  | Satisfied as a v0 boundary                           |

A genuine source-backed bare-fifth example remains useful future coverage, but
it is not a missing freeze cell: the plan explicitly allowed a lone-bass or
bare-fifth boundary, and _Maiden Voyage_ supplies the stronger recovered source
for that boundary. V0 continues to require two complete common chordal units for
a positive annotation, so this disposition does not widen or narrow the frozen
display vocabulary.

The selector-independent input, evidence, reason-code, metric, and
stable-display controls are also satisfied by the pinned decision-control and
exact-scorer tests. The scorer's synthetic complete-path control is generated
from expected answers; it verifies machinery and is not a selector result.

## Frozen inventory

The suite contains 17 cases: 8 positives, 5 boundaries, and 4 negative guards.
Its epistemic strata contain 7 literature-attested constructions, 3
theory-derived boundaries, and 7 synthetic regression guards. Adjacent-register
eligibility contains 9 eligible, 5 ineligible, and 3 ambiguous cases.

The adjacent-register scorer evaluates 6 eligible positives and all 9 boundary
or negative-guard cases. The 6 positives divide evenly between 3
literature-attested and 3 synthetic cases. The two remaining positives, Augurs
and Petrushka, are explicit literature-attested coverage exclusions rather than
detector misses. The 9 guards comprise 2 literature boundaries, 3 theory-derived
boundaries, and 4 synthetic negative guards.

| Case identifier                                  | Epistemic stratum   | Product class  | Adjacent status | Expected answer ID               | Candidate count |
| ------------------------------------------------ | ------------------- | -------------- | --------------- | -------------------------------- | --------------: |
| `hancock-maiden-voyage-a-minor-seven-over-d`     | literature-attested | boundary       | ineligible      | -                                |               0 |
| `herrmann-pass-first-a-flat-minor-attack`        | literature-attested | positive       | eligible        | `g-minor-over-a-flat-minor`      |               1 |
| `ives-psalm-67-opening`                          | literature-attested | positive       | eligible        | `c-major-over-g-minor`           |               1 |
| `strauss-elektra-chord-overlap`                  | theory-derived      | boundary       | ineligible      | -                                |               0 |
| `stravinsky-augurs-r13`                          | literature-attested | positive       | ineligible      | `f-flat-major-then-e-flat-seven` |               0 |
| `stravinsky-petrushka-r49-arpeggios`             | literature-attested | positive       | ineligible      | `c-major-over-f-sharp-major`     |               0 |
| `stravinsky-shrovetide-second-attack`            | literature-attested | boundary       | eligible        | -                                |               1 |
| `stravinsky-three-movements-g-over-a-flat-seven` | literature-attested | positive       | eligible        | `g-major-over-a-flat-seven`      |               2 |
| `synthetic-c-major-nine-assignment-ambiguity`    | synthetic           | negative guard | ambiguous       | -                                |               2 |
| `synthetic-c-major-seven-accompaniment`          | synthetic           | negative guard | ambiguous       | -                                |               1 |
| `synthetic-d-over-c-major-seven`                 | theory-derived      | boundary       | eligible        | -                                |               1 |
| `synthetic-d-over-c-seven-shell`                 | theory-derived      | boundary       | eligible        | -                                |               0 |
| `synthetic-d-sharp-seven-over-e`                 | synthetic           | positive       | eligible        | `d-sharp-seven-over-e-major`     |               1 |
| `synthetic-integrated-d-six`                     | synthetic           | negative guard | ambiguous       | -                                |               1 |
| `synthetic-layered-c-over-g-minor`               | synthetic           | positive       | eligible        | `c-major-over-g-minor`           |               1 |
| `synthetic-same-root-c-major-registers`          | synthetic           | negative guard | ineligible      | -                                |               0 |
| `synthetic-separated-f-sharp-over-c`             | synthetic           | positive       | eligible        | `f-sharp-major-over-c-major`     |               1 |

Candidate count is the complete adjacent-register baseline count for the exact
snapshot or selected replay frame. The moving Petrushka window has no candidate
on any frame; its aggregate note union is not treated as a snapshot.

## Freeze action and interpretation

The suite status is now `frozen-author-adjudicated-adoption` and
`scoringAllowed` is true. This permits a future preregistered selector to be
scored under `adjacentRegisterSnapshot`. It does not assert that the suite is
independent ground truth, authorize held data, or establish generalized
accuracy.

The internal-suite score is only adoption-bar items 2 through 4. Even a perfect
`suiteExactGatePass` does not satisfy the required development-corpus fire
dispositions, primary-engine regression checks, prior-art baselines, performance
budget, or device accessibility checks. Those remain future work after a
selector is separately specified.

After this freeze, any case, label, eligibility, metric, threshold, or
interpretation change requires a dated amendment and a new versioned suite
before further scoring. A correction that could affect interpretation is not a
typographical exception.

## Commands and verification

The audit inventory and final state were checked from the repository root with:

```sh
jq '{total:(.cases|length),byProduct:(.cases|group_by(.productExpectation.class)|map({key:.[0].productExpectation.class,value:length})|from_entries),byEpistemic:(.cases|group_by(.epistemicStatus)|map({key:.[0].epistemicStatus,value:length})|from_entries),byAdjacentEligibility:(.cases|group_by(.inputEligibility.adjacentRegisterSnapshot.status)|map({key:.[0].inputEligibility.adjacentRegisterSnapshot.status,value:length})|from_entries)}' \
  research/polychord/data/internal-suite/suite-v0.json
jq -r '.cases[] | [.id,.epistemicStatus,.productExpectation.class,.inputEligibility.adjacentRegisterSnapshot.status,([.productExpectation.expectedPolychords[].id]|join(", ")),(if .registerBaseline.expectedCandidates then (.registerBaseline.expectedCandidates|length) else ([.registerBaseline.expectedCandidateFrames[].candidates[]]|length) end)] | @tsv' \
  research/polychord/data/internal-suite/suite-v0.json
python3 tool/polychord/register_conformance.py \
  --verify build/polychord/register-conformance-v1.json
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/adoption-suite-plan.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/data/internal-suite/suite-v0.json \
  research/polychord/log/2026-08-11-03-adoption-suite-freeze.md
git diff --check
```

The conformance report verified, the suite validator accepted all 17 cases, all
223 polychord Python tests passed, Python lint and formatting passed, and
Markdown and JSON formatting passed.

Final SHA-256 pins:

- frozen suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`;
- framework: `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615`;
- fulfilled adoption plan:
  `f80d4bce9a144c884e06e2caee7ad71e854ebdc2b23b12e42d8a26081a162791`;
- output/evaluation contract:
  `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`;
- internal-suite schema:
  `657ba8f1ff2ffd8d5b6e4425e324dedaed976732ebdccace0ae90549d5abdeb8`;
- register-candidate schema:
  `533c20205d07e14291029af3455c366e0605d1a5c4b96311be85879069f22538`;
- frame-replay manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- internal-suite validator:
  `255cce5e0c8db9c890e28492737e725378202b50ca0a7f83a5fada2b1771e278`;
- exact scorer:
  `0942adf1bc07c041a443be21d54da845c8adc17d296392bfee6adba868d177d9`;
- protocol: `576006ba114dbe0a948201fc52b84489a5e0069178a7559c79876fea92af1df4`;
- internal-suite tests:
  `3b0dc3cf0c11594a590353311318d0f3f0378e7515c79e61178f6cfaf59d094e`;
- exact-scorer tests:
  `d27a3782fea5bb55fb721f37913d1f07fded62346bb2978b50b0f2cafb9052a1`;
- decision controls:
  `847d6d5a909b93e1b61457ab1185b4dc876080ace452d9c0d0e66bf8460fe8e3`;
- decision-control tests:
  `43185bd68099f58be3e2dc3adfe2f720743ec42d424809100f2334375ef975d8`;
- register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- conformance harness:
  `a6e6240edd71f1c5a0d097fe1846932e389f0d221cd51a1c50a1d6ee9d13e627`;
- conformance tests:
  `c4a114ef2fe2d282b0ff688d296d94023a645ba099d6ad3946d99d3c5be96331`; and
- conformance report:
  `00234efa005f25258b30e760ceb5f3d89ecc6e68badd470b968fa1ae02a31704`.

**Plain-English reading.** The questions and expected answers are now locked
before we build the rule that will answer them. Six cases ask a future selector
to produce one exact polychord, while nine ask it to abstain. Two important
Stravinsky constructions stay visible as coverage, but they are not counted as
misses because the specific adjacent-register input cannot recover them. A
perfect score here will mean agreement with this conservative WhatChord policy,
not universal musical correctness.

**Decisions.** Freeze the exact 17-case suite and permit scoring. Preserve the
author-adjudicated authority label and every construct-coverage exclusion. Keep
the held POP909 reserve untouched. Treat any future outcome-sensitive ruler
change as a versioned amendment rather than an edit to this suite.

**Next.** Define and preregister one selector or explicit selector ablation
without consulting suite outcomes. Only then implement the pure-Dart candidate
adapter and selector and run the frozen internal-suite and development-exposure
measurements.
