# POP909 product held exposure v2

Status: prospectively frozen final false-display safety measurement for release
candidate `polychord-output/3`. This supersedes the unexecuted v1 contract after
the app adopted MIDI All Sound Off (CC120) as a temporal reset. The POP909 held
reserve remained unopened. This is the single authorized opening of the 808 IDs
in the `held` roster field; it is not an accuracy or recall test.

## Candidate and stopping boundary

Run only from the first clean commit containing this contract, its harness, the
passing benchmark-v2 result, and the accepted iPhone and Android product and
accessibility checks. Product behavior is the candidate at app commit
`1a1cb852c990c436438ba82120b7a295d006bf0b`; the following commit may contain
only this measurement correction and its research record.

Run the held pool once. If any stable display is out of scope, the release
candidate fails and this pool becomes development evidence. Do not tune and
rerun it as held. An in-scope display is allowed but must be dispositioned; the
gate is zero out-of-scope stable displays, not zero total displays.

## Frozen source and projection

- POP909 checkout commit: `d83e6edba6872a704f5d3b8b32f5cb540088dae6`.
- Roster: `research/performed-input/data/pop909-held-pool.json`, SHA-256
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`.
- Exactly 808 unique held IDs and 101 unique sample IDs with no overlap. The
  harness has no sample/development selection flag.
- Original `<song>/<song>.mid` files only.
- Include named tracks `BRIDGE` and `PIANO`, exclude `MELODY`, then discard
  channel identity. Preserve the development parser's deterministic merged
  order, track checks, note/pedal state, repeated-message rules, and frame
  projection.
- Parse note-on, note-off, sustain CC64, All Sound Off CC120, and All Notes Off
  CC123. Before shared normalization, map CC120 to the same empty reset as CC123,
  matching `MidiConstants.endsAllNotes` and the app temporal provider at commit
  `1a1cb852c`. Preserve pedal state across either reset.
- Record the number of mapped CC120 messages. Do not read or supply chord labels.

This CC120 mapping is the only methodological change from unexecuted v1. The v1
contract and its prospective log remain unchanged as provenance.

## Frozen product replay

`tool/polychord/held_exposure_batch.dart` executes the package
`PolychordProductEngine`. For each piece it:

1. starts with empty input and unavailable primary output;
2. processes a matured display timer before the next later source event;
3. applies every normalized note, pedal, or reset event and verifies the
   engine's state against the independently normalized frame;
4. computes unchanged `ChordAnalyzer` primary availability and applies its
   transition at the same timestamp;
5. closes a timer that matures by MIDI end, then resets the engine; and
6. counts every action while retaining every candidate-bearing, selected,
   authorized, pending, visible, or transitioning observation and stable display
   episode.

Primary availability uses C-major/solo for replay. Every displayed frame must
also have invariant availability across all 24 major/minor keys and solo and
ensemble contexts; otherwise the batch fails closed.

The harness writes immutable, manifest-hashed piece reports and an aggregate
summary under a new child of `build/`. Its initial `review.json` is retained as a
hashed adjudication template and may change only in `disposition` and
`musicalRationale`. The verifier reconstructs every other review field from the
immutable reports.

## Integrity and interpretation

Before reading counts, require:

- clean WhatChord and POP909 checkouts at their pinned commits;
- 808 unique held inputs, zero sample inputs, and zero supplied labels;
- matching schema, measurement ID, source-event accounting, piece index, output
  inventory, and recorded SHA-256 values;
- exact reconstruction of aggregate counts, displayed time, review coverage,
  and the initial adjudication template; and
- no primary-context availability warning.

`tool/polychord/held_exposure_verify.py` audits the retained result without
rerunning analysis. If stable episodes exist, review every item using the frozen
product semantics and rerun with `--require-pass`. That mode fails on incomplete
review or any disposition other than `in-scope-polychord`. It passes an empty
review set when no stable episode exists.

Retain the result regardless of pass or failure. Report exposure and
false-display safety only; POP909 has no verified positive polychord labels and
cannot measure recall.

## Registered commands

From the clean v2 release-candidate commit:

```sh
./.venv/bin/python tool/polychord/held_exposure.py \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory build/polychord/product-held-exposure-v2

./.venv/bin/python tool/polychord/held_exposure_verify.py \
  --result-directory build/polychord/product-held-exposure-v2 \
  --require-pass
```

The output directory must not exist before the run and must never be
overwritten.
