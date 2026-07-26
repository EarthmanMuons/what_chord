# 2026-07-26: The warmup gate was the cold-start mechanism all along

**Goal.** Complete the cold-start probe correctly. Entry -13 tested the tonic
prior with the three-event warmup gate still in place, which (as the initiative
discussion pointed out) cannot produce an earlier claim by construction; the
full probe lets the margin floor take over gating from the first event, with and
without the prior.

**Setup.** Existing options only: `--min-events` (shipped value 3, never swept
in the original research; the abstain-calibration work swept the margin floor)
and `--cold-start-tonic-prior` from entry -13. Shipped configuration otherwise
(cadence boost 4).

```
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --min-events 1 \
  --out build/whatkey-local/wir-dev-stable-me1
```

**What happened.** minEvents 1 alone (no prior) is the strongest paired result
of the initiative:

| Ruler, timescale      | Coverage        | Exact           | Spur med/p90 | TTFC med/p90 |
| --------------------- | --------------- | --------------- | ------------ | ------------ |
| WiR stable base / me1 | 0.7717 / 0.8216 | 0.4548 / 0.4655 | 0/1 both     | 2/5 to 0/4   |
| WiR hl4 base / me1    | 0.7432 / 0.7930 | 0.4858 / 0.4941 | 1/3 to 1/4   | 2/4 to 0/4   |
| WiR hl1 base / me1    | 0.7079 / 0.7575 | 0.5553 / 0.5634 | 1/5 both     | 2/4 to 0/4   |
| Iso stable base / me1 | 0.9110 / 0.9368 | 0.7796 / 0.7758 | 0/2 both     | 2/3 to 0/1   |
| Iso hl4 base / me1    | 0.8666 / 0.8918 | 0.7611 / 0.7583 | 1/5 both     | 2/3 to 0/1   |
| Iso hl1 base / me1    | 0.7937 / 0.8139 | 0.7134 / 0.7129 | 3/9 both     | 2/3 to 0/1   |

Paired statistics:

- WiR stable exact +0.0094, CI95 [+0.0013, +0.0184], p = 0.0015 (29/8/20);
  coverage +0.0499, CI95 [+0.0219, +0.0928], p < 0.0001, 39 wins and zero
  losses.
- WiR hl1 exact +0.0103, CI95 [+0.0039, +0.0179], p = 0.0028 (30/8/19): the
  first mechanism in the initiative to meet adoption bar 1's exact criterion at
  the reactive operating point as written.
- Iso stable coverage +0.0258, CI95 [+0.0229, +0.0292], p < 0.0001 (168 wins,
  zero losses); exact -0.0038, CI95 [-0.0065, -0.0014], p = 0.0048, a small but
  real dilution from the newly claimed early events. Combined with the cadence
  boost, Iso stable now sits above the pre-initiative baseline on both axes
  (coverage 0.9368 vs 0.9216, exact 0.7758 vs 0.7753).

Behavioral suite at minEvents 1: every probe improves or holds (all exact 1.00
stay 1.00, the blues fixtures gain coverage, zero spurious switches anywhere),
and both deliberately ambiguous probes remain fully acceptable-key compliant
(ambiguousOk 8/8 and 7/7, unchanged), so the extra early coverage is legitimate
claims, not noise.

The cold-start tonic prior on top is closed as behaviorally negative: jazz
openings start on ii, not the tonic, so the seed front-loads confident wrong
claims (ii-V-I exact 1.00 to 0.67; the Dorian vamp locks into a wrong
full-coverage reading). The gate was the mechanism; the prior was a wrong theory
of openings.

**Plain-English reading.** The detector has been forced to stay silent for its
first three chords since the earliest configurations, and nobody had ever
re-tested that rule. Removing it means the key indicator can light up on the
very first chord you play, the claims it makes that early are overwhelmingly
right (both classical rulers get more accurate, not less), pop songs only give
up a whisker of accuracy for a solid coverage gain, and genuinely ambiguous
openings still stay quiet because the margin floor was the real safety mechanism
all along.

**Decisions.**

- `coldStartTonicPrior` closed as negative; retained at 0, recipes pin it.
- minEvents 1 is the adoption candidate, pending the pre-declared overlap
  confirmation below and the product decision (the shipped default is a
  constructor value; recipes pin 3 for the paper contract).
- Adoption-bar status: bar 1 met as written at the reactive operating point; bar
  2 shows a significant but small Iso exact cost (-0.0038) against a significant
  coverage gain, the same decision shape as the cadence boost's entry -05; bar 3
  met; bars 4 and 5 pending.

**Pre-declared next runs.** ASAP x When-in-Rome overlap: base and minEvents 1 at
hl30, hl4, and hl1. Expectation: coverage and time-to-first-claim improve at
every timescale with exact not materially worse; reported either way. A
posterior-calibration comparison (raw ECE, base vs minEvents 1) rides along,
since the display temperature was fitted on claims made under the three-event
gate.

**Next.** Overlap runs, calibration check, then the ship decision.
