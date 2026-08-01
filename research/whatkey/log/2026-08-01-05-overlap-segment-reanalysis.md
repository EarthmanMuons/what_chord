# 2026-08-01: Make the overlap segment result piece-aware

**Goal.** Run predeclared analysis R2 on the corrected ASAP/When-in-Rome
overlap: reproduce the historical pooled figure, then add contributing counts,
per-piece coverage/accuracy, paired descriptive intervals, and an
identical-event common-claim sensitivity view.

**Setup.** The scorer is clean commit
`bde0f19b3ceb7d117cefcefe97e900f6157feeb8`, including the enharmonic-equivalence
correction in log entry 2026-08-01-04. It verified the frozen corrected fixture
content and paper/reflex claims declared in entry -01. The final command was:

```sh
python3 tool/whatkey/revision_reanalysis.py overlap-segments \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --claims paper=build/whatkey-harness/asap-wir-v2pw-paper/claims.json \
  --claims reflex=build/whatkey-harness/asap-wir-v2pw-reflex/claims.json \
  --min-segment-measures 0,12,20,32 \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/overlap-segments.json
```

The output records a clean repository and has local SHA-256
`00c18bb98d697b93f01f081ce587b87e532f65eb6abeae6462d483192955b95c`. The
thresholds and pooled direction were already inspected, so all intervals below
are post-hoc descriptive summaries, not confirmatory tests.

**What happened.** The required reproduction gate passed exactly. At minimum
segment spans 0, 12, 20, and 32, paper exact/claim counts are respectively
4,864/9,360, 4,340/6,996, 3,397/5,325, and 2,585/3,783; reflex counts are
5,491/8,956, 4,157/6,713, 3,153/5,073, and 2,245/3,618. These are the preserved
pooled figure values.

The piece-aware own-claim view is:

| Minimum span | Pieces | Eligible events | Paper coverage | Reflex coverage | Paper exact | Reflex exact | Paper-reflex exact difference, descriptive CI95 |
| -----------: | -----: | --------------: | -------------: | --------------: | ----------: | -----------: | ----------------------------------------------: |
|            0 |     36 |          10,395 |         0.8954 |          0.8456 |      0.5019 |       0.6048 |                      -0.1030 [-0.1579, -0.0464] |
|           12 |     36 |           7,688 |         0.9088 |          0.8634 |      0.6004 |       0.6281 |                      -0.0277 [-0.0841, +0.0285] |
|           20 |     35 |           5,832 |         0.9072 |          0.8638 |      0.6249 |       0.6242 |                      +0.0007 [-0.0670, +0.0685] |
|           32 |     30 |           4,123 |         0.9126 |          0.8753 |      0.6905 |       0.6444 |                      +0.0461 [-0.0303, +0.1197] |

Paper has higher macro coverage at every threshold by 0.0498, 0.0454, 0.0434,
and 0.0373 respectively; each descriptive bootstrap interval remains above zero.
Claimed-event accuracy changes from a clear reflex advantage on all events
toward a near tie at 20 measures and a descriptive paper advantage at 32
measures. Unlike the pooled figure, the per-piece ordering does not reverse at
12 measures. The 32-measure accuracy interval spans zero.

The common-claim view restricts each threshold to the same events claimed by
both packages:

| Minimum span | Common claims | Macro common-claim fraction | Paper exact | Reflex exact | Paper-reflex difference, descriptive CI95 |
| -----------: | ------------: | --------------------------: | ----------: | -----------: | ----------------------------------------: |
|            0 |         8,160 |                      0.7699 |      0.5180 |       0.6106 |                -0.0926 [-0.1460, -0.0393] |
|           12 |         6,189 |                      0.7969 |      0.6084 |       0.6387 |                -0.0303 [-0.0864, +0.0246] |
|           20 |         4,693 |                      0.7950 |      0.6319 |       0.6378 |                -0.0060 [-0.0747, +0.0614] |
|           32 |         3,351 |                      0.8075 |      0.6913 |       0.6588 |                +0.0325 [-0.0432, +0.1082] |

The common-claim events are 78.5% to 81.3% of eligible events when pooled and
77.0% to 80.7% in the per-piece macro. Every eligible piece contributes common
claims. The relative shift therefore remains when unequal abstention sets are
removed: paper gains much more as the minimum analyst-segment span rises. But
only the all-event reflex advantage has an interval excluding zero; the later
near-tie and paper-leading values are descriptive.

**Plain-English reading.** The old pooled graph found a crossover at 12
measures, but that was partly a consequence of letting longer movements
contribute more observations. Giving every movement equal weight moves the
near-tie to 20 measures. Requiring both detectors to have spoken on the same
events produces the same gradual change. Longer, unchanged analyst-key regions
are associated with a growing relative advantage for the paper package, but the
data do not establish a sharp boundary or a reliable positive long-memory win at
a particular threshold.

**Decisions.** Preserve the old pooled counts as historical output, but do not
use their 12-measure crossover as a headline or as proof that the labels were
reannotated at multiple granularities. The supported result is narrower: as the
analysis is restricted to longer-persistence analyst-key segments, relative
accuracy shifts progressively from reflex toward paper on the same performed
corpus, including on common-claim events. Report the changing piece/event counts
and paper's consistently greater coverage. If this figure remains in the
revision, make the piece-level view primary and show uncertainty; a pooled curve
may appear only as a clearly labeled historical/secondary view.

**Next.** Commit the R2 record, then run predeclared R3. R3 changes the
reference construct on these same performances and claims; it must not be
described as a clean annotation-granularity manipulation.
