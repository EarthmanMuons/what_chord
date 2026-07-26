# 2026-07-26: Overlap confirmation and downstream characterization

**Goal.** Execute the runs pre-declared in entry -02: confirm the cadence
boost's direction on performed input (ASAP x When-in-Rome overlap), then measure
the downstream effect on the DCML local-key diagnostic and the ensemble-mode
rootless harness, and take stock against the adoption bar.

**Setup.** Engine and fixtures as in entries -01/-02. The chord-context
harnesses `key_error_diagnostic.dart` and `rootless_corpus.dart` gained a
`--cadence-boost` flag (default 0, shipped behavior; the value is recorded in
their reports). Overlap runs use the full evaluation-only set (36 performances),
as pre-declared.

```
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v1 --detector hmm \
  --decay-half-life-seconds 1 --cadence-boost 3 \
  --out build/whatkey-local/overlap-hl1-cb3

dart run tool/chord-context/key_error_diagnostic.dart \
  --fixtures build/chord-context/fixtures/dcml-distant-listening-v1-span \
  --labels build/chord-context/labels/dcml-distant-listening-v1-span.labels.json \
  --split-file research/chord-context/data/splits/dcml-distant-listening-v1.json \
  --split development --behavior stable --cadence-boost 3 \
  --out build/whatkey-local/dcml-key-diag-stable-cb3

dart run tool/chord-context/rootless_corpus.dart \
  --fixtures build/chord-context/fixtures/dcml-distant-listening-v1-span \
  --labels build/chord-context/labels/dcml-distant-listening-v1-span.labels.json \
  --split-file research/chord-context/data/splits/dcml-distant-listening-v1.json \
  --split development --behavior stable --cadence-boost 3 \
  --out build/whatkey-local/rootless-dev-stable-cb3
```

**What happened.**

Overlap (performed input, analyst local keys), as pre-declared:

| Config                 | Coverage | Exact  | MIREX  | Mods    | Spur med/p90 |
| ---------------------- | -------- | ------ | ------ | ------- | ------------ |
| hl30 base              | 0.8954   | 0.5042 | 0.6283 | 141/459 | 3/7          |
| hl30 cb 3              | 0.8896   | 0.5132 | 0.6340 | 149/459 | 3/7          |
| hl1 base               | 0.8124   | 0.5186 | 0.6456 | 264/459 | 11/28        |
| hl1 cb 3               | 0.8164   | 0.5266 | 0.6494 | 267/459 | 11/30        |
| hl1 cb 5 (exploration) | 0.8281   | 0.5302 | 0.6520 | 276/459 | 12/29        |

Paired exact, cb 3 vs base: hl30 +0.0089, CI95 [+0.0049, +0.0133], p = 0.0004
(23/5/8); hl1 +0.0080, CI95 [+0.0002, +0.0160], p = 0.018 (25/9/2). The
pre-declared expectation (exact and matched modulations up, spurious not
materially worse) is met at both timescales, with statistical significance the
declaration did not even require. The hl30 baseline reproduces the whatkey log
2026-07-07-23 overlap numbers (0.50 exact, 141/459 matched).

DCML local-key diagnostic (dev split, characterization only):

| Config        | Coverage | Exact  | Fn-adjacent errors | Other | Lag share |
| ------------- | -------- | ------ | ------------------ | ----- | --------- |
| stable base   | 0.9100   | 0.6114 | 24.0%              | 12.1% | 15.8%     |
| stable cb 3   | 0.9011   | 0.6268 | 22.7%              | 12.0% | 16.5%     |
| stable cb 5   | 0.8850   | 0.6474 | 21.0%              | 11.5% | 16.9%     |
| reactive base | 0.8290   | 0.6575 | 20.3%              | 11.5% | 17.0%     |
| reactive cb 3 | 0.8285   | 0.6624 | 19.6%              | 11.7% | 16.5%     |

The mechanism eats exactly the error mass it was aimed at: the
dominant/subdominant/relative share of stable claims falls from 24.0% to 22.7%
(cb 3) and 21.0% (cb 5), and stable local exactness gains +1.5 to +3.6 points.
The baseline row reproduces chord-context log 2026-07-20-18.

Ensemble-mode rootless harness (dev split, real engine, characterization only):

| Config        | Engine inferred exact | Annotated oracle     |
| ------------- | --------------------- | -------------------- |
| stable base   | 12240/13197 (92.75%)  | 12654/13197 (95.89%) |
| stable cb 3   | 12234/13197 (92.70%)  | same                 |
| stable cb 5   | 12236/13197 (92.72%)  | same                 |
| reactive base | 12294/13197 (93.16%)  | same                 |
| reactive cb 3 | 12320/13197 (93.35%)  | same                 |

Flat at stable, +0.2 points at reactive. The local-key gains do not reach
ensemble accuracy, and the reason is structural, not a tuning miss: the ensemble
residual concentrates on dominant7 and halfDiminished7 events, and a dominant7
that announces a modulation is sounding at the moment before its cadence
completes. A cadence-triggered transition can only move the posterior on the
following event, one event too late for naming the dominant itself. The rootless
harness also carries claims forward through abstentions (`claimBefore` falls
back to the last claim), so claimed-event exactness gains partially wash out
against the sticky-key arrangement.

**Plain-English reading.** On real performances the improvement holds up: the
boosted detector names the analyst's local key more often at both timescales,
and the effect is statistically solid. On the corpus that motivated this whole
initiative, the detector now agrees with the annotated local key substantially
more often, and its remaining errors are less concentrated in the
fifth-and-relative confusion the mechanism targets. What the boost does not do
is lift ensemble-mode chord naming: the chords ensemble mode still misses are
mostly the dominants that announce a key change, and no cadence-completion
signal can arrive before the cadence completes. Closing that gap needs a
mechanism that acts on the dominant event itself.

**Decisions.**

- Adoption-bar status for cadenceBoost 3 (PROTOCOL.md): bar 1 partially met at
  the reactive operating point (coverage +0.0211, p = 0.0003; MIREX +0.0089, p =
  0.041; exact +0.0072, CI95 [-0.0074, +0.0213], p = 0.11, a positive trend
  short of significance); bar 2 met (Iso stable coverage -0.002, spurious p90
  unchanged); bar 3 met (no wrong claims, blues byte-identical; noted coverage
  dip on the secondary-dominants probe at hl1); bar 4 met with significance at
  both timescales; bar 5 met (both downstream harnesses measured). Adoption is
  therefore not claimed today: the exact-on-claimed criterion on the primary
  ruler is not met at the shippable dose. The candidate stays open with
  everything else in its favor.
- The ensemble-mode gap is explicitly out of scope for the cadence mechanism; a
  future entry should scope a dominant-event mechanism (for example, scoring the
  sounding dominant's hypotheses under the keys it could tonicize, or an
  ensemble-filter change) rather than pushing the boost higher.

**Next.**

- Either strengthen the exact-on-claimed evidence (a complementary mechanism
  aimed at the remaining relative confusion, or re-testing the bass-motion
  cadence feature as an additional trigger) or bring an amendment case to the
  protocol if coverage-plus-MIREX wins at flat exactness are judged
  adoption-worthy on their own. No test-split run until one of those resolves.
- Scope the dominant-event mechanism for ensemble mode as its own candidate.
