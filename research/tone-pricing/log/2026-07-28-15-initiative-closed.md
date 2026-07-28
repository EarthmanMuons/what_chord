# 2026-07-28: Initiative closed: one side declined, one side shipped

**Goal.** Close the initiative: final standing-row accounting, README summary,
and the handoff state.

**Standing rows, final read.** The 13 committed rows were re-read against the
shipped default. Three moved, all in the 0-2-9 shell family, and all as
designed:

- 0-2-9_b2 (root position): the surfaced band gains D7(omit3) beside Am/D. This
  is the one intended change in the whole pool, re-verdicted under
  review-on-flip.
- 0-2-9_b9 and 0-2-9_b0 (fifth and seventh in the bass): the shell candidate
  rises in the ranked list to second, but the bass penalty keeps it outside the
  surfaced band, so the app-visible output is byte-identical. Their reviewed
  notes are amended to record that the shell vocabulary now exists and that the
  verdicts stand for these inversions.

The remaining ten rows are unchanged at every price examined during the
initiative. Worth noting for future readers: the row that changed was a standing
row, which is what the standing set was committed for.

**Final state.**

- Engine: one price added (defaultShellMissingThirdCost 1.1, current profile
  only) and one display convention (showsOmittedThird). The research override
  parameter (shellSeventhCost) and the earlier unexplainedToneCost parameter
  both remain for future sweeps, defaulting to shipped behavior.
- Frozen reproduction: the whatKeyPaper2026 profile keeps both original prices,
  so published fixtures and paper numbers regenerate unchanged.
- Tooling added and kept: --shell-seventh-cost and --unexplained-tone-cost on
  the pool snapshot and ruler extractor paths, the dense-set stress census, and
  the standing-row set.
- Corpora: the ASAP test split is still sealed, and the POP909 held pool is
  still evaluation-virgin (it was touched only by engine-free frequency
  counting, per its freeze note).

**What the initiative bought.** One user-visible naming improvement on about 1%
of live playing time, and four documented declinations that close the superset
question with receipts instead of leaving it as a standing "we should look at
pricing someday". The declinations are the larger share of the value: each one
now has a measured reason a future reader can check rather than re-derive.

**Plain-English reading.** The initiative asked one question from two sides: how
forgiving should a chord name be about notes it cannot explain, and how honest
should it be about notes that are missing. The forgiving side lost every
argument it picked, for reasons we can now point at. The honest side won a
small, tightly bounded change that the app ships today. Both halves are written
down, and nothing is left half-explored.

**Next.** Nothing inside this initiative. The performed-input holdout (the
sealed ASAP test split) is now unblocked: tone-pricing was the last engine
question standing between the shipped state and a confirmation run, and it
resolved without moving any development-split number, so the pre-declaration can
quote the existing baselines directly.
