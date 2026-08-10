# 2026-08-10: Audit release and pedal history

**Goal.** Execute the preregistered, label-free audit once and determine which
raw release and pedal facts the reusable temporal evidence contract must
preserve.

**Setup.** The audit definition was committed at repository commit `c9e6cc1c`.
The worktree was clean and the output path did not exist before execution. The
fixed measurement identity was `pop909-sample-disjoint-release-pedal-audit/1`,
with report schema `polychord-release-pedal-audit/1`.

The run used:

- the previously generated onset-exposure report with SHA-256
  `60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`;
- its complete 59-instance pitch-class-disjoint subset in the 12 preregistered
  POP909 sample songs;
- POP909 commit `d83e6edba6872a704f5d3b8b32f5cb540088dae6`, with a clean source
  checkout;
- aggregate selected-MIDI SHA-256
  `d426291b305b1e2a1332c99313e965beb9be8181d797561b3177542ea80e66d4`;
- Python 3.12.13 and Mido 1.3.3; and
- the exact ten schema and implementation pins embedded in the report.

Both the source report and new report state `labelsRead: false`. The new report
also states `heldPoolRead: false`, `repositoryMeasurementInputsDirty: false`,
and `pop909Dirty: false`.

The exact measurement and primary validation commands were:

```sh
./.venv/bin/python tool/polychord/release_pedal_audit.py \
  --out build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
shasum -a 256 \
  build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
wc -c \
  build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
jq -r '.contracts.pins[] | "\(.sha256)  \(.path)"' \
  build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json \
  | shasum -a 256 -c -
./.venv/bin/python -c "import json,sys; from pathlib import Path; sys.path.insert(0,'tool/polychord'); import release_pedal_audit as a; p=json.loads(Path('build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json').read_text()); assert a.summarize_runs(p['runs']) == p['summary']; assert sum(r['frameCount'] for r in p['runs']) == 59; assert sum(r['observedDurationMs'] for r in p['runs']) == 4920; assert sum(r['zeroDwellFrameCount'] for r in p['runs']) == 8; print('all fixed summaries and run aggregates recomputed exactly')"
```

The preregistered summary helper recorded minimum, median, and maximum but
omitted the p90 required by this protocol's general reporting rules. The report
is preserved unchanged. Nearest-rank p90 values, with rank `ceil(0.9 * count)`,
were derived after the run from the retained observations with:

```sh
./.venv/bin/python -c "import json,math; from pathlib import Path; p=json.loads(Path('build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json').read_text()); o=[x for r in p['runs'] for x in r['observations']]; e=[x['releasePedalEvidence'] for x in o]; n=lambda e:[x for l in (e['lower'],e['upper']) for x in l['notes']]; p90=lambda v:sorted(v)[math.ceil(0.9*len(v))-1]; values={'candidateRunDurationMs':[r['observedDurationMs'] for r in p['runs']],'candidateRunFrameCount':[r['frameCount'] for r in p['runs']],'sustainedNoteCountPerInstance':[e['sustainedCandidateNoteCount'] for e in e],'distinctReleaseTimestampsPerInstance':[len(set(e['lower']['distinctKnownReleaseTimestampsMs']+e['upper']['distinctKnownReleaseTimestampsMs'])) for e in e],'pedalStateAgeMs':[e['pedal']['currentStateAgeMs'] for e in e if e['pedal']['currentStateAgeMs'] is not None],'candidateNoteOnsetAgeMs':[x['onsetAgeMs'] for e in e for x in n(e) if x['onsetAgeMs'] is not None],'sustainedNoteReleaseAgeMs':[x['releaseAgeMs'] for e in e for x in n(e) if x['releaseAgeMs'] is not None],'lowerLayerReleaseSpanMs':[e['lower']['knownReleaseSpanMs'] for e in e if e['lower']['knownReleaseSpanMs'] is not None],'upperLayerReleaseSpanMs':[e['upper']['knownReleaseSpanMs'] for e in e if e['upper']['knownReleaseSpanMs'] is not None]}; print(json.dumps({k:{'count':len(v),'nearestRankP90':p90(v)} for k,v in values.items()},indent=2))"
```

The state, release, and run summaries were reproduced with:

