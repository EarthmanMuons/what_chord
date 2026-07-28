# 2026-07-28: Pre-declaration for the held test-split spend

**Status: FROZEN 2026-07-28, approved in review. No test number existed when
this entry was frozen.** The test split is spent once (PROTOCOL, Binding now),
so this entry fixes the result set, the predictions, and the interpretation
rules in advance. The results land in a separate entry whatever they say; this
entry is not edited after the run.

**What this spend is.** A generalization check on the shipped engine and the
shipped display gate: do the development-split conclusions hold on twelve
Beethoven movements the tuning never saw? It is not a hypothesis test of a
change. There is no A/B on the test split, and no lever is waiting on the
outcome.

**Why now.** Avenues 1 through 5 are resolved, ruler v1.1 was declined by
measurement, the piecewise rescue is applied to both sides, and the last engine
question (tone pricing) closed today without moving a single development-split
number, verified by regenerating the development fixtures on the shipped engine
(0 of 23 pieces changed). The shipped state and the measured state are therefore
the same state.

## The result set (what gets reported, decided now)

1. **Identity, test split, full attribution decomposition** (PROTOCOL requires
   headline with decomposition): arms A0, B, C, BC, and A1 at all three behavior
   presets, seven arms in total. Per arm: coverage, exact, root, members, mean
   per piece, plus the per-piece table. All three A1 presets are reported even
   though they agreed to a thousandth on development, per the review decision:
   the protocol asks for the preset sweep, and a preset that diverges on
   held-out music would be worth knowing about precisely because development
   said it could not happen.
2. **Stability, test split**: labeledShare, switchesPerMin, flickerShare,
   settleMs median and p90, churnPerEvent, mean per piece.
3. **Display-policy frontier, test split**: raw, dwell-100/200/300/500/750,
   gated, gated-live, each with flickerShare, switchesPerMin, latency median and
   p90, missedEventShare.
4. **The development reference, regenerated in the same run** on the same
   shipped engine and the same rescued split, so every test number has a
   like-for-like development twin. This matters: the committed display-policy
   development report predates the piecewise rescue, so its raw flicker (0.466)
   is not comparable to a post-rescue test number without regeneration.

Every table ships with its development twin beside it. No number is quoted
alone.

## Predictions, declared before the run

The development distribution is 23 movements; the test draw is 12. Bootstrap
resampling of 12-movement means from the development per-piece values (10,000
reps, seed 20260728) gives the spread a same-population draw would show. The
intervals below are that spread, and they are predictions, not adoption gates.

| metric   | dev (23) | predicted test 80% | predicted test 95% |
| -------- | -------- | ------------------ | ------------------ |
| coverage | 0.481    | 0.413 to 0.548     | 0.376 to 0.583     |
| exact    | 0.602    | 0.575 to 0.628     | 0.558 to 0.641     |
| root     | 0.747    | 0.727 to 0.767     | 0.716 to 0.777     |
| members  | 0.529    | 0.496 to 0.561     | 0.482 to 0.580     |

Stability, same method:

| metric         | dev (23) | predicted test 80% | predicted test 95% |
| -------------- | -------- | ------------------ | ------------------ |
| flickerShare   | 0.489    | 0.420 to 0.558     | 0.383 to 0.598     |
| switchesPerMin | 340.8    | 274.8 to 411.2     | 246.4 to 454.6     |
| labeledShare   | 0.560    | 0.500 to 0.618     | 0.470 to 0.647     |
| settleMsMedian | 217.6    | 180.9 to 252.2     | 157.8 to 266.8     |
| settleMsP90    | 869.0    | 760.4 to 985.8     | 717.8 to 1060.4    |
| churnPerEvent  | 1.394    | 1.150 to 1.657     | 1.079 to 1.826     |

Read the 95% column as the honest one for a twelve-movement draw and the 80%
column as where the numbers should land if nothing is unusual. Both are
published so a result in the 80-to-95 band is visible as such rather than retold
as either a hit or a miss.

Structural predictions, which matter more than the point values:

- **Arms stay flat in context, wide in segmentation.** B, A1-stable,
  A1-balanced, and A1-reactive land within 0.01 exact of A0, reproducing the
  development finding that key context does not move solo naming. C and BC raise
  coverage sharply (development: 0.48 to about 0.75) while lowering exact by
  0.02 to 0.04, reproducing the finding that the segmenter buys precision at the
  cost of recall.
