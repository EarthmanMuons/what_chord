# 2026-08-12: Automatic timing sensitivity failed attempt

**Goal.** Run the preregistered automatic timing-sensitivity measurement from
the clean implementation commit, and preserve any pre-result failure rather than
repairing the harness and silently retrying.

**Setup.** The implementation was committed as
`ad56d12f0ee121d75827ea0db69adbadc1ddcd8e`. The exact source URL already
recorded in log 2026-08-12-02 was fetched to the registered local path. It was
130,151 bytes and reproduced the required SHA-256
`e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05`.

The registered command was invoked once:

```sh
./.venv/bin/python tool/polychord/automatic_timing_sensitivity.py \
  --onset-report \
  build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json \
  --liszt-midi tmp/pdfs/liszt-malediction.mid \
  --out build/polychord/automatic-timing-sensitivity-v1.json
```

**What happened.** The run aborted before writing the output file. It raised:

```text
ValueError: fixture.events[1672] releases note 52, which is not pressed
```

No sensitivity row, aggregate, or report was produced. The exception occurred
while adapting the complete Liszt normalization into the stricter frame-replay
fixture, after the fixed input hashes and POP909 evidence had been validated but
before the source case or expected-outcome assertions completed.

The unchanged development normalizer intentionally models WhatChord's
channel-blind, distinct-note input. The Liszt sequence has duplicate messages
from tracks sharing channel 0. At 62,046 milliseconds, a pedal-up event cleared
sustained pitches, the pedal immediately returned down, and later duplicate
note-off messages for pitches 52, 55, and 64 arrived while those pitches were no
longer pressed. Under the development normalizer, an unmatched note-off while
the pedal is down adds that pitch to the sustained set. That mirrors the
previously used live-input approximation, but the strict reusable fixture
grammar correctly rejects a note-off without a pressed note.

The exact registered target occurs much earlier. Searching the complete
normalized stream through the unchanged register generator reproduced its ten
serialized frames at event indices 842 through 846 and 872 through 876. Only
events 842 and 872 have positive dwell, at the already disclosed timestamps and
durations. The incompatible event occurs at index 1672 and is therefore outside
the causal onset-history prefix needed for every exact target frame.

**Plain-English reading.** The measurement did not fail because one timing
threshold performed differently. It failed because the implementation tried to
force an unrelated, later duplicate release into a stricter event format than
the source normalizer promises. We learned nothing new about which timing value
is preferable, and there is no partial result to interpret.

**Decisions.** Preserve this as a failed measurement attempt. Keep the unchanged
development normalization and search the complete normalized source for the
exact registered target assignment. After the final target is known, replay
onset evidence through the strict fixture only from the start of the file
through that final relevant event. Do not skip any event inside that prefix, do
not synthesize onset records, and continue deriving each target frame's dwell
from the complete normalized stream. Report both the final strict-replay event
index and the number of later excluded events.

The correction also makes the preregistration's opportunity unit explicit:
same-timestamp serialization frames remain visible candidate instances, while
the expected two Liszt opportunities are the two independently tracked
positive-duration authorization episodes.

The corrected implementation and test pins are:

- `tool/polychord/automatic_timing_sensitivity.py`:
  `9e0600ada3ad703f8a77c7d5cc4866a7e66cc051a1d23fa798bbc38a99a0b870`; and
- `tool/polychord/automatic_timing_sensitivity_test.py`:
  `716f6f56febc1a4482a4f48d22f37aca635ef4fb8e34f1dfce36cdad4c7d7c8e`.

The regression test reconstructs the same contract mismatch: complete strict
adaptation rejects the unmatched release, while a prefix ending before it
replays and validates exactly. Python formatting and lint passed, and the full
polychord Python suite passed 276 tests:

```sh
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover -s tool/polychord -p '*_test.py'
```

**Next.** Commit this failed-attempt record and correction as its own provenance
boundary. Then rerun the exact registered command from that clean commit and
record its result separately, whether it succeeds or exposes another failure. Do
not inspect the held POP909 reserve or alter any timing profile.
