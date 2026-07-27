# 2026-07-27: Correction addendum: asap-wir ground-truth labels were misaligned

**Goal.** Record corrected numbers for the results that scored against
`asap-wir-nc-v1`, whose analyst key labels turned out to be measure-shifted in
11 of 36 movements. This entry amends the record without editing the original
entries (2026-07-07-21, -22, -23), per the append-only convention.

**Setup.** The performed-input initiative's alignment census (performed-input
log 2026-07-27-02) found that the extractor's downbeat-map offset calibration,
which matched only the last measure numbers over offsets {0, +1}, picked the
wrong offset for 8 movements and could not represent the -1 cases at all;
content-based calibration plus the census then corrected 11 movements in total
(performed-input log 2026-07-27-03). The v1 and v2 replays are event-identical,
so the diff is purely ground truth: 347 of 10,395 event key labels (3.34%) were
wrong, worst in 30-1 (22.9%), 7-1 (18.9%), and 16-2 (15.9%). The corrected
corpus is `asap-wir-nc-v2`; v1 stays frozen for the reproduction contract.

```sh
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --recipe whatKeyPaper2026 --out build/whatkey-harness/asap-wir-v2-paper
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --recipe whatKeyPaper2026Reflex --out build/whatkey-harness/asap-wir-v2-reflex
python3 tool/whatkey/mode_confusion.py \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --claims build/whatkey-harness/asap-wir-v2-paper/claims.json
```

**What happened.** The controlled timescale experiment (entry -21), re-run with
the era configurations via the pinned paper recipes on corrected labels
(published values in parentheses):

| config             | coverage     | exact        | MIREX        | modulations       | spurious       |
| ------------------ | ------------ | ------------ | ------------ | ----------------- | -------------- |
| shipped (30 s)     | 0.895 (0.91) | 0.504 (0.47) | 0.627 (0.60) | 142/454 (126/459) | med 3, p90 7   |
| reflex (1 s, f0.1) | 0.846 (0.85) | 0.601 (0.59) | 0.696 (0.69) | 310/454 (305/459) | med 12, p90 29 |

The headline conclusion is unchanged and slightly stronger: on identical
performed input the tonicization-scale ruler still decisively prefers the reflex
configuration, and the label correction moved both arms up, the shipped arm most
(its errors were concentrated where the labels were wrong). The annotated-change
count moved from 459 to 454 because corrected offsets relocated a few key-change
boundaries.

Mode accuracy (entry -21's second table), corrected (published in parentheses):

| config  | exact    | fifth    | relative (mode) | parallel (mode) | other    |
| ------- | -------- | -------- | --------------- | --------------- | -------- |
| shipped | 52% (50) | 18% (17) | 5% (5)          | 6% (9)          | 18% (18) |
| reflex  | 60% (60) | 14% (14) | 5% (6)          | 6% (6)          | 15% (15) |

The material correction: the shipped configuration's parallel-mode confusion was
overstated by half (9% to 6%), so total mode error is 11% of claims, not 14%.
About one in nine claims, not one in seven, and a third of the previously
measured mode error was the answer key, not the detector.

Entries -22 and -23 used this corpus only as corroboration (the filtered-mode
variant and the tilt-strength confirmation); their adoption decisions rested on
the Isophonics and When in Rome development sweeps, which never touched this
alignment. The corrected shipped-arm numbers above are the corrected form of
that corroboration (the paper recipe includes mode tilt 2), and no conclusion in
either entry changes.

Entry -22's segment-filtered series feeds the paper's within-corpus crossover
figure, so it was re-run on corrected labels (pooled exact on claims,
`mode_confusion.py --min-segment-measures`; published values in parentheses):

| segments | shipped exact | reflex exact |
| -------- | ------------- | ------------ |
| all      | 0.52 (0.50)   | 0.60 (0.60)  |
| >= 12    | 0.62 (0.60)   | 0.61 (0.62)  |
| >= 20    | 0.64 (0.63)   | 0.62 (0.62)  |
| >= 32    | 0.69 (0.65)   | 0.62 (0.62)  |

The crossover sharpens: the long-memory configuration now overtakes by
12-measure segments (published: at 20) and its advantage widens to 7 points at
32-measure segments, while reflex stays flat. The mislabeled movements were
diluting exactly the long-segment cells where the section-scale configuration
earns its wins.

**Plain-English reading.** The answer key for the performed-piano corpus had
eleven pieces labeled one measure off. Regrading with the fixed key, every
finding stands, the detector scores a little better than reported, and the most
user-facing number, how often the displayed mode is wrong, improves from one in
seven claims to one in nine.

**Decisions.**

- Published entries stay as written; this addendum plus REPRODUCING.md's note
  are the record. The paper contract still reproduces the published numbers bit
  for bit against frozen v1.
- Any future work on this corpus uses `asap-wir-nc-v2` or later.

**Next.** None for this initiative (complete); the corpus work continues in
research/performed-input/.
