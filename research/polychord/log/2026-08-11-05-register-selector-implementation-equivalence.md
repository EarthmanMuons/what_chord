# 2026-08-11: Implement and cross-check the register selector

**Goal.** Implement the preregistered register-only candidate path and selector
independently in Python and pure Dart, then establish complete decision-document
equivalence on the pinned structural input surface before scoring the frozen
adoption suite.

**Setup.** Work began from clean repository commit `558345e7`, which contains
the preregistration in `register-selector-v1.md`. No adoption-suite prediction,
adoption-suite score, development-corpus selector result, prior-art baseline
result, or held POP909 item was read while implementing or cross-checking the
two forms.

The comparison inputs are label-free structural controls rather than musical
product expectations. They comprise the already-pinned 3,300 combinations from
`polychord-register-conformance/1` plus its 11 focused controls. Every input was
evaluated under the full selector and the three fixed leave-one-component-out
ablations, for 13,244 complete decision comparisons.

## Implementation

`tool/polychord/register_selector.py` is the research reference. It implements
the exact compact, rooted-ninth, and rooted-seventh-extension predicates;
same-identity assignment removal; unique-widest-gap selection; fixed ablation
profiles; frozen abstention reasons; and complete per-candidate traces. An
externally supplied candidate sequence must be distinct and exactly equal to the
complete output of the pinned Python register generator, although its order may
differ.

The pure-Dart package now contains parallel immutable layer, identity,
candidate, trace, and decision types plus a register generator and selector. The
path is separate from `ChordAnalyzer`: it consumes registered MIDI notes and
does not alter or inspect primary candidates, costs, context, cache behavior, or
ranking. The library exports the new pure-Dart analysis surface, but this step
does not connect it to providers, history, presentation, or UI.

`register_selector_batch.dart` is a persistent JSON-lines adapter used only by
the equivalence harness. `register_selector_equivalence.py` reconstructs the
pinned matrix inputs, sends each frame through all four Dart profiles, builds
the same four Python decisions, and compares the decoded complete documents.
Equality therefore covers candidate generation and order, exact assignments,
identities, neutral symbols, every predicate trace, removal flags, selection,
and reason codes rather than only the final symbol.

## Measurement result

The final run reported:

```text
13244 decisions across 3311 cases; 0 mismatches -> build/polychord/register-selector-equivalence-v1.json
```

| Selector profile                | Selected | No structural candidate | Not selected by policy | Multiple unresolved identities |
| ------------------------------- | -------: | ----------------------: | ---------------------: | -----------------------------: |
| full v1                         |    2,766 |                       3 |                    542 |                              0 |
| without integrated-tertian veto |    3,307 |                       3 |                      1 |                              0 |
| without assignment veto         |    2,766 |                       3 |                    542 |                              0 |
| without widest-gap resolution   |    2,250 |                       3 |                    542 |                            516 |

These counts describe generated structural inputs, not product accuracy or
corpus safety. The assignment-veto ablation has the same aggregate counts as the
full selector here because the one focused same-identity ambiguity also matches
the separately preregistered rooted-ninth veto. The candidate traces still
distinguish the two mechanisms. This does not show that the assignment veto is
redundant on other registered voicings.

## Execution correction

The first equivalence command failed before its first case because the managed
Codex filesystem sandbox denied Flutter permission to refresh its external
engine-cache metadata. It was rerun with the same command after narrowly scoped
approval; this was not a nono failure and required no source change.

That first escalated comparison processed the cases but the harness rejected the
successful Dart process's normal `Running build hooks...` stderr text. The
harness was narrowed to ignore only that exact toolchain message and to continue
rejecting any other stderr or nonzero exit. The selector implementations and
input surface were unchanged. The formatted harness was then rerun from the
start to produce the final zero-mismatch report.

Dependency resolution also aligned `pubspec.lock` with the intentionally exact
Flutter `3.44.8` constraint already declared in `pubspec.yaml`. The exact lock
constraint is retained; it is not a selector dependency change.

## Verification

The implementation and record were checked with:

```sh
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
python3 tool/polychord/register_selector_equivalence.py \
  --out build/polychord/register-selector-equivalence-v1.json
dart format .
dart run import_order_lint:import_order
flutter analyze
cd packages/whatchord
dart analyze
dart run import_order_lint:import_order
dart test
cd ../..
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/log/2026-08-11-05-register-selector-implementation-equivalence.md
git diff --check
```

All 238 polychord Python tests and all 554 pure-Dart package tests passed.
Python formatting and lint, root and package import ordering, package and root
analysis, Markdown formatting, and whitespace validation passed. The equivalence
report contains 3,311 cases, 13,244 decision comparisons, and zero mismatches.

Final SHA-256 pins:

- preregistration:
  `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff`;
- Python selector:
  `e72d97326abb36e03418be7c41b98305ca3f756d530787e288758d26f2d2e1e7`;
- Python selector tests:
  `81a7f6c45ad65b7437d614d87adbb949d1da3f800c86a77cc5c59d625eb99a03`;
- Dart model:
  `e048f93ae937dd561a70a36636606a8b8566db097f7cb436d478274c106cab47`;
- Dart generator:
  `8554bb1eb18baa63c8707085039cd8f5480e1d5556c9998b0d93f0c37e4741db`;
- Dart selector:
  `b362196dfe29ee95e19f7fe5888d94459662436dd5573ec94319da59d7c0a0ca`;
- Dart generator tests:
  `394485ee4b050a265f767139161a5b19adab78187b8c6d9fea6ea6aa8698bbb0`;
- Dart selector tests:
  `53e5aa1fb56afc8a0da952780a6aeb1aa8d39a6989531d6234b1566492b2cbbc`;
- Dart batch adapter:
  `062b9854df8184265abf70b074f7e7a656562cf99e4674ca65b9d17ea2a7779f`;
- equivalence harness:
  `f89a30634a13ad5975017a055e9d48c4634b7e0cb850c18debf8c13decf293a0`;
- equivalence-harness tests:
  `4ee9ff35831ac96ddae5a07ad3bc6a7d8ebebb92435d7bac123393ef0a7fc854`;
- generated equivalence report:
  `985bdbdce1890009a5d421c2ec1be0d421bf042a499d3104e9bb5ed08885b3c2`;
- protocol: `d060e766c4ae85f6a7327fe7eb5c7627d079f05817a0e886c151178c4df27918`;
  and
- unchanged structural-matrix harness:
  `a6e6240edd71f1c5a0d097fe1846932e389f0d221cd51a1c50a1d6ee9d13e627`.

**Plain-English reading.** We now have two independent implementations of the
same proposed rule, and they agree on every field for every generated structural
case we promised to compare. That tells us the Dart code faithfully implements
the preregistration. It does not yet tell us whether the policy agrees with the
frozen musical cases or behaves safely on development corpora.

**Next.** Commit the implementation and equivalence record as one logical
boundary. Then generate all four suite-pinned prediction artifacts and run the
frozen scorer once, retaining every per-case result. Do not change version 1 in
response to that score, and do not use the held POP909 reserve.
