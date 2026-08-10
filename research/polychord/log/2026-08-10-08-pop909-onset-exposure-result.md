# 2026-08-10: Measure POP909 onset-support exposure

**Goal.** Execute the preregistered POP909 accompaniment census once, without
tuning, then determine how often the fixed register generator appears and how
often `coherent-separated-onsets-50-200ms/1` positively supports one of its
candidates.

**Setup.** The preregistration was committed at repository commit `b8761437`.
The worktree was clean and the detailed report did not exist before execution.
The fixed measurement identity was
`pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1`, with
report schema `polychord-onset-exposure-census/1`.

The run used:

- the 101-song `sample` field of the hard-pinned `performed-input-held-pool/1`
  roster;
- POP909 commit `d83e6edba6872a704f5d3b8b32f5cb540088dae6`, with a clean source
  checkout;
- aggregate MIDI-content SHA-256
  `2aa21f03506d26ce256ed9d22eedc34a6f87694ef9ece389af198ff2e4440eb3`;
- the paper-defined `BRIDGE` plus `PIANO` accompaniment projection, with channel
  identity discarded after track selection;
- Python 3.12.13 and Mido 1.3.3; and
- the exact ten schema and implementation pins embedded in the report.

The report states `labelsRead: false`,
`repositoryMeasurementInputsDirty: false`, and `pop909Dirty: false`. The
808-song clean reserve was not selectable and was not read.

The exact measurement and validation commands were:

```sh
./.venv/bin/python tool/polychord/onset_exposure_census.py \
  --out build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
shasum -a 256 \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
jq -r '.contracts.pins[] | "\(.sha256)  \(.path)"' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json \
  | shasum -a 256 -c -
./.venv/bin/python -c 'import json; from pathlib import Path; p=json.loads(Path("build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json").read_text()); s=p["summary"]; pieces=p["perPiece"]; assert len(pieces)==p["source"]["songCount"]==101; assert len(p["candidateFrames"])==s["eventFrames"]["withCandidates"]==sum(x["metrics"]["eventFrames"]["withCandidates"] for x in pieces); assert s["candidateInstances"]["total"]==sum(x["metrics"]["candidateInstances"]["total"] for x in pieces); assert s["candidateInstances"]["completeEvidence"]+s["candidateInstances"]["incompleteEvidence"]==s["candidateInstances"]["total"]; assert s["candidateInstances"]["positiveSupport"]+s["candidateInstances"]["neutral"]==s["candidateInstances"]["total"]; assert all(s["eventFrames"][k]==sum(x["metrics"]["eventFrames"][k] for x in pieces) for k in ("total","zeroDwell","sounding","withCandidates","zeroDwellWithCandidates","withPositiveSupport","zeroDwellWithPositiveSupport")); assert all(s["dwellMs"][k]==sum(x["metrics"]["dwellMs"][k] for x in pieces) for k in ("sounding","withCandidates","withPositiveSupport")); assert all(p["normalization"][k]==sum(x["normalization"][k] for x in pieces) for k in p["normalization"]); assert p["projection"]["channelPedalDisagreementMs"]==sum(x["projection"]["channelPedalDisagreementMs"] for x in pieces); print("report structure and per-piece aggregates verified")'
```

The aggregate and condition summaries were reproduced with:

