# 2026-08-10: Preregister rigid-layer motion exposure

**Goal.** Freeze endpoint enumeration, exposure units, corpus scope, report
structure, and executable implementation before measuring the first rigid-layer
motion-support outcome.

**Setup.** Work began from repository commit `a2a2f0d4`. The fixed inputs were
`polychord-frame-replay/1`, `polychord-register-candidates/1`,
`polychord-release-pedal-evidence/1`, `polychord-frame-transition-evidence/1`,
and `rigid-layers-oblique-or-contrary/1`. No POP909 MIDI file, corpus report,
candidate-transition total, positive-support total, or held data was read while
the endpoint and measurement policy were chosen.

The preregistration artifacts and final SHA-256 pins are:

- motion-exposure contract:
  `4cd93c6a53f32f1a344878843dca01aa76825ee9737466de0134a0e332f444e1`;
- canonical implementation:
  `517613cefdae9249aaaf35b6469b33fd3ed2387d5605c20986ef639c1acf8b7c`; and
- focused test module:
  `755a4138c0b5016a2fb751bcc4e5b7fb6de4b96946d97044df51249ae2f5be87`.

The exact validation commands were:

```sh
python3 tool/polychord/motion_exposure_census.py --help
python3 -m unittest discover \
  -s tool/polychord \
  -p 'motion_exposure_census_test.py'
python3 -m unittest discover -s tool/polychord -p '*_test.py'
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/motion-exposure-census.md \
  research/polychord/log/2026-08-10-14-motion-exposure-preregistration.md
shasum -a 256 \
  research/polychord/motion-exposure-census.md \
  tool/polychord/motion_exposure_census.py \
  tool/polychord/motion_exposure_census_test.py
git diff --check
```

**What happened.** The measurement identity is
`pop909-sample-accompaniment-channel-blind-timestamp-terminal-rigid-motion/1`,
emitted as `polychord-motion-exposure-census/1`. It reuses the exact 101-song
POP909 accompaniment projection and channel-blind normalization from the onset
census. The 808-song held roster is not selectable.

The fixed endpoint policy is `adjacent-timestamp-terminal-frames/1`. Events are
grouped by exact timestamp, and only the frame after the last event in each
group can be an endpoint. Each endpoint is paired only with its immediately
preceding terminal frame. The census never pairs within a timestamp, never skips
a terminal frame, and uses no elapsed-time cutoff.

This resolves the main serialization ambiguity without erasing it.
Same-timestamp nonterminal frames remain in each exact transition window and are
counted separately, including every candidate-bearing excluded frame. They
cannot become motion endpoints. A positive-duration noncandidate state is a
terminal frame and therefore breaks candidate-to-candidate continuity instead of
being skipped.

Every adjacent window is classified as neither-candidate, candidate entry,
candidate exit, or candidate-to-candidate. Only the final class is
motion-evaluable. A first terminal candidate and a candidate entry are recorded
as motion-unavailable rather than neutral because they have no source candidate.
Same-sounding-set candidate transitions remain evaluable and receive the fixed
static neutral interpretation.

For each evaluable window, every source-target candidate pair and both unranked
correspondence hypotheses are interpreted. A target candidate is separately
counted as having any positive incoming hypothesis, but that disjunction is
explicitly an exposure aggregation: it does not select a source candidate or
correspondence.

Four denominator families remain separate: raw and timestamp-terminal endpoint
frames, adjacent observation transitions, target terminal-state dwell, and
candidate/pair/hypothesis instances. Positive duration is the target terminal
state's dwell until the next distinct timestamp or MIDI end, not the elapsed
time between endpoints. Same-sounding and pitch-changing candidate transitions
receive separate counts so pedal or state-only events remain visible.

Endpoint elapsed-time and per-window candidate/hypothesis multiplicities report
count, minimum, nearest-rank median, nearest-rank p90, and maximum. Nearest rank
is fixed as one-indexed `ceil(p * n)`. These summaries satisfy the protocol's
distribution requirement without making elapsed time a filter.

The synthetic contrary-motion fixture fixes the intended positive path: its 18
raw frames collapse to terminal endpoints after events 5 and 17, the intervening
12 events remain in the window, and the one candidate-to-candidate transition
has one positive preserving hypothesis. The inner-motion fixture fixes the
non-skipping guard: the positive-duration noncandidate state after event 7
creates a candidate exit followed by a candidate entry, so no candidate pair is
motion-evaluable. The pedal-history fixture freezes excluded zero-dwell
candidate counts and static neutral transitions.

The implementation refuses corpus-derived output outside `build/`, refuses to
start while relevant repository inputs are dirty, and refuses to write a result
if they become dirty during execution. It records the full source, runtime,
projection, normalization, per-piece, concentration, evidence, and contract-pin
trail. No corpus measurement was executed in this checkpoint. Thirteen focused
controls bring the complete polychord Python suite to 150 passing tests.

**Plain-English reading.** Simultaneous MIDI messages are allowed to finish
forming one observation before motion is compared, but their intermediate states
remain auditable. The next observation is always the very next distinct
timestamp. If a real noncandidate state occurs between two candidates, the
measurement does not reach backward across it to manufacture a motion link.

**Decisions.** Use adjacent timestamp-terminal frames as the first fixed
endpoint rule. Apply no elapsed-time threshold. Keep construction frames as
reported raw exposure but exclude them from endpoint selection. Treat candidate
entry as unavailable, not neutral. Attribute support duration to target-state
dwell. Report every aggregation level without selecting a candidate or
correspondence.

**Next.** Commit this preregistration before running the corpus command. Then
execute the implementation unchanged against the frozen 101-song sample, verify
every aggregate against per-piece and detailed records, disposition every
positive window, and record only aggregate findings and cryptographic report
pins in a new dated result entry. Keep the 808-song reserve untouched.
