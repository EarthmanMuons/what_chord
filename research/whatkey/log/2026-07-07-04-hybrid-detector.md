# 2026-07-07: Hybrid detector beats the floor, with paired statistics

**Goal.** Combine the two complementary failures from entry 03: profile
correlation as the base score, the weighted evidence model's functional points
as an adjustment. Also add the paired-comparison tool the protocol's reporting
rules require, so the win (if any) is claimed properly.

**Setup.**

- New `HybridKeyDetector` in `lib/features/key/`, built by composition: it runs
  both sub-detectors internally and scores each key as
  `correlation + functionalBlend * points per weighted event`. Blend zero
  reduces exactly to profile correlation (unit-tested), which is the ablation
  anchor. Harness: `--detector hybrid`, `--functional-blend`.
- New `tool/whatkey/compare.py`: paired per-piece comparison of two harness
  reports with Wilcoxon signed-rank (normal approximation, tie and continuity
  corrections), seeded-bootstrap CI95 of the mean delta, and win/loss/tie
  counts. Pure stdlib.
- Fixtures and split as before. Blend swept on the development split at
  0.01/0.02/0.05/0.1/0.15/0.25; margin floor 0.05 (correlation units)
  throughout.

**Results, development split.**

| blend       | coverage | exact | MIREX | modulations |
| ----------- | -------- | ----- | ----- | ----------- |
| 0 (= floor) | 0.67     | 0.45  | 0.59  | 116/399     |
| 0.02        | 0.68     | 0.48  | 0.60  | 117/399     |
| 0.05        | 0.70     | 0.53  | 0.64  | 120/399     |
| 0.1         | 0.74     | 0.54  | 0.64  | 120/399     |
| 0.15        | 0.75     | 0.54  | 0.64  | 123/399     |
| 0.25        | 0.78     | 0.53  | 0.64  | 123/399     |

The hybrid dominates the floor on both axes at once: more coverage and more
accuracy. Paired test at blend 0.1 against the floor (56 paired pieces): mean
delta **+0.096 exact**, CI95 [+0.044, +0.150], **Wilcoxon p = 0.003**,
wins/losses/ties 32/18/6, with the hybrid at higher coverage (0.74 vs 0.67), so
the accuracy comparison is conservative in its favor. This is the first result
that clears the protocol's bar for picking a winner. Default blend pinned at
0.1, the start of the plateau.

**Results, behavioral suite** (blend 0.1): pop loop, ii-V-I, harmonic-minor
cadence, and secondary dominants all exact 1.00 with zero switches (the
histogram base damps the V/V flap that hit the evidence model alone); ambiguous
fixtures 8/8 and 7/7. One real regression: **blues**, exact 0.00 (MIREX 0.50,
claims F): the functional V-of-F pull now drags the histogram off C, where the
pure histogram had scored blues 1.00. The modulating chain improves only
slightly over the floor (0.20 vs 0.17), well short of the evidence model alone
(0.40): the histogram's inertia still dominates fast key areas at this blend.

**Reading.** Function and shape genuinely combine: the corpus win is large and
statistically solid, coverage rises because functional evidence breaks ties the
profile margin alone could not clear, and modulation matching only inches up,
confirming the remaining lag lives in the histogram's inertia, not the ranking.
Blues is now the flagship open probe: any fix (mode heuristic, tonic-anchoring,
or the 2e pattern layer) must not cost corpus accuracy.

**Plain-English reading.** Unpacking the headline claim, "+0.096 exact per
piece, CI95 [+0.044, +0.150], Wilcoxon p = 0.003, 32/18/6, at higher coverage"
(terms in [../../GLOSSARY.md](../../GLOSSARY.md)):

- **+0.096 exact per piece**: on an average piece, the hybrid names the
  analyst's exact key about 10 percentage points more often than the floor does,
  on the moments where each was willing to answer.
- **CI95 [+0.044, +0.150]**: given only these 56 pieces, the plausible range for
  that true average gain runs from about +4 to +15 points. The whole range sits
  above zero, so even the most pessimistic reading is still a win.
- **Wilcoxon p = 0.003**: if the two detectors were actually equally good,
  piece-to-piece luck would produce a lopsided result like this about 3 times
  in 1000. The win is very unlikely to be corpus noise.
- **32/18/6**: the hybrid won on 32 pieces, lost on 18, tied on 6. It is a
  consistent advantage across the corpus, not a few blowout pieces carrying the
  average.
- **At higher coverage**: the hybrid answered more often (74% of moments vs 67%)
  while also being more accurate. That direction matters: answering more
  questions usually costs accuracy, so winning both at once means the
  comparison, if anything, understates the improvement.

**Decisions.**

- Hybrid at blend 0.1 is the new champion and default detector recommendation;
  the blend was selected on the development split via the sweep plus a paired
  test, exactly what the split is for. The test split remains untouched.
- The comparison tool is the standard for any future "X beats Y" claim; means
  alone no longer qualify.
- Blues stays failing; no special case.

**Next.** In value order: modulation responsiveness (shorter or adaptive decay,
or claim-level hysteresis that lets the functional signal move first), the 2e
progression detectors, and eventually the deferred default-profile revisit, all
through paired comparisons on the development split.