```sh
jq '[.runs[] | .songId as $song | .observations[] |
      [$song, .observationFrame.afterEventIndex,
              .observationFrame.timestampMs]] as $frames |
  [.runs[].observations[]] as $o |
  [$o[].releasePedalEvidence] as $e |
  {
    uniqueCandidateFrames: ($frames | unique | length),
    causingEventTypes:
      ($o | map(.causingEvent.type) | group_by(.) |
       map({type: .[0], count: length})),
    layerSustainPresence: {
      both: ($e | map(select(.lower.sustainedNoteCount > 0 and
                             .upper.sustainedNoteCount > 0)) | length),
      lowerOnly: ($e | map(select(.lower.sustainedNoteCount > 0 and
                                  .upper.sustainedNoteCount == 0)) | length),
      upperOnly: ($e | map(select(.lower.sustainedNoteCount == 0 and
                                  .upper.sustainedNoteCount > 0)) | length),
      neither: ($e | map(select(.lower.sustainedNoteCount == 0 and
                                .upper.sustainedNoteCount == 0)) | length)
    },
    candidateNoteOccurrences: {
      sustained: ($e | map(.sustainedCandidateNoteCount) | add),
      pressed: ($e | map(.pressedCandidateNoteCount) | add),
      reattackedFromSustain:
        ($e | map(.reattackedFromSustainCount) | add),
      onsetBeforePedalDown:
        ($e | map(.onsetBeforeCurrentPedalDownCount) | add)
    },
    everySustainedNoteHasDistinctReleaseTimestamp:
      ($e | all((([.lower.distinctKnownReleaseTimestampsMs[],
                   .upper.distinctKnownReleaseTimestampsMs[]] |
                  unique | length) == .sustainedCandidateNoteCount)))
  }' \
  build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
jq '[.runs[].observations[].releasePedalEvidence] as $e |
  {
    releaseIntervalOrder:
      ([$e[] |
         select(.lower.sustainedNoteCount > 0 and
                .upper.sustainedNoteCount > 0) |
         if .lower.latestKnownReleaseMs < .upper.earliestKnownReleaseMs
         then "lower-before-upper"
         elif .upper.latestKnownReleaseMs < .lower.earliestKnownReleaseMs
         then "upper-before-lower"
         else "overlapping-or-interleaved" end] |
       group_by(.) | map({order: .[0], count: length})),
    reattackByPrePedalAttack:
      ([$e[] | {
         reattack: (.reattackedFromSustainCount > 0),
         prePedal: (.onsetBeforeCurrentPedalDownCount > 0)
       }] | group_by([.reattack, .prePedal]) |
       map({reattack: .[0].reattack,
            prePedal: .[0].prePedal,
            count: length}))
  }' \
  build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
jq '[.runs[] | {
    frameCount,
    observedDurationMs,
    sequence: ([.observations[].causingEvent.type] | join(">")),
    terminator: (.terminatingEvent.type // "midiEnd")
  }] |
  group_by([.sequence, .terminator]) |
  map({sequence: .[0].sequence,
       terminator: .[0].terminator,
       runs: length,
       frames: (map(.frameCount) | add),
       durationMs: (map(.observedDurationMs) | add)}) |
  sort_by(-.runs, .sequence, .terminator)' \
  build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
```

**What happened.** The report is 902,217 bytes with SHA-256
`73f9f4d09673ce5255dd1577652eb990afe16b88b2be168ec83a1df07bb60520`. All ten
embedded contract pins matched, and the fixed summaries and run aggregates
recomputed exactly from retained observations.

### Observation and run units

| Unit                                              | Result                 |
| ------------------------------------------------- | ---------------------- |
| Candidate instances                               | 59                     |
| Unique candidate-bearing event frames             | 58                     |
| Exact-candidate runs                              | 26                     |
| Songs                                             | 12                     |
| Zero-dwell candidate instances                    | 8                      |
| Zero-duration runs                                | 4                      |
| Observed candidate duration                       | 4,920 ms               |
| One-frame runs                                    | 18 of 26               |
| Run duration, minimum / median / p90 / maximum    | 0 / 179 / 405 / 536 ms |
| Run frame count, minimum / median / p90 / maximum | 1 / 1 / 5 / 13         |

One event frame carried two different exact candidates, which accounts for 59
candidate instances on 58 frames. Eighteen runs, or 69.23%, lasted one replay
frame. Four runs had no positive dwell, but their same-timestamp transition
states remain part of the event-order record.

Every run began on a note-on. Fourteen ended when the next note-on changed the
candidate, and 12 ended on a pedal transition. Across all retained observations,
35 followed a note-on and 24 followed a note-off. Note-offs under the depressed
pedal often changed pressed notes into sustained notes without changing the
sounding pitch set, so an exact candidate could persist across those events.

### Held-state and pedal history

