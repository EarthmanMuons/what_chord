# 2026-08-01: Correct the reference-temporal denominator

**Goal.** Complete the predeclared audit in entry 2026-08-01-13: keep wholly
null-reference tracks in behavioral reporting, exclude their unclassifiable
nominal zeros from the per-piece spurious-switch distribution, and verify every
Isophonics stability and modulation result retained by the manuscript.

## Setup

The audit began at commit `a36b5e60b03fac935fdfb9b43a1ab31fca26c7b7`. The
detector runs used the frozen `isophonics-nc-v1` fixtures and split previously
verified in entries 2026-08-01-01 through 2026-08-01-08. The working-tree
changes affected the research scorer, claim-artifact replay, audit tooling,
tests, protocol, and manuscript; they did not alter the detector or fixture
content.

The historical HMM development reports were reproduced with this copy-pasteable
shell definition and fixed calls:

```sh
run_temporal_hmm() {
  local audit_out="$1"
  local audit_self_transition="$2"
  local audit_mode_tilt="$3"
  local audit_relative_tilt="$4"
  local audit_relative_cadence_tilt="$5"
  dart run tool/whatkey/harness.dart \
    --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
    --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
    --split development --detector hmm \
    --confidence-weighting off --functional-blend 0 \
    --progression-blend 0 --self-transition "$audit_self_transition" \
    --emission-temperature 0.25 --hysteresis 1 \
    --profiles albrechtShanahan --weighting duration \
    --decay-half-life-seconds 30 --min-events 3 --margin-floor 0.3 \
    --mode-tilt "$audit_mode_tilt" \
    --relative-tilt "$audit_relative_tilt" \
    --relative-cadence-tilt "$audit_relative_cadence_tilt" \
    --relative-evidence-tilt 0 --relative-evidence-window 1 \
    --cadence-boost 0 --cadence-triad-boost 0 \
    --cadence-margin-factor 1 --cold-start-tonic-prior 0 \
    --relative-switch-factor 1 --fifths-decay 0.5 \
    --mode-switch-factor 0.5 --calibration-temperature 1 \
    --out "$audit_out"
}

for audit_tilt in 0 0.25 0.5 1 2 3 4; do
  run_temporal_hmm \
    "build/whatkey-reference-temporal/mode-$audit_tilt" \
    0.9 "$audit_tilt" 0 0
done

for audit_tilt in 0.5 1 2; do
  run_temporal_hmm \
    "build/whatkey-reference-temporal/relative-bass-$audit_tilt" \
    0.9 2 "$audit_tilt" 0
done

for audit_tilt in 1 2 4; do
  run_temporal_hmm \
    "build/whatkey-reference-temporal/relative-cadence-$audit_tilt" \
    0.9 2 0 "$audit_tilt"
done

for audit_transition in 0.7 0.8 0.95 0.98; do
  run_temporal_hmm \
    "build/whatkey-reference-temporal/dwell-$audit_transition" \
    "$audit_transition" 2 0 0
done
```

The self-transition-0.9 report is the mode-tilt-2 baseline. The BOCPD reports
were reproduced separately because that detector has no HMM transition or
emission-history settings:

```sh
run_temporal_bocpd() {
  local audit_out="$1"
  local audit_hazard="$2"
  local audit_temperature="$3"
  dart run tool/whatkey/harness.dart \
    --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
    --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
    --split development --detector bocpd \
    --profiles albrechtShanahan --weighting duration \
    --emission-temperature "$audit_temperature" --min-events 3 \
    --margin-floor 0.3 --mode-tilt 2 --hazard "$audit_hazard" \
    --max-run-length 128 --hysteresis 1 --calibration-temperature 1 \
    --out "$audit_out"
}

for audit_hazard in 0.005 0.015625 0.03125 0.0625; do
  run_temporal_bocpd \
    "build/whatkey-reference-temporal/bocpd-h$audit_hazard-t0.25" \
    "$audit_hazard" 0.25
done
for audit_temperature in 0.5 1.0; do
  run_temporal_bocpd \
    "build/whatkey-reference-temporal/bocpd-h0.005-t$audit_temperature" \
    0.005 "$audit_temperature"
done
```