- **The gated policy dominates the dwell family** on flicker, switches, and
  missed events simultaneously, and gated-live remains far worse than gated
  (development: 0.413 versus 0.064 flicker). This is the structural claim behind
  the shipped display gate, and it is the single most important thing this spend
  confirms.
- **Dwell filters past 200 ms miss real chords wholesale** (development: 0.31
  missed at dwell-300, 0.57 at dwell-500).

## Interpretation rules, fixed now

- **Inside the 80% intervals with the structural predictions holding**: the
  development picture generalizes. Recorded, initiative closes, no action.
- **Between the 80% and 95% intervals**: still consistent with a twelve-movement
  draw. Reported as landing in that band, in those words, and treated the same
  as an inside-80% result for decision purposes.
- **Outside the 95% interval but structure holding**: recorded as a corpus-shape
  difference with the per-piece table showing which movements drive it. Not a
  defect, and explicitly not a reason to tune. Movement character (texture
  density, tempo, ornamentation) is known to dominate per-piece variance, and
  coverage in particular has a wide development spread (0.126 to 0.772).
- **A structural prediction failing** (context arms diverging, gated losing its
  dominance, the missed-chord cliff absent): the interesting outcome, and the
  one worth a follow-up initiative. It would be recorded in full and would put
  the display-gate rationale back under review. It would still not license
  tuning against the test split.
- **No engine or display change is made in response to these numbers.** The
  split is spent by reading it. Anything it surfaces enters the queue as a new
  question measured on new data.

## Commands

```sh
# fixtures: identity arms (test and development share each extraction)
.venv/bin/python tool/whatkey/asap_wir_extract.py --arm A0 --emit-frames \
  --analysis-profile current --set holdout-a0 \
  --asap-root build/whatkey-corpora/asap-dataset \
  --bench-root build/whatkey-corpora/contrapunctus-bench
# ... repeated for --arm B, --arm C, --arm BC, and
# --arm A1 --behavior {stable,balanced,reactive}

# identity, per arm, both splits
.venv/bin/python tool/performed-input/identity_score.py \
  --fixtures build/whatkey-fixtures/holdout-a0 --split test \
  --out build/performed-input/holdout/a0-test.json

# stability and display policy, from the A0 frames, both splits
.venv/bin/python tool/performed-input/stability_score.py \
  --fixtures build/whatkey-fixtures/holdout-a0 --split test \
  --out build/performed-input/holdout/stability-test.json
.venv/bin/python tool/performed-input/display_policy_sim.py \
  --fixtures build/whatkey-fixtures/holdout-a0 --split test \
  --out build/performed-input/holdout/display-policy-test.json
```

The frozen split file (`data/splits/asap-wir-nc-v2.json`) is used unchanged and
is not regenerated. Fixtures stay under `build/` per the license gate.

## Caveats recorded before the fact

- Twelve movements is a small draw, and the intervals above are honest about it.
  The bootstrap treats test movements as exchangeable with development
  movements, which is approximate: the split is by sonata, so the test side is a
  different set of works, not a random subsample of the same ones.
- The corpus is one composer on one instrument. This spend confirms
  generalization across Beethoven works, not across idioms. POP909 already
  carries the cross-idiom structural replication for stability.
- The gate-excluded movement (31-3_4, Op110 finale) stays excluded, for the
  reason recorded in log -11. Its exclusion was decided on alignment quality,
  before and independent of any test number.
- The test side is complete: all twelve of its movements pass the census gate,
  including 12-1, which the piecewise rescue returned to the roster. The one
  remaining gate exclusion (31-3_4) sits on the development side, so it is the
  reference that carries a benched movement, not the holdout.
- That rescue touched the test side, which deserves naming rather than burying:
  a calibration tuned against test identity scores would be a leak. It was not.
  The piecewise offsets are fit to score-alignment overlap only, with no
  identity or stability number in the objective, and they are frozen before this
  run computes anything.

**Plain-English reading.** We are about to open the sealed envelope. Before
opening it, this entry writes down exactly which numbers we will read, what we
expect them to say, and what we will do in each case, including the case where
they surprise us. The main thing being checked is not a score, it is whether the
reasoning holds up on music the tuning never touched: that key context does not
change chord naming, that our segmenter trades recall for precision, and above
all that the display gate we shipped this week is genuinely the right shape
rather than an artifact of the movements we happened to study. And the rule that
makes the check honest: whatever comes back, we do not go tune the engine
against it.

**Next.** Review this declaration. On approval, freeze it, run the commands, and
record the results in a separate entry.
