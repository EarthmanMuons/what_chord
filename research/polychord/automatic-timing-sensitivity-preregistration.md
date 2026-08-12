# Automatic polychord timing sensitivity preregistration

Status: preregistered design for `polychord-automatic-timing-sensitivity/1`.
This document must be committed before its implementation is written or the
comparison is run. It defines an exploratory sensitivity measurement, not a
selector, accuracy evaluation, threshold choice, or product-adoption gate.

The planned canonical implementation is
`tool/polychord/automatic_timing_sensitivity.py`. It does not exist at this
preregistration stage.

## Questions

The measurement asks three bounded questions:

1. Did the 200-millisecond between-layer onset requirement materially cause the
   zero-positive result in the exposed POP909 accompaniment sample?
2. Which source and control cases change interpretation across a
   literature-bounded onset-gap comparison?
3. How often would cue-positive authorization opportunities survive several
   independently reported appearance dwells?

The measurement does not ask which threshold is correct. POP909 has no verified
polychord labels, the currently event-complete source inventory has no admitted
automatic-decision positive, and a candidate surviving an appearance dwell is
not evidence that its musical decomposition is valid.

## Disclosed development knowledge

This comparison is development-informed. Before the profile family was fixed,
the research record already contained:

- zero positives under `coherent-separated-onsets-50-200ms/1` in the exposed
  101-song POP909 sample;
- the fact that all 33 POP909 candidate instances with two compact layers had
  zero onset separation;
- 96- and 97-millisecond onset gaps and candidate lifetimes in the
  hand-sequenced Liszt _Malediction_ boundary;
- a 125-millisecond note duration in the independently authored Stravinsky
  sequence, without source-fixed note-for-note candidate alignment; and
- the app's already measured primary-display comparisons at 100, 200, and 300
  milliseconds.

Those observations may be characterized by this exploratory study but may not
later be reused as independent confirmation of a chosen parameter.

## Expected outcomes from the disclosed record

This is a deterministic reinterpretation of already inspected evidence, not a
blind hypothesis test. The following outcomes are expected before
implementation:

- POP909 remains at zero positive instances for every gap minimum in the frozen
  family. The prior report already establishes that its only 33 instances with
  two compact layers have zero interval separation; every profile here requires
  a positive separation of at least 50 milliseconds.
- The two Liszt opportunities become onset-positive at 50 and 80 milliseconds
  and remain neutral at 100, 200, and 300 milliseconds, based on their already
  reported 96- and 97-millisecond gaps.
- When an onset-positive Liszt opportunity is considered, its already reported
  96- or 97-millisecond lifetime survives appearance dwells of 0 and 50
  milliseconds but not 100, 200, or 300 milliseconds.

The implementation must verify these implications from the pinned raw records. A
mismatch is a failed reproduction that stops interpretation; it is not a
surprising scientific result to explain post hoc.

## Fixed inputs

### POP909 threshold-free candidate evidence

Use the existing local report:

`build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json`

Required SHA-256:
`60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`.

The report was generated from the 101-song `sample` roster at POP909 commit
`d83e6edba6872a704f5d3b8b32f5cb540088dae6`, using the named `BRIDGE` plus
`PIANO` projection. Its detailed candidate frames retain the raw onset evidence
needed for reinterpretation. The implementation must verify the report schema,
measurement ID, digest, source commit, aggregate MIDI-content digest, roster
digest, `labelsRead: false`, and all embedded contract pins before reading a
candidate record.

The implementation must derive every comparison row from the stored raw
`onsetEvidence`. It may read the stored 200-millisecond interpretation only to
verify baseline equivalence; it may not treat that categorical output as the
input to alternate profiles.

The detailed report remains under `build/` because it contains copyrighted event
data. The sensitivity output must also remain under `build/`; only aggregates,
case dispositions, and cryptographic pins may enter the research log.

### Source case

Use Antonio Laviano's 2008 hand-sequenced MIDI realization of Liszt's
_Malediction_, fetched from the Kunst der Fuge URL and pinned in log
2026-08-12-02 with SHA-256
`e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05`. The
implementation must reproduce that log's channel-blind, pedal-aware replay
through the unchanged normalization and register-candidate functions rather than
transcribing the reported 96- and 97-millisecond results by hand.

