# 2026-08-10: Measure rigid-layer motion exposure

**Goal.** Execute the committed motion-exposure preregistration unchanged,
verify its complete accounting and provenance, disposition every positive
window, and determine what the strict rigid-layer cue contributes on the frozen
POP909 sample.

**Setup.** The preregistration was committed as `0d19454d`. The relevant
worktree was clean, the POP909 checkout was present and clean, and Mido was
available before execution. The exact measurement command was:

```sh
./.venv/bin/python tool/polychord/motion_exposure_census.py \
  --out \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
```

The tool completed on all 101 sample songs and wrote a 99,737,986-byte local
report with SHA-256
`3489da54e0c2b71ba0a9f1c17acb6678115eae07afacf280c8afef8b81a2a3b6`. The report
remains under `build/` and is not committed.

Its recorded source and runtime provenance is:

- report schema: `polychord-motion-exposure-census/1`;
- measurement:
  `pop909-sample-accompaniment-channel-blind-timestamp-terminal-rigid-motion/1`;
- repository commit: `0d19454dc606bb38e207ddbaa2acb4121dedc584`;
- repository measurement inputs dirty: `false`;
- POP909 commit: `d83e6edba6872a704f5d3b8b32f5cb540088dae6`;
- POP909 dirty: `false`;
- roster SHA-256:
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`;
- aggregate MIDI-content SHA-256:
  `2aa21f03506d26ce256ed9d22eedc34a6f87694ef9ece389af198ff2e4440eb3`;
- labels read: `false`;
- Python: 3.12.13; and
- Mido: 1.3.3.

A read-only verifier was added after measurement; it does not alter or rerun the
frozen census. Its final pins are:

- verifier implementation:
  `f58276e20ba35672dba84dfb50d6f39655f4879fc41328e748177085ed715497`; and
- focused verifier tests:
  `22604abb4c1c3786b24547cede8965640b8966a33207d580bcf2af82c120e8a2`.

The verifier resolves every contract pin from the recorded measurement commit,
checks the committed sample roster and 808-song held isolation, hashes all 101
MIDI files and their aggregate, verifies pooled integers against every per-piece
record, reconstructs every candidate-related endpoint class and Cartesian
candidate product, recounts every hypothesis and reason code, recomputes
target-dwell and candidate-window distributions, and checks the raw candidate
universe against the earlier onset-exposure report. That comparison used the
report already pinned in log 2026-08-10-08, SHA-256
`60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`. The exact
command was:

```sh
python3 tool/polychord/motion_exposure_result_verify.py \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json \
  --onset-report \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
```

It returned:

```text
valid: build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json (101 songs; 0 positive windows; sha256 3489da54e0c2b71ba0a9f1c17acb6678115eae07afacf280c8afef8b81a2a3b6)
```

Two focused verifier controls bring the complete polychord Python suite to 152
passing tests.

Additional result-inspection commands were:

```sh
stat -f '%z bytes' \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
shasum -a 256 \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
jq '.summary' \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
jq -s -e \
  '.[0].source.songIds == .[1].source.songIds and
   .[0].source.midiContentSha256 == .[1].source.midiContentSha256 and
   .[0].normalization == .[1].normalization and
   .[0].projection == .[1].projection and
   .[0].summary.endpointFrames.rawEventFrames ==
     .[1].summary.eventFrames.total and
   .[0].summary.endpointFrames.rawEventFramesWithCandidates ==
     .[1].summary.eventFrames.withCandidates and
   (.[0].summary.candidateInstances.timestampTerminalTotal +
    (.[0].excludedSameTimestampCandidateFrames |
      map(.candidates | length) | add)) ==
     .[1].summary.candidateInstances.total and
   .[0].summary.terminalDwellMs.sounding ==
     .[1].summary.dwellMs.sounding and
   .[0].summary.terminalDwellMs.withCandidates ==
     .[1].summary.dwellMs.withCandidates' \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
