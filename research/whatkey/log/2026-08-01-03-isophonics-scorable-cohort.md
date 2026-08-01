# 2026-08-01: Correct the Isophonics selective-prediction cohort

**Goal.** Run predeclared analysis R1: pair coverage and exact accuracy on the
same Isophonics events that have references inside the detector's 24-state
major/minor ontology, while retaining the modal tracks as a separate behavioral
audit.

**Setup.** The scorer is commit `d37655e0c4198767f1ca5ddb24362b5c87003a61`. It
verified the frozen Isophonics fixture manifest/content, split, and paper/reflex
held-out claim hashes declared in log entry 2026-08-01-01. The repository was
clean. The one scoring command was:

```sh
python3 tool/whatkey/revision_reanalysis.py isophonics-cohort \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split test \
  --claims paper=research/whatkey/results/test-split-2026-07-07/test-iso-hmm-shipped/claims.json \
  --claims reflex=research/whatkey/results/test-split-2026-07-07/test-iso-hmm-reflex/claims.json \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/isophonics-test-cohort.json
```

The local output SHA-256 is
`484e8027d749761f6a9712d57d3a2aac0a2abd7be7d694459c8601624bfe39f3`.

**What happened.** The objective mask produced exactly the expected partition:
38 tracks with 3,260 scorable events and three entirely modal Beatles tracks
with 305 out-of-ontology events. The two partitions sum to the frozen 41 tracks
and 3,565 events. The paper claims 2,886 scorable events and the reflex package
2,616. Adding their modal-track claims (274 and 250 respectively) reproduces the
archived all-event claim totals of 3,160 and 2,866.

| Package | Archived macro coverage, 41 tracks | Corrected macro coverage, 38 scorable tracks | Macro exact on claims | Micro coverage | Micro exact on claims |
| ------- | ---------------------------------: | -------------------------------------------: | --------------------: | -------------: | --------------------: |
| paper   |                             0.8843 |                                       0.8841 |                0.7316 |         0.8853 |                0.7207 |
| reflex  |                             0.7968 |                                       0.7934 |                0.5564 |         0.8025 |                0.6021 |

Exact accuracy is unchanged from the archive because the old exact scorer
already skipped null reference labels. Coverage moves only slightly when its
cohort is made consistent with accuracy. On the corrected paired 38-track
cohort, paper minus reflex is `+0.0907` macro coverage (descriptive bootstrap
CI95 `[+0.0488, +0.1317]`) and `+0.1753` macro exact accuracy on claims (CI95
`[+0.0419, +0.3124]`). These intervals are post-hoc construct-validity
summaries, not new confirmatory tests.

The three modal tracks remain visible without a correctness judgment:

| Track                  | Events | Paper claims / switches / first claim | Reflex claims / switches / first claim |
| ---------------------- | -----: | ------------------------------------: | -------------------------------------: |
| Baby You're A Rich Man |     79 |                            64 / 2 / 2 |                             76 / 1 / 2 |
| Fixing A Hole          |     97 |                            87 / 8 / 3 |                             82 / 8 / 3 |
| Dear Prudence          |    129 |                           123 / 0 / 3 |                            92 / 20 / 2 |

Switches here are raw changes between claims. They are not errors: a modal
reference outside the model cannot determine whether any 24-key switch was
spurious.

**Plain-English reading.** The denominator problem was real but numerically
small. The old table asked accuracy about 38 tracks and coverage about 41; the
corrected table asks both questions about the same 38 scorable tracks. Doing so
does not rescue or damage either configuration. The paper package still answers
more often and is more accurate when it answers under this held-out Isophonics
regime. The three excluded-from-correctness tracks have not disappeared; they
are reported as examples of how a major/minor-only system behaves when the
source annotation calls the music modal.

**Decisions.** Use the corrected 38-track coverage-accuracy pair in the revised
manuscript, naming it as 38 scorable tracks within the frozen 41-track split.
Preserve the archived 41-track coverage semantics in the audit trail and state
that exact accuracy did not change. Do not call abstention correct on modal
events, do not remove the modal tracks from the dataset, and do not interpret
their raw switches as errors. The package-ordering conclusion is unchanged.
Reference-dependent stability denominators remain a separate open audit; until
then, do not use the modal tracks' nominal zero spurious-switch counts as
evidence.

**Next.** Commit this R1 record, then run R2 on the frozen corrected overlap
claims. R2 must reproduce the historical pooled counts before its piece-level,
coverage, and common-claim summaries are interpreted.
