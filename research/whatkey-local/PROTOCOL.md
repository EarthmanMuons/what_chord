# WhatKey Local Evaluation Protocol

Status: FROZEN 2026-07-26 (log entry 2026-07-26-01). This protocol inherits the
frozen WhatKey protocol (`research/whatkey/PROTOCOL.md`) wholesale: metric
definitions, scoring implementation (`tool/whatkey/src/scoring.dart`),
statistics (per-piece means, seeded bootstrap CI95, paired Wilcoxon via
`tool/whatkey/compare.py`), split discipline, and the spend-it-once rule for
test splits. This document records only what is specific to the local-key
target.

## Rulers

1. **When-in-Rome dev** (`when-in-rome-v1`, committed fixtures, frozen split
   `research/whatkey/data/splits/when-in-rome-v1.json`; 59 pieces, 3694 events).
   The primary ruler. Analyst local keys are the ground truth, so
   exact-on-claimed here scores local-key tracking. The local-key operating
   point is the reactive timescale (emission half-life 1 s); report stable (30
   s) alongside it so section-scale cost is always visible.
2. **ASAP x When-in-Rome overlap** (`asap-wir-nc-v1`, build-only, 36
   performances, evaluation-only, no split). Confirmation on performed input.
   Runs against it are pre-declared in a log entry before execution, per the
   precedent in whatkey log 2026-07-07-21.
3. **Isophonics dev guard** (`isophonics-nc-v1`, build-only, frozen split; 183
   tracks). Any adopted change must leave the shipped stable configuration's
   section-key numbers within noise: exact-on-claimed, coverage, and spurious
   switches (median/p90) are the guarded quantities.
4. **pop-jazz-v2 behavioral suite** (committed). Per-fixture pass/fail, excluded
   from pooled statistics. The blues fixtures are the sharp edge: no IV-key
   readings, no claim churn. A mechanism that wins on classical corpora and
   breaks blues does not ship, per the precedent in key-behavior-modes.md.

## Downstream characterization (not adoption rulers)

The DCML-based harnesses in `tool/chord-context/` (`key_error_diagnostic.dart`,
`rootless_corpus.dart`, `spelling_eval.dart`) measure the downstream effect of a
detector change on local-key agreement, ensemble-mode accuracy, and spelling.
They are motivation and effect-size confirmation only. Per the decision in
chord-context log 2026-07-20-18, DCML is not a WhatKey ruler; adoption is
decided on the rulers above.

## New-parameter discipline

Every new detector option defaults to the shipped behavior. With defaults, the
detector's output must be byte-identical to the shipped configuration on every
ruler (verified by comparing claims files). Experimental settings are exercised
only through harness flags until adopted.

## Adoption bar

1. Paired per-piece win on When-in-Rome dev exact-on-claimed at the reactive
   operating point (bootstrap CI95 excluding zero and Wilcoxon p < 0.05), at
   equal or better coverage, without a material spurious-switch cost.
2. Isophonics dev guard within noise for the stable configuration.
3. pop-jazz-v2 passes unchanged.
4. Effect direction confirmed on the ASAP x WiR overlap.
5. Downstream effect measured at least once (key_error_diagnostic or
   rootless_corpus) before any claim that the change helps the app.

## Overfitting caution

The key-behavior-modes held-out audit (2026-07-10) is the standing warning: the
reactive preset's +0.104 dev advantage on When-in-Rome local exact did not
transfer to the test split (-0.013, p = 0.98, n = 18 pieces). Dev wins on one
ruler are weak evidence. Prefer mechanisms with a structural rationale that show
consistent direction across rulers; treat single-ruler significance as
provisional. The When-in-Rome test split remains spent-once and is touched only
for a final declared result with a dated log entry.

## Amendments

None.