```sh
jq '{summary,projection,normalization,perPieceCount:(.perPiece|length),candidateFrameCount:(.candidateFrames|length)}' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
jq '{reasonCombinations:([.candidateFrames[].candidateInterpretations[].onsetInterpretation.reasonCodes | join("+")] | group_by(.) | map({reasons:.[0],count:length}) | sort_by(-.count)),conditionPassMatrix:([.candidateFrames[].candidateInterpretations[].onsetInterpretation | [(.lowerWithinCohortSpanMaximum|tostring),(.upperWithinCohortSpanMaximum|tostring),((.betweenLayerOnsetIntervalGapMs >= 200)|tostring)] | join("/")] | group_by(.) | map({lowerUpperSeparated:.[0],count:length}) | sort_by(-.count)),layerOrder:([.candidateFrames[].candidateInterpretations[].onsetInterpretation.layerOnsetOrder] | group_by(.) | map({order:.[0],count:length}) | sort_by(-.count))}' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
jq '{sharedPitchClassCounts:([.candidateFrames[] as $frame | $frame.candidateInterpretations[] | {shared:(.candidate.sharedPitchClasses|length),dwellMs:$frame.dwellMs}] | group_by(.shared) | map({sharedPitchClasses:.[0].shared,instances:length,dwellMs:(map(.dwellMs)|add)}) | sort_by(.sharedPitchClasses)),sustainedNotePresence:([.candidateFrames[].candidateInterpretations[] | ([.onsetEvidence.lower.notes[],.onsetEvidence.upper.notes[]] | any(.soundingState=="sustained"))] | group_by(.) | map({hasSustainedNote:.[0],instances:length}) | sort_by(.hasSustainedNote))}' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
jq '{totals:{instances:.summary.candidateInstances.total,candidateFrames:.summary.eventFrames.withCandidates,candidateMs:.summary.dwellMs.withCandidates},derived:{bothLayersCompact:([.candidateFrames[].candidateInterpretations[].onsetInterpretation|select(.lowerWithinCohortSpanMaximum and .upperWithinCohortSpanMaximum)]|length),separatedAtLeast200:([.candidateFrames[].candidateInterpretations[].onsetInterpretation|select(.betweenLayerOnsetIntervalGapMs>=200)]|length),nonoverlappingIntervals:([.candidateFrames[].candidateInterpretations[].onsetInterpretation|select(.layerOnsetOrder!="overlapping")]|length),instancesWithAnySustainedNote:([.candidateFrames[].candidateInterpretations[]|select(([.onsetEvidence.lower.notes[],.onsetEvidence.upper.notes[]]|any(.soundingState=="sustained")))]|length),disjointPitchClassInstances:([.candidateFrames[].candidateInterpretations[]|select((.candidate.sharedPitchClasses|length)==0)]|length),disjointInstancesWithAnySustainedNote:([.candidateFrames[].candidateInterpretations[]|select((.candidate.sharedPitchClasses|length)==0)|select(([.onsetEvidence.lower.notes[],.onsetEvidence.upper.notes[]]|any(.soundingState=="sustained")))]|length)},top20CandidateTimeShare:(.summary.dwellMs.withCandidates as $total|([.perPiece[].metrics.dwellMs.withCandidates]|sort|reverse|.[:20]|add)/$total)}' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
jq '{compactTriples:([.candidateFrames[].candidateInterpretations[] | select(.onsetInterpretation.lowerWithinCohortSpanMaximum and .onsetInterpretation.upperWithinCohortSpanMaximum) | [.onsetEvidence.lower.knownOnsetSpanMs,.onsetEvidence.upper.knownOnsetSpanMs,.onsetInterpretation.betweenLayerOnsetIntervalGapMs]] | unique),separatedOneCompactFailingSpans:([.candidateFrames[].candidateInterpretations[] | select(.onsetInterpretation.betweenLayerOnsetIntervalGapMs>=200) | select(.onsetInterpretation.lowerWithinCohortSpanMaximum or .onsetInterpretation.upperWithinCohortSpanMaximum) | (if .onsetInterpretation.lowerWithinCohortSpanMaximum then .onsetEvidence.upper.knownOnsetSpanMs else .onsetEvidence.lower.knownOnsetSpanMs end)] | sort),disjointPieceCount:([.candidateFrames[] as $frame | $frame.candidateInterpretations[] | select((.candidate.sharedPitchClasses|length)==0) | $frame.songId] | unique | length)}' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
jq '[.perPiece[] | select(.metrics.dwellMs.withCandidates > 0) | {songId,candidateMs:.metrics.dwellMs.withCandidates,candidateFrames:.metrics.eventFrames.withCandidates,candidateInstances:.metrics.candidateInstances.total}] | sort_by(-.candidateMs,.songId) | .[:20]' \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
```

**What happened.** The report is 18,988,418 bytes with SHA-256
`60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`. All ten
embedded contract pins matched the committed files, and every global count
recomputed exactly from the 101 per-piece records.

### Generator exposure

| Unit                                  | Count or duration | Share                         |
| ------------------------------------- | ----------------- | ----------------------------- |
| All normalized event frames           | 276,420           | -                             |
| Sounding event frames                 | 269,885           | -                             |
| Candidate event frames                | 2,524             | 0.9352% of sounding frames    |
| Zero-dwell candidate frames           | 438               | 17.35% of candidate frames    |
| Sounding time                         | 24,485,451 ms     | -                             |
| Candidate time                        | 205,302 ms        | 0.8385% of sounding time      |
| Candidate instances across all splits | 3,645             | 1.44 instances per fire frame |
| Pieces with at least one candidate    | 79 of 101         | 78.22%                        |

