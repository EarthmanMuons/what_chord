# 2026-08-13: Implement and cross-check Dart onset support

**Goal.** Promote the already-frozen `coherent-separated-onsets-50-200ms/1`
interpretation into the pure-Dart library as a separately named diagnostic, then
compare the complete Dart output with the canonical Python implementation on
every pinned replay frame. Do not name onset as a licensing cue, select a new
timing profile, define a version-2 selector, or alter display policy.

**Setup.** Work began from clean repository commit
`53150a077dd66101962886494b326ca3a2c677e0`. The source contract was
`polychord-onset-support/1`, canonically implemented by
`tool/polychord/onset_support.py` under ablation ID
`coherent-separated-onsets-50-200ms/1`. Its immutable parameters remained a
50-millisecond maximum onset span within each layer and a 200-millisecond
minimum gap between the two layer intervals. The input substrate remained all
124 frames from the nine fixtures pinned by
`research/polychord/data/frame-replay/manifest.json`.

This port does not reverse the current source-coverage stopping rule. Logs
2026-08-12-02, 2026-08-12-06, and 2026-08-12-07 establish that no onset profile
has both a source-attested automatic-decision positive and the required matched
cue-positive ordinary integrated controls. The 50/200-millisecond profile
therefore remains a conservative construct probe and diagnostic, not an
automatic display license.

The exact final measurement command was:

```sh
python3 tool/polychord/onset_support_equivalence.py \
  --out build/polychord/onset-support-equivalence-v1.json
```

The first in-sandbox measurement attempt failed before its first fixture because
the managed Codex filesystem sandbox denied the Dart launcher access to Flutter
engine-cache metadata under `/opt/homebrew`. The same command was rerun with
narrowly scoped approval. This was not a nono failure and did not change the
code, data, or comparison method.

**What happened.** The package now exposes an immutable candidate-bound onset
interpretation and a stateless interpreter with the frozen ablation ID and
parameters. Complete histories receive exact booleans for each layer's
within-cohort span, an orientation-neutral interval order, the exact interval
gap, one-sided positive or neutral support, and ordered reason codes. Incomplete
history produces incomplete availability, null derived fields, neutral support,
and `onset-history-incomplete`; partial history is not interpreted.

The interpretation is symmetric in register order. Lower-then-upper and
upper-then-lower histories can both qualify. Touching or overlapping intervals
have gap zero. Exact 50- and 200-millisecond boundaries qualify, while 51- and
199-millisecond controls remain neutral for the corresponding reason. The
interpreter accepts every candidate evidence record independently and returns
all interpretations in candidate order. It contains no candidate selection,
licensing-cue registry, evidence aggregation, confidence, rejection, endpoint
policy, or display behavior.

The direct Dart suite covers fixed parameter identity, the positive layered
control, reverse layer order, inclusive and just-outside boundaries, synchronous
overlap, incomplete history, and multiple candidates without selection.

`onset_support_batch.dart` adapts complete sounding-note histories to the Dart
evidence analyzer and interpretation. `onset_support_equivalence.py` validates
the fixture manifest, independently replays Python onset history, derives raw
candidate evidence and interpretation with the canonical implementations, and
compares decoded complete records with Dart. Equality covers every raw onset
field and every categorical interpretation field. The final measurement
reported:

```text
124 frames and 18 candidate interpretations across 9 fixtures; 0 mismatches -> build/polychord/onset-support-equivalence-v1.json
```

All 18 fixture candidate interpretations have complete onset history. One is
positive and 17 are neutral. Incomplete-history behavior remains covered by
direct unit controls rather than this particular fixture candidate surface.

**Plain-English reading.** Dart and Python now apply the existing conservative
onset-timing experiment identically everywhere the pinned fixtures produce a
candidate. This makes the named diagnostic available in the pure-Dart library.
It does not establish that 200 milliseconds is the correct perceptual cutoff,
that a positive result identifies a true polychord, or that the app should show
one automatically.

**Decisions.** Keep onset interpretation in a separately named class rather than
folding thresholds into raw evidence or the analyzer. Keep positive and neutral
one-sided. Export the interpreter for research and later diagnostic composition,
but do not implement `polychord-output/2` cue aggregation or an automatic
selector until the standing source-coverage prerequisite is met. Preserve motion
endpoint selection as a separate unresolved decision.

Final SHA-256 pins:

- onset-evidence schema:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- onset-support contract:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`;
- fixture manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- unchanged Python replay implementation:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- unchanged Python register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- unchanged Python onset-evidence implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- unchanged Python onset-support implementation:
  `e5d74ecc2583cd60b6be155d56c9dbc5bc9e4bd3f3b107cbeda5a2285c996544`;
- unchanged Dart onset-evidence model:
  `b58289a2c4dd0f307fa68430d5ad2ad9486660de27fe6168df3231e3126560b8`;
- unchanged Dart onset-evidence analyzer:
  `c02a8028187e9aee36eabf313d78b261929d8f5ca98bcbdc8dcc8c2583d3cd27`;
- Dart onset-support model:
  `337102c8ee9b03a1e15baa6ba5c71f8af7bda07547d474ac7637220eddfe0359`;
- Dart onset-support interpreter:
  `7e3b4bea29418445ccf5ba63f5262a0f6154fd2a05d8ad032623dda1d15f7c82`;
- Dart public API:
  `b412745df7e4a7ba865231e2912713e1d5c3f8aa249794c24195bda22036a294`;
- Dart direct tests:
  `bdf6497d074f1d4a3f5ad7d0df11b98f643ef9e5cfa7dfacea9bd347232098d6`;
- Dart batch adapter:
  `1687dc9774decae45f48a50e7172f3089459e01d7e15836cc4b71e605a6912d6`;
- equivalence harness:
  `eb291bf884eaf9945ea1462237b29d7b0b10b25fe2693847c48b05228d98b32d`;
- equivalence-harness tests:
  `59e223cc59fd685fd0f7fc7916662f5d0294db3cc884e9aa8d61b6c42bcdcfb8`; and
- generated ignored report:
  `7652f7873885b52f8e142ab91cbf0c307f1dca0b7b27276ceba084ae4f313a53`.

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
  research/polychord/log/2026-08-13-05-dart-onset-support-equivalence.md
git diff --check
```

All 613 pure-Dart package tests and all 291 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** With the frozen onset, release/pedal, transition, and motion layers
now available in Dart, pause automatic selector and cue-aggregation work at the
existing source-evidence prerequisite. The next scientific step remains
admitting an event-complete source-attested automatic positive and matched
cue-positive ordinary integrated controls under one named profile. Further
implementation can proceed independently only where it does not choose a
licensing branch, motion endpoint policy, or product behavior.
