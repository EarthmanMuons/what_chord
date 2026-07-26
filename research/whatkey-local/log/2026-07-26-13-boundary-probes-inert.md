# 2026-07-26: Boundary probes inert; detector work complete

**Goal.** Measure the two wrap-up candidates from entry -12: cadence-conditioned
margin relief and the cold-start tonic prior.

**Setup.** Two new `HmmKeyDetector` options, byte-identical at defaults
(claims-verified): `cadenceMarginFactor` (multiplier on the claim margin floor
for the event that fires the cadence trigger; 1 keeps the shipped floor) and
`coldStartTonicPrior` (log-space boost, applied once on the first event after a
reset, to the key reading that chord as its tonic). Recipes pin both at neutral.
Shipped configuration otherwise (cadenceBoost 4).

```
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --cadence-margin-factor 0.25 \
  --out build/whatkey-local/wir-dev-stable-cmf0.25
```

**What happened.** When-in-Rome dev:

| Config                       | Coverage                 | Exact                    | Mods        | Spur p90 | TTFC med/p90 |
| ---------------------------- | ------------------------ | ------------------------ | ----------- | -------- | ------------ |
| stable base                  | 0.7717                   | 0.4548                   | 124/399     | 1        | 2/5          |
| stable margin 0.5 / 0.25 / 0 | 0.7775 / 0.7790 / 0.7827 | 0.4546 / 0.4543 / 0.4535 | 128-131/399 | 2        | 2/4          |
| hl1 base                     | 0.7079                   | 0.5553                   | 197/399     | 5        | 2/4          |
| hl1 margin 0.5 / 0.25 / 0    | 0.7093 / 0.7103 / 0.7113 | 0.5554 all               | 197/399     | 5        | 2/4          |
| hl1 cold-start 1 / 2         | 0.7124 / 0.7115          | 0.5556 / 0.5547          | 197 / 196   | 5        | 2/4          |

Both inert. The margin relief does what it says (a few more claims and matched
modulations on trigger events at flat accuracy) but the effect tops out near one
coverage point even with the floor removed entirely, and at the stable timescale
it doubles the spurious p90, the same trade shape rejected at cadence boost 5.
The reason is in entry -12's own data: the boundary abstention mass sits on the
events around a key change, not specifically on the cadence-trigger event, and
the trigger fires on too few events to move the total. The cold-start prior
cannot claim earlier than the three-event warmup gate, so time to first claim is
unchanged and everything else is noise.

**Plain-English reading.** Letting the detector speak more bravely at the exact
moment a cadence lands turns out to barely matter: the silence lives in the
messy couple of chords around a key change, and the cadence moment is just one
of them. Seeding the detector with "the first chord is probably the tonic"
changes nothing the warmup rule does not already hold back.

**Decisions.** Both options closed as measured-inert; retained at neutral
defaults per the initiative's precedent, recipes pin them. With this, every
candidate from the founding document and every lead surfaced by the residual
mining has been measured and dispositioned. The initiative's detector work is
complete: one adopted mechanism (cadence-conditioned transitions), two adopted
app integrations (internal ensemble key, one-event history relabel), and six
mechanisms closed by measurement.

**Next.** The holdout evaluation and the headline tables, per the paused
discussion. One correction folded into that plan from today's review: mode tilt
was part of the paper's reported configuration (whatkey log 2026-07-07-23
predates the test-split freeze and the recipe pins it), so the current-vs-paper
paired delta on the test split isolates this initiative's cadence boost; the
post-paper engine-era changes (the F sharp side, lever 0) live in fixture
generation, so the plan runs a two-by-two (paper fixtures and current-behavior
fixtures, paper recipe and current detector) to attribute the improvement
honestly.
