# 2026-08-01: Predeclare the reference-temporal denominator audit

**Goal.** Correct the aggregation cohort for label-relative spurious-switch
summaries and verify every Isophonics stability or annotated-change result used
by the manuscript. This entry is written before the remaining historical
development reports are regenerated or their corrected summaries are calculated.

## Defect and metric contract

The event-level spurious-switch rule is sound: a claim transition is called
spurious only when the reference at both claim endpoints is non-null and
unchanged, and the new claim is not that reference. The aggregate report is not
sound for a wholly unscorable piece. It currently inserts that piece's nominal
zero into the per-piece spurious-switch distribution even though a null
reference cannot classify any switch as spurious.

The correction is label-only and fixed before the audit:

- a piece enters the per-piece spurious-switch distribution if and only if it
  contains at least one event with a non-null `localKey`;
- a partially scorable piece remains eligible, while claim transitions touching
  a null-reference region remain unclassified under the existing event-level
  rule;
- raw switches and time to first claim remain all-piece behavioral metrics;
- annotated-change totals already count only adjacent non-null, differing
  `localKey` values, and modulation-lag distributions already range only over
  matched annotated changes. Their event denominators must be verified but not
  replaced with a piece-level scorable cohort; and
- no track, configuration, detector output, or parameter may be selected in
  response to the corrected results.

The durable scorer change will make the spurious distribution's `n` equal to the
number of reference-scorable pieces. A regression test will cover a wholly null
piece with raw switches so that it cannot silently contribute a zero spurious
count again.

## State already known

This declaration follows a read-only diagnosis, so the values already inspected
are recorded rather than represented as unseen:

- the frozen held-out Isophonics split contains 41 tracks, of which 38 have an
  exact-scorable reference and three are wholly modal under the 24-key ontology;
- for the held-out long-memory package, restricting the spurious distribution to
  the 38 scorable tracks leaves median/p90 at `0/3`; annotated changes remain 22
  and matched changes remain 10;
- for the held-out short-memory package, the restriction changes spurious
  median/p90 from the archived `5/11` over 41 tracks to `5/12` over 38;
  annotated changes remain 22 and matched changes remain 18; and
- the four R4 Isophonics development cells change from 183 to 180 pieces in the
  spurious distribution. Their already inspected median/p90 values remain `2/9`
  (1 s, functional blend 0), `3/9` (1 s, 0.1), `0/1` (30 s, 0), and `0/1` (30 s,
  0.1). Each cell still has 192 annotated changes; matched counts are
  respectively 150, 154, 94, and 86.

These observations determine no additional inclusion rule or configuration.

## Frozen inputs and remaining audit set

The audit starts at repository commit
`a36b5e60b03fac935fdfb9b43a1ab31fca26c7b7`. It uses the same `isophonics-nc-v1`
fixtures and development/test split already verified for R1 and R4 in entries
2026-08-01-01 through 2026-08-01-08. Held-out claims remain the immutable paper
and reflex artifacts declared in entry 2026-08-01-01.

The remaining development configurations are fixed by the historical records
that the manuscript cites:

1. mode-tilt strengths `0`, `0.25`, `0.5`, `1`, `2`, `3`, and `4`;
2. relative bass-tilt strengths `0.5`, `1`, and `2`, and relative cadence-tilt
   strengths `1`, `2`, and `4`, against the mode-tilt-2 baseline;
3. HMM self-transition values `0.7`, `0.8`, `0.9`, `0.95`, and `0.98`;
4. BOCPD hazards `0.005`, `0.015625`, `0.03125`, and `0.0625` at emission
   temperature `0.25`, plus the historical hazard-`0.005` rescue cells at
   temperatures `0.5` and `1.0`; and
5. the four existing R4 factorial reports and two immutable held-out reports
   listed above.

Every HMM regeneration will spell out the historical detector settings:
confidence weighting off, functional and progression blends zero,
self-transition `0.9` except in the dwell sweep, emission temperature `0.25`,
hysteresis `1`, Albrecht-Shanahan profiles, duration weighting, 30-second
emission half-life, minimum events `3`, margin floor `0.3`, mode tilt `2` except
in its own sweep, every relative/cadence setting zero except in its own sweep,
cold-start tonic prior zero, relative switch factor `1`, fifths decay `0.5`,
mode switch factor `0.5`, and calibration temperature `1`. BOCPD will use the
same applicable emission and claim settings, hazard/run-length settings stated
by its historical record, and no current application recipe.

The regenerated uncorrected headline values must first agree with entries
2026-07-07-23 through 2026-07-07-26. A mismatch stops the audit rather than
inviting parameter adjustment.

## Planned outputs

The audit will report, for every configuration:

- all pieces and reference-scorable pieces;
- archived/all-piece versus corrected scorable-piece spurious median and p90;
- annotated changes, matched changes, censored changes, and lag-event
  distribution before and after the cohort correction; and
- whether each quantitative manuscript statement changes.

The expected modulation comparison is exact equality because its denominators
are event-defined already. Any inequality is a defect requiring investigation.
The spurious values may change in either direction and will be carried into the
manuscript wherever the affected number or qualitative comparison remains.

**Plain-English reading.** Six songs in the full Isophonics collection use key
labels outside the detector's major/minor vocabulary. They are valid songs and
useful behavioral inputs, but their answer key cannot tell us whether a detector
switch is false. The existing summary quietly treated each such song as having
zero false switches, which makes the distribution look slightly calmer. This
audit fixes that denominator without deleting the songs or changing a single
detector output, then checks every stability statement that could have inherited
the mistake.

**Decisions.** Treat this as a reporting correction, not a detector experiment.
Preserve the historical reports and claims, publish only the corrected
label-relative denominator in new reports, and retain all-piece raw behavior
metrics for the modal tracks.

**Next.** Implement the scorer regression, regenerate the fixed historical
development report set, calculate one cohort-audit artifact, and update the
manuscript and revision scratchpad only after the complete result is known.
