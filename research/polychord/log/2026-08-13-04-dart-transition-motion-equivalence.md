# 2026-08-13: Implement and cross-check Dart transition and motion evidence

**Goal.** Promote the frozen threshold-free frame-transition contract and its
separately named rigid-layer motion interpretation into the pure-Dart library.
Preserve complete caller-selected event windows, both unranked layer
correspondences, and one-sided motion support without inferring voices,
selecting endpoints, rejecting candidates, ranking candidates, or authorizing a
display. Compare complete Dart output with the canonical Python implementations
for every possible frame pair in the pinned replay fixtures.

**Setup.** Work began from clean repository commit
`80462bd7cf39f7350467f69413ce44141aaa9c08`. The source contracts were
`polychord-frame-transition-evidence/1`, canonically implemented by
`tool/polychord/transition_evidence.py`, and
`rigid-layers-oblique-or-contrary/1`, emitted as `polychord-motion-support/1` by
`tool/polychord/motion_support.py`. The event substrate remained the nine
fixtures in `research/polychord/data/frame-replay/manifest.json`, containing 124
frames. The repository was necessarily dirty because the Dart implementation and
equivalence tooling were the artifacts under test.

The exact final measurement command was:

```sh
python3 tool/polychord/transition_motion_equivalence.py \
  --out build/polychord/transition-motion-equivalence-v1.json
```

The first in-sandbox measurement attempt failed before its first fixture because
the managed Codex filesystem sandbox denied the Dart launcher access to Flutter
engine-cache metadata under `/opt/homebrew`. The same command was rerun with
narrowly scoped approval. This was not a nono failure and did not change code,
data, endpoint enumeration, or comparison method.

**What happened.** The package now exposes immutable models for exact sounding
instance identity, continuity, all four source-to-target layer relations, both
unranked layer-correspondence hypotheses, and candidate transitions. The Dart
analyzer independently generates every structural candidate at each endpoint and
reports the Cartesian product in generator order.

The public transition window requires at least one transition step, one tracker
epoch, consecutive event indices, and nondecreasing timestamps. Each step pairs
the normalized event with the complete tracker frame it produced. Its JSON form
matches the research replay schema's pressed, sustained, sounding, and pedal
state. The final step is necessarily the target frame. This preserves every
zero-dwell note-off, note-on, and pedal event between caller-selected endpoints
instead of reducing the input to two summaries. The constructor also replays
each paired event from the prior frame and requires exact frame equality, so a
same-time event cannot be paired with a different plausible-looking frame.

Sounding instances are keyed within a tracker epoch by MIDI note and onset event
index. Unknown carried-in onsets remain null. Reattack therefore produces one
departure and one arrival even when the MIDI number is unchanged. Retained
instances preserve exact source and target register membership and
pressed-versus-sustained state. Departed and arrived notes are never joined into
inferred voices. Every layer relation retains the complete target-minus-source
pitch matrix rather than choosing a note pairing.

The separately exported motion interpreter implements only the fixed
`rigid-layers-oblique-or-contrary/1` policy. For each correspondence it checks
exact whole-set translation and chord-identity consistency, independently
classifies static, common translation, oblique, contrary, or unequal
same-direction motion, and emits positive support only for oblique or contrary
motion. Retained instances contradicting a correspondence force neutral support.
Neutral is not negative evidence. The interpreter does not select between its
two correspondence outputs.

Direct Dart controls freeze complete inner-motion provenance, zero-elapsed
windows, incomplete-window rejection, same-note reattack identity, contrary
positive support, contradictory retained-instance neutrality, every exact
between-layer motion class, and the immutable ablation parameters.

The equivalence harness validates the pinned manifest and enumerates every
ordered source-target frame pair within each fixture. Python independently
derives complete windows, endpoint candidates, candidate-transition records, and
both motion interpretations. A persistent Dart adapter replays each fixture
once, constructs the same 930 windows, and returns decoded JSON for exact
field-for-field equality. The final measurement reported:

```text
930 frame windows, 48 candidate transitions, and 96 hypothesis interpretations across 9 fixtures; 0 mismatches -> build/polychord/transition-motion-equivalence-v1.json
```

