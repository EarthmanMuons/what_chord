# 2026-07-26: Cadence-conditioned transitions, dev sweep

**Goal.** Build and measure candidate mechanism 1 from the founding document:
condition the HMM's transition prior on cadential evidence, so key changes are
licensed by harmony instead of paying a flat switch cost, and probe candidate
mechanism 2 (relative-twin transition damping) alongside it.

**Setup.** Engine commit 0ce8809f plus the working-copy changes described below.
Fixtures and splits as in entry -01. New `HmmKeyDetector` options, both
byte-identical to shipped behavior at their defaults (verified: claims files for
the default run match entry -01's baseline exactly):

- `cadenceBoost` (default 0): when the incoming event completes an authentic
  cadence into key k, transition mass into k is multiplied by exp(boost) with
  each row renormalized. Trigger: previous event is a dominant-seventh-family
  chord rooted a fifth above the current chord's root, current chord has a tonic
  quality; the resolved quality selects the mode.
- `relativeSwitchFactor` (default 1): multiplier on transition weight between
  relative twins, which the shipped kernel places at signature distance zero.

Two trigger exclusions came out of unit-test failures rather than corpus runs,
and are deliberate:

- A plain major triad does not count as the dominant: two root-position major
  triads a fifth apart are the same bigram as I moving to IV, so a C-F-G7-C
  cadence would boost F at the second chord. Only the seventh disambiguates the
  direction.
- A dominant-quality chord does not count as a tonic target: blues I7 to IV7
  would otherwise read as V7 to I in the IV key, the exact failure that
  disqualified the functional blend.

Representative commands (dose and timescale varied per run):

```
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --decay-half-life-seconds 1 \
  --cadence-boost 3 --out build/whatkey-local/wir-dev-hl1-cb3

python3 tool/whatkey/compare.py \
  build/whatkey-local/wir-dev-hl1-cb3/report.json \
  build/whatkey-local/wir-dev-reactive/report.json --metric coverage
```

**What happened.**

When-in-Rome dev, reactive timescale (hl1), dose response:

| Config | Coverage | Exact  | MIREX  | Mods    | Spur p90 |
| ------ | -------- | ------ | ------ | ------- | -------- |
| base   | 0.6803   | 0.5457 | 0.6527 | 184/399 | 5        |
| cb 0.5 | 0.6819   | 0.5478 | 0.6539 | 185/399 | 5        |
| cb 1   | 0.6819   | 0.5496 | 0.6551 | 185/399 | 5        |
| cb 2   | 0.6904   | 0.5505 | 0.6573 | 191/399 | 5        |
| cb 3   | 0.7014   | 0.5529 | 0.6616 | 195/399 | 5        |
| cb 4   | 0.7079   | 0.5553 | 0.6636 | 197/399 | 5        |
| cb 5   | 0.7162   | 0.5578 | 0.6664 | 196/399 | 5        |
| cb 6   | 0.7177   | 0.5585 | 0.6672 | 196/399 | 5        |

Every column improves monotonically to a plateau at cb 5-6, with spurious
switches flat. Coverage and accuracy rising together is the notable shape: this
mechanism does not slide along the coverage-accuracy curve, it moves the curve.

Paired statistics on the primary ruler (vs the hl1 baseline):

- cb 5: coverage +0.0360/piece, CI95 [+0.0200, +0.0556], p < 0.0001 (27/1/31);
  MIREX +0.0136, CI95 [+0.0026, +0.0260], p = 0.041 (21/11/25); exact +0.0121,
  CI95 [-0.0055, +0.0311], p = 0.15 (20/11/26).
- cb 3: coverage +0.0211, CI95 [+0.0100, +0.0350], p = 0.0003 (24/4/31); exact
  +0.0072, CI95 [-0.0074, +0.0213], p = 0.11.

Stable timescale (hl30), both rulers:

| Config | WiR cov | WiR exact | WiR mods | Iso cov | Iso exact | Iso mods | Iso spur p90 |
| ------ | ------- | --------- | -------- | ------- | --------- | -------- | ------------ |
| base   | 0.7836  | 0.4338    | 120/399  | 0.9216  | 0.7753    | 94/192   | 1            |
| cb 2   | 0.7871  | 0.4469    | 120/399  | 0.9198  | 0.7769    | 94/192   | 1            |
| cb 3   | 0.7831  | 0.4496    | 121/399  | 0.9197  | 0.7783    | 96/192   | 1            |
| cb 5   | 0.7773  | 0.4622    | 136/399  | 0.9066  | 0.7781    | 103/192  | 2            |

Paired: WiR hl30 cb 5 exact +0.0188, CI95 [+0.0039, +0.0352], p = 0.012; cb 3
exact +0.0060, CI95 [+0.0009, +0.0116], p = 0.058. Iso guard at cb 5 fails:
coverage -0.0150, CI95 [-0.0240, -0.0061], p < 0.0001 (9/58 pieces), spurious
p90 doubles. Iso guard at cb 3 holds: coverage -0.0020, CI95 [-0.0056, +0.0014],
p = 0.049, a detectable but negligible 0.2% at unchanged spurious p90 and a
positive exact trend (+0.0030, p = 0.16).

Other axes measured and closed:

- Stiffer self-transition under the boost (cb 3 with 0.95 / 0.98 at hl1): buys
  coverage (0.71 / 0.73) but gives back exact and modulation recall (184 / 176
  matched vs 195). The escape-hatch framing is wrong on this ruler; 0.9 stays.
- `relativeSwitchFactor` 0.5 / 0.25 at hl1: exact 0.5443 / 0.5412 vs 0.5457
  base, a wash trending negative, and combining 0.5 with cb 5 is slightly worse
  than cb 5 alone (0.5542 vs 0.5578). Candidate mechanism 2 is closed as
  measured-negative in its cheap form.

pop-jazz-v2 behavioral suite, per fixture (coverage/exact/spurious), both
timescales:

- Both 12-bar blues fixtures, the Dorian vamp, the ambiguous Am-F-C-G loop,
  I-V-vi-IV, i-iv-V7-i, and (at hl30) secondary dominants: byte-identical at
  every dose. The blues immunity is by construction (dominant-quality targets
  excluded), not by tuning.
- ii-V-I in C, hl30: coverage 0.50 to 0.67 at cb 3+, exact stays 1.00. The
  cadence claim arrives an event earlier.
- Descending ii-V-I chain (the probe the reactive preset lost when the
  functional blend was removed, key-behavior-modes.md): hl1 base exact 0.20 with
  one spurious switch; cb 3 exact 0.50, no spurious; cb 5 exact 1.00, MIREX
  1.00. The chain-following ability the functional blend used to buy, recovered
  on the transition side without touching emissions.
- Secondary dominants in C, hl1: base coverage 0.75 exact 1.00; cb 3 coverage
  0.50 exact 1.00 (extra abstention, no wrong claims); cb 5 coverage 0.75 exact
  0.67, a real wrong-key regression. This is tonicization overshoot and it caps
  the shippable dose.

**Plain-English reading.** Telling the detector "a V7 chord just resolved, so a
key change to that tonic is now cheap" makes it claim more often, follow more
real modulations, and be right more often, all at once, on the corpus where
local keys are the answer sheet. The dose matters: at strength 3 every guard
holds and blues is untouched; at strength 5 the detector starts chasing
secondary dominants inside a stable key (reading V7-of-ii as a move to ii),
which shows up as a small coverage loss on pop songs and a wrong-key reading on
the secondary-dominants probe. Strength 3 is the candidate; strength 5 is what
the mechanism can do when local-key chasing is all that matters.

**Decisions.**

- `cadenceBoost` 3 is the adoption candidate; 5-6 is the measurement ceiling
  (local-ruler optimum) but fails the Iso guard and the secondary-dominants
  probe, so it does not ship.
- Plain-major dominants and dominant-quality targets stay excluded from the
  trigger; both exclusions are load-bearing (the suite immunity depends on
  them).
- `relativeSwitchFactor` stays 1; the axis is closed unless a future mechanism
  reopens it with structure (for example, gating on cadential context rather
  than a static kernel change).
- Self-transition stays 0.9 in every configuration.

**Pre-declared next run.** Per PROTOCOL.md, the ASAP x When-in-Rome overlap run
is declared here before execution: base and cb 3 at hl1 and hl30 (four runs),
plus cb 5 at hl1 as labeled exploration. Expectation: exact and matched
modulations improve at cb 3 on both timescales with spurious switches not
materially worse; the entry reports whatever happens, including a miss.

**Next.** Overlap confirmation, then downstream characterization
(key_error_diagnostic on the DCML dev split with the boosted detector), then a
decision entry on adoption.
