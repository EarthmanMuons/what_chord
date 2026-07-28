# 2026-07-28: Avenue 3 scoped: exposure weights yes, observed voicings no

**Goal.** Scope avenue 3 (frequency-weighted oracle pool; observed-voicing
sampling) with measurements before committing to either half.

**Setup.** Scratchpad probe (method recorded here): every POP909 fixture event
(101-song sample, 6.1 hours of committed-event mass) mapped onto the oracle
pool's canonical case classes (`canonical_pc_set` plus bass interval, matching
`oracle_compare.py` case ids), duration-weighted. Cross-referenced with
`tool/chord/oracle_reviewed.json`. Revoicing consistency: for classes observed
under multiple distinct octave layouts, the mass share of the majority engine
top-1 name.

**What happened.**

Exposure concentration over the pool:

| top N cases | share of pool-mappable mass |
| ----------- | --------------------------- |
| 10          | 0.600                       |
| 25          | 0.784                       |
| 50          | 0.888                       |
| 100         | 0.956                       |
| 250         | 0.995                       |

Only 376 of the roughly 1,600 pool cases were observed at all; 10.9% of event
mass has more than 7 pitch classes and sits outside the pool's scope entirely.
The reviewed-entry set covers 16.5% of observed exposure mass (148 of 352
reviewed cases observed), which is expected, review was disagreement-driven, but
it means the harness's row-counting arithmetic (blast radius, ablation deltas,
triage order) treats a once-a-year cluster identically to a shape carrying a
fifth of all playing time. The top exposure rows are ordinary triads and
sevenths in inversions, most of them never reviewed because they never
disagreed; the weighting's real use is re-scaling the disagreement and
blast-radius computations, not reopening settled rows.

Revoicing consistency: 274 canonical classes were observed under 2 or more
distinct octave layouts, 7,834 layouts in total, and 99.29% of their mass
receives the majority top-1 name. Voicing evidence almost never changes the
engine's name across the revoicings musicians actually play.

**Verdicts.**

- **Observed-voicing pool expansion: measured and dismissed.** The engine is
  robust to real revoicing at 99.3%; canonical stacks are not hiding a
  voicing-sensitivity problem. Another entry in the initiative's pattern of the
  engine being exonerated by measurement.
- **Exposure weighting: worth adopting, cheap, and proposed.** Concentration
  this extreme (top 100 shapes = 96% of exposure) means a mass-weighted blast
  radius answers "how much playing time would this price change touch" instead
  of "how many enumeration rows flip". Proposal, pending review: a committed
  exposure-weight table (case id to observed mass, generated from the POP909
  sample, extendable with ChoCo symbol counts) plus an optional weights input to
  `tool/chord/pool_diff.py` and `rule_ablation.py`, reported alongside, never
  instead of, the unweighted counts, so the oracle workflow keeps its
  deterministic full-pool semantics.

**Plain-English reading.** Real playing lives on about a hundred chord shapes,
and the oracle harness has been giving equal air time to sixteen hundred.
Weighting its arithmetic by actual exposure is a small change that makes every
future blast-radius number mean something human. Meanwhile the worry that the
engine might name real-world voicings differently from textbook stacks is
retired: across nearly eight thousand distinct layouts, it changes its answer
less than one percent of the time.

**Decisions.**

- Observed-voicing sampling closed as unnecessary, with the consistency number
  as the record.
- Exposure weighting proposed for the oracle harness (table plus optional
  weighted reporting in pool_diff and rule_ablation), pending review since it
  touches the chord-oracle-comparison workflow.

**Next.** On approval: generate and commit the exposure-weight table, wire the
optional weighted reporting into the two oracle tools, and note the change in
research/chord-oracle-comparison.md. That closes avenue 3 and, with it, the
initiative's last queued avenue; what remains is the held test-split spend and
any product follow-through on the display-policy frontier.
