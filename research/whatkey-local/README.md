# WhatKey Local

Local-key accuracy for WhatKey: making the streaming detector's claimed key
match analyst-marked local keys more often, without giving up the section-key
stability the shipped presets were frozen for. This initiative picks up the
handoff recorded twice before: whatkey log 2026-07-08-04 scoped local-key
tracking as its own task, and chord-context log 2026-07-20-18 characterized the
error structure and prescribed testing a cadence-aware transition model on the
WhatKey rulers.

Status: active (started 2026-07-26).

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
