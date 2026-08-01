# 2026-08-01: Restore enharmonic equivalence in the revision scorer

**Goal.** Resolve a failed R2 reproduction gate before interpreting any new
piece-level or common-claim result.

**Setup.** The first R2 execution used scorer commit
`d37655e0c4198767f1ca5ddb24362b5c87003a61` from a clean repository and the exact
predeclared command in log entry 2026-08-01-01. The expected historical pooled
exact/claim counts, already inspected before R2, were:

| Minimum segment measures | Paper exact / claims | Reflex exact / claims |
| -----------------------: | -------------------: | --------------------: |
|                        0 |        4,864 / 9,360 |         5,491 / 8,956 |
|                       12 |        4,340 / 6,996 |         4,157 / 6,713 |
|                       20 |        3,397 / 5,325 |         3,153 / 5,073 |
|                       32 |        2,585 / 3,783 |         2,245 / 3,618 |

The diagnostic and correction commands were:

```sh
python3 tool/whatkey/revision_reanalysis.py overlap-segments \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --claims paper=build/whatkey-harness/asap-wir-v2pw-paper/claims.json \
  --claims reflex=build/whatkey-harness/asap-wir-v2pw-reflex/claims.json \
  --min-segment-measures 0,12,20,32 \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/overlap-segments.json
mise python:format
mise python:lint
python3 tool/whatkey/revision_reanalysis_test.py
python3 -m py_compile \
  tool/whatkey/revision_reanalysis.py \
  tool/whatkey/revision_reanalysis_test.py
```

**What happened.** The first pass reproduced every eligibility and claim count
but undercounted exact matches:

| Minimum segment measures | Literal-string paper exact | Literal-string reflex exact |
| -----------------------: | -------------------------: | --------------------------: |
|                        0 |                      4,849 |                       5,302 |
|                       12 |                      4,329 |                       4,094 |
|                       20 |                      3,386 |                       3,105 |
|                       32 |                      2,574 |                       2,217 |

The cause was semantic rather than data drift. The Dart harness parses labels
and claims into canonical tonalities, and the earlier Python mode-confusion
diagnostic compares tonic pitch class plus mode. The new generic piece scorer
instead compared raw strings, so enharmonic spellings such as `D#:min` and
`Eb:min` were incorrectly different.

The scorer now permits the claim and reference to be transformed separately and
uses the same pitch-class/mode parser for every 24-key exact view in R1, R2, and
R4. A synthetic enharmonic regression test was added. Ruff formatting/lint,
Python compilation, and all 10 unit tests pass. A second diagnostic R2 pass
reproduced all four historical count pairs exactly, including 4,864/9,360 and
5,491/8,956 at the unfiltered threshold. That pass reports a dirty repository
and is not the final R2 artifact; it will be overwritten after this correction
is committed. No new R2 endpoint from either diagnostic pass is adopted or
interpreted here.

R1's result is unchanged: its corrected macro exact values already matched the
archived harness values exactly, so its held-out Isophonics cohort contains no
claim/reference alias that changes the result. Canonical parsing simply makes
that intended semantics explicit for future runs.

**Plain-English reading.** Two differently spelled names can denote the same
musical key. The first calculator version forgot that and failed the deliberate
historical cross-check. Fixing the comparison makes the new calculator agree
with both the app's scorer and the preserved old diagnostic before we look at
the genuinely new R2 summaries.

**Decisions.** Treat exact key identity as tonic pitch class plus major/minor
mode throughout the revision analyses. Retain the historical-count gate as a
required R2 invariant. Do not cite or preserve the dirty diagnostic result as
the analysis output.

**Next.** Commit this correction, rerun R2 from the clean scorer commit, verify
the same four count pairs again, and only then interpret the piece-level,
coverage, and common-claim results.
