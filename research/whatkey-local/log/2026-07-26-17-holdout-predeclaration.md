# 2026-07-26: Holdout evaluation pre-declaration

**Goal.** Declare, before execution, the one-shot holdout result set that closes
this initiative: the test-split evaluation of the shipped detector and the
headline comparison against the paper-era configuration and the external music21
baselines.

**Design.** A two-by-two per test split attributes the improvement honestly:

- Fixture axis: the paper-era pinned fixtures (local builds verified
  byte-identical to the v2026.7.14 reproduction lock) versus fixtures
  regenerated from the same pinned corpus checkouts under the current analysis
  profile (capturing the post-paper engine-era changes: lever 0, the F sharp
  side, the explanation-cost era refinements to candidates).
- Detector axis: the `whatKeyPaper2026` recipe versus the current shipped
  defaults (cadence boost 4, one-event warmup gate; mode tilt was already in the
  paper configuration, so the detector delta isolates this initiative).

Cell A (paper detector, paper fixtures) is the committed
`results/test-split-2026-07-07` artifact set, hash-verified today; it is not
re-spent. The new runs, all one-shot:

1. Cell B: current defaults, paper fixtures, stable timescale, Isophonics test
   and When-in-Rome test.
2. Cell C: paper recipe, current fixtures, both test splits.
3. Cell D: current defaults, current fixtures, both test splits (the headline
   "system today" cell).
4. Preset rows: current defaults at hl4 and hl1 on current fixtures, both test
   splits (the secondary table; not headline claims).
5. External anchor: the committed music21 baseline claims re-scored at matched
   coverage against Cell D's claimed events on Isophonics test (the paper's "KS
   matched" method), plus the committed offline rows (coverage 1.00) reused as
   published.

Paired statistics via `tool/whatkey/compare.py` (per-piece Wilcoxon and seeded
bootstrap CI95): B versus A (the initiative's detector delta on paper fixtures),
D versus C (the same delta on current fixtures), D versus B (the engine-era
fixture delta), and Cell D versus the matched-coverage KS baseline.

**Pre-declared expectations.** The detector delta (B vs A, D vs C) improves
exact on both splits, directionally consistent with the dev and overlap results
(When-in-Rome local exact by roughly one to two points, Isophonics exact within
noise to slightly positive, coverage up on both); the fixture delta (D vs B) is
small (the reproduction contract recorded 55 reordered events on Isophonics);
and the current system holds or extends the paper's "at least parity under a
strictly harder setting" position against the matched KS baseline. Reported
either way, including any miss.

**Spend accounting.** This is one declared result set spending both test splits
once, including the preset rows; per the inherited protocol, no further
test-split runs occur in this initiative after this set. Results land in the
next entry; the headline and preset tables land in the initiative README.

**Setup pins.** Engine at the shipped defaults (this entry follows log -16).
Fixture regeneration commands, from the same pinned checkouts the reproduction
lock records:

```
.venv/bin/python3 tool/whatkey/isophonics_extract.py \
  --choco-root build/whatkey-corpora/choco --set isophonics-nc-v1 \
  --out build/whatkey-fixtures-current --analysis-profile current

.venv/bin/python3 tool/whatkey/fixture_extract.py \
  --set when-in-rome-v1 --out build/whatkey-fixtures-current \
  --analysis-profile current when-in-rome \
  --bench-root build/whatkey-corpora/contrapunctus-bench \
  --groups bach-wtc brahms-lieder schubert-lieder tavern
```
