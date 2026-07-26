# 2026-07-26: Overlap confirms boost 4; adoption shipped

**Goal.** Execute the overlap runs pre-declared in entry -05 and implement the
shipping decision recorded there: cadenceBoost 4 as the detector default, with
the historical reproduction contract preserved.

**Setup.** Engine and fixtures as in entry -01.

```
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v1 --detector hmm \
  --decay-half-life-seconds 4 --cadence-boost 4 \
  --out build/whatkey-local/overlap-hl4-cb4

dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --recipe whatKeyPaper2026 \
  --out build/whatkey-local/wir-dev-recipe-check
```

**What happened.** Overlap (performed input, analyst local keys), cb 4 vs base,
paired exact:

| Timescale | Base   | cb 4   | Mods           | Paired exact                                          |
| --------- | ------ | ------ | -------------- | ----------------------------------------------------- |
| hl30      | 0.5042 | 0.5211 | 141 to 153/459 | +0.0169, CI95 [+0.0101, +0.0244], p = 0.0001 (25/5/6) |
| hl4       | 0.5155 | 0.5351 | 226 to 239/459 | +0.0197, CI95 [+0.0093, +0.0301], p = 0.0008 (28/7/1) |
| hl1       | 0.5186 | 0.5282 | 264 to 271/459 | +0.0096, CI95 [-0.0005, +0.0200], p = 0.087 (23/12/1) |

The pre-declared expectation (exact and matched modulations up at every
timescale, spurious not materially worse) is met; hl30 and hl4 are individually
significant, hl1 is a positive trend, and spurious tails move at most by two
(hl30 p90 7 to 9, hl1 p90 28 to 30, medians unchanged or +1).

Adoption implementation, per the decision in entry -05:

- `HmmKeyDetector.defaultCadenceBoost` is now 4; the app constructs the detector
  with defaults (`inferred_key_notifier.dart`), so all three presets receive it
  with no app-side change.
- `DetectorRecipe` now pins `cadenceBoost: 0`, `cadenceTriadBoost: 0`, and
  `relativeSwitchFactor: 1` in both paper recipes, and the harness reads those
  recipe values, so the frozen v2026.7.14 behavior no longer depends on mutable
  detector defaults. Verified: a `--recipe whatKeyPaper2026` run on When-in-Rome
  dev produces claims byte-identical to the pre-adoption baseline (entry -01),
  and a default `--detector hmm` run produces claims byte-identical to the
  measured cb 4 arm.
- The chord-context harnesses (`key_error_diagnostic.dart`,
  `rootless_corpus.dart`) now default `--cadence-boost` to the detector default
  so they keep mirroring shipped behavior; passing 0 reproduces pre-adoption
  runs.
- Package tests updated to compare explicit boost values rather than assuming
  the default is off; the blues byte-identity test now spans strength 0 to 6.
- Changelog entry added (Changed: cadence-aware key detection).

**Plain-English reading.** On real recorded performances, the shipped strength
makes the detector name the analyst's local key about 1.7 to 2 points more often
at the stable and balanced timescales, with the reactive timescale trending the
same way, and it catches more of the annotated key changes at every speed. The
research contract is intact: the paper's frozen detector still reproduces its
published results bit for bit, because the recipes now spell out the
pre-adoption values instead of borrowing the current defaults.

**Decisions.** Adopted as decided in entry -05. The dose reference for any
future per-preset dialing stays entry -05's matrix.

**Next.**

- The remaining open avenues from entry -04 stand: mine the relative residual,
  probe the sticky-key dilution in the ensemble filter, and scope the
  retro-resolution relabel's new load-bearing role for ensemble history naming
  (chord-context log 2026-07-20-15 proved the mechanism at 100% flip precision;
  its adoption question deserves a fresh entry now that announcing dominants are
  19% of the ensemble residual).
- Holdout stays untouched until those avenues resolve.
