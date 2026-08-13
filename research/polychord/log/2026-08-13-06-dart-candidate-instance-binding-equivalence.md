# 2026-08-13: Implement and cross-check Dart candidate-instance binding

**Goal.** Implement the exact candidate-to-sounding-instance binding already
frozen by `polychord-output/2`, then compare its complete Dart serialization
with the existing Python opportunity-key mechanics on every pinned replay frame
and an explicit incomplete-history control. Do not choose licensing cues,
aggregate cue support, select a candidate, define a motion endpoint, or change
display behavior.

**Setup.** Work began from clean repository commit
`1b3f145f0ec8b365910fd622e48bdc7b775546da`. The source contract was
`research/polychord/automatic-output-contract-v2.md`, which binds an exact
structural candidate and complete note assignment to the sorted set of
`(midiNote, onsetEventIdentifier)` pairs in a reset-delimited tracker epoch.
Null onset identifiers remain explicit and make the binding incomplete.

The Python reference was the already-measured
`automatic_timing_sensitivity.opportunity_key` path. The cross-check adapts its
layered `lower` and `upper` instance lists into one MIDI-sorted target-instance
list, adds the tracker epoch required by `polychord-output/2`, and derives
complete versus incomplete availability without changing the candidate or
instance identities.

The comparison input comprised all 124 frames from the nine fixtures pinned by
`research/polychord/data/frame-replay/manifest.json`, plus one synthetic
carried-in control. The control supplies the complete six-note `C|Gm` structural
candidate with all onset event identifiers null and tracker epoch 7. This
exercises incomplete availability and nonzero epoch serialization, which the
pinned fixture candidate surface does not contain.

The exact final measurement command was:

```sh
python3 tool/polychord/candidate_instance_binding_equivalence.py \
  --out build/polychord/candidate-instance-binding-equivalence-v1.json
```

The first in-sandbox measurement attempt failed before its first fixture because
the managed Codex filesystem sandbox denied the Dart launcher access to Flutter
engine-cache metadata under `/opt/homebrew`. The same command was rerun with
narrowly scoped approval. This was not a nono failure and produced no partial
measurement. The first in-sandbox full Python verification later encountered the
same denial in three Dart integration tests and teardown; its approved rerun
passed.

**What happened.** The package now exposes one compact sounding-instance key for
the onset, release/pedal, and motion-transition substrates. A candidate binding
retains the exact ordered chord identities and lower/upper MIDI-note
assignments, the reset-delimited tracker epoch, every assigned note's MIDI and
onset-event identity, and explicit complete or incomplete availability.

The binder accepts immutable onset or release/pedal tracking frames directly.
This prevents a caller from pairing notes from one observation with an epoch
from another. It can bind all generated candidates, bind one exact candidate, or
revalidate a prior binding against a later frame. Revalidation is exact:

- a held-to-sustained state change under pedal preserves the same instance;
- an unrelated pedal transition preserves the binding;
- same-note reattack replaces the onset event identity and invalidates it;
- note-set or exact-candidate assignment changes invalidate it; and
- reset invalidates it even when MIDI notes and reused event indices match.

The model intentionally retains null identifiers. A complete structural
candidate built from carried-in notes therefore has an incomplete binding; it is
not assigned fabricated attacks and cannot later masquerade as a complete
authorization identity.

The final cross-language measurement reported:

```text
125 frames and 19 candidate bindings across 9 fixtures; 0 mismatches -> build/polychord/candidate-instance-binding-equivalence-v1.json
```

This consists of 124 pinned frames and one synthetic control. The pinned frames
produce 18 complete bindings. The synthetic carried-in control produces one
incomplete binding. Python and Dart agree on the full serialized candidate,
epoch, target-instance list, and availability in every case.

**Plain-English reading.** The library can now tell whether later evidence is
still about the same actual sounding notes, rather than merely the same pitches
or chord label. Letting a key go under sustain does not invent a new note, but
playing that pitch again does. Restarting the event stream also creates a new
identity namespace. This is bookkeeping needed to keep future evidence honest;
it does not decide that a polychord should be shown.

**Decisions.** Use one shared compact instance-key type rather than allowing
onset, motion, and future cue code to reproduce the pair differently. Accept
complete tracker frames at the public binder boundary rather than separate epoch
and note arguments. Keep instance binding as causal substrate only: no cue ID,
positive or neutral support, confidence, candidate precedence, authorization
key, timer, or selector was added.

The source-coverage stopping rule remains in force. This implementation does not
make the existing onset or motion construct probes into licensing cues and does
not satisfy the missing source-attested automatic positive or matched
cue-positive ordinary integrated control.

Final SHA-256 pins:

- automatic output contract:
  `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee`;
- fixture manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- unchanged Python replay implementation:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- unchanged Python register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- unchanged Python onset-evidence implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- unchanged Python opportunity-key implementation:
  `9e0600ada3ad703f8a77c7d5cc4866a7e66cc051a1d23fa798bbc38a99a0b870`;
- Dart sounding-instance key:
  `483d486de7661d8b847d15350ce38b31bdd1ceb09f28e7f3fea88f51ccf2f867`;
- Dart candidate-binding model:
  `4c45053dcac859784ffcee0f1b29534dec0f698f2a515f563aee33b514bc1175`;
- Dart candidate binder:
  `355b84e89d8ce372c22dd365aa664b3b122afd1fe8a072e9952b44bcd5c2e40f`;
- Dart transition-evidence model:
  `1d5c3f74e2667f0e08e7843e789c0132d3d6f3dea84bcec2527359f7fb0ae264`;
- Dart transition analyzer:
  `169ce5ff4f2b11834cf55740912bf02128bdadc46092cab061cc5994f126a594`;
- Dart public API:
  `991e94e7ca2e0a79b3ec93c2e26e7139860ed14ff1b6836bb377808ac067f8fe`;
- Dart direct tests:
  `5a954d731788bfa6138f9a87ac572428fc9fb9f1a82e1f25af273dd7e7fbe1e8`;
- Dart batch adapter:
  `db78841c6f8dfd82e40d6132d698939c1ea2842f5c3412dad49d32e8a99808de`;
- equivalence harness:
  `5c7b53e4e60e922b8d6d1eab2e7a9684eb4eafb686aa6334d979110718c0e688`;
- equivalence-harness tests:
  `0a2ff55fe22156e984d84a08191bf60ba663ef097266097083b181dd888938ad`; and
- generated ignored report:
  `d1aba1ba5c2c4f885cdfe76fef4ac8270586df993e3adc0e0c21e5f730857f70`.

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
  research/polychord/log/2026-08-13-06-dart-candidate-instance-binding-equivalence.md
git diff --check
```

All 621 pure-Dart package tests and all 294 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** Keep automatic selector and cue-aggregation work paused at the
existing source-evidence prerequisite. The next scientific step remains an
event-complete source-attested automatic positive and matched cue-positive
ordinary integrated control under one named profile. Further implementation can
proceed independently only where it does not choose a licensing branch, motion
endpoint policy, evidence aggregation rule, or product behavior.
