# 2026-08-12: Automatic timing sensitivity result

**Goal.** Execute and audit the comparison preregistered in
`automatic-timing-sensitivity-preregistration.md`, after preserving the first
pre-output failure and committing its correction.

**Setup.** The successful run used clean relevant research and code paths at
repository commit `11907edbae9eef6cd92091be1ca2c613699c5b5f`. The local report
records Python 3.12.13 and Mido 1.3.3. Its fixed inputs were:

- preregistration SHA-256:
  `957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522`;
- POP909 onset-report SHA-256:
  `60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`; and
- Antonio Laviano's 2008 _Malediction_ MIDI SHA-256:
  `e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05`.

The source MIDI remains ignored under `tmp/` and is not republished. The
36,105,342-byte detailed output remains ignored under `build/` at:

`build/polychord/automatic-timing-sensitivity-v1.json`

Its SHA-256 is
`69dae7ed22fd7fed12e195bbb05a71ade6ba4d03085a4e4e83de95b7be3be8ca`.

The exact registered command was:

```sh
./.venv/bin/python tool/polychord/automatic_timing_sensitivity.py \
  --onset-report \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json \
  --liszt-midi tmp/pdfs/liszt-malediction.mid \
  --out build/polychord/automatic-timing-sensitivity-v1.json
```

It printed:

```text
POP909 remained zero at every onset gap; Liszt opportunities reproduced; report -> build/polychord/automatic-timing-sensitivity-v1.json
```

The report pins the complete implementation dependency surface, identifies
commit `11907edb`, and records `repositoryRelevantDirty: false`. It asserts that
the stored 200-millisecond interpretations and frozen POP909 totals reproduced,
both monotonicity requirements held, every expected all-zero POP909 row
reproduced, and the Liszt rows reproduced.

The independent accounting check was:

```sh
jq -e '
  (.pop909.perPiece | length) == 101 and
  (.pop909.candidateFrames | length) == 2524 and
  ([.pop909.candidateFrames[].candidateInterpretations[]] | length) == 3645 and
  ([.pop909.perPiece[].baselineCandidateExposure.candidateInstances] | add) == 3645 and
  ([.pop909.perPiece[].baselineCandidateExposure.candidateEventFrames] | add) == 2524 and
  ([.pop909.perPiece[].baselineCandidateExposure.candidateDwellMs] | add) == 205302 and
  ([.pop909.candidateFrames[].candidateInterpretations[] |
    select(.rawOnset.allCandidateOnsetsKnown)] | length) == 3645 and
  ([.pop909.candidateFrames[].candidateInterpretations[] |
    select(.rawOnset.lowerSpanMs <= 50 and .rawOnset.upperSpanMs <= 50)] |
    length) == 33 and
  ([.pop909.candidateFrames[].candidateInterpretations[] |
    select(.rawOnset.lowerSpanMs <= 50 and .rawOnset.upperSpanMs <= 50) |
    .rawOnset.intervalGapMs] | unique) == [0] and
  ([.lisztSourceCase.frames[] | select(.dwellMs > 0) |
    [.timestampMs, .dwellMs,
     .candidateInterpretations[0].rawOnset.intervalGapMs]]) ==
    [[24404, 97, 96], [24792, 96, 97]] and
  (.assertions | to_entries | all(.value == true))
' build/polychord/automatic-timing-sensitivity-v1.json
```

It returned `true`.

**Results.** The frozen POP909 denominator reproduced exactly: 3,645 candidate
instances on 2,524 candidate frames spanning 205,302 candidate milliseconds in
the 101-song sample. All evidence was complete. Every onset profile produced
zero positive candidate instances, frames, milliseconds, pieces, or
authorization episodes:

| Between-layer minimum | Positive instances | Positive frames | Positive ms | Positive pieces | Episodes |
| --------------------- | -----------------: | --------------: | ----------: | --------------: | -------: |
| 50 ms                 |                  0 |               0 |           0 |               0 |        0 |
| 80 ms                 |                  0 |               0 |           0 |               0 |        0 |
| 100 ms                |                  0 |               0 |           0 |               0 |        0 |
| 200 ms baseline       |                  0 |               0 |           0 |               0 |        0 |
| 300 ms                |                  0 |               0 |           0 |               0 |        0 |

The raw distribution explains the null. Of 3,645 candidate instances:

- 3,564 contained at least one sustained note;
- 3,586 shared a pitch class across layers and 59 were pitch-class disjoint;
- 132 had nonoverlapping layer-onset intervals; but
- only 33 had both layer-onset spans at or below the fixed 50-millisecond
  maximum, and every one of those 33 had an interval gap of exactly zero.

Therefore lowering only the between-layer minimum could not make a POP909
instance positive. The 200-millisecond minimum did not cause this corpus null.
The comparison did not vary or validate the 50-millisecond within-layer maximum.

The Liszt source case retained its fixed `boundary` construction label. Its
complete normalized stream contained ten same-candidate serialization frames
across two exact sounding-instance bindings. The authorization tracker grouped
them into the preregistered two opportunities:

| Start event | Timestamp | Onset gap | Episode duration |
| ----------: | --------: | --------: | ---------------: |
|         842 | 24,404 ms |     96 ms |            97 ms |
|         872 | 24,792 ms |     97 ms |            96 ms |

Both opportunities were cue-positive at the 50- and 80-millisecond onset
profiles. Neither was positive at 100, 200, or 300 milliseconds. Under either
cue-positive profile:

| Appearance dwell | Surviving opportunities | Summed opportunity post-dwell ms |
| ---------------: | ----------------------: | -------------------------------: |
|             0 ms |                       2 |                              193 |
|            50 ms |                       2 |                               93 |
|           100 ms |                       0 |                                0 |
|           200 ms |                       0 |                                0 |
|           300 ms |                       0 |                                0 |

The duration column is summed across independently tracked opportunities. It is
not selector or product display time.

All exact-threshold synthetic controls were positive, all one-millisecond-below
controls were neutral or did not survive, the synchronous committed `C|Gm`
control stayed neutral, and its 400-millisecond matched-history counterpart was
positive under every onset row. Those controls are excluded from every source
and corpus total.

**Plain-English reading.** The original 200-millisecond onset requirement was
not the reason the POP909 sample produced no onset-supported polychords. The
only candidates whose notes formed two sufficiently compact groups formed those
groups at the same time, so even the 50-millisecond comparison had nothing to
admit. This says something precise about this sample and fixed interpretation;
it does not say that onset is irrelevant in music generally.

The lower onset values do notice the brief pedal overlap in the Liszt sequence,
but that passage is a known alternation boundary, not the positive example we
would need to license a detector. A 50-millisecond display wait would let both
opportunities survive; 100 milliseconds would suppress both. That is coverage
information, not evidence that either product wait is correct.

**Decisions.** Select no onset threshold and no appearance dwell. Preserve the
200-millisecond profiles as named conservative baselines, not universal
constants. Do not reinterpret the Liszt boundary as a source positive. Do not
vary the within-layer maximum after seeing this result without a new
preregistration. Do not build or evaluate an automatic selector, encode the
automatic suite, or read the held POP909 reserve.

The next prerequisite remains source coverage: obtain at least one
event-complete, source-attested automatic-decision positive and its matched
cue-positive integrated or boundary guard under the same named evidence profile.
Only then can a threshold be selected as calibrated policy and frozen before
independent confirmation.

**Next.** Commit this result record. Continue the source-coverage work with
onset, release/pedal, and motion evidence kept separate. If a new
within-layer-span comparison becomes justified by source evidence, preregister
it as a distinct study rather than extending this completed sweep post hoc.
