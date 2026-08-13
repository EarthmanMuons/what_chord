# 2026-08-13: Implement and cross-check Dart release/pedal evidence

**Goal.** Promote the frozen threshold-free release and pedal evidence contract
into the pure-Dart library. Preserve current note state, releases, reattacks,
prior sustained-instance releases, and pedal transitions without adding an age
limit, release-group tolerance, confidence, eligibility, or display rule. Check
the complete Dart output against the canonical Python implementation on every
pinned replay frame.

**Setup.** Work began from clean repository commit
`c0aba8f926a5a39f03490937fbf4d6f0dbbccdf3`. The source contract was
`polychord-release-pedal-evidence/1`; its canonical implementation was
`tool/polychord/release_pedal_evidence.py`. The event substrate remained the
nine fixtures in `research/polychord/data/frame-replay/manifest.json`,
containing 124 frames. The structural surface remained the unmodified
register-candidate generator. The repository was necessarily dirty because the
Dart implementation and equivalence tooling were the artifacts under test.

The exact final measurement command was:

```sh
python3 tool/polychord/release_pedal_equivalence.py \
  --out build/polychord/release-pedal-equivalence-v1.json
```

The first in-sandbox measurement attempt failed before its first fixture because
the managed Codex filesystem sandbox denied the Dart launcher access to Flutter
engine-cache metadata under `/opt/homebrew`. The same command was rerun with
narrowly scoped approval. This was not a nono failure and did not change the
code, data, or comparison method.

**What happened.** The package now exposes an immutable release/pedal evidence
model, a pure event-stream tracker, and a stateless candidate analyzer. The
tracker consumes the same normalized note-on, note-off, and sustain-pedal event
types as the onset tracker. After every successful event it emits:

- each sounding note's current pressed or sustained state;
- its current onset when observed;
- the release and current-state origin when sustain holds it;
- whether the current onset reattacked a sustained instance;
- the prior sustained instance's observed release when applicable; and
- the latest observed transition into the current pedal state.

Carried-in history remains unknown. Note and pedal relations use timestamp plus
event index, preserving array order when timestamps tie. Pedal release removes
sustained histories but leaves pressed-note histories intact. Reset remains an
administrative epoch boundary with unknown carried-in origins; it is not a
fabricated MIDI event.

The exported models validate exact JSON-integer bounds, MIDI and velocity
ranges, state/origin consistency, event ordering, nonfuture origins, sorted
distinct notes, unique event indices, pedal/state agreement, exact candidate
assignments, and a common frame identity across both candidate layers. Failed
events and invalid resets do not mutate tracker state or consume an event index.

The candidate analyzer reproduces every field in
`polychord-release-pedal-evidence/1`: pedal history, per-note ages and origins,
pressed and sustained counts, known and unknown completeness counts, raw release
timestamps and spans, state-age ranges, reattack counts, and onset-versus-pedal
ordering. These are descriptive causal facts. No field names support,
confidence, eligibility, penalty, or display.

The richer tracker also projects each note to the existing onset observation
type. A Dart regression test steps the onset and release/pedal trackers over the
same sequence and requires identical projections after every event. Thus this
work extends the onset substrate rather than silently redefining the sounding
instance already verified in the preceding step.

`release_pedal_evidence_batch.dart` adapts a complete fixture stream to Dart.
`release_pedal_equivalence.py` validates the pinned manifest, derives raw
history frames and every candidate summary with the canonical Python replay,
generator, and evidence implementation, and compares decoded complete outputs
against Dart. The wrapper adds `trackerEpoch: 0` for each independently replayed
fixture; that administrative Dart field is outside the Python schema and does
not alter evidence within an epoch.

The final measurement reported:

```text
124 frames and 18 candidate records across 9 fixtures; 0 mismatches -> build/polychord/release-pedal-equivalence-v1.json
```

All 18 frames having one or more candidates contained exactly one candidate in
the current fixture set. The comparison nevertheless checks complete candidate
lists in generator order, so additional or missing Dart candidates would be a
mismatch.

**Plain-English reading.** Given the same normalized performance events, Dart
and Python now retain the same information about held keys, pedal-sustained
notes, releases, reattacks, prior releases, and pedal episodes at every tested
event. They also summarize those facts identically for every structural
candidate. This is implementation equivalence, not evidence that pedal or
release history distinguishes true polychords, and it does not license a timing
cutoff or automatic annotation.

**Decisions.** Keep release/pedal provenance separate from the chord analyzer,
application state, onset interpretation, motion evidence, and stable display.
Reuse the shared normalized temporal events. Keep reset epochs explicit. Retain
raw ages and timestamps while leaving every categorical interpretation to a
later named and justified ablation.

Final SHA-256 pins:

- frame-replay schema:
  `93cbfe0cb77cb570d4c444438b8cde8df82c04e68e0667c134ba21cde10e85b8`;
- release/pedal evidence schema:
  `95f2492e46e61b8dfc36f4c286a3883a9a8fa5ee4ddd6cc3ad1b9f4a7519b15a`;
- fixture manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- unchanged Python replay implementation:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- unchanged Python register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- unchanged Python release/pedal implementation:
  `b4401dad62e26a3f76609e631387362cce12c6e7907cf1f1ff32ad681a40fcc2`;
- Dart candidate model:
  `e048f93ae937dd561a70a36636606a8b8566db097f7cb436d478274c106cab47`;
- Dart temporal-event model:
  `8c5bebcccd660b15fd28d0a3fe4ec3651c32c2e99d9e419e7bd0e039f94ddc0d`;
- Dart release/pedal evidence model:
  `1d49c64b1c92eeade7a1bae1deba7b1bdc41797472e6afae1e9cfc3191578870`;
- Dart register generator:
  `8554bb1eb18baa63c8707085039cd8f5480e1d5556c9998b0d93f0c37e4741db`;
- Dart release/pedal tracker:
  `c609a40c9229f641bc672cf5b61fba4740c742ace97ccb2a7e8b8b0764885217`;
- Dart release/pedal analyzer:
  `83765b457b0c5343d70f595bb5f4e50cd2e916001ee8ce8f210f95e51b01a2c8`;
- Dart release/pedal tests:
  `090ae2578ff36582c7c55d2ead0416f792bc45dec7e067e463fc31cb0327c275`;
- Dart batch adapter:
  `98de3bc2c70860149493079b18d2563e5fc9c985c0daf2aec7f804789d5958d6`;
- equivalence harness:
  `245dce49d4600210ef4c967e130e0e326aa0b5b3e4d7f7256b3b8ce0fae189ee`;
- equivalence-harness tests:
  `c5c4ca9aa62afc9258f61849b23379f3acc93dd6bb6cd691b96f4aaf982ffab4`; and
- generated ignored report:
  `ba7ea9524b399119347b9a0537f595c331879a7716265f5a70b37e92a6a19142`.

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
  research/polychord/log/2026-08-13-03-dart-release-pedal-equivalence.md
git diff --check
```

All 598 pure-Dart package tests and all 285 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** Port the already-frozen threshold-free frame-transition and motion
substrate to pure Dart, preserving caller-selected endpoint semantics and
explicit unevaluable cases. Establish complete equivalence against the canonical
Python transition frames and candidate motion summaries before application
integration or any motion-support interpretation.
