# The Local-Key Bottleneck

This document settles a debate that three completed initiatives left on the
record. One side: WhatKey tested progression analysis and temporal context
repeatedly and found no benefit. The other side: chord-context and ensemble-mode
both concluded that key detection is what limits their accuracy, with
improvements theorized from temporal context. Both sides are quoted correctly,
and both are right, because they are about different mechanisms measured against
different targets. The numbers below are collected from the original logs so the
reconciliation is checkable.

## 1. What the "no benefit" side actually tested

Every temporal or progression mechanism WhatKey measured, with its final
verdict. "Section" is the section-key target (Isophonics ruler, 30 s emission
half-life); "local" is the local-key target (When-in-Rome ruler, short
half-life).

| Mechanism                                               | Result                                                                                                                                                              | Where                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| Progression blend (emission) under the pre-HMM hybrid   | Real win: coverage +0.052/piece, CI95 [+0.026, +0.081], p = 0.0008; exact a wash                                                                                    | whatkey log 2026-07-07-08                              |
| Progression blend under the HMM, section scale          | Removed by 2^4 ablation; pure profile emissions beat the blend cell (+0.053 exact, p = 0.016)                                                                       | whatkey log 2026-07-07-18                              |
| Progression blend under the HMM, local scale (hl1)      | Wash: -0.004 exact, p = 0.10; modulations 207 both ways                                                                                                             | whatkey log 2026-07-07-20                              |
| Progression blend re-tested for mode presets (hl1, hl4) | Within noise (+0.007, +0.004 exact); churns blues probes at hl1                                                                                                     | key-behavior-modes.md                                  |
| Functional blend (emission), section scale              | Removed by the same ablation                                                                                                                                        | whatkey log 2026-07-07-18                              |
| Functional blend, local scale                           | Sign flips: +0.061 exact paired, p = 0.010 on classical; but reads 12-bar blues as the IV key (exact 0.00) at hl1, collapses coverage at hl4; kept 0 in all presets | whatkey log 2026-07-07-20; key-behavior-modes.md       |
| Claim hysteresis                                        | Negative three times (hybrid, HMM, hl1 presets); "closed for good"                                                                                                  | whatkey logs 2026-07-07-07, -12; key-behavior-modes.md |
| BOCPD changepoint detector                              | Dominated by some HMM half-life on one or both rulers, twice                                                                                                        | whatkey log 2026-07-07-26; key-behavior-modes.md       |
| Dwell prior probe (HSMM headroom)                       | Insensitive; behavior owned by emissions plus margin floor                                                                                                          | whatkey log 2026-07-07-25                              |
| Event-count decay                                       | Monotone tradeoff, no crossover; negative                                                                                                                           | whatkey log 2026-07-07-15                              |
| Mode tilt = 2                                           | Adopted: +0.0164 Iso dev, +0.0302 WiR dev, both p = 0.03                                                                                                            | whatkey log 2026-07-07-23                              |
| Relative tilt, relative cadence tilt                    | Inert or harmful; default 0                                                                                                                                         | whatkey log 2026-07-07-24                              |
| Confidence weighting                                    | Six nulls; permanently closed                                                                                                                                       | key-behavior-modes.md                                  |
| Functional blend re-tested on the shipped config        | Classical dev win reproduces (+0.041 exact, p = 0.02) but both blues fixtures collapse to exact 0.00 at hl1 and hl4 and the secondary-dominants probe regresses     | whatkey-local log 2026-07-27-01                        |
| Progression blend re-tested on the shipped config       | Exact a wash trending negative (-0.016, p = 0.17); its coverage gain is a smaller copy of the cadence boost's; churns the blues and secondary-dominants probes      | whatkey-local log 2026-07-27-01                        |

Two things are worth noticing. First, every progression mechanism tested is an
**emission** ingredient: it adds progression-pattern points into the per-event
evidence that scores how well the current sound fits each key. None of them
touches the **transition** model, the prior over key changes, which has been a
static fifths-decay kernel with a fixed self-transition since the HMM was
adopted (whatkey log 2026-07-07-12). Second, the only adopted mechanism, mode
tilt, works precisely because it is structure-aware and conserving: it moves
probability inside a parallel pair without touching tonic evidence.

## 2. What the "bottleneck" side actually measured

### Local-key exactness of the shipped detector

Against DCML annotated local keys on the chord-context dev split (chord-context
log 2026-07-20-18, `key_error_diagnostic.dart`):

| Preset   | Coverage | Exact on claimed |
| -------- | -------- | ---------------- |
| stable   | 91.0%    | 61.1%            |
| balanced | 87.8%    | 65.2%            |
| reactive | 82.9%    | 65.7%            |

The relabel harness (chord-context log 2026-07-20-15) reports lower absolute
numbers for the same presets (57.7 / 59.6 / 58.8) under a different claim
accounting; the two entries were never reconciled, so the honest statement is
that local-key exactness sits roughly in the 58-66% range depending on preset
and accounting. On WhatKey's own local ruler (When-in-Rome dev), exact on
claimed is 0.434 stable and 0.546 reactive.

### What that costs downstream

Live (inferred) key against annotated-key oracle, same engine, same corpora:

| Surface                            | Live key   | Oracle key | Gap         | Where                                 |
| ---------------------------------- | ---------- | ---------- | ----------- | ------------------------------------- |
| Solo identity, DCML dev clean pool | 98.46%     | 98.82%     | 0.36 pts    | chord-context log 2026-07-20-06       |
| Solo identity, DCML test           | 98.81%     | 99.29%     | 0.48 pts    | chord-context log 2026-07-20-21       |
| Spelling (tones), DCML dev         | 98.64%     | 99.41%     | 0.77 pts    | chord-context logs 2026-07-20-11, -17 |
| Spelling (tones), DCML test        | 98.75%     | 99.36%     | 0.61 pts    | chord-context log 2026-07-20-21       |
| Ensemble top-1, DCML dev           | 92.7-93.2% | 95.9%      | ~3 pts      | ensemble-mode log 2026-07-25-03       |
| Ensemble top-1, DCML test          | 92.5-93.6% | 96.7%      | 3.1-4.2 pts | ensemble-mode log 2026-07-25-03       |

