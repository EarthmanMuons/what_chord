# POP909 product held exposure v3

Status: prospectively frozen completion run after the v2 held exposure aborted
for a technical replay mismatch on its second song. This is not a pristine new
held test: v2 already produced a zero-display report for song 002 and exposed an
unmatched note-off condition in song 003. No selector, threshold, product engine,
or musical output was changed in response.

## Candidate and deviation boundary

Product behavior remains frozen at app commit
`1a1cb852c990c436438ba82120b7a295d006bf0b`. The following commits may contain
only the app-equivalent replay correction, this contract, and the retained v2
failure record. V3 reruns all 808 pieces to produce one internally consistent
result; interpret it as a post-abort reserve completion with the disclosed
one-piece negative exposure, not as an untouched held estimate.

Any out-of-scope stable display fails the release candidate. In-scope displays
are permitted but must be dispositioned. Do not tune and rerun v3.

## Frozen source and projection

- POP909 commit: `d83e6edba6872a704f5d3b8b32f5cb540088dae6`.
- Roster SHA-256:
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`.
- Exactly 808 held IDs and 101 sample IDs with no overlap; the harness exposes
  no sample/development switch and supplies no labels.
- Use original `<song>/<song>.mid` files. Include `BRIDGE` and `PIANO`, exclude
  `MELODY`, discard channel identity, and preserve the frozen Mido merged order
  and track checks from `development_exposure.py`.

## App-equivalent normalization correction

V2 reused the historical development state normalizer. Under sustain, that
normalizer can turn an unmatched note-off into a new sustained note and emit it;
the live `midiTemporalEventsProvider` instead ignores any note-off whose note is
not currently pressed. The strict product tracker correctly rejected the v2
event before a result for song 003 was returned.

V3 owns the event-state projection after the unchanged source parser and mirrors
the app provider:

- ignore a note-on for an already pressed note;
- ignore a note-off for a note that is not pressed;
- on a valid note-off, move the note to sustained only while pedal is down;
- emit pedal events only when pedal state changes and clear sustained notes on
  release;
- emit an empty reset for every CC120 or CC123, clearing pressed and sustained
  notes while preserving pedal state; and
- retain exact counts for every filtered repeat, unmatched release, reset type,
  raw relevant message, and normalized event.

This corrects replay fidelity only. It does not inspect chord output or change
musical policy.

## Frozen product replay and integrity

All other mechanics remain those of v2: the actual `PolychordProductEngine`,
matured timers before later events, same-timestamp primary availability,
C-major/solo replay plus 48-context availability audit at every appearance,
complete relevant diagnostic retention, stable-episode review, per-piece
reports, aggregate reconstruction, source and output hashes, and a mutable-only
disposition/rationale review file checked against immutable evidence.

The gate is zero out-of-scope stable displays. If episodes exist, adjudicate all
of them and run the verifier with `--require-pass`; an empty episode set passes.
Report only exposure and false-display safety, never recall or generalized
accuracy.

Preserve the partial v2 directory unchanged. V3 writes to a new directory and
must be retained regardless of pass or failure.

## Registered commands

From the first clean commit containing v3:

```sh
./.venv/bin/python tool/polychord/held_exposure.py \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory build/polychord/product-held-exposure-v3

./.venv/bin/python tool/polychord/held_exposure_verify.py \
  --result-directory build/polychord/product-held-exposure-v3 \
  --require-pass
```

The v3 output directory must not exist before the run and must never be
overwritten.
