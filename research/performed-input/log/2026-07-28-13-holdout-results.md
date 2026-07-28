# 2026-07-28: The holdout, spent: structure confirmed, identity lower than predicted

**Goal.** Run the frozen pre-declaration (log -12) and report what came back.
The test split is now spent.

**Run.** Seven arm extractions on the shipped engine (A0 with frames, B, C, BC,
A1 at stable/balanced/reactive), then identity, stability, and display-policy
scoring on both splits, with the development reference regenerated in the same
run so every test number has a like-for-like twin. No failures; all twelve test
movements scored.

## Identity, test split, full decomposition

| arm         | segmentation  | context     | coverage | exact | root  | members |
| ----------- | ------------- | ----------- | -------- | ----- | ----- | ------- |
| A0          | app           | neutral     | 0.516    | 0.551 | 0.689 | 0.498   |
| B           | app           | analyst key | 0.516    | 0.561 | 0.698 | 0.497   |
| A1-stable   | app           | live (30 s) | 0.516    | 0.559 | 0.697 | 0.498   |
| A1-balanced | app           | live (4 s)  | 0.516    | 0.556 | 0.694 | 0.498   |
| A1-reactive | app           | live (1 s)  | 0.516    | 0.557 | 0.694 | 0.498   |
| C           | analyst spans | neutral     | 0.958    | 0.543 | 0.699 | 0.489   |
| BC          | analyst spans | analyst key | 0.958    | 0.554 | 0.709 | 0.489   |

Development twin, same run: A0 0.481 / 0.602 / 0.747 / 0.529, with the other
arms tracking as before.

## Against the frozen predictions

| metric   | predicted (dev) | test  | verdict     |
| -------- | --------------- | ----- | ----------- |
| coverage | 0.481           | 0.516 | inside 80%  |
| exact    | 0.602           | 0.551 | OUTSIDE 95% |
| root     | 0.747           | 0.689 | OUTSIDE 95% |
| members  | 0.529           | 0.498 | inside 80%  |

Stability, every metric inside the 80% interval: flicker 0.446 (dev twin 0.489),
switches/min 292.3 (340.5), labeled 0.601 (0.560), settle median 203 ms (217),
p90 941 ms (867), churn/event 1.253 (1.390).

**All three structural predictions held.**

- Context arms flat: B is +0.0094 exact against A0 on test, and the three A1
  presets sit between +0.005 and +0.008, all inside the declared 0.01 band. Key
  context still does not meaningfully move solo naming.
- Segmentation trades recall for precision: C and BC lift coverage by 0.442
  (0.516 to 0.958) while exact falls slightly.
- **The display-gate claim reproduced cleanly**, which was the most important
  thing this spend could confirm. On held-out music the gated policy dominates
  the entire dwell family on all three axes at once (flicker 0.061 versus raw
  0.446, switches 38.9 versus 292.3, missed 0.000), gated-live remains far worse
  than gated (0.388 versus 0.061), and the missed-chord cliff is intact
  (dwell-300 misses 0.330, dwell-500 misses 0.588).

## The identity shortfall, characterized honestly

Exact is 5.1 points below the development mean and root 5.9, both outside the
95% interval. The pre-declaration anticipated this case and labeled it "a
corpus-shape difference". The data only partly supports that label, and the
label is not allowed to survive contact with evidence that contradicts it, so
here is what the numbers actually say.

- **Not an outlier artifact.** The test distribution is shifted, not tailed:
  medians 0.552 versus 0.619 while the extremes nearly coincide (test 0.371 to
  0.714, development 0.388 to 0.717). Dropping the worst movement (26-2, the Les
  Adieux Andante) lifts the test mean only to 0.568.
- **Not a coverage tradeoff.** Coverage is higher on test, and the
  coverage-to-exact correlation across all 35 movements is weakly positive
  (+0.20), so the usual precision-recall story does not apply. Test movements
  score lower inside matched coverage bands.
- **Not a quality-naming problem.** The root-to-exact spread is essentially
  identical (0.138 test, 0.146 development), so the engine names qualities as
  well as ever. The shortfall is in recovering the analyst's root.
- **About half of it is engine-actionable.** The error census decomposes the gap
  by content, and the pieces sum to the observed shortfall (+0.0502 against the
  -0.0506 exact gap): playable +0.0257 (the engine had every analyst chord tone
  in hand and named something else), absent +0.0147 (the analyst's chord was not
  literally sounding), partial +0.0097.

So roughly half the gap is genuinely harder-to-name content and roughly half is
the engine doing worse on material it had in hand. That is a real, mild
generalization gap, and calling it purely corpus shape would have been the
comfortable answer rather than the true one.

**Where the engine-actionable half sits.** Within the playable bucket the two
growing cells are superset absorption (0.0501 to 0.0622 of displayed time) and
overlapping readings (0.0229 to 0.0372). The larger one is exactly the
phenomenon the tone-pricing initiative measured all day and declined to change,
because every available lever failed a guard or the arithmetic. That
initiative's verdicts stand on their evidence; this entry records that the
bucket they left in place is slightly larger on held-out music than the
development split suggested.

**Per the declared interpretation rule, nothing is tuned in response.** The
split is spent by reading it. The headline number for live performed input is
now 0.551 exact on held-out music, and that is the figure to quote going
forward, with 0.602 correctly described as the development figure.

**A secondary observation, recorded for lineage.** The development key-context
delta (B minus A0) is now +0.011 exact, where the pre-rescue decomposition (log
2026-07-27-06) measured 0.000. The piecewise calibration sharpened the analyst
timeline, which made perfect key context slightly more valuable than it
appeared. Still small, still consistent with the "context does not move naming"
conclusion, but no longer exactly zero.

**Plain-English reading.** We opened the sealed envelope. The most important
thing we wanted to check came back clean: the calmer chord display we shipped
this week is the right design, and on twelve pieces it had never seen, it beats
every alternative on every axis at once, exactly as it did on the pieces we
studied. The accuracy scores, though, came in about five points lower than
predicted, and we looked hard at why rather than reaching for the flattering
explanation. Half of it is that this music is genuinely harder to label. The
other half is our engine doing worse on chords it could see perfectly well, and
the biggest single piece of that is the same naming habit we spent today
deciding we could not fix without breaking things musicians care about. So the
honest headline is that our live accuracy number was a little optimistic, we now
know the real one, and we are not going to go tune against the test set to make
it look better.

**Next.** The initiative's measurement program is complete: both rulers frozen,
all avenues resolved, the holdout spent and reported. Any follow-up on the
absorption bucket starts as a new question on new data, per the protocol.
