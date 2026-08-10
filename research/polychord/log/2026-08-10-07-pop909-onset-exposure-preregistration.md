# 2026-08-10: Preregister the POP909 onset-exposure census

**Goal.** Fix the corpus boundary, MIDI normalization, denominators, evidence
trail, and executable profile for the first raw-event onset-exposure measurement
before observing its candidate or onset-support outcomes.

**Setup.** The base repository commit was `54c94542`. The source checkout was
POP909 commit `d83e6edba6872a704f5d3b8b32f5cb540088dae6` with a clean worktree.
The frozen roster was `performed-input-held-pool/1`: its previously exposed
`sample` field contains 101 song identifiers, its evaluation-virgin `held` field
contains 808, and the fields do not overlap. The measurement tool exposes only
the sample field; it has no roster-path or held-roster selector and hard-pins
the committed roster's SHA-256 digest.

The 808 songs remain a clean reserve rather than a declared final test set. The
101-song sample supplies about 7.0 hours and 276,420 normalized event frames for
this label-free descriptive census. If POP909 later gains a labeled or formal
corroboration role, an appropriate development and final-test allocation may be
frozen from the reserve before any outcome-dependent tuning; this measurement
does not prejudge that ratio.

The corpus projection follows Wang et al.,
["POP909: A Pop-song Dataset for Music Arrangement Generation"](https://archives.ismir.net/ismir2020/paper/000089.pdf),
ISMIR 2020. The paper defines `MELODY` as the lead vocal transcription and the
combination of `BRIDGE` and `PIANO` as the piano accompaniment arrangement. The
measurement therefore selects the named `BRIDGE` and `PIANO` tracks and excludes
`MELODY`. All 101 files passed the exact named-track and disjoint-channel layout
check.

The adapter preflight used Python 3.12.13 and Mido 1.3.3. It read only the raw
MIDI files and roster. It did not read POP909 chord, key, beat, audio-alignment,
or version files. It invoked MIDI reading and normalization but did not invoke
the register generator, onset evidence, onset-support interpretation, or any
current chord analyzer. The candidate and support outcomes therefore remained
unobserved.

The exact commands were:

```sh
./.venv/bin/python -c 'import collections, json, sys; sys.path.insert(0, "tool/polychord"); import onset_exposure_census as c; totals = collections.Counter(); songs = c.load_frozen_sample_song_ids(); [(lambda raw_end, song: (totals.update(c.normalize_messages(song, raw_end[0], raw_end[1])[1]), totals.update({"selectedRelevantMessages": raw_end[2]["selectedRelevantMessages"], "excludedRelevantMessages": raw_end[2]["excludedRelevantMessages"], "channelPedalDisagreementMs": raw_end[2]["channelPedalDisagreementMs"], "songsWithChannelPedalDisagreement": bool(raw_end[2]["channelPedalDisagreementMs"]), "songsWithPedalOnBothSelectedChannels": all(raw_end[2]["selectedPedalMessagesByChannel"].values())})))(c.read_midi_messages(c.DEFAULT_POP909_ROOT / song / f"{song}.mid"), song) for song in songs]; totals["sampleSongs"] = len(songs); print(json.dumps(dict(sorted(totals.items())), indent=2))'
./.venv/bin/python tool/polychord/onset_exposure_census.py --help
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/onset-exposure-census.md \
  research/polychord/log/2026-08-10-07-pop909-onset-exposure-preregistration.md
shasum -a 256 \
  research/polychord/PROTOCOL.md \
  research/polychord/onset-exposure-census.md \
  tool/polychord/onset_exposure_census.py \
  tool/polychord/onset_exposure_census_test.py \
  research/performed-input/data/pop909-held-pool.json \
  research/polychord/frame-replay-schema.md \
  tool/polychord/frame_replay.py \
  research/polychord/register-candidate-schema.md \
  tool/polychord/register_candidates.py \
  research/polychord/onset-evidence-schema.md \
  tool/polychord/onset_evidence.py \
  research/polychord/onset-support-ablation.md \
  tool/polychord/onset_support.py
git diff --check
```

The preregistered corpus command was deliberately not run in this session. It
must run only after this entry, contract, implementation, and tests are
committed together.

**What happened.** The committed WhatKey-derived POP909 snapshot fixtures were
rejected for this measurement because they retain committed chord-identity
states, not the attack, release, sustain, and same-timestamp event history
required to evaluate onset evidence.

The first adapter draft merged all three tracks, preserved cross-channel pitch
multiplicity, and treated sustain as global. An input-only audit caught two
problems before any candidate code ran. First, the paper defines `MELODY` as a
separate vocal transcription rather than part of the accompaniment. Second, the
mixed multiplicity policy preserved channel ownership for notes but not for
pedal, so it represented neither source-channel playback nor WhatChord's
channel-blind input. That draft was discarded before preregistration. Its
354,672 relevant-message and 324,548 normalized-event capability counts are not
a measurement result and are not comparable to the fixed profile below.

The corrected adapter selects `BRIDGE` plus `PIANO`, merges their messages in
source order, then discards channel identity and maps them to the exact
`polychord-frame-replay/1` event surface. This matches WhatChord's observable
one-pitch-set and one-global-pedal state. It deliberately does not claim to
reconstruct channel-scoped MIDI playback.

The input-only audit reported:

```json
{
  "channelPedalDisagreementMs": 17506054,
  "excludedRelevantMessages": 70764,
  "normalizedEvents": 276420,
  "rawRelevantMessages": 283908,
  "repeatedNoteOnMessages": 2944,
  "repeatedPedalMessages": 1600,
  "sameTimestampPedalReversals": 6,
  "sampleSongs": 101,
  "selectedRelevantMessages": 283908,
  "songsWithChannelPedalDisagreement": 91,
  "songsWithPedalOnBothSelectedChannels": 21,
  "unmatchedNoteOffMessages": 2944
}
```

No selected file contained an all-sound-off or all-notes-off controller that
would force an out-of-contract reset decision. The raw channel-specific pedal
states disagree for about 4.86 hours across 91 songs, including 21 songs with
pedal messages on both selected channels. That is why the report retains this
diagnostic and identifies its result as channel-blind app exposure rather than
source-channel playback. Six opposing pedal transitions share a timestamp;
merged event order remains authoritative and their intermediate frames have zero
dwell.

Repeated pedal states, repeated note-ons for an already pressed pitch, and
releases for a pitch not in the app's pressed set are omitted and counted. A
repeated attack does not replace its pitch's onset, which is a declared
conservative choice for onset support. The matched 2,944 repeat and release
counts make cross-track pitch collisions visible without adding channel
ownership to an app-input condition that does not possess it.

The fixed measurement identity is
`pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1`, with
report schema `polychord-onset-exposure-census/1`. It applies, in order, exact
frame replay, the symmetric complete-common register generator, threshold-free
onset evidence, and `coherent-separated-onsets-50-200ms/1`. The CLI exposes
paths for the POP909 checkout and local output only; the roster is hard-pinned.
It exposes no layer, register-gap, onset-threshold, shared-tone, roster-field,
analyzer, or display policy flag.

The report keeps three denominators separate:

- event frames, including same-timestamp intermediate and zero-dwell frames;
- sounding dwell time, for which zero-dwell frames contribute no duration; and
- candidate instances, including multiple register splits on one frame.

It retains every candidate-bearing frame with its observation, split, raw onset
evidence, and interpretation, plus the same counts per piece and a top-20
positive-support concentration view. The detailed report contains exact
corpus-derived event frames, so the tool requires output under `build/`; only
aggregates and cryptographic pins may enter a later log.

Sixteen new tests cover sample-only roster access, the frozen roster pin,
invalid overlap, exact track selection and rejection, MIDI event mapping,
sustain and reattack behavior, channel collapse, pedal-order visibility, no-op
accounting, unsupported resets, distinct support-time controls, zero-dwell
exposure, exact raw and interpreted evidence, separate denominator shares,
projection aggregation, contract pins, and the output-location guard. All 96
polychord Python tests passed, and formatting, lint, and diff checks passed.

Pinned SHA-256 digests:

- protocol: `21b7c37d691e35d2808d420c80d427074c02db6a9cf38ef88adbefafc605beb2`;
- census contract:
  `9d9ca59b06e610615adca3dbbadc8df16448113a924f9e08236876e0a8a87a0b`;
- census implementation:
  `e8a141fa84234f02aacbd5adc06fd2a3f45b4d2bc9f7d275a3a070f04720fba4`;
- census tests:
  `341b0e31a71960945c0711ffa6c3365b0ed7d42a62f362f1bbaae87da511f294`;
- frozen roster:
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`;
- frame-replay contract:
  `58f6c5cbc99c6e4ee7476e12f247f1ee0e526b3aee7bd5f595e8f712a0f0a1fa`;
- frame-replay implementation:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- register-candidate contract:
  `533c20205d07e14291029af3455c366e0605d1a5c4b96311be85879069f22538`;
- register-candidate implementation:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- onset-evidence contract:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- onset-evidence implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- onset-support contract:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`; and
- onset-support implementation:
  `e5d74ecc2583cd60b6be155d56c9dbc5bc9e4bd3f3b107cbeda5a2285c996544`.

**Plain-English reading.** The 101-song sample's accompaniment can be translated
into the same event language as the app without an unsupported MIDI-control
case. The MIDI files keep track-specific pedal information that the app does not
keep, so the report makes that loss measurable instead of pretending it is
musically neutral. None of this tells us whether the proposed polychord splits
are good, frequent, or displayable. It only establishes that the next
measurement has a declared and auditable input path before its answers are seen.

**Decisions.** Use the paper-defined `BRIDGE` plus `PIANO` accompaniment from
raw POP909 MIDI for this temporal exposure measurement while preserving the
previously exposed sample and untouched held roster. Match WhatChord's
channel-blind pitch-set and global-pedal observation after selecting those
tracks; expose per-channel pedal disagreement as a limitation rather than mixing
source-channel and app-input semantics. Freeze that normalization policy and the
three denominators before observing candidate results. Treat same-timestamp
intermediate states as event exposure but not duration exposure. Keep the
complete detailed report local under `build/`.

Treat the 808-song `held` field as a clean split reservoir, not an already fixed
89% final test set. Do not expand development merely to approximate a
conventional ratio when this corpus supplies no verified target labels and the
current measurement performs no fitting.

Describe the next result as label-free proposal and onset-support exposure, not
accuracy, perception, intent, confidence, stable-display behavior, or product
safety. Do not tune the fixed profile in response to it. Any alternate timing or
generator profile requires a separately named comparison.

**Next.** After this preregistration is committed, run exactly:

```sh
./.venv/bin/python tool/polychord/onset_exposure_census.py \
  --out build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
```

Verify the report's clean-worktree, corpus, roster, runtime, contract, and
content hashes before reading the aggregate outcomes. Then record the complete
aggregate and per-piece concentration findings in a new dated measurement log
without changing the preregistered profile. Do not inspect the 808-song held
pool.
