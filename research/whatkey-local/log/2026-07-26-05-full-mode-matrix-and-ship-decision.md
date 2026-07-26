# 2026-07-26: Full behavior-mode matrix and the decision to ship boost 4

**Goal.** Answer the open dose question with the complete preset matrix (entries
-02/-04 had only measured stable and reactive timescales, and the Isophonics
guard only at stable), and record the shipping decision.

**Setup.** Engine and fixtures as in entry -01. New runs: When-in-Rome and
Isophonics dev at the balanced timescale (hl4) with and without the boost,
Isophonics dev at hl1, and the pop-jazz suite at hl4.

```
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split development --detector hmm --decay-half-life-seconds 4 \
  --cadence-boost 4 --out build/whatkey-local/iso-dev-hl4-cb4
```

**What happened.** The complete matrix (exact on claimed; paired deltas vs the
same-timescale baseline):

When-in-Rome dev (local ruler): the boost helps every preset.

| Preset         | Base   | cb 3   | cb 4   | cb 4 paired exact                                                |
| -------------- | ------ | ------ | ------ | ---------------------------------------------------------------- |
| stable (hl30)  | 0.4338 | 0.4496 | 0.4548 | +0.0113, CI95 [+0.0010, +0.0218], p = 0.015                      |
| balanced (hl4) | 0.4579 | 0.4780 | 0.4858 | +0.0187, CI95 [+0.0032, +0.0365], p = 0.025                      |
| reactive (hl1) | 0.5457 | 0.5529 | 0.5553 | +0.0096, p = 0.16 (coverage +0.028 and MIREX +0.011 significant) |

Balanced also gains matched modulations 139 to 156 and holds spurious at 1/3.

Isophonics dev (section guard): the cost migrates from coverage to accuracy as
memory shortens.

| Preset   | Base   | cb 3   | cb 4   | cb 4 paired exact                                      |
| -------- | ------ | ------ | ------ | ------------------------------------------------------ |
| stable   | 0.7753 | 0.7783 | 0.7796 | wash (+0.0043, p = 0.51); coverage -0.0106, p = 0.0003 |
| balanced | 0.7694 | 0.7688 | 0.7611 | -0.0082, CI95 [-0.0200, +0.0031], p = 0.016 (22/45)    |
| reactive | 0.7356 | 0.7228 | 0.7134 | -0.0221, CI95 [-0.0339, -0.0118], p < 0.0001 (20/62)   |

At cb 3 the balanced Iso cost is a wash (-0.0006, p = 0.31) and the reactive
cost is -0.0127 (p = 0.0001), so no dose is free at reactive.

pop-jazz suite at hl4: improvements only (ii-V-I coverage 0.50 to 0.67 at exact
1.00; descending chain exact 0.00 to 0.60, no spurious switches). With hl30 and
hl1 from entry -04, the suite is clean at cb 4 across all three preset
timescales.

**Plain-English reading.** The boost makes every preset better at naming the
analyst's local key. On pop, the stable preset pays only in silence (it abstains
about one point more often, at unchanged accuracy, with one extra tail-end
spurious switch); the balanced and reactive presets pay in accuracy (about 1 and
2 points of pop exactness), because at short memory the boosted chain follows
tonicization-shaped moves that section-scale pop labels count as wrong. Those
presets already trade pop stability for responsiveness by design, and the
product's own behavioral suite stays clean, so the trade is consistent with what
the presets are for, but it is a real cost and it is recorded here, not hidden.

**Decisions.** Product decision (2026-07-26): ship cadenceBoost 4 as the
detector default for all presets, per the framing in entry -04 ("4 if a
coverage-only trade on pop is judged acceptable") extended with the full matrix
above. The per-preset alternative (4 stable, 3 balanced, 0-3 reactive) stays
available as a one-line change in `KeyBehavior` if the pop cost at the faster
presets is later judged too high; the matrix in this entry is the reference for
that call. This supersedes the entry -03/-04 "3 under the frozen guard"
recommendation by explicit decision rather than by meeting the frozen bar, and
the protocol's Isophonics guard is amended accordingly for this adoption only:
the accepted cost is the stable-preset coverage trade and the faster presets'
measured exactness cost, everything else within noise.

**Pre-declared next runs.** The ASAP x When-in-Rome overlap at cb 4: base and cb
4 at hl30, hl4, and hl1 (hl30 and hl1 baselines exist from entry -03).
Expectation: exact and matched modulations improve at every timescale, spurious
not materially worse; reported either way.

**Next.** Overlap runs, then the adoption implementation (detector default,
recipe pinning for the historical reproduction contract, harness default
alignment, changelog), each verified byte-identical where contracts require it.
