# Ensemble-Tiebreak Evaluation Protocol

Status: FROZEN 2026-07-26 (log entry 2026-07-26-01). This protocol inherits the
frozen chord-context protocol (`research/chord-context/PROTOCOL.md`) wholesale:
split discipline, label isolation, ground-truth rules, statistics, and the
performance budget apply as written there. This document records only what is
specific to this initiative.

## Rulers

1. **Weimar comping synthesis** (`weimar-comping-v1`, build-only fixtures,
   frozen split `data/splits/weimar-comping-v1.json`: 295 eligible tunes split
   by tune so all solos of a standard share a side; 361 development / 83 test
   solos after the NC-only eligibility gate, log entry 2026-07-26-01). The
   primary ruler: roots stripped from synthesized seventh-chord voicings via
   `rootless_corpus.dart`, scored top-1 exact at root plus quality against the
   WJazzD symbols. Tuning happens on the development split; the test split is
   spent once for the declared shipping result.
2. **Comping suite** (`chord-context-comping-suite/1`, 18 cases). The acceptance
   ruler, inherited from ensemble mode: 12/12 rootless and shell, 6/6 solo and
   guard, exactly, before and after every change.
3. **DCML rootless synthesis** (dev split), the continuity ruler: the
   annotated-key arm's miss shapes are the target list, and no change may
   regress its exact rates beyond noise while claiming to fix them.

## Guards

- **Solo invariance.** With `PlayingContext.solo`, engine output stays
  bit-identical: golden suite unchanged, `tool/benchmark.sh --check` passes,
  exactly as the ensemble-mode protocol demanded.
- **Key-detection non-interference.** Tiebreak changes live in the naming path;
  the WhatKey rulers are not touched by this initiative, and any change that
  alters committed event identities re-runs the whatkey-local guard commands
  (its log 2026-07-26-01) to confirm key detection is unmoved beyond the
  fixture-axis scale already characterized.

## Adoption bar

1. Paired per-solo win on the Weimar development split, top-1 exact under the
   INFERRED key (bootstrap CI95 excluding zero and Wilcoxon p < 0.05 via
   `tool/whatkey/compare.py` conventions), with the annotated arm reported
   alongside and not materially regressed.
2. Comping suite passes exactly.
3. DCML dev annotated arm improves or holds on the targeted miss shapes without
   new regressions elsewhere in its shape table.
4. Solo invariance verified.

## Amendments

- 2026-07-26 (log entry 2026-07-26-01, before any tuning): bar 1's primary arm
  is the inferred key rather than the annotated key. The baseline showed
  WJazzD's per-solo global key is a fixed-key reference, not a local-key oracle
  (the inferred arm outscores it), so the realistic product arm is the primary
  metric on this ruler.
