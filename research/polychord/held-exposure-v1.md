# POP909 product held exposure v1

Status: prospectively frozen final false-display safety measurement for release
candidate `polychord-output/3`. This is the single authorized opening of the 808
song IDs in the `held` field of the pinned POP909 roster. It is not an accuracy
test, a supervised test split, or evidence about missed polychords.

## Candidate and stopping boundary

Run only from the first clean commit containing this contract, the held harness,
the passing benchmark-v2 result, and the recorded iPhone and Android product and
accessibility acceptance. The product implementation is otherwise the exact
candidate at app commit `609d06e7f`. No selector, cue, vocabulary, threshold,
display rule, presentation behavior, or primary analyzer behavior may change
after the held result is read.

Run the held pool once. If any stable display is out of scope, the release
candidate fails and this 808-song pool becomes development evidence. Do not tune
and rerun on the same pool as though it remained held. An in-scope display is
allowed but must be dispositioned; the gate is zero out-of-scope stable
displays, not zero total displays.

## Frozen source and projection

- POP909 checkout commit: `d83e6edba6872a704f5d3b8b32f5cb540088dae6`.
- Roster: `research/performed-input/data/pop909-held-pool.json`, SHA-256
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`.
- Exactly 808 unique IDs from `held`; exactly 101 unique IDs from `sample`; no
  overlap. The harness has no sample/development selection flag.
- Original `<song>/<song>.mid` files only.
- Frozen named-track projection: include `BRIDGE` and `PIANO`, exclude `MELODY`,
  then discard channel identity. Track order and one-channel-per-track checks
  remain identical to development exposure.
- Parse note-on, note-off, sustain CC64, all-notes-off CC123, and all-sound-off
  CC120 with Mido's deterministic merged order. Normalize through the same
  pressed, sustained, pedal, repeated-message, and observable-frame rules as
  `tool/polychord/development_exposure.py`.
- Do not read or supply corpus chord labels.

## Frozen product replay

`tool/polychord/held_exposure_batch.dart` executes the package
`PolychordProductEngine`, not the superseded register-only exposure selector.
For each piece it:

1. starts from empty input and unavailable primary output;
2. inserts a pending display timer before the next source event whenever the
   frozen deadline matures first;
3. applies each normalized note, pedal, or reset event and verifies the engine's
   sounding state against the independently normalized frame;
4. computes primary availability with the unchanged `ChordAnalyzer` and applies
   an availability transition at the same timestamp when needed;
5. closes any matured timer at MIDI end, then resets the engine; and
6. counts every product action and retains every complete observation that has a
   structural candidate, selection, authorization, pending or visible state, or
   display transition, plus every stable display episode.

The primary availability check uses the existing C-major/solo audit context.
Every displayed frame must also have invariant availability across all 24 major
and minor keys and both solo and ensemble playing contexts; the batch fails
closed if it does not.

The replay retains aggregate source-event and action counts plus complete
candidate-bearing, selected, authorized, pending, visible, and transition
observations. Those records preserve transition, duration, primary,
pressed/sustained, and exact assignment evidence for every potentially relevant
held fire without retaining millions of repetitive zero-candidate maps. The
harness writes one detailed piece report plus aggregate summary, review index,
provenance manifest, source hashes, contract hashes, runtime versions, and a
complete output inventory under a new child of `build/`.

The immutable piece reports and summary are content-hashed in the manifest. The
initial `review.json` is separately retained as a hashed adjudication template,
then may change only in its `disposition` and `musicalRationale` fields. The
verifier reconstructs every other review field from the immutable reports, so
completing a required review neither invalidates the measurement nor permits its
evidence to drift.

## Integrity and interpretation

Before reading counts, require:

- clean WhatChord and POP909 checkouts at their pinned commits;
- 808 unique held inputs, zero sample inputs, and zero supplied labels;
- matching schema, measurement ID, source-event accounting, piece index, output
  inventory, and every recorded SHA-256;
- exact reconstruction of aggregate counts, displayed time, and review coverage
  from all 808 piece reports; and
- no primary-context availability warning.

`tool/polychord/held_exposure_verify.py` performs the output and aggregation
audit without rerunning analysis. If stable episodes exist, review every item
using the frozen product semantics, fill `disposition` and `musicalRationale`,
and rerun the verifier with `--require-pass`. That mode fails on incomplete
review or any disposition other than `in-scope-polychord`. If no stable episode
exists, `--require-pass` passes with an empty review set.

Retain the summary, review, manifest, and sufficient machine output or hashes in
a new append-only result record regardless of pass or failure. Report exposure
and false-display safety only; POP909 provides no verified positive polychord
labels and cannot measure recall.

## Registered commands

From the clean release-candidate commit:

```sh
./.venv/bin/python tool/polychord/held_exposure.py \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory build/polychord/product-held-exposure-v1

./.venv/bin/python tool/polychord/held_exposure_verify.py \
  --result-directory build/polychord/product-held-exposure-v1 \
  --require-pass
```

The output directory must not exist before the run and must never be
overwritten.
