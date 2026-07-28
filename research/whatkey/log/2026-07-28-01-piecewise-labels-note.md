# 2026-07-28: Note: piecewise label refinement nudges overlap numbers within rounding

**Goal.** Record the effect of the piecewise offset calibration (performed-input
log 2026-07-28-11, eight movements re-labeled) on the asap-wir numbers corrected
yesterday (log 2026-07-27-01).

**What happened.** Era-recipe re-runs on the piecewise labels, against the
single-offset corrected values in parentheses: shipped-era coverage 0.895
(0.895), exact 0.502 (0.504), MIREX 0.626 (0.627); reflex coverage 0.846
(0.846), exact 0.605 (0.601), MIREX 0.699 (0.696); annotated changes back to 459
as corrected offsets relocated boundaries again. The paper's segment-filtered
series moves by a hundredth in three cells (30 s: 0.52, 0.62, 0.64, 0.68; 1 s:
0.61, 0.62, 0.62, 0.62), and the long-memory configuration still overtakes by
12-measure segments. Spot check of the cadence-boost confirmation (hl4, cb 4 vs
base): +0.0198, CI95 [+0.0095, +0.0299], p = 0.0006 (28/7/1), against +0.0188
corrected and +0.0197 originally published.

**Decisions.** Every conclusion is unchanged; the deltas sit within a hundredth.
The paper's figure series and noise-control sentence are updated to the
piecewise values; yesterday's addendum tables stand as the record of the
single-offset correction, with this note as the lineage link. Future runs on
this corpus use the piecewise-calibrated set.
