# 2026-07-27: Emission blends re-tested on the shipped config, negative

**Goal.** Close the one open cell left by the blend ledger in
[../local-key-bottleneck.md](../local-key-bottleneck.md): every prior verdict
against the functional and progression emission blends predates the shipped
cadence boost (4) and warmup-gate removal (minEvents 1). With the retrospective
relabel now shipped and proving that progression information pays when applied
with hindsight, the question was whether the causal emission blends deserve a
fresh look on top of the current defaults.

**Setup.** Dev-only, no split spend. Primary ruler at the reactive operating
point, historical doses (functional 0.1, progression 0.02), guards per protocol.
The harness blend flags still work on the HMM (emission-side, default 0).

```
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --decay-half-life-seconds 1 \
  [--functional-blend 0.1 | --progression-blend 0.02] \
  --out build/whatkey-local/wir-dev-hl1-shipped-{base,fb0.1,pb0.02}
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/pop-jazz-v2 --detector hmm \
  --decay-half-life-seconds {1,4} [blend flag] \
  --out build/whatkey-local/pj-hl{1,4}-shipped-...
```

**What happened.** When-in-Rome dev, hl1, paired vs the shipped baseline:

- Functional blend 0.1: exact +0.0412/piece, CI95 [+0.0005, +0.0800], p = 0.0205
  (35/19/4); coverage +0.0517, CI95 [+0.0003, +0.0921], p = 0.0003. The old
  local-scale classical win reproduces on top of the cadence boost.
- Progression blend 0.02: exact -0.0157, CI95 [-0.0393, +0.0027], p = 0.169
  (17/25/17); coverage +0.0192, CI95 [+0.0074, +0.0344], p = 0.0023. A
  coverage-for-accuracy slide, and the coverage gain is a smaller copy of what
  the cadence boost already delivered by moving both together.

pop-jazz-v2 behavioral guard (baseline is clean at both timescales: blues
fixtures exact 1.00, secondary dominants 1.00, no spurious switches):

- Functional blend, hl1: both 12-bar blues fixtures collapse to exact 0.00
  (MIREX 0.50, the IV-key reading), secondary dominants fall to 0.83 with a
  spurious switch. hl4: blues 0.00 again, the descending ii-V-I chain falls to
  0.43. The exact failure that disqualified it twice before, unchanged.
- Progression blend, hl1: blues churns (exact 0.89 with 1-2 spurious switches
  per chorus), secondary dominants 0.75 with a spurious switch, descending chain
  0.60.

**Plain-English reading.** The relabel's success does not transfer, and the
reason is structural: the relabel works because it waits for the next chord
before deciding, and it never feeds the detector. The blends are causal emission
ingredients, so they must encode "a dominant seventh means a key change is
coming" before the resolution arrives, and that assumption is exactly what blues
violates. The classical points the functional blend buys are the same points it
has always bought, paid for with the same blues failure; the cadence boost
already banked the progression signal in the only form that survives the guards
(transition-side, with the dominant-target exclusions).

**Decisions.** Both blends stay at 0 in every preset. The ledger in
local-key-bottleneck.md gains two rows so the next reader sees the verdicts were
re-earned on the current config, not inherited. No protocol amendment; no
detector or recipe change; nothing here touches the paper pinning.

**Next.** Nothing. The initiative remains complete; this entry is an addendum
closing a question raised after the resolution relabel shipped.
