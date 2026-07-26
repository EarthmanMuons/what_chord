# WhatKey Local

Local-key accuracy for WhatKey: making the streaming detector's claimed key
match analyst-marked local keys more often, without giving up the section-key
stability the shipped presets were frozen for. This initiative picks up the
handoff recorded twice before: whatkey log 2026-07-08-04 scoped local-key
tracking as its own task, and chord-context log 2026-07-20-18 characterized the
error structure and prescribed testing a cadence-aware transition model on the
WhatKey rulers.

Status: detector work complete; holdout evaluated (log entries -16, -18).
Shipped: cadence-conditioned transitions (boost 4), the one-event warmup gate,
the internal ensemble naming key, and the one-event history relabel. Seven
further mechanisms were closed by measurement.

## Results

Held-out test splits, one-shot per the pre-declaration in log entry -17. Cell
labels: the paper detector is the frozen `whatKeyPaper2026` recipe; the current
detector is the shipped defaults after this initiative. The fixture axis
(paper-era versus current-engine fixture generation) measured negligible, so the
deltas below attribute to the detector work.

Headline, Isophonics test (41 tracks), stable behavior, coverage / exact /
MIREX:

| System                                  | Coverage | Exact | MIREX |
| --------------------------------------- | -------- | ----- | ----- |
| WhatKey today (stable)                  | 0.895    | 0.741 | 0.788 |
| WhatKey at the paper freeze             | 0.884    | 0.732 | 0.782 |
| music21 KS, matched coverage            | 1.000    | 0.625 | 0.727 |
| music21 Temperley-Kostka-Payne, offline | 1.000    | 0.637 | 0.740 |
| music21 Krumhansl-Schmuckler, offline   | 1.000    | 0.624 | 0.726 |
| music21 Aarden-Essen, offline           | 1.000    | 0.558 | 0.690 |

Paired, today versus the paper freeze: coverage +0.0101 (p = 0.0067), exact
+0.0098 (CI95 [-0.0023, +0.0269], p = 0.70). On When-in-Rome test the same delta
is coverage +0.1269 (p = 0.033) at statistically unchanged exact and MIREX.
Against KS at matched coverage, the exact advantage is +0.1161 with CI95
[+0.0009, +0.2356] (Wilcoxon p = 0.20 at n = 41): the paper's "at least parity
under a strictly harder setting" strengthens to parity or better with a
bootstrap interval that no longer touches zero. The offline baselines analyze
whole pieces with no abstention, a strictly easier setting.

Key behavior presets against the same rulers (current system, coverage / exact /
MIREX; the offline baselines above apply unchanged):

| Preset         | Isophonics test       | When-in-Rome test     |
| -------------- | --------------------- | --------------------- |
| stable (hl30)  | 0.895 / 0.741 / 0.788 | 0.938 / 0.576 / 0.695 |
| balanced (hl4) | 0.873 / 0.722 / 0.782 | 0.886 / 0.571 / 0.693 |
| reactive (hl1) | 0.805 / 0.683 / 0.754 | 0.860 / 0.580 / 0.704 |

## Why

Three completed initiatives left a debate on the record. The original WhatKey
work and the key-behavior-modes follow-up both tested progression analysis and
found no benefit; the chord-context and ensemble-mode work both concluded that
key detection is what limits their accuracy. The founding document,
[The local-key bottleneck](local-key-bottleneck.md), reconciles the two with the
measured numbers. The short version:

- Progression evidence as an **emission** ingredient is dead. It was tested
  under the HMM at every timescale, twice, and is a wash everywhere (whatkey
  logs 2026-07-07-18, 2026-07-07-20; key-behavior-modes.md).
- Local-key exactness is nevertheless the measured bottleneck downstream:
  roughly 58-66% exact against annotated local keys, costing ensemble mode 3-4
  points against the annotated-key oracle on held-out data, accounting for 98%
  of the residual spelling gap, and 0.36-0.48 points of solo identity
  (chord-context logs 2026-07-20-17/-18/-21; ensemble-mode log 2026-07-25-03).
- The error structure is organized, not noisy: about a quarter of claims land on
  the dominant, subdominant, or relative key, the tonicization-vs-modulation
  problem. The one mechanism aimed at that structure, conditioning key
  **transitions** on cadential evidence, has never been tested.

## Contents

- [The local-key bottleneck](local-key-bottleneck.md): the founding document;
  settles the temporal-context debate with the recorded numbers and lays out the
  candidate mechanisms.
- [Protocol](PROTOCOL.md): rulers, guards, and adoption bar; inherits the frozen
  WhatKey protocol.
- [Log](log/): dated, append-only record of every experiment and decision.

Supporting code: the WhatKey harness (`tool/whatkey/`) and the chord-context
diagnostic harnesses (`tool/chord-context/`) are extended in place; detector
changes land in `packages/whatkey/` behind options that default to shipped
behavior.
