# 2026-08-10: Preregister adoption-suite coverage

**Goal.** Audit the ten-case internal seed against the frozen output and
evaluation contract, correct any policy or provenance defects before a selector
exists, and preregister the coverage required for the eventual adoption ruler.

**Setup.** Work began from clean repository commit `2e8e3885`. No selector has
been implemented or evaluated. No development-corpus result, held POP909 item,
or external-review response was consulted to choose cases or labels.

The audit read the framework, candidate schema, internal-suite schema, output
contract, active JSON suite, validator and tests, golden-candidate backlog, and
the dated source-verification records. It classified each active case by source
status, product class, adjacent-register eligibility, candidate count, layer
quality, shared-tone behavior, and integrated alternative.

The first validation command failed as it was designed to:

```text
ValueError: suite.dependencies.framework digest does not match .../FRAMEWORK.md
```

Commit `2e8e3885` changed the pinned framework and suite-schema documents while
leaving the non-scorable seed and replay-manifest pins unchanged. That was a
provenance regression, not a fixture or measurement change. This audit restores
a valid dependency closure and adds the newly normative output contract and
adoption plan as explicit pins.

## Audit result

The seed is not ready to freeze. Its only adjacent-register-eligible,
literature-attested positive is the Ives opening. The Augurs chord is an
important literature construction but is correctly ineligible because its source
units overlap in register. The remaining eligible positives are synthetic. That
is sufficient for mechanics research but not a strong basis for an
all-cases-exact product adoption gate or a publication-facing dataset.

The audit also found one substantive product-label error. The synthetic
`D|Cmaj7` case was marked positive solely because its recipe generated two
complete units. The same notes form the conventional integrated `Cmaj13(#11)`,
and Framework v0 already excludes an upper structure when an established
integrated extension names the sonority. The case is therefore a theory-derived
boundary: the register generator must still emit `D|Cmaj7`, but a selector must
abstain. This correction was made before any selector output existed.

The remaining coverage gaps are not one undifferentiated request for more
examples. `adoption-suite-plan.md` separates:

- exhaustive generated structural conformance across the symmetric five-by-five
  layer vocabulary from musical product labels;
- source-attested construction anchors from synthetic implementation controls;
- positive cells from explicit integrated, incomplete-layer, same-root,
  multiple-candidate, assignment-ambiguity, and overlapping-cover guards;
- snapshot, temporal, and missing-register input behavior; and
- author product-policy conformance from any future external-validity study.

The generated structural matrix is intentionally exhaustive: five ordered upper
qualities by five lower qualities, 11 nonzero relative-root intervals, and 12
transpositions, or 3,300 identity combinations. It prevents a return to an
upper-triad-only implementation without pretending that generated examples are
3,300 validated musical positives.

## Decisions

Adopt `adoption-suite-plan.md` as the preregistered completion and stopping
rule. Keep the ten-case seed at `scoringAllowed: false`. Add the plan and output
contract to the suite dependency closure. Reclassify the complete
C-major-seven-plus-D-major case as an integrated-extension boundary while
retaining its exact structural-candidate expectation.

A required source-attested positive cell may not be filled by an arbitrary
synthetic construction. Before the ruler freezes, the project must either admit
a pinned exact case or narrow the selectable v0 vocabulary for the unresolved
cell. Ineligible literature cases remain coverage exclusions rather than
detector misses, but they stay in the record so detector convenience cannot
silently redefine the construct.

External review remains optional validation of the mature task and labels, not a
blocking authority that must bless this plan. The held 808-song POP909 reserve
remains untouched.

## Validation and pins

The repaired dependency closure and ten cases passed with:

```sh
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/adoption-suite-plan.md \
  research/polychord/data/frame-replay/manifest.json \
  research/polychord/data/internal-suite/suite-v0.json \
  research/polychord/log/2026-08-10-19-adoption-suite-coverage-audit.md
git diff --check
```

The frame-replay validator accepted all eight fixtures, the suite validator
accepted all ten cases, and all 156 polychord Python tests passed.

Final SHA-256 pins:

- adoption-suite plan:
  `720a50e34d38bd6cf1c02be9627e55247a10395dac59ac49b1d22348ff6014a0`;
- internal-suite schema:
  `c208e1ddc39e124462918ce973f1314f67ced55f4ab5c9d3f481e3c55b4ea415`;
- frame-replay manifest:
  `5e1434e24f68650d25955647414e7e2a25b0b1e5ddfafad9d2bb66464269e04a`;
- ten-case non-scorable suite:
  `bebffd8834a29595da08cfbb07702cf77da18d530747587f547f0633bd97154d`;
- internal-suite validator:
  `32f3d2f756f2b5ef1069e4db92b9af760d0a7a691bd82d6a95cac3eea266bba2`; and
- internal-suite tests:
  `912c07b889d804c95d01f95bf0d5d9283d959a832c09a20fc115242267a8ac38`.

**Next.** Implement the generated structural conformance matrix before searching
for or admitting the missing source-attested cases. It is deterministic,
selector-independent work and will establish whether the symmetric common-chord
scope is actually implemented without hidden asymmetry.