No detector was run on the held-out split. The two immutable event-claim
artifacts were replayed through the corrected scorer:

```sh
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split test \
  --claims-file research/whatkey/results/test-split-2026-07-07/test-iso-hmm-shipped/claims.json \
  --out build/whatkey-reference-temporal/heldout-paper-rescored
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split test \
  --claims-file research/whatkey/results/test-split-2026-07-07/test-iso-hmm-reflex/claims.json \
  --out build/whatkey-reference-temporal/heldout-reflex-rescored
```

The replayed `claims.json` files are byte-for-byte identical to their inputs:

- paper SHA-256:
  `401042ec2232fe3c5870af9b6ae78bea43760b5294e381a0b79b362d56e8671f`;
- reflex SHA-256:
  `c6e8dd76d837095c4e36126ad44acf520d2c776834a16cca0f73904e20704f5f`.

The consolidated audit command supplied 30 named reports to:

```sh
python3 tool/whatkey/revision_reanalysis.py reference-temporal \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --report mode-0=build/whatkey-reference-temporal/mode-0/report.json \
  --report mode-0.25=build/whatkey-reference-temporal/mode-0.25/report.json \
  --report mode-0.5=build/whatkey-reference-temporal/mode-0.5/report.json \
  --report mode-1=build/whatkey-reference-temporal/mode-1/report.json \
  --report mode-2=build/whatkey-reference-temporal/mode-2/report.json \
  --report mode-3=build/whatkey-reference-temporal/mode-3/report.json \
  --report mode-4=build/whatkey-reference-temporal/mode-4/report.json \
  --report relative-bass-0.5=build/whatkey-reference-temporal/relative-bass-0.5/report.json \
  --report relative-bass-1=build/whatkey-reference-temporal/relative-bass-1/report.json \
  --report relative-bass-2=build/whatkey-reference-temporal/relative-bass-2/report.json \
  --report relative-cadence-1=build/whatkey-reference-temporal/relative-cadence-1/report.json \
  --report relative-cadence-2=build/whatkey-reference-temporal/relative-cadence-2/report.json \
  --report relative-cadence-4=build/whatkey-reference-temporal/relative-cadence-4/report.json \
  --report dwell-0.7=build/whatkey-reference-temporal/dwell-0.7/report.json \
  --report dwell-0.8=build/whatkey-reference-temporal/dwell-0.8/report.json \
  --report dwell-0.9=build/whatkey-reference-temporal/mode-2/report.json \
  --report dwell-0.95=build/whatkey-reference-temporal/dwell-0.95/report.json \
  --report dwell-0.98=build/whatkey-reference-temporal/dwell-0.98/report.json \
  --report bocpd-h0.005-t0.25=build/whatkey-reference-temporal/bocpd-h0.005-t0.25/report.json \
  --report bocpd-h0.015625-t0.25=build/whatkey-reference-temporal/bocpd-h0.015625-t0.25/report.json \
  --report bocpd-h0.03125-t0.25=build/whatkey-reference-temporal/bocpd-h0.03125-t0.25/report.json \
  --report bocpd-h0.0625-t0.25=build/whatkey-reference-temporal/bocpd-h0.0625-t0.25/report.json \
  --report bocpd-h0.005-t0.5=build/whatkey-reference-temporal/bocpd-h0.005-t0.5/report.json \
  --report bocpd-h0.005-t1.0=build/whatkey-reference-temporal/bocpd-h0.005-t1.0/report.json \
  --report r4-hl1-f0=build/whatkey-revision/grid-iso-hl1-f0/report.json \
  --report r4-hl1-f0.1=build/whatkey-revision/grid-iso-hl1-f0.1/report.json \
  --report r4-hl30-f0=build/whatkey-revision/grid-iso-hl30-f0/report.json \
  --report r4-hl30-f0.1=build/whatkey-revision/grid-iso-hl30-f0.1/report.json \
  --report heldout-paper=build/whatkey-reference-temporal/heldout-paper-rescored/report.json \
  --report heldout-reflex=build/whatkey-reference-temporal/heldout-reflex-rescored/report.json \
  --out build/whatkey-reference-temporal/audit.json
```

