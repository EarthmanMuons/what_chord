# 2026-08-13: Implement and cross-check the Dart onset tracker

**Goal.** Add a pure-Dart state machine that derives the already-implemented
threshold-free onset evidence from normalized note and sustain-pedal events,
without coupling temporal history to the chord analyzer, application providers,
support thresholds, or automatic display policy. Compare every emitted frame
with the canonical Python replay and onset implementations.

**Setup.** Work began from clean repository commit
`d9f80ff862005118852fe8bfaab7511d59f6630b`. The implementation follows the note,
pedal, carried-in-state, event-order, and frame semantics fixed by
`polychord-frame-replay/1` and the onset-origin semantics fixed by
`polychord-onset-evidence/1`. The comparison surface is all 124 frames in all 9
fixtures pinned by `research/polychord/data/frame-replay/manifest.json`. The
repository was necessarily dirty because the Dart tracker and comparison harness
were the artifacts under test.

The exact final measurement command was:

```sh
python3 tool/polychord/onset_tracker_equivalence.py \
  --out build/polychord/onset-tracker-equivalence-v1.json
```

The first measurement invocation failed before processing its first fixture
because the managed Codex filesystem sandbox denied the Dart launcher access to
external Flutter engine-cache metadata under `/opt/homebrew`. The same command
was rerun with narrowly scoped approval. This was not a nono failure and did not
change the implementation, fixtures, or comparison method.

**What happened.** The package now exposes shared normalized temporal events for
note-on, note-off, and binary sustain-pedal transitions. The onset tracker
accepts those events atomically in nondecreasing timestamp order and emits an
immutable frame after every successful event. A frame combines the replay state
with each sounding note's current pressed-versus-sustained state and optional
note-on origin.

The tracker implements the frozen causal rules:

- note-on starts a new sounding instance and records its event index, timestamp,
  and velocity;
- note-off removes a pressed note while the pedal is up or moves it to sustained
  while the pedal is down without replacing its onset;
- note-on for a sustained note reattacks it and replaces the onset;
- pedal release clears sustained notes but preserves pressed notes and origins;
- carried-in notes have unknown origins rather than invented time-zero attacks;
- event order remains authoritative when timestamps tie; and
- invalid events do not mutate state or consume an event index.

Reset is an administrative stream boundary rather than a fabricated MIDI event.
It atomically clears history, may establish a new valid carried-in state, resets
the within-stream event index, and increments an explicit tracker epoch. The
epoch prevents equal MIDI-note and event-index pairs on opposite sides of a
reset from being mistaken for the same sounding instance. It is tracker
provenance and does not alter `polychord-onset-evidence/1` within an epoch. The
Python schemas do not contain this field; the equivalence harness asserts the
Dart wrapper's initial epoch is zero for every independently replayed fixture.

The public event types are independent of the onset frame so later release,
pedal, and transition trackers can consume the same normalized stream. The
tracker output feeds `PolychordOnsetEvidenceAnalyzer` directly; it does not
generate support labels, select candidates, or apply timing thresholds.

`onset_tracker_batch.dart` adapts one complete fixture event stream to Dart.
`onset_tracker_equivalence.py` validates the pinned manifest, combines Python's
canonical replay frames with its canonical per-note onset frames, and compares
decoded complete frame lists against Dart. Equality covers event indices and
timestamps, pedal state, pressed, sustained, and sounding note sets, note-state
labels, unknown carried-in origins, attack indices, attack times, attack
velocities, sustain preservation, and reattacks. It additionally checks the
Dart-only initial tracker epoch described above.

Preliminary runs before the shared-event API extraction and reset-epoch
correction each also reported zero mismatches. They were implementation checks,
not frozen results. The final epoch-aware run reported:

```text
124 frames across 9 fixtures; 0 mismatches -> build/polychord/onset-tracker-equivalence-v1.json
```

**Plain-English reading.** Given the same normalized performance events, the new
Dart library reconstructs exactly the same sounding notes, pedal state, and
known attack history as the established Python research model at every tested
event. This verifies the event-to-evidence plumbing. It does not show that onset
timing distinguishes polychords, choose a timing cutoff, or authorize an
automatic annotation.

**Decisions.** Retain the tracker as a pure-Dart temporal substrate separate
from application state management and the stateless chord analyzer. Retain reset
as an explicit epoch boundary rather than silently clearing state under an
ordinary MIDI event. Keep all onset interpretation, including the exploratory
50/200-millisecond rule, outside this tracker. Do not treat the zero-mismatch
result as musical accuracy.

Final SHA-256 pins:

- frame-replay schema:
  `93cbfe0cb77cb570d4c444438b8cde8df82c04e68e0667c134ba21cde10e85b8`;
- onset-evidence schema:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- fixture manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- unchanged Python replay implementation:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- unchanged Python onset implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- Dart onset model:
  `b58289a2c4dd0f307fa68430d5ad2ad9486660de27fe6168df3231e3126560b8`;
- Dart temporal-event model:
  `8c5bebcccd660b15fd28d0a3fe4ec3651c32c2e99d9e419e7bd0e039f94ddc0d`;
- Dart tracking-frame model:
  `9d57ad27de7be929f2b0a3efe71d5afdfa5375cdae79da0392d2db1966f61bdb`;
- Dart onset tracker:
  `d63b3d09c4a31fd2c7710ac3c4a7e0593e49726dd2d4f750e3301fbfad6e87f8`;
- Dart onset-evidence tests:
  `7f1802548b8b1e5e9f79ded5d0ccb0d682516b387e2c77629e7d84509086cdb8`;
- Dart tracker tests:
  `55674a1d16ef25a11859ba499f82ca36c2db88fa417a25cc88d2b304b4f2f4dd`;
- Dart batch adapter:
  `8d8491b8334ebf808312e7f76af40526a68ab8c5238bc63991da74a45814229c`;
- equivalence harness:
  `d212c6f6f452ba1672aa890b260718ff43a222e959737244d9d1cf04356a0932`;
- equivalence-harness tests:
  `1a1cac698a7eb2b9fffbacd258f15e360e90da9066aa9a175a0dccd1aad20028`; and
- generated ignored report:
  `7fb65b9ffb31d918feab7c11c66db002179dfce9f86f165135c74dec3db6412d`.

**Verification.** The implementation, harness, and record were checked with:

```sh
dart format .
dart run import_order_lint:import_order
flutter analyze
cd packages/whatchord
dart analyze
dart run import_order_lint:import_order
dart test
cd ../..
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  packages/whatchord/CHANGELOG.md \
  research/polychord/log/2026-08-13-02-dart-onset-tracker-equivalence.md
git diff --check
```

All 587 pure-Dart package tests and all 282 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** Promote the threshold-free release and pedal provenance layer into
pure Dart on top of the shared event model. Preserve release origin,
current-state origin, reattack history, prior sustained-instance release, and
pedal-transition provenance without adding stale-note thresholds, penalties,
support labels, or display decisions. Establish complete equivalence against the
canonical Python release/pedal frames before application integration.