Candidate exposure was widespread but individually brief. Song 091 contributed
the largest candidate duration, 10,532 milliseconds or 5.13% of corpus candidate
time. The top 20 songs contributed 62.28%; no one piece dominated the result.
The remaining leading durations were song 874 at 9,834 milliseconds, 721 at
7,960, 127 at 7,648, 262 at 7,623, 784 at 7,433, 496 at 6,686, 865 at 6,638, 802
at 6,403, and 703 at 6,345.

### Onset-support result

All 3,645 candidate instances had complete onset evidence. None received
positive onset support. There were zero positive frames and zero positive
milliseconds.

The three fixed conditions failed as follows. Rows show lower-layer compactness,
upper-layer compactness, and at least 200 milliseconds of interval separation,
in that order:

| Lower compact | Upper compact | Separated | Instances |
| ------------- | ------------- | --------- | --------- |
| no            | no            | no        | 3,292     |
| no            | yes           | no        | 139       |
| no            | no            | yes       | 108       |
| yes           | no            | no        | 67        |
| yes           | yes           | no        | 33        |
| no            | yes           | yes       | 4         |
| yes           | no            | yes       | 2         |
| yes           | yes           | yes       | 0         |

Only 33 instances had two layers whose attack spans were each at most 50
milliseconds, and all 33 had exactly synchronous zero-millisecond layer spans
and separation. Of the 114 instances with at least 200 milliseconds of
separation, 108 had neither compact layer. The six with one compact layer had a
failing other-layer span from 853 through 2,813 milliseconds. The result is
therefore not clustered just outside either preregistered boundary.

The raw onset intervals overlapped in 3,513 instances. There were 109
upper-then-lower and 23 lower-then-upper nonoverlapping instances. The neutral
reason totals overlap because one instance may fail several conditions:

- 3,543 lower-layer spans exceeded 50 milliseconds;
- 3,469 upper-layer spans exceeded 50 milliseconds; and
- 3,531 between-layer gaps were below 200 milliseconds.

### Structural and pedal context

The candidate instances were dominated by pitch-class overlap:

| Shared pitch classes | Instances |
| -------------------- | --------- |
| 0                    | 59        |
| 1                    | 609       |
| 2                    | 1,628     |
| 3                    | 1,349     |

Thus 98.38% of instances shared at least one pitch class between their sounded
register layers. Separately, 3,564 instances, or 97.78%, contained at least one
note sounding only through sustain. All 59 pitch-class-disjoint instances
contained a sustained note; those instances occurred in 12 songs. These are
properties of candidate instances, not correctness labels.

The source-projection diagnostics matched the preregistration audit: 283,908
selected relevant messages became 276,420 replay events; 2,944 repeated
note-ons, 2,944 unmatched note-offs, 1,600 repeated pedal messages, and six
same-timestamp pedal reversals were counted. The selected channels' raw pedal
states disagreed for 17,506,054 milliseconds across 91 pieces. These values do
not enter candidate denominators.

**Plain-English reading.** The register rule proposed two-layer readings for
less than one percent of the time, in short bursts spread through most songs.
The strict onset rule supported none of them. This was not because many examples
barely missed its limits: compact attacks were synchronous, while attacks that
were clearly separated usually belonged to long rolled or accumulated note sets.
Nearly every proposal also involved shared pitch classes and pedal-held notes,
the exact conditions in which ordinary integrated harmony and pedal wash can
resemble two register layers.

This is a useful negative ablation result. It does not show that onset history
is irrelevant, that the register proposals are false, or that polychords never
occur in POP909. The corpus has no verified polychord labels, and the rule was
designed to add one-sided support rather than reject candidates.

**Decisions.** Preserve the zero-positive result unchanged. Do not loosen the
50- or 200-millisecond constants in response to it. A modest boundary adjustment
would not reach the observed misses, while a large adjustment would define a
different construct and require a separately named preregistration.

Keep `coherent-separated-onsets-50-200ms/1` as a conservative optional evidence
profile and as a synthetic regression control, not as an expected high-recall
corpus license. Do not use its zero output to remove simultaneous or
history-free polychord support from the product semantics.

Treat pedal and release history as the next temporal-evidence question. That
priority follows the result directly: 97.78% of candidate instances and every
pitch-class-disjoint instance involved a sustained note. The next step should
remain threshold-free and descriptive before any new gate is proposed.

**Next.** Group and locally inspect the 59 pitch-class-disjoint instances
without consulting POP909 labels, retaining their 12-song and event provenance.
Use that bounded audit to define which raw release, pedal, reattack, and
note-age fields a threshold-free evidence contract must expose. Commit that
contract before trying any categorical interpretation. Leave motion as the
following named increment and leave the 808-song clean reserve untouched.