The local audit output SHA-256 is
`22ea791f8433c9a4aae453babb717931f34fcc4e0f292272e137766d284ef7a2`.

## What happened

The historical development headlines reproduced exactly at the precision
recorded in entries 2026-07-07-23 through 2026-07-07-26. The corrected
spurious-switch cohort contains 180 rather than 183 development tracks and 38
rather than 41 held-out tracks.

| Result family                    |       Legacy median/p90 | Corrected median/p90 | Consequence |
| -------------------------------- | ----------------------: | -------------------: | ----------- |
| mode tilt 0 through 4            |                     0/1 |                  0/1 | unchanged   |
| relative bass tilt 0.5, 1, 2     |           0/2, 0/2, 0/4 |        0/2, 0/2, 0/4 | unchanged   |
| relative cadence tilt 1, 2, 4    |           0/1, 0/1, 0/2 |        0/1, 0/1, 0/2 | unchanged   |
| self-transition 0.7 through 0.98 | 0/1, 0/1, 0/1, 0/1, 0/2 |                 same | unchanged   |
| BOCPD manuscript cells           |          5/14, 2/7, 0/4 |       5/14, 2/7, 0/4 | unchanged   |
| held-out paper package           |                     0/3 |                  0/3 | unchanged   |
| held-out reflex package          |                    5/11 |                 5/12 | p90 +1      |

One BOCPD hazard cell not quoted in the manuscript (`h=0.03125`, `T=0.25`)
changes median/p90 from `8/21` to `9/21`. Every other audited development median
and p90 is unchanged, including all four R4 cells.

The audit also checked the full modulation objects rather than only headline
counts. Across all 30 entries, the all-piece and reference-scorable-piece views
are identical in annotated changes, matched changes, censored changes, and lag
median/p90. Each development report has 192 annotated changes; the held-out
reports have 22. This confirms that modulation denominators were already safe:
wholly null tracks generate no annotated changes and therefore no nominal
observations.

The manuscript's stability conclusions survive, but one existing compression was
too strong independently of this correction. In the dwell sweep, spurious p90 is
1 from self-transition 0.7 through 0.95 and 2 at 0.98; it is not unconditionally
"pinned at 1." The manuscript now states the full result. The mode-tilt
paragraph now gives its actual secondary diagnostics: coverage spans 1.2
percentage points, spurious p90 remains 1, and matched changes rise from 82 to
102 of 192.

The replay attempt also found that `ClaimsFile` could read external global
baselines but not the harness's own per-event artifacts. It now supports both
forms, with regression coverage for abstentions, switches, and fixture-length
validation. This changes no claim artifact and enables exact post-hoc rescoring
without rerunning a detector.

**Plain-English reading.** The modal songs were making the false-switch summary
look slightly calmer by contributing zeros that the labels could not actually
justify. Removing those uninformative zeros changes one held-out tail value and
one unused development median; all stability numbers the paper discusses stay
the same. Key-change counts and lags need no correction because songs without a
major/minor answer key never contributed a key change in the first place.

## Decisions

- Use the reference-scorable piece cohort for every per-piece spurious-switch
  distribution from now on. Keep raw switching and time to first claim over all
  pieces.
- Keep the event-defined modulation metrics unchanged, while documenting why
  null-reference regions are outside their denominator.
- Retain the 41-track held-out split and the modal-track behavior audit.
  Describe `38` as the reference-scorable metric cohort, not as a replacement
  split.
- Do not add the held-out `5/12` reflex p90 to the manuscript merely because it
  changed; the revised held-out table no longer makes a stability claim.
- Correct the dwell wording and make the mode-tilt diagnostics quantitative. No
  detector, parameter, or substantive conclusion changes.

**Next.** Finish the fresh-submission prose cleanup, then let the author read
the complete manuscript before deciding which secondary material to compress or
move to a supplement.
