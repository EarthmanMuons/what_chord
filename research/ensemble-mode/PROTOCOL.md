# Ensemble-Mode Evaluation Protocol

Status: FROZEN 2026-07-25 (log entry 2026-07-25-03; text unchanged since
initiative start). This protocol inherits the frozen chord-context protocol
(`research/chord-context/PROTOCOL.md`) wholesale: split discipline, label
isolation, ground-truth rules, statistics, and the performance budget all apply
as written there. This document records only what is specific to ensemble mode.

## Rulers

1. **Comping suite** (`chord-context-comping-suite/1`, committed at
   `research/chord-context/data/sources/comping/comping-suite-v1.json`). 18
   hand-authored cases with intents `rootless`, `shell`, `solo`. Behavioral
   probes, pass/fail, excluded from pooled statistics. This is the acceptance
   ruler: 12/12 on rootless and shell cases, 6/6 on solo and guard cases.
2. **DCML rootless synthesis** (dev split of dcml-distant-listening-v1, roots
   stripped from sounding seventh chords as in chord-context log entry
   2026-07-20-19). The corpus-scale ruler; 13,197 eligible events. Tuning
   happens here; the held-out split is spent once for the declared shipping
   result, per the inherited spend-it-once rule.

## Baselines to beat

Recorded by the simulation in chord-context entry 2026-07-20-19, all on the DCML
dev synthesis:

- Shipped engine (no mode): 0.0% exact.
- Simulated ensemble, inferred key: 81.9% unique-correct (stable preset), 82.4%
  (balanced), 83.1% (reactive).
- Annotated-key oracle ceiling: 89.2% unique-correct.
- Tiebreak headroom (unique-correct plus ambiguous, inferred key): 93.0%.

The real-engine implementation must not fall below the simulated inferred-key
numbers; the tiebreak's value is reported as recovery of the ambiguous bucket
toward the 93.0% ceiling.

## Adoption bar

In addition to the inherited bar:

1. **Solo invariance.** With `PlayingContext.solo` (the default), engine output
   is bit-identical to the shipped engine: full golden suite unchanged,
   analyze-call and operation counters unchanged, `tool/benchmark.sh --check`
   passes.
2. **Acceptance suite.** 12/12 rootless and shell, 6/6 solo and guard, run
   through the real engine (not the simulation) and committed as package unit
   tests.
3. **Corpus floor.** Real-engine ensemble accuracy on the DCML dev synthesis at
   or above the simulated 81.9% (stable preset), confirmed on the held-out split
   before shipping.
4. **Measured, not estimated.** The guide-tone/dominant-color tiebreak ships
   only with its own measured contribution; if it underperforms, the mode can
   ship without it (82% against 0% stands on its own) and the tiebreak returns
   to the backlog with a log entry.

## Amendments

None.
