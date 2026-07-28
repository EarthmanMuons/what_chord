# 2026-07-28: Exposure weights explored: uses, stability, and the held pool

**Goal.** Answer the review questions on the exposure-weight proposal before
implementation: what the table is for practically, whether reviewed verdicts
need re-evaluation, whether an engine rule is warranted, why the corpus was
sampled at one ninth, and whether POP909 needs a holdout.

**What happened.**

**Practical uses, enumerated.** The table serves measurement, not ranking:

1. _Mass-weighted blast radius_ (`pool_diff.py`): a price change's flips
   reported as "share of real playing time touched" alongside row counts.
2. _Mass-weighted rule ablation_ (`rule_ablation.py`): a hard rule protecting
   only never-played shapes reads differently from one guarding a shape carrying
   a fifth of playing time.
3. _A bounded, one-off second look at high-mass soft verdicts_, not a wholesale
   re-review: 7.5% of observed mass sits on `genuine-ambiguity` rows and 1.9% on
   `context-dependent`, concentrated in about ten rows (the largest,
   `0-1-3-8-10_b8`, carries 1.5%; several top rows are 7-pc diatonic pedal-wash
   clusters). Re-reading roughly ten notes with product eyes is the whole job.
4. _Pool-scope evidence_: 21.8% of raw sounding time (10.9% of committed events)
   has more than 7 pitch classes and is invisible to the pool. Now measured;
   whether the pool should grow a weighted 8-plus tier is a future
   oracle-harness question, not part of this change.

**No engine rule.** The existing ChoCo prior discriminates between candidate
names for the same observed notes, which is what a tiebreak needs. Exposure is a
distribution over shapes, and all candidates for an observation share its shape,
so it carries zero discriminating signal between names. The table is decision
support for humans and harness arithmetic, full stop.

**Sampling and method stability.** The stride-9 choice was scoping conservatism,
and it turns out not to matter: the full-corpus, engine-free table (all 909
songs, raw snapshot dwell mass, 62 hours, 832 cases) against the 101-song
committed-event table agrees at 90/100 on the top-100 cases, 0.929 distribution
intersection, with no case moving more than one point. Decision: the committed
table is built from the full corpus with the snapshot method (deterministic from
MIDI, engine-free, regenerable without replay), and the 0.929 agreement is the
recorded evidence that this choice is immaterial in practice.

**Holdout.** Not needed for the current uses: the weight table is a measurement
instrument with no correctness labels and nothing tuned against it, and the
stability work is descriptive. But the boundary is worth freezing now because it
is free: every evaluation-flavored measurement so far touched only the 101
stride-sample songs, while the full-corpus pass was engine-free frequency
counting. The 808 complement songs are therefore clean, and the implementation
will record them as a held pool from which a split can be frozen if POP909 ever
graduates to an evaluation corpus (identity with improved labels, or formal
stability-adoption corroboration). Per the diligence entry, any such graduation
freezes a split before tuning.

**Plain-English reading.** The weight table will not change what the engine
does; it changes what our numbers mean when we consider changing the engine,
converting "how many rows flip" into "how much of an evening of playing changes
name". The reviewed backlog does not need reopening, just ten minutes on the ten
heaviest judgment calls. And the pop corpus keeps a clean two-thirds we have
never evaluated against, fenced off today while it costs nothing.

**Decisions.**

- Committed table: full corpus, snapshot method, with the sample/method
  agreement recorded above.
- Bounded second look at the top ten soft-verdict rows folded into the
  implementation.
- The 808 non-sample songs recorded as a held pool at implementation time.

**Next.** Implement: the exposure-table generator as a committed tool, the
optional weighted reporting in `pool_diff.py` and `rule_ablation.py` (alongside,
never replacing, unweighted counts), the held-pool record, the top-ten
soft-verdict skim, and a note in research/chord-oracle-comparison.md.