The score-derived construction label remains `boundary`: rapid alternation that
may blur, not a score-attested simultaneous static polychord. This fixed label
does not change when an exploratory cue profile becomes positive. The Liszt case
may therefore become a cue-positive guard; it cannot become a source positive in
this measurement.

The 125-millisecond Stravinsky observation is excluded from candidate-level
sensitivity because the public sequence did not corroborate the proposed exact
score voicing. It remains disclosed context rather than being converted into a
favorable fixture.

### Synthetic mechanics controls

Retain the existing synchronous 0-millisecond and separated 400-millisecond
`C|Gm` matched-history fixtures. For every onset-gap threshold `T`,
implementation tests must also construct an exact-`T` positive and a `T - 1`
neutral control with simultaneous attacks inside each complete layer. For every
nonzero appearance dwell `D`, tests must construct authorization episodes
lasting exactly `D` and `D - 1` milliseconds. These prove inclusive boundary and
timer mechanics only; they are never counted as source coverage.

## Frozen onset comparison

Keep `withinLayerCohortSpanMaximumMs` fixed at 50. Vary only
`betweenLayerSeparationMinimumMs` over this ordered family:

| Gap minimum | Role in this comparison                                                                 |
| ----------- | --------------------------------------------------------------------------------------- |
| 50 ms       | Lower stress bound; studies show this is detectable but can still behave as one chord.  |
| 80 ms       | Approximate point where Hukin and Darwin report reduced pitch contribution beginning.   |
| 100 ms      | Round intermediate value and an existing app timing comparison.                         |
| 200 ms      | The unchanged `coherent-separated-onsets-50-200ms/1` baseline.                          |
| 300 ms      | Approximate point where Hukin and Darwin report the leading contribution reaching zero. |

The 50-, 80-, 100-, and 300-millisecond rows are exploratory profiles with IDs
of the form `coherent-separated-onsets-50-<gap>ms/sensitivity-1`. The
200-millisecond row must call or exactly reproduce the committed
`coherent-separated-onsets-50-200ms/1` implementation and match every stored
baseline result.

All profiles retain the existing requirements: complete onset history, both
layer intervals compact under the fixed 50-millisecond maximum, nonoverlapping
intervals, orientation-neutral layer order, inclusive threshold comparison, and
one-sided positive or neutral support. No profile may inspect construction
labels, chord-analyzer results, sustain state, velocity, source name, or dwell
when interpreting onset support.

This study does not validate the fixed 50-millisecond within-layer parameter.
Its pass/fail state and raw spans must be reported prominently so that a
different bottleneck cannot be misattributed to the gap sweep. Any later
within-layer comparison requires another named preregistration.

## Frozen authorization-survival comparison

Independently compare appearance dwells of 0, 50, 100, 200, and 300
milliseconds. The 200-millisecond row is the existing `polychord-output/2`
presentation baseline. All other rows are exploratory coverage diagnostics, not
alternate output contracts.

The study has no selector. It therefore measures **candidate authorization
opportunities**, not product displays:

1. The opportunity key is the exact ordered candidate and MIDI-note assignment
   plus every assigned note's current `(midiNote, onsetEventIndex)` binding.
2. An opportunity is active only while the named onset profile is positive for
   that complete binding.
3. Consecutive normalized frames continue one opportunity only when their event
   indices are consecutive and the complete key remains equal. A missing frame,
   candidate, binding, or positive interpretation ends it immediately.
4. Pressed-to-sustained changes may continue an opportunity when the sounding
   instance and complete key remain equal. Reattack cannot.
5. An episode survives dwell `D` when its duration is at least `D`; equality is
   inclusive and may produce zero potential displayed duration.
6. Multiple candidates are tracked independently. Their durations must not be
   pooled as though a selector had chosen or displayed all of them.

An episode begins at the timestamp of its first positive frame, accumulates the
following dwell of every continuing positive frame, and ends at the first
invalidating event or the source's exclusive end boundary. Same-timestamp frames
may therefore create zero-duration episodes. Report those separately. Potential
post-dwell duration is `max(0, episodeDurationMs - D)` for a surviving episode;
do not add overlapping candidates' durations into one product-time total.

