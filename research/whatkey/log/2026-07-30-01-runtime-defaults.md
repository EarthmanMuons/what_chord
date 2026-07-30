# 2026-07-30: Runtime defaults follow shipped behavior

**Goal.** Remove the mixed meaning of "default" in the WhatKey package. A
developer constructing the shipped detector or one of its shipped scoring
components should receive current app behavior, while historical research
configurations should require an explicit recipe or named constructor.

**Setup.** Base engine commit `74d8eaeb24094356e8ae09e393fd9ebef5041d61`. This
is a configuration-boundary decision, not a new detector experiment: no
fixtures, corpus split, labels, or metrics were consulted. The existing evidence
and adoption decisions remain in logs 2026-07-07-04, 2026-07-07-08,
2026-07-07-18, 2026-07-20-01, and the local 2026-07-26 adoption series.

The verification commands are:

```sh
dart format .
flutter analyze
cd packages/whatkey
dart analyze
dart run import_order_lint:import_order
dart test
cd ../..
mise research:whatkey-reproduction-verify
```

**What happened.** The audit first confirmed that `HmmKeyDetector` already had
the desired contract. The app constructs it with only the selected behavior
preset's emission half-life overridden; every other constructor default is the
current shipped value. The `whatKeyPaper2026` recipes separately pin every
consequential historical value, including the paper-era three-event warmup and
zero cadence boost.

The inconsistency was in the supporting scorers. `HybridKeyDetector` and
`ProfileCorrelationKeyDetector` participate in the shipped HMM, but their
unnamed constructors still selected standalone research-era claim gates and
blends. The boundary is now:

- Unnamed hybrid and profile constructors match their configuration on the
  current app path.
- `HybridKeyDetector.researchBaseline` and
  `ProfileCorrelationKeyDetector.researchBaseline` name the earlier standalone
  configurations explicitly.
- Zero functional and progression blends do not construct or evaluate their
  research-only scorers.
- The research harness explicitly selects the historical standalone hybrid blend
  values when a caller asks for that alternative detector, preserving pre-recipe
  experiment commands without letting those values masquerade as app defaults.
- The HMM emission constants refer to the hybrid's current defaults, and a
  package test pins that relationship.

The reproduction verifier passed all six fixture hashes and all nine frozen
result locks.

**Plain-English reading.** "Default" now means what a developer would see in the
app. Reproducing an older experiment remains supported, but the caller must say
that is what they want. The shipped detector's answers do not change; the
cleanup removes ambiguity and avoids calculating two research scores that were
being multiplied by zero.

**Decisions.** Current runtime behavior owns unnamed defaults for shipped code.
Historical publication configurations stay fully pinned in `DetectorRecipe`, and
standalone pre-HMM baselines use named constructors or explicit harness
fallbacks. Research-only detectors with no app equivalent keep their
algorithm-specific defaults.

No protocol amendment is required because the task, fixtures, splits, metrics,
scoring, and frozen recipes are unchanged.

**Next.** Apply the same rule whenever a future detector setting is adopted:
change the runtime default, pin any historical recipe that must retain the old
value, and verify the reproduction lock before merging.
