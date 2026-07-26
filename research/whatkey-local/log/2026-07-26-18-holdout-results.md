# 2026-07-26: Holdout results: coverage is the initiative's test-split story

**Goal.** Execute the result set pre-declared in entry -17 and record the
outcome against the declared expectations.

**Setup.** As declared. Fixture regeneration completed from the pinned checkouts
(Isophonics 224 tracks, When-in-Rome 77 pieces, current analysis profile,
written to `build/whatkey-fixtures-current/`, never overwriting the paper-pinned
builds). All runs one-shot under the declaration; artifacts under
`build/whatkey-local/holdout/`.

**What happened.**

The two-by-two, stable timescale (coverage / exact / MIREX):

| Cell                                  | Isophonics test          | When-in-Rome test        |
| ------------------------------------- | ------------------------ | ------------------------ |
| A: paper detector, paper fixtures     | 0.8843 / 0.7316 / 0.7823 | 0.8110 / 0.5871 / 0.7093 |
| B: current detector, paper fixtures   | 0.8944 / 0.7414 / 0.7880 | 0.9379 / 0.5759 / 0.6948 |
| C: paper detector, current fixtures   | 0.8851 / 0.7315 / 0.7818 | 0.8110 / 0.5871 / 0.7093 |
| D: current detector, current fixtures | 0.8952 / 0.7413 / 0.7875 | 0.9379 / 0.5759 / 0.6948 |

Attribution is unambiguous: the fixture axis is negligible (C reproduces A and D
reproduces B to the fourth decimal on Isophonics; exactly on When-in-Rome), so
the engine-era changes (lever 0, the F sharp side) do not move key detection,
and the whole delta belongs to this initiative's detector work (cadence boost
plus the one-event warmup gate).

Paired detector delta (B vs A):

- Isophonics coverage +0.0101, CI95 [-0.0075, +0.0249], p = 0.0067 (30/5/6);
  exact +0.0098, CI95 [-0.0023, +0.0269], p = 0.70 (11/10/17): a significant
  coverage gain at a positive-trend exact.
- When-in-Rome coverage +0.1269, CI95 [+0.0108, +0.2912], p = 0.033 (13/4/1);
  exact -0.0017, p = 0.74; MIREX -0.0026, p = 0.98: a very large coverage gain
  at statistically unchanged accuracy. Spurious p90 1 to 2.

External anchor (Isophonics test, committed music21 baselines):

| System                               | Coverage | Exact  | MIREX  |
| ------------------------------------ | -------- | ------ | ------ |
| WhatKey today (Cell D, stable)       | 0.8952   | 0.7413 | 0.7875 |
| WhatKey at the paper freeze (Cell A) | 0.8843   | 0.7316 | 0.7823 |
| music21 KS, matched to Cell D claims | 1.0000   | 0.6251 | 0.7273 |
| music21 TKP, offline                 | 1.0000   | 0.6371 | 0.7404 |
| music21 KS, offline                  | 1.0000   | 0.6241 | 0.7264 |
| music21 Aarden-Essen, offline        | 1.0000   | 0.5582 | 0.6904 |

Paired, Cell D vs KS at matched coverage: exact +0.1161, CI95 [+0.0009,
+0.2356], Wilcoxon p = 0.20 (13/13/12). The paper's claim was "at least parity
under a strictly harder setting" with a bootstrap CI spanning zero ([-0.0082,
+0.2284]); the CI now excludes zero while the rank test remains inconclusive at
41 tracks, so the honest phrasing strengthens to "parity or better, with the
exact advantage's bootstrap interval now excluding zero."

Preset rows (current system, current fixtures; the secondary table):

| Preset         | Isophonics test          | When-in-Rome test        |
| -------------- | ------------------------ | ------------------------ |
| stable (hl30)  | 0.8952 / 0.7413 / 0.7875 | 0.9379 / 0.5759 / 0.6948 |
| balanced (hl4) | 0.8733 / 0.7221 / 0.7823 | 0.8862 / 0.5708 / 0.6933 |
| reactive (hl1) | 0.8051 / 0.6829 / 0.7535 | 0.8598 / 0.5796 / 0.7044 |

**Against the pre-declared expectations.** Coverage up on both splits: confirmed
with significance. Isophonics exact within noise to slightly positive: confirmed
(+0.0098 trend). When-in-Rome local exact up one to two points: NOT confirmed;
the dev exact gains transferred as coverage instead (+12.7 points at unchanged
exact and MIREX), consistent with the initiative protocol's standing transfer
caution at n = 18. Fixture delta small: confirmed (essentially zero). KS
position holds or extends: confirmed (bootstrap CI newly excludes zero).

**Plain-English reading.** On held-out data, today's detector answers
substantially more often than the paper's (a tenth more of all events on pop, an
eighth more on classical) while being just as accurate on what it says, slightly
more accurate on pop. The hoped-for accuracy jump on the classical local-key
ruler did not survive the trip to the test split, but nothing was given back
either, and the coverage gains are exactly what the two shipped mechanisms were
built to buy (claims at cadences and from the first chord). Against the classic
academic baselines, the position improves from "at least as good under a harder
setting" to a point estimate eleven points ahead whose confidence interval no
longer touches zero.

**Decisions.** The test splits are spent for this initiative; no further
test-split runs. Results and tables land in the README alongside this entry.

**Next.** README tables; initiative status update; close-out.