For dwell zero, every positive opportunity survives immediately. For other
dwells, report both the number of surviving opportunities and their potential
post-dwell duration. Call neither quantity a stable display, because structural
selection, ambiguity resolution, primary-display availability, and product
output are absent.

## Required report

The local JSON report uses schema `polychord-automatic-timing-sensitivity/1` and
must retain:

- exact command, timestamp, working directory, repository commit and relevant
  dirtiness, Python and Mido versions;
- input paths, hashes, schemas, measurement IDs, source pins, and every profile
  parameter and identity;
- the raw gap, both raw within-layer spans, completeness, layer order, candidate
  identity and assignment, shared pitch classes, sustain presence, event dwell,
  and sounding-instance binding for every reinterpreted candidate instance;
- for every onset profile, positive candidate instances, event frames, dwell
  milliseconds, pieces, neutral reasons, and all cases newly positive relative
  to the 200-millisecond baseline;
- the joint raw distribution of lower span, upper span, and signed interval gap,
  including separate summaries for complete evidence, two compact layers,
  nonoverlapping intervals, shared-tone candidates, disjoint candidates, and
  candidates containing sustained notes;
- per-piece POP909 counts and duration, with the top 20 pieces by newly positive
  time and their share of the total;
- every exact candidate authorization episode and its survival under each
  appearance dwell, including zero-duration episodes and potential post-dwell
  duration, without merging overlapping candidates;
- the Liszt case's fixed construction label, exact replayed opportunities, cue
  interpretations, and dwell-survival results; and
- synthetic-control results in a separate mechanics section excluded from every
  source and corpus total.

The report must assert two monotonicity invariants:

- lowering the onset-gap minimum cannot remove a positive interpretation when
  every other field is fixed; and
- shortening the appearance dwell cannot remove a surviving authorization
  opportunity.

It must also reproduce the existing 200-millisecond POP909 totals exactly: 3,645
candidate instances, 2,524 candidate frames, 205,302 candidate milliseconds, and
zero positively supported instances, frames, or milliseconds. A mismatch aborts
the run.

## Interpretation and stopping rules

The following are fixed before implementation:

- No row wins this comparison. Do not choose, recommend, or implement a product
  threshold from the report.
- POP909 results are exposure, not precision or recall. A larger positive count
  may mean increased sensitivity, increased false support, or both.
- If all POP909 rows reproduce zero as expected, report that the 200-millisecond
  gap did not cause this corpus null. Do not conclude that onset evidence is
  useless.
- When the lower-gap profiles make the Liszt boundary positive as expected,
  treat it as a source-backed cue-positive guard for those profiles, not as
  evidence against the fixed construction label.
- If any lower-gap profile produces POP909 positives, retain and disposition
  every newly positive episode before designing a selector. Do not tune against
  those dispositions and call the result confirmatory.
- No cue becomes licensing until at least one event-complete source-attested
  automatic-decision positive and its required guard exist under the same named
  profile.
- No appearance dwell becomes product policy until an exact selector decision
  stream exists and its latency, suppression, false-display, and accessibility
  behavior are evaluated separately.
- Do not read the 808-song POP909 reserve, the ASAP test split, or any corpus
  label.

## Planned execution sequence

1. Commit this preregistration and its dated decision record.
2. Implement the canonical comparison and focused tests without changing this
   document.
3. Commit the implementation before running the full comparison.
4. Run exactly:

   ```sh
   ./.venv/bin/python tool/polychord/automatic_timing_sensitivity.py \
     --onset-report \
     build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json \
     --liszt-midi tmp/pdfs/liszt-malediction.mid \
     --out build/polychord/automatic-timing-sensitivity-v1.json
   ```

5. Verify the output structure, frozen baseline totals, monotonicity, input and
   implementation pins, then record the complete aggregate and source-case
   result in a new dated measurement entry regardless of outcome.

Thresholds are constants in the implementation. The command exposes no flags for
alternate grids, corpora, rosters, labels, source cases, or output outside
`build/`.
