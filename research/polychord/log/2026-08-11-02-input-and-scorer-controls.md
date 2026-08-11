# 2026-08-11: Implement input and exact-scorer controls

**Goal.** Close the preregistered input-condition, stable-display, and scoring
control gaps without defining or observing a polychord selector, then determine
whether the seventeen-case active seed is ready for a separate freeze audit.

**Setup.** Work began from clean repository commit `ae1cb472`. No selector
output, development-corpus result, held POP909 item, or empirical product-policy
score was read. All metric tests used hand-authored or expectation-derived
synthetic control candidates. The committed suite remained
`active-author-adjudicated-seed` with `scoringAllowed: false` throughout this
work. One unit test changes only the status pair in a temporary suite copy so
the scorer's successful path can execute; that copy is discarded and its perfect
predictions are generated from the expected answers, not from a selector.

The audit covered `PROTOCOL.md`, `FRAMEWORK.md`, the output/evaluation contract,
the adoption-suite plan, the internal-suite schema and validator, and the
seventeen-case seed. It found four contract gaps before implementation:

1. The adoption plan required a frozen scorer pin, while the implementation
   order froze the suite before creating that scorer. This was circular.
2. Acceptable answers had no stable identifiers, and multiple-answer scoring had
   no deterministic winner rule.
3. The scorer did not name which of the three input conditions it evaluated.
4. The protocol's source rule incorrectly forced every analytically normalized
   case into the synthetic stratum, despite the newly admitted _Maiden Voyage_
   case preserving a published exact pitch collection and named decomposition.

## Contract decisions

The implementation order is now: complete the suite; implement and test the
selector-independent controls; freeze the final suite, scorer, strata, and pins;
then define a selector. This lets the scorer become part of the frozen ruler
without exposing the ruler to selector outcomes.

The v0 scorer evaluates only `adjacentRegisterSnapshot`. General registered
snapshots and timestamped event streams remain separately reported construct
coverage until each has a named, preregistered method. Their results may not be
pooled into the adjacent-register gate.

Every acceptable positive answer now has a stable identifier. When a case has
more than one acceptable answer, the scorer takes the lexicographic maximum of:

1. ordered-composite exact;
2. assignment exact;
3. layer-identity credit;
4. orientation correct, with undefined below zero; and
5. note-assignment accuracy.

The first declared answer wins an exact tie. This orders the exact gates before
all partial diagnostics, so a partly similar reading cannot outrank an exact
acceptable decomposition. Resolved answers must identify units in upper-then-
lower order. Identifiers and decompositions are both unique, so different IDs
cannot alias one answer; the tie control uses genuinely distinct alternatives.
If an orientation-neutral construction becomes eligible for any ordered gate,
the validator requires both orientations rather than treating array order as an
answer.

Analytical normalization remains source-attested only when the pinned analysis
supplies the complete pitch collection and named decomposition and the suite
discloses exactly how octave placement was normalized. It must not be described
as a literal score transcription. A normalization that supplies or changes the
decomposition remains synthetic or theory-derived.

## Executable controls

`tool/polychord/decision_contract.py` implements `polychord-decision-control/1`
as a research control surface, not a production output type or selector. An
externally supplied policy selection must be one of the exhaustive structural
candidates, and each candidate's assigned pitch classes must exactly realize its
declared roots and qualities. The controls establish that:

- registered static MIDI stays eligible without onset or motion history;
- neutral or unavailable temporal evidence does not veto a selection;
- positive temporal evidence is recorded but cannot create a selection;
- pitch-class-only input cannot carry register candidates and reports
  `missing-register-evidence`; and
- the 200-millisecond display reducer delays appearance and identity changes but
  clears immediately on silence, absent primary analysis, selector abstention,
  or invalidated exact assignment.

`tool/polychord/internal_suite_scorer.py` implements `polychord-exact-scorer/1`.
A prediction artifact must pin the suite digest, input condition, selector
identifier, and exactly one prediction record for every suite case. It rejects
duplicate cases, incomplete case coverage, unversioned or duplicate reason
codes, an unexplained abstention, an abstention reason attached to a selection,
invalid candidates, and a mismatched suite digest. Most importantly, it refuses
to score while `scoringAllowed` is false, and any selected prediction must
exactly match one candidate from the case's frozen register baseline.

