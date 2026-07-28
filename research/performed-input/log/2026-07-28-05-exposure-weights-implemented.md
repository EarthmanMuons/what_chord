# 2026-07-28: Exposure weights implemented; avenue 3 closed

**Goal.** Implement the reviewed exposure-weight package (log -04): the
committed table, weighted reporting in the oracle tools, the held-pool record,
the soft-verdict skim, and the workflow doc note.

**What happened.**

- `tool/chord/pop909_exposure.py` generates the committed table
  (`tool/chord/pop909_exposure_weights.json`): all 909 songs, engine-free
  snapshot dwell mass, 62.0 hours sounding, 832 canonical cases, 21.8% outside
  the pool's 3-7 note range. Aggregate statistics only, so committable under the
  license gate.
- `tool/chord/exposure_weights.py` is the shared loader; `pool_diff.py` (diff
  and census) and `rule_ablation.py` now print each stratum's exposure share
  alongside, never replacing, the unweighted counts. The
  zero-flips-on-clearly-correct constraint stays count-based. The workflow doc
  gains a paragraph (research/chord-oracle-comparison.md).
- The census smoke run pays for the feature immediately with a count-versus-mass
  inversion: "prefer fewer altered/tension colors" decides 139 pool cases
  carrying 0.6% of playing time, while "prefer root position" decides 47 cases
  carrying 5.5%. Row counts and human impact disagree by an order of magnitude
  in both directions.
- **Latent breakage found and fixed by the smoke test:** both `pool_diff.py` and
  `rule_ablation.py` still pointed at the pre-reorganization batch path
  (`tool/chord_oracle_batch.dart`) and have been broken since the 2026-07-13
  tooling move to `tool/chord/oracle_batch.dart`. The hard-rule initiative's
  published ablation results predate the reorganization and are unaffected; the
  tools simply could not run since then.
- Held pool frozen: `research/performed-input/data/pop909-held-pool.json`
  records the 101 stride-sample songs (used for evaluation-flavored work) and
  the 808 clean complement songs from which any future POP909 evaluation split
  must be frozen before tuning.
- Soft-verdict skim (top ten by exposure, verdict notes re-read): no verdict
  changes. The 7-pc diatonic rows are pedal-wash collections with careful
  reasoning that stands. One observation elevated by exposure, then sharpened
  against the live engine: the `0-2-9` and `0-1-8` context-dependent rows are a
  pricing question, not a vocabulary absence. Power-with-add-color forms exist
  (C-G-Db names C5addb9 top-1), and D-A-C offers D7 as a candidate, but at cost
  1.7 behind Am/D at 0.95 because the seventh reading pays a missing-third
  penalty; an honest shell label (D7(no3) or D5addb7) that names exactly the
  sounding tones at a competitive price is what does not exist. Shell-voicing
  idioms (a jazz left hand playing D-A-C as a D7 shell) expect the seventh
  reading; folk contexts support the slash reading, which is why the verdicts
  are context-dependent. Together these shapes carry about 1.8% of real playing
  time; recorded as a measured vocabulary-plus-pricing question for a future
  engine conversation, not an action item.

**Plain-English reading.** The oracle tools now say how much of an actual
evening of playing a change touches, next to how many catalog rows it flips, and
the first look already shows the two rankings disagree tenfold. Along the way
the smoke test caught that both measurement tools had been quietly broken by a
file move for two weeks, the pop corpus got a fenced clean two-thirds for future
use, and the review backlog needed nothing but a note that one small vocabulary
gap is worth more than its row count suggested.

**Decisions.**

- Avenue 3 closed: exposure weighting shipped as measurement support;
  observed-voicing expansion stayed dismissed (log -03).
- The power-with-color question is recorded with its 1.8% exposure figure and
  the pricing-not-vocabulary characterization above, deliberately not opened as
  engine work here.
- Pool expansion to 8-plus pitch classes: declined for oracle purposes. The
  advisory oracles and naming conventions both run out past 7 pitch classes, so
  disagreement rows there would be noise; the dense-set surface (21.8% of
  sounding time, mostly pedal wash) is already served by the identity census and
  the display-policy work, and a descriptive self-consistency census over the
  8-plus events in existing fixtures is the right instrument if the pricing
  conversation ever opens.

**Next.** The initiative's queued avenues are all resolved (1 and 2 complete, 3
closed, 4 done, 5 shelved). Remaining: the held ASAP test-split spend when a
pre-declared confirmation set warrants it, and product follow-through on the
display-policy frontier.
