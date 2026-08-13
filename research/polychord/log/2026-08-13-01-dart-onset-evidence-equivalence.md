# 2026-08-13: Implement and cross-check the Dart onset evidence layer

**Goal.** Promote the already-fixed threshold-free onset evidence contract into
the pure-Dart package, without importing the exploratory 50/200-millisecond
support rule or making an automatic display decision, then compare the complete
Dart records with the canonical Python implementation on every pinned temporal
fixture frame.

**Setup.** Work began from repository commit
`0c9916f99a9e3adf0b2ad1e9625af1eaa6ef776e`. The implementation follows
`polychord-onset-evidence/1` in `onset-evidence-schema.md` and uses the existing
`polychord-register-candidates/1` Dart generator. The comparison surface is all
124 frames in all 9 fixtures pinned by
`research/polychord/data/frame-replay/manifest.json`, including frames with no
structural candidate. The repository was necessarily dirty because the Dart
implementation and comparison harness were the artifacts under test.

The exact successful measurement command was:

```sh
python3 tool/polychord/onset_evidence_equivalence.py \
  --out build/polychord/onset-evidence-equivalence-v1.json
```

The first invocation failed before processing its first frame because the
managed Codex filesystem sandbox denied the Dart launcher permission to refresh
external Flutter engine-cache metadata under `/opt/homebrew`. The same command
was rerun with narrowly scoped approval. This was not a nono failure and did not
change the source, fixtures, or comparison method.

**What happened.** The package now exposes immutable models for sounding-note
state, optional note-on origin, layer summaries, and candidate-bound onset
evidence. The analyzer consumes a complete sorted sounding-note observation,
reuses the existing symmetric register generator, and derives all counts, spans,
and signed interval relations from per-note facts. It validates MIDI, velocity,
event-order, event-identity, and exact generated-candidate invariants.

No support category or threshold appears in the package API. Synchronous,
separated, and reverse-order attack histories remain signed raw observations. A
carried-in note has a null origin, and the candidate-level relations remain null
unless every assigned note has known provenance. Pressed versus pedal-sustained
state is retained but not interpreted.

`onset_evidence_batch.dart` adapts JSON-lines requests to the Dart analyzer.
`onset_evidence_equivalence.py` validates the pinned manifest, independently
replays the Python onset state, sends every frame to Dart, and compares decoded
complete candidate-evidence lists. Equality therefore covers candidate order,
exact note assignments, shared pitch classes, sounding state, origin event and
velocity, unknown onsets, layer counts and spans, and both signed relations.

The successful run reported:

```text
124 frames and 18 candidate records; 0 mismatches -> build/polychord/onset-evidence-equivalence-v1.json
```

All 124 frames were compared. Eighteen frames contained structural candidates,
producing 18 complete candidate-evidence records. There were zero mismatches.

**Plain-English reading.** The app library and the research reference now
describe the attack history of every tested polychord proposal in exactly the
same way. This establishes implementation fidelity for the raw onset facts. It
does not establish that a particular timing gap means "polychord," select a
millisecond cutoff, or authorize an automatic label.

**Decisions.** Keep the threshold-free onset substrate in the package and keep
the named 50/200-millisecond support interpretation in research. Do not wire
this analyzer to application providers in the same change: the package accepts
transport-neutral evidence, while a later integration must define how the live
event stream preserves monotonic timestamps, event indices, reattacks, sustain,
and reset boundaries. Do not treat the zero-mismatch result as musical accuracy.

Final SHA-256 pins:

- onset schema:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- fixture manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- unchanged Python evidence implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- unchanged Python candidate generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- unchanged Dart candidate model:
  `e048f93ae937dd561a70a36636606a8b8566db097f7cb436d478274c106cab47`;
- unchanged Dart candidate generator:
  `8554bb1eb18baa63c8707085039cd8f5480e1d5556c9998b0d93f0c37e4741db`;
- Dart evidence model:
  `15a151906938effb5e8f0b9e0c28c3e3d3fa01c9aa12b1eaf2b7b51d4cec445c`;
- Dart evidence analyzer:
  `c02a8028187e9aee36eabf313d78b261929d8f5ca98bcbdc8dcc8c2583d3cd27`;
- Dart analyzer tests:
  `01d0da53037e8ebf20867a2306dd5a954e6dce26c2d601e3bfdcad5cccaca764`;
- Dart batch adapter:
  `83713f827512835ce8257b2d854ec75f40479c78eb5a5bf755492f6ed6e1926b`;
- equivalence harness:
  `b62c26e5853880b40c46c10982b60cd7cf2df8065f36095d8fcbda821ba36a81`;
- equivalence-harness tests:
  `b55cadbbce3dabd0b6335a9f6c2741b48123ac02f51f881d09aab83c1b3fac3e`; and
- generated ignored report:
  `88ed5e836b8dd90e3d51c1e18ab863cd15ebcd4663b2dde64e27b73932d3489b`.

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
  research/polychord/log/2026-08-13-01-dart-onset-evidence-equivalence.md
git diff --check
```

All 575 pure-Dart package tests and all 279 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** Add a pure-Dart onset-instance tracker driven by normalized note-on,
note-off, pedal, and reset events, then establish replay equivalence against the
same pinned fixtures. Keep that tracker independent of selector thresholds and
application state management. A later app-integration change can adapt the
existing input providers to the tracker after its event semantics are frozen and
tested.
