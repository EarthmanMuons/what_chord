# 2026-07-28: Piecewise calibration rescues three movements and refines four

**Goal.** Rescue every gate-excluded movement that can be rescued (dev and test
sides), per the review decision.

**Setup.** `asap_wir_extract.py`'s calibration generalized from a single
content-chosen offset to piecewise-constant offsets: per-downbeat overlap scores
for candidate offsets within 5 of the anchor, greedy changepoint splits up to 6
segments, each split gated by a 0.02 mean-overlap gain and an 8-downbeat minimum
segment. The threshold, not the cap, is the guardrail: 28 movements kept a
single segment. A reconnaissance finding removed the suspected structural
blocker: Op110 has no separate fourth-movement analysis; "31-3" is the combined
Adagio/Fuga analysis with a continuous map, so one mechanism covers all four
candidates.

**What happened.**

- Rescued (now sharply at zero, healthy band): 7-1 (three segments, 0.793), 7-4
  (two, 0.721), 12-1 (three, 0.759).
- Refined, unrequested: the piecewise search found real internal drift inside
  four movements the global offset had papered over: 10-1 (0.713 to 0.812,
  explaining its long-standing shallowness), 16-2 (0.701 to 0.781), 30-1 (0.723
  to 0.822), 7-3 (0.719 to 0.795).
- 31-3_4: improved from flat 0.41 to a sharp 0.623 peak with five segments
  spanning offsets +1 to -5, but its final third (the fugue's back half) stays
  flat at every constant offset; the divergence there is continuous, not
  piecewise-constant. Still excluded, now with the terminal diagnosis recorded:
  0.62 at shift 0 against the 0.70 healthy bar.
- Full census: 35 of 36 sharply at zero and healthy, 1 shallow (31-3_4), none
  off-peak.

**Split execution, not re-freeze.** The frozen by-sonata rule pre-assigned every
rescue: 7-1 and 7-4 join development (now 23 movements, 6,301 events), 12-1
joins test (12 movements, 3,309 events; untouched by any run), event mass still
66/34. The gate roster in `freeze_split.py` shrinks to 31-3_4.

**Refreshed development baselines** (23 movements; the frozen logs' 21-piece
numbers stand as historical):

- Identity A0: coverage 0.481, exact 0.602, root 0.747, members 0.529.
- Stability: labeled 0.560, switches/min 340.8, flicker 0.489, settle median 218
  ms, p90 869 ms, churn/event 1.39.

Key-label lineage note: the piecewise pass changed labels only in the eight
multi-segment movements; v1 remains frozen for the whatkey reproduction
contract, and v2's lineage note (log 2026-07-27-03 and REPRODUCING.md) covers
this as a further correction in the same direction.

**Plain-English reading.** Three of the four benched movements are back on the
roster, including the one on the test side, and four movements we thought were
fine turn out to fit even better once their mid-piece numbering shifts are
honored. The one holdout is the Op110 finale, whose closing fugue drifts against
the score map in a way no constant correction can follow; it keeps its bench
seat with the reason written down.

**Next.** Pre-holdout checklist: only the pre-declaration remains (the v1.1
ruler question and the 12-1 rescue are both resolved).