```

The cross-report assertion returned `true`.

## Result

The headline result is **zero positive rigid-layer motion-support windows**.
This holds at every aggregation level: zero positive hypotheses, candidate
pairs, target candidates, endpoint windows, and target-state milliseconds. There
are therefore no positive cases to disposition.

The complete exposure accounting is:

| Unit                                        | Count or duration | Reading                                            |
| ------------------------------------------- | ----------------: | -------------------------------------------------- |
| Raw event frames                            |           276,420 | Every normalized note or pedal state change        |
| Timestamp-terminal frames                   |           221,175 | One endpoint-eligible state per distinct timestamp |
| Sounding terminal frames                    |           214,870 | Terminal states with at least one sounding note    |
| Raw candidate frames                        |             2,524 | Matches the prior onset report                     |
| Terminal candidate frames                   |             2,086 | 0.9708% of sounding terminal frames                |
| Excluded same-timestamp candidate frames    |               438 | 17.35% of raw candidate frames; all zero dwell     |
| Raw candidate instances                     |             3,645 | Matches the prior onset report                     |
| Terminal candidate instances                |             2,968 | Candidate instances eligible as terminal states    |
| Excluded same-timestamp candidate instances |               677 | 18.57% of raw candidate instances                  |
| Sounding terminal dwell                     |     24,485,451 ms | Same sounding-time denominator as the onset report |
| Candidate terminal dwell                    |        205,302 ms | 0.8385% of sounding time                           |
| Motion-evaluable terminal frames            |             1,733 | 83.08% of terminal candidate frames                |
| Motion-evaluable target dwell               |        158,130 ms | 77.02% of candidate time                           |
| Positive target dwell                       |              0 ms | No rigid-layer support                             |

Endpoint adjacency produced 353 candidate entries, 353 candidate exits, and
1,733 candidate-to-candidate windows. Of the evaluable windows, 1,606 (92.67%)
had the same sounding MIDI set and received static neutral interpretations. Only
127 windows (7.33%) changed sounding pitch; they contributed 13,462 milliseconds
across 39 pieces.

Candidate-to-candidate elapsed time had a nearest-rank median of 61
milliseconds, p90 of 229 milliseconds, and maximum of 1,118 milliseconds. The
1,733 evaluable windows produced 4,466 candidate pairs and 8,932 hypothesis
interpretations. Candidate-pair multiplicity per window had median 1, p90 4, and
maximum 25.

## Why the strict cue did not fire

The 127 pitch-changing windows produced 388 candidate pairs and 776
correspondence hypotheses. A post-result diagnostic grouped their already
recorded facts without changing the measurement:

- all 388 register-role-exchanging hypotheses contradicted retained sounding
  instances and neither mapped layer was an exact translation;
- 167 register-role-preserving hypotheses also contradicted retained instances
  after the candidate boundary changed, and neither layer was exact;
- 221 preserving hypotheses were consistent with retained instances;
- among those 221 consistent hypotheses, 175 had exactly one exact layer
  relation and 46 had neither; and
- all 175 exact single-layer relations had translation delta zero.

No pitch-changing hypothesis therefore contained even one nonzero rigid layer
translation, and none had both exact layers. Every `betweenLayerMotionClass`
remained `null`. The zero result is not caused by an elapsed-time threshold, a
selected correspondence, or a final display gate. The strict moving-block
pattern simply did not occur among the observed candidate transitions in this
sample.

The exact diagnostic commands were:

```sh
jq \
  '[.candidateEndpointWindows[] |
    select(.classification == "candidate-to-candidate" and .pitchChanging) |
    .candidateInterpretations[] |
    .hypothesisInterpretations[]] |
   group_by([.hypothesisId,.retainedInstanceEvidence]) |
   map({hypothesis:.[0].hypothesisId,
        retained:.[0].retainedInstanceEvidence,
        count:length,
        oneExact:(map(select([.layerTranslations[].exactMidiSetTranslation] |
          any))|length),
        bothExact:(map(select(.bothLayersExactTranslations))|length)})' \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
jq \
  '[.candidateEndpointWindows[] |
    select(.classification == "candidate-to-candidate" and .pitchChanging) |
    .candidateInterpretations[] |
    .hypothesisInterpretations[] |
    select(.hypothesisId == "register-role-preserving" and
      .retainedInstanceEvidence == "consistent") |
    .layerTranslations[] |
    select(.exactMidiSetTranslation and .chordIdentityFollowsTranslation) |
    .translationSemitones] |
   {count:length,byDelta:(group_by(.)|map({delta:.[0],count:length}))}' \
  build/polychord/pop909-sample-timestamp-terminal-rigid-motion-v1.json
```

## Interpretation

This is an informative null for one strict cue on one label-free pop
accompaniment sample. It is not evidence that polychords are absent, that motion
is perceptually irrelevant, or that the feature is accurate or safe. POP909 is
not a polychord-rich ruler, the projection is channel-blind and globally
pedaled, and no labels were inspected.

The result does establish that exact complete-set translation is too sparse to
add positive support to the current register candidates in this sample. Its zero
exposure makes it harmless here but not useful here. Loosening it in response to
this result would be outcome-dependent tuning on the development sample and is
not authorized.

**Decisions.** Preserve `rigid-layers-oblique-or-contrary/1` as the conservative
first ablation and report this null unchanged. Do not reinterpret neutral cases
as failures or positives. Do not spend the 808-song reserve. Do not make a
product-safety, accuracy, perceptual-streaming, or general prevalence claim.

**Next.** Commit this result and verifier as one measurement record. Before
designing a more permissive motion model, encode score-verified positive motion
windows from the literature-attested ruler and test whether the strict cue has
construct validity outside its synthetic control. Any voice-assignment,
partial-set, revoicing-tolerant, or distance-based alternative must be a new
named and preregistered ablation, not an edit to this result.