The famous "98% of the residual is key error" figure (chord-context log
2026-07-20-17) belongs to the spelling row: of the 0.77-point tone gap on dev,
perfect enharmonic side-following would recover 0.02 points and the rest is the
inferred key's pitch class or mode simply being wrong. It is not a statement
about chord identity, where the gap is real but small. The large per-event
stakes are in ensemble mode, where the hypothesis filter consumes the key
directly.

### The error structure

Under the stable preset (chord-context log 2026-07-20-18), the non-exact claims
decompose into:

- dominant key (+5th): 7.9% of claims
- subdominant key (-5th): 7.5%
- relative major/minor: 8.6%
- parallel: 2.7%
- unrelated: 12.1%
- share of mismatches that is pure tracking lag: ~16%

The detector is not lost and not merely late. It is choosing a key a fifth away
or the relative, which is exactly what a tonicized V or IV or a passing
modulation looks like to a fifths-decay transition prior that has no concept of
a cadence. This is the tonicization-vs-modulation problem, and roughly a quarter
of all claims sit in it.

## 3. The reconciliation

The apparent contradiction dissolves once mechanism and target are separated:

1. **Different mechanism.** What was ablated to zero is progression evidence in
   the emissions. What was never tested is progression evidence in the
   transitions: letting cadential motion license or gate key changes. The
   chord-context characterization points at the transition prior explicitly and
   prescribes exactly this experiment (log 2026-07-20-18).
2. **Different target.** The ablations that killed temporal ingredients were run
   against the section-key target, where long emission memory already solves
   stability, or at fixed timescales where the ingredient traded accuracy for
   churn. The bottleneck measurements are against local keys, where the shipped
   detector was never optimized and sits at 58-66%.
3. **Different era.** Before chord-context lever 0, key knowledge barely
   affected chord naming at all (annotated-key oracle moved dev identity by -0.1
   to 0.0 points; chord-context logs 2026-07-19-01, -04). Key correctness became
   a bottleneck only after the engine started consuming the key. Quotes from
   before and after that change look contradictory but are not.

So: the earlier conclusion "progression analysis does not help" stands, for
emissions, for the section-key target. The later conclusion "key detection holds
accuracy back" also stands, for local keys, for the surfaces that now consume
them. The open question is whether any mechanism can lift local-key exactness
without breaking the section-key product surface, and the recorded error
structure says where to aim.

## 4. Candidate mechanisms

Ranked by how directly they attack the measured error structure, with the
strongest prior evidence first.

1. **Cadence-conditioned transitions.** Keep emissions pure. Modulate the
   transition matrix per event: when the incoming event completes a cadential
   pattern into key k (dominant-quality chord rooted a fifth above k resolving
   to a tonic-quality chord of k), boost transition mass into k; otherwise leave
   the kernel unchanged, optionally with a stiffer baseline self-transition so
   tonicization drift is suppressed. This is the never-tested lead from
   chord-context log 2026-07-20-18. It is causal (the frame at event t may
   condition on event t), conserving per source state (rows renormalize), and
   off by default.
2. **Transition-kernel reshaping.** The kernel has never been fit: relative keys
   sit at signature distance zero (as cheap as staying put), mode switches are a
   flat factor 0.5, fifths decay is 0.5. Relative confusion is 8.6% of claims.
   Sweeping relative distance, mode-switch factor, and fifths decay is nearly
   free and has never been done on the local ruler.
3. **Chord-symbol emission likelihood.** The emissions correlate a decayed
   pitch-class histogram with key profiles; the analyzer's ranked candidate
   identity (root + quality) is thrown away. A categorical P(chord | key)
   emission term, estimated from DCML dev counts and blended with the profile
   term, captures "dominant seventh implies the key a fifth below" directly.
   Riskier: this is where blues broke the functional blend, so pop-jazz-v2 is
   the gate.
4. **Relationship-conditioned claim guard.** Plain hysteresis failed because it
   delays every switch. A guard that only makes fifth/relative switches stickier
   (hold the incumbent when the challenger is a functional neighbor and evidence
   is thin) targets the 24% without taxing unrelated modulations. Claim-layer
   only; posterior untouched.
5. **Two-timescale posterior.** Run fast and slow posteriors; let the slow one
   anchor the fast one's prior, or surface both (noted as future work in whatkey
   log 2026-07-07-16). Highest complexity, pursue only if the cheaper mechanisms
   stall.
6. **Bass-motion evidence.** A 5-to-1 bass movement detector as a cadence
   feature feeding mechanism 1 (design-doc idea, never built). Subsumed by
   mechanism 1's feature definition; not separate work initially.

## 5. Standing cautions

- When-in-Rome test is 18 pieces; the reactive preset's +0.104 dev win
  transferred as -0.013 (p = 0.98). Cross-ruler consistency beats single-ruler
  significance (see PROTOCOL.md).
- Blues fixtures veto. Every mechanism that connects chord function to key has
  so far read 12-bar blues as the IV key at short timescales. The behavioral
  suite is part of the bar, not an afterthought.
- Coverage accounting. Local-key numbers move a lot with the margin floor; every
  comparison must hold the coverage-accuracy pair together, never accuracy alone
  (inherited protocol rule).
- DCML motivates; the WhatKey rulers decide (per the decision in chord-context
  log 2026-07-20-18).