Synthetic unit controls exercise the complete scorer path, exact predictions,
swapped orientation, one correct layer, wrong assignment, positive abstention,
correct guard abstention, an unexpected guard fire, a selection outside the
frozen candidate set, multiple acceptable answers, exact-answer ties,
unversioned or incoherent reasons, malformed layer identities, static and
temporal evidence states, and every frozen display transition. These are
code-path controls, not observations of a future selector.

The scorer retains exact integer numerators and denominators for all metrics:
cases for the binary gates, matched versus expected layers for layer credit,
defined cases for orientation, and correctly assigned versus observed notes for
note-assignment accuracy. This prevents a later report from replacing the frozen
per-case evidence with an opaque rounded average.

The summary field is `suiteExactGatePass`, not `adoptionExactPass`. It is false
when either the eligible-positive or guard denominator is zero, and it covers
only the internal-suite exact gates. Corpus dispositions, regressions,
baselines, performance, and device accessibility remain separate adoption
requirements.

## Validation

The completed change was checked from the repository root with:

```sh
mise python:format
npx prettier --write --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/adoption-suite-plan.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/data/internal-suite/suite-v0.json \
  research/polychord/log/2026-08-11-02-input-and-scorer-controls.md
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/adoption-suite-plan.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/data/internal-suite/suite-v0.json \
  research/polychord/log/2026-08-11-02-input-and-scorer-controls.md
git diff --check
```

The suite validator accepted all 17 active cases, all 223 polychord Python tests
passed, Python lint and formatting passed, and Markdown and JSON formatting
passed.

Final SHA-256 pins:

- protocol: `ae17e947ad51cb102f23b25e6f8a12ed94f49e129a3febd121a2dd2ed9397202`;
- adoption-suite plan:
  `0cc41ef9c28c235679c7956198122d3678d854f86effcd644e1a62f38fd68b5b`;
- output/evaluation contract:
  `492c023ee26784d80c997b7c83b80549952762e7fb95834164ff77ffd7ccd2eb`;
- internal-suite schema:
  `653d61120de28d26c146b6fba69228db599a1bacb44b0fa5237500a4e824e6ac`;
- seventeen-case non-scorable suite:
  `98223e429d792fcb1235f0cf483d4c746e3ea3e3fd74c7fc65aef0e4c8bbf665`;
- decision controls:
  `847d6d5a909b93e1b61457ab1185b4dc876080ace452d9c0d0e66bf8460fe8e3`;
- decision-control tests:
  `43185bd68099f58be3e2dc3adfe2f720743ec42d424809100f2334375ef975d8`;
- internal-suite validator:
  `255cce5e0c8db9c890e28492737e725378202b50ca0a7f83a5fada2b1771e278`;
- internal-suite tests:
  `5138a6a5b5ddafd576e543f18b88c10fdc909ec94c50dbe8123cb30bfdda2566`;
- exact scorer:
  `0942adf1bc07c041a443be21d54da845c8adc17d296392bfee6adba868d177d9`; and
- exact-scorer tests:
  `a72a10ae8ea3ddfd1a4ea80e53896ed4b5ab054d2b67e2d0a1410958bd1a3278`.

**Plain-English reading.** We can now test a future selector without changing
the questions after seeing its answers. The code first checks whether a
prediction names the right two chords, in the right upper/lower order, with the
right notes assigned to each. Softer similarity numbers are retained only to
explain failures. Timing information may support a result, but lack of timing
does not disqualify a valid registered snapshot, and timing alone cannot invent
one.

**Decisions.** Adopt the executable decision controls and exact scorer as part
of the prospective ruler. Keep the suite non-scorable. Treat the four audit
findings as pre-freeze contract corrections rather than measurements, and
preserve them in this entry because they change the scientific evaluation
method.

**Next.** Perform a separate dated freeze audit that checks every required
coverage cell, records exact case identifiers and stratum counts, verifies every
dependency digest, and only then changes the suite to
`frozen-author-adjudicated-adoption` with `scoringAllowed: true`. Do not define
or execute a selector until that freeze is complete.