All 59 instances occurred with the sustain pedal down, included at least one
sustained note, and had complete state-changing release provenance for every
sustained note. Both proposed layers contained sustained notes in 53 instances;
the other six had sustained notes only in the upper layer. No instance had
sustain confined to the lower layer. Two instances had every candidate note
sustained.

The 59 frame-level candidates contained 447 candidate-note occurrences:

| Current or historical fact                | Occurrences | Share of 447 |
| ----------------------------------------- | ----------- | ------------ |
| Currently sustained                       | 300         | 67.11%       |
| Currently pressed                         | 147         | 32.89%       |
| Current onset reattacked a sustained note | 105         | 23.49%       |
| Current onset preceded current pedal-down | 103         | 23.04%       |

At the instance level, 46 of 59 included a pedal-sustained reattack and 40
included an onset preceding the current pedal-down transition. Twenty-seven
included both facts, 19 included a reattack but no pre-pedal onset, and 13
included a pre-pedal onset but no reattack. Thus every selected instance
included at least one of those two forms of accumulated history.

The current pedal state was 379 through 2,911 milliseconds old, with a median of
896 and p90 of 1,904 milliseconds. Candidate-note onsets were zero through 4,930
milliseconds old, with a median of 535 and p90 of 1,467 milliseconds.
Sustained-note releases were zero through 2,783 milliseconds old, with a median
of 366 and p90 of 1,006 milliseconds.

### Release structure

The sustained-note count per instance ranged from two through ten, with a median
of five and p90 of seven. The distinct release-timestamp count had the same
distribution and p90. Every one of the 300 sustained candidate-note occurrences
had a release timestamp distinct from every other sustained candidate note in
the same instance. Consequently, no two currently sustained candidate notes
formed an exact same-millisecond release cohort.

All 53 lower layers containing sustained notes had a known release span; their
median span was 668 milliseconds, p90 was 1,663 milliseconds, and maximum was
2,186 milliseconds. All 59 upper layers contained sustained notes; their median
span was 192 milliseconds, p90 was 488 milliseconds, and maximum was 1,004
milliseconds. A layer span was zero only in the 17 cases where that layer
contained exactly one sustained note. Every layer with two or more sustained
notes had a positive span, from 4 through 2,186 milliseconds.

Among the 53 instances with sustained notes in both layers, the lower release
interval ended before the upper began in nine, the upper ended before the lower
began in 11, and the intervals overlapped or interleaved in 33. No one temporal
ordering dominated.

**Plain-English reading.** The original register rule briefly saw two complete,
pitch-class-disjoint chord shapes in these passages, but it saw them inside a
longer pedal history. Notes had generally accumulated, been released one by one,
and often been re-pressed while the pedal kept the earlier sound alive. The
proposed two-chord shape usually lasted only until another note arrived or the
pedal cleared it. This is a signature consistent with transient accumulated
voicings that release and pedal evidence must make visible to later logic.

It is not proof that every instance is musically false. The selection has no
polychord labels, legitimate polychords may use sustain, exact performance
timestamps do not define perceptual cohorts by themselves, and the subset was
chosen for pitch-class disjointness rather than representativeness. The audit
therefore supports an evidence contract, not a pedal-based rejection rule or an
accuracy claim.

**Decisions.** Preserve the report and result unchanged. The reusable
threshold-free contract must retain, for every sounding candidate note, its
pressed-versus-sustained state, current onset origin, state-changing release
origin and velocity when applicable, current-state origin, reattack-from-sustain
status and prior release, and exact relation to the current pedal-down origin.
It must retain the pedal state and last observed transition, preserve unknown
carried-in history, and expose raw per-layer state counts and release timestamps
or spans without defining a cohort tolerance.

Keep exact-candidate run grouping, causing events, terminating events, and
corpus causal windows in the audit methodology rather than the reusable
single-frame evidence object. Frame replay already preserves the underlying
event sequence, and later motion or stable-display work can define its own
window contract.

Do not infer a release-synchrony threshold from this unlabeled descriptive
subset. Do not adopt `pedalDown` or `hasSustainedNotes` as a rejection rule;
those states are compatible with legitimate constructions. Do not reinterpret
the onset ablation's zero result. Release/pedal evidence is a separate named
increment, after which motion remains the next research step. Future measurement
reports must include protocol-required p90 values in their frozen summary schema
rather than relying on a post-run derivation.

**Next.** Freeze the reusable threshold-free release/pedal evidence schema,
canonical implementation, and synthetic tests in their own logical commit. The
schema must contain no support, penalty, eligibility, or display decision. Only
after that contract is committed may a separately named interpretation be
proposed. Leave POP909 labels and the 808-song reserve untouched.
