# 2026-08-13: Implement and cross-check Dart onset cue records

**Goal.** Package the already-frozen `coherent-separated-onsets-50-200ms/1`
interpretation as a complete candidate-bound diagnostic cue record under the
`polychord-output/2` shape, then compare Dart and Python on every pinned replay
frame and an explicit incomplete-history control. Do not name a licensing
branch, aggregate cue support, select a candidate, choose motion endpoints, or
change display policy.

**Setup.** Work began from clean repository commit
`ef84bceaa6dfc3ccbfadde6dd6e0e6513e35c26b`. The governing records were
`automatic-output-contract-v2.md`, `onset-support-ablation.md`, and the exact
candidate-instance binding implemented and cross-checked in log 2026-08-13-06.

The comparison input comprised all 124 frames from the nine fixtures pinned by
`research/polychord/data/frame-replay/manifest.json`, plus the same explicit
carried-in control used by the candidate-binding cross-check. That control has
one complete six-note structural candidate, all onset identifiers null, and
tracker epoch 7. It distinguishes an incomplete cue record with null support
from a complete record whose interpretation is neutral.

The exact final measurement command was:

```sh
python3 tool/polychord/onset_cue_record_equivalence.py \
  --out build/polychord/onset-cue-record-equivalence-v1.json
```

Before measurement, the new Python harness control failed while constructing
expectations because a chained comparison expressed the availability-consistency
check incorrectly. The expression was corrected, Python formatting and lint were
rerun, and all harness controls passed before the measurement command was
executed. No comparison report had been produced by the failed control.

The final measurement ran with narrowly scoped approval because the Dart
launcher requires access to Flutter engine-cache metadata outside the managed
Codex filesystem sandbox. This was not a nono failure.

**What happened.** The package now exposes a diagnostic onset cue-record model
and builder. Each record retains:

- the fixed versioned cue ID and onset-evidence schema ID;
- the complete immutable target observation, including tracker epoch and event
  frame;
- the exact candidate and target sounding-instance binding;
- complete or incomplete availability;
- positive, neutral, or null support;
- the ordered reason codes; and
- the full raw onset evidence and named interpretation.

The builder emits one record for every generated candidate in generator order.
It verifies that the interpretation and target binding refer to the same exact
candidate and agree on availability. It contains no cue registry, licensing
flag, aggregation, candidate selection, authorization key, persistence tracker,
or display interaction.

For complete history, the fixed onset interpretation maps positive to positive
cue support and neutral to neutral cue support. For incomplete history, the cue
record retains the interpretation's `onset-history-incomplete` reason but maps
cue support to null. This preserves the v2 distinction: neutral says a complete
application of the named cue did not support the candidate, while null says the
cue could not be interpreted completely.

The final cross-language measurement reported:

```text
125 frames and 19 cue records across 9 fixtures; 0 mismatches -> build/polychord/onset-cue-record-equivalence-v1.json
```

The 19 records comprise 18 complete pinned-fixture records and one incomplete
synthetic record. Support counts are one positive, 17 neutral, and one null.
Dart and Python agree on the full observation, candidate, instance binding,
availability, support, reason codes, and nested diagnostic for every record.

**Plain-English reading.** The library can now describe an onset result without
losing what it was about or why it was available. A genuine neutral result and a
result with missing note history are no longer forced into the same bucket. This
is an auditable diagnostic envelope around an existing timing experiment; it is
not evidence that the app should automatically show a polychord.

**Decisions.** Use the frozen ablation ID as the diagnostic cue ID and retain
the entire underlying interpretation rather than copying only its final support.
Keep incomplete availability distinct from unavailable: onset history is present
for the current frame but lacks at least one required attack identity. Reserve
unavailable for future cue families whose required source observation or
interpretation cannot be formed at all.

Do not add a motion cue record yet. Motion interpretation has two unranked
correspondence hypotheses for every explicit source-target candidate pair, and
the application-facing endpoint and correspondence policy remains unfrozen.
Wrapping one hypothesis as though it were the adopted cue would silently make
that policy choice. Do not add aggregate support or a selector: doing so would
name the onset diagnostic as a licensing branch without the required
source-attested automatic positive and matched cue-positive ordinary integrated
control.

Final SHA-256 pins:

- automatic output contract:
  `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee`;
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
- unchanged Python binding adapter:
  `5c7b53e4e60e922b8d6d1eab2e7a9684eb4eafb686aa6334d979110718c0e688`;
- Dart cue-record model:
  `f74ea2f31b86fba1637d5234508e158f0aa1d21aaab9feecff9804c46ecc8791`;
- Dart cue-record builder:
  `dc51578df32d315eec0aa5078911acd2ab0ba0076548f5193524bb623022501f`;
- Dart public API:
  `d137fd62ad3167f335af347934c9e676987727a36cba40174340dd39a55bf2e0`;
- Dart direct tests:
  `4c2e267940776df447c6680144c576d4af32856f1f8ca8bda186d0d4a1fd67c3`;
- Dart batch adapter:
  `df246a5e36c6c9462db6212b81a3fccb1dad5a0413b6ac677801bff52e172381`;
- equivalence harness:
  `444199ca0d7a2f04a0e7a5ee9c892a1205dc8548a5cf8625eec5b864850f6afc`;
- equivalence-harness tests:
  `bc08a38b1772f066f0e467f394efc2f3cfaba22b74a9157778e115e3878c1618`; and
- generated ignored report:
  `9abc34eba808006861c5fa2a783d6648b6fb771be284ad8f4ba0bad6705c83ae`.

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
  research/polychord/log/2026-08-13-07-dart-onset-cue-record-equivalence.md
git diff --check
```

All 627 pure-Dart package tests and all 297 polychord Python tests passed.
Package and root analysis, Dart and Python formatting, import ordering, Python
lint, Markdown formatting, and whitespace validation passed.

**Next.** This completes the onset cue-record substrate without adopting it as a
licensing cue. The next scientific step remains the source-evidence
prerequisite: an event-complete source-attested automatic positive and matched
cue-positive ordinary integrated control under one named profile. Motion cue
packaging, support aggregation, automatic selection, and product behavior remain
paused until their respective endpoint and source-coverage decisions are
eligible.