Those windows contain 5,830 compared transition steps. Of the 930 windows, 280
have zero elapsed milliseconds and are still compared because event-array order
is authoritative. Only 48 endpoint pairs have candidates at both ends in the
current fixtures; each supplies two independently compared correspondence
interpretations.

**Plain-English reading.** For every earlier-to-later frame pair in the current
fixtures, Dart and Python preserve the same complete sequence of events between
the endpoints and describe every possible structural transition identically.
They also agree exactly about whether either explicit layer mapping exhibits the
strict rigid-motion pattern. This establishes implementation equivalence. It
does not establish which frame pair an application should compare, whether the
motion pattern is perceptually decisive, or whether a polychord should be shown.

**Decisions.** Keep the complete transition window in the public Dart evidence
object rather than treating intermediate events as harness-only provenance. Keep
transition facts separate from motion interpretation. Preserve both
correspondences without a selected hypothesis. Keep the fixed motion profile
threshold-free and one-sided: positive can support later policy, while every
other result remains neutral. Do not add voice assignment, endpoint lookback,
dwell, ranking, rejection, confidence, or display behavior in this layer.

Final SHA-256 pins:

- frame-replay schema:
  `93cbfe0cb77cb570d4c444438b8cde8df82c04e68e0667c134ba21cde10e85b8`;
- frame-transition schema:
  `7db90bb1a40fc0a34be5a1ab84da0724ae2da1db0dd8529b81e2d31970eccc78`;
- motion-support contract:
  `50886b62cf5e361148af3b05fd015f0e75a54eb5f4a36fac4ac690f07d57e083`;
- fixture manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- unchanged Python replay implementation:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- unchanged Python register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- unchanged Python release/pedal implementation:
  `b4401dad62e26a3f76609e631387362cce12c6e7907cf1f1ff32ad681a40fcc2`;
- unchanged Python transition implementation:
  `6a843a87ed7e8b9223f480495d6237318944b6d36510dc6e939bc59a23c0fa84`;
- unchanged Python motion implementation:
  `89cb372cb8f3055779624d4d4870c08381d5da65c24531fde5de1791152c61cf`;
- Dart transition model:
  `f04091a08ea2cb335d8fccb676b893c92b31c3ec800178a28adeeb2b46aa46d8`;
- Dart motion model:
  `e710eacb5485659ddcc1dfcac94eb3b085dbc44b2cd7b69ab0d5a1d5df1268c9`;
- Dart transition analyzer:
  `8f66780af9660060e54d9a56ec0df159fb823dd18f87181beb2d85fc16140a95`;
- Dart motion interpreter:
  `582a31e504326a0b861af8d41f949324b906b9a723fae28744510a9b5339b8f5`;
- Dart public API:
  `3af8d50d9dc15338478f03e793e044d113bb60bef7d281cb6709fd3abcdf281a`;
- Dart direct tests:
  `defbd1fe624839ec8ef85c30720132f227cefbfb33527fcb4f51b92847521782`;
- Dart batch adapter:
  `9d975958724840ab95dba80bf4133b27283ca723cfa6b8f1c374ddf270e2b936`;
- equivalence harness:
  `70a6a76a27d5cee17612e082cd482130c67215360d75eba3488e8e590e60d66d`;
- equivalence-harness tests:
  `b4751153f5fcbe164a088d52975b6da8778ec622fd009d685a7d40259898e1c4`; and
- generated ignored report:
  `34a0fb1c770c701ec084ca74513d284e70ef25dd30b20c5f2c8f156b6669301a`.

**Verification.** The final implementation, harness, and record were checked
with:

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
  research/polychord/log/2026-08-13-04-dart-transition-motion-equivalence.md
git diff --check
```

All 606 pure-Dart package tests and all 288 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** Define and preregister the application-facing endpoint-selection and
evidence-combination policy. That step must explicitly consume the now-verified
onset, release/pedal, and motion signals while preserving neutral or unevaluable
states. Keep it separate from chord ranking and display stability until its
development-corpus exposure has been measured.
