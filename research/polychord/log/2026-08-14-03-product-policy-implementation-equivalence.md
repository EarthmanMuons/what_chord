# 2026-08-14: Implement and cross-check the automatic product policy

**Goal.** Implement the already-frozen
`polychord-onset-register-policy/1` and `polychord-output/3` as a narrow
composition of the established structural and temporal substrate, then compare
the complete independent Python and pure-Dart paths before producing a product
suite score, prior-art output, new development output, held output, or app
integration.

**Starting state and no-peek boundary.** Work began from repository commit
`3d2077850ea5edb8bdea01c0a2c5ab89f9603b5c`. The 20-case, 108-checkpoint
author-adjudicated ruler was already frozen, but no product-policy
implementation or prediction existed. The equivalence input reused all 20
product fixture and action scripts while removing every checkpoint and expected
value before the Dart process received them. It compared implementations; it
did not invoke the product scorer or compare either path with the ruler. No
prior-art baseline, development, or held output was produced or read.

**What was implemented.** `tool/polychord/product_policy.py` is the independent
Python reference. The pure-Dart package now exposes separately versioned product
models and services for:

- the inclusive, orientation-neutral
  `coherent-separated-onsets-50-80ms/product-1` cue;
- complete candidate-bound cue records and aggregate support;
- exact assignment, integrated-tertian, and positive-support selector stages
  with the frozen reason precedence;
- a reset-scoped authorization key containing identity, assignment, and every
  current onset-event identifier;
- the `polychord-continuous-authorization-200ms/1` absent, pending, and visible
  reducer; and
- one pure-Dart product engine accepting normalized musical events, timer
  observations, primary-display availability changes, and tracker resets.

The earlier 50/200-millisecond diagnostic, register-only selector, and
candidate-only stable-display gate remain unchanged. The product selector
reuses their already-equivalent generator and static predicate behavior instead
of rebuilding that substrate. Its implementation asserts the preregistered
positive-survivor uniqueness invariant at runtime.

The output classes validate complete authorization bindings, legal display
state, monotonic product observations, reset isolation, and agreement between an
active display and its current authorization. The engine exposes the exact
pending deadline needed by a later application provider without coupling the
pure package to Riverpod, Flutter, the primary analyzer, or presentation.
Its reset path can also restore carried-in pressed or sustained notes only as
unknown onset history, preserving the contract's automatic-abstention boundary.

**Cross-language method.** The persistent Dart adapter received two kinds of
expectation-free requests:

1. all 202 musical and product-control actions across the 20 frozen replay
   cases, including non-checkpoint actions, sustain, reattack, timer, primary
   availability, and reset behavior; and
2. 3,300 structural decisions covering all five lower qualities, all five
   upper qualities, all 11 different-root relations, and all 12 transpositions,
   with the intended adjacent layers attacked at the inclusive 80-millisecond
   boundary.

The harness compared decoded complete product-observation documents for the
session inputs and decoded complete raw-decision documents for the structural
matrix. Equality includes frames, full candidates, onset diagnostics, instance
bindings, every selector stage and trace, authorization keys, display state,
transition reasons, deadlines, and all version identities.

**Measurement result.** The pinned run reported:

```text
202 product actions and 3300 structural decisions; 0 mismatches -> build/polychord/product-policy-equivalence-v1.json
```

The 3,300 structural controls yielded 2,472 selections, 540
`integrated-tertian-reading` abstentions, and 288
`layer-separation-not-supported` abstentions in both implementations. These are
implementation-coverage dispositions, not a product-suite score, baseline
comparison, corpus exposure result, or musical-accuracy estimate. Every control
retained at most one positive survivor.

**Execution correction.** The first unapproved equivalence attempt ended before
its first case because the managed Codex filesystem sandbox denied Dart access
to Flutter SDK cache files under `/opt/homebrew`. The command was rerun with
narrowly scoped approval and the repository's pinned Python 3.12.13 runtime.
This was not a nono failure and did not change code, inputs, expectations, or
comparison behavior.

**Verification.** The final implementation and record were checked with:

```text
dart format .
flutter analyze
dart run import_order_lint:import_order
cd packages/whatchord
dart analyze
dart run import_order_lint:import_order
dart test
cd ../..
mise python:format
mise python:lint
mise exec -- python -m unittest discover -s tool/polychord -p '*_test.py'
mise exec -- python tool/polychord/product_policy_equivalence.py \
  --out build/polychord/product-policy-equivalence-v1.json
git diff --check
```

All 639 pure-Dart package tests and all 328 polychord Python tests passed. Root
and package analysis, Dart and Python formatting, both import-order runs, Python
lint, and whitespace validation passed. The equivalence report records Python
3.12.13, Dart 3.12.2, the starting commit, dirty implementation state, command,
and complete artifact hashes.

Final SHA-256 pins are:

- product output contract:
  `77c2f6a9085aec3a53c733372ae3e3d3e8f20127e6af0f0e74af2f6337301b89`;
- selector specification:
  `f909263d052ad88c5f001fe9694ff4a558a3888df0ef541c2eaa83438a9fbc58`;
- frozen product suite:
  `f3891fb35466ef8019c3785c21bd21fcbfad12375b10283e2c364bf544406af4`;
- Python product policy:
  `8e0d8fde82049e84bd0840b1429a819a8778f28eef2984fa6e16822c81767aa0`;
- Python policy tests:
  `14c612d07881e284d1bc68bb0dcc441bb919610051edb10663b784e7a4e39672`;
- equivalence harness:
  `7628239c341c18019be8fd4497f9c3aab373fb7bf89e969a0b4b0f8897d394bf`;
- equivalence-harness tests:
  `94272e4a6cba28c3db7aac75bf6f499def33695e31879248f8f366d583ec01e2`;
- Dart batch adapter:
  `e2c70602720674a2d8911483cd4dda606100b115656be0ea9f69b6bc3bd1ce4f`;
- Dart public API:
  `c0c11dd64400904dc584a0910f478e4a080a4efd06bdfd4cee9b5004d18a87ce`;
- Dart product cue model:
  `9e6413d7d388c62c675f68387ad1554211095b92a406375d2e96b1a99d64f14c`;
- Dart product decision model:
  `7ceaf4b4c5070aad685eeb24b5cf52c9da0bf9cb63921bcd98f2f03770daa201`;
- Dart product output model:
  `c3cf1835772bb69337b6761d726ab809df0506ec142c9783ea17004471117be0`;
- Dart product onset interpreter:
  `31b3ea7a24613efa5950aa1f087d8e03829cec4cfd29af92696ee2f9ec28d856`;
- Dart product cue builder:
  `f3efbe13219f49ad858948d5fa9ee8fbd55c8f995f45dcac495559dcaea238f2`;
- Dart onset-register selector:
  `4f81b6e3a956519d174b8a4afc7d6a5aa2296dd3ff5b2660521951d2ebaf4c0c`;
- Dart product authorizer:
  `b2a9ab6d24571d4aa83569aa7aa5e9387099a7e27f9e51db26a216edafd26494`;
- Dart continuous-authorization gate:
  `b4fcca861ed98fb8378fd9273a2fe0466585ccf1115a8e142d4fdb7060805c3e`;
- Dart product engine:
  `3e042ec8b7a8a29fd94787eb9faf70e89476773379b6b0bfc926bd9d4fa66aaa`;
- Dart product-policy tests:
  `7066034fd1f4fc0e12ec3d3eac19ea473128e85e47a28d79cef761f50792aac8`;
  and
- generated equivalence report:
  `f6d364266d92038e666e0fcb89226cf9fb6c7721e5a446235ff4b65dd05841ce`.

**Decision.** Accept the Python and pure-Dart implementations as exactly
equivalent on the preregistered temporal controls and complete symmetric
structural matrix. This closes the implementation-fidelity prerequisite only;
the frozen author-adjudicated product suite remains deliberately unscored.

**Next.** Commit this implementation and equivalence record as one logical
change. Then implement and freeze the hash-locked prior-art environments,
adapters, smoke controls, and expectation-free product prediction projection.
Only after that prospective commit may the first product-suite score and
baseline comparison be produced. No additional literature, corpus, or ruler
work is required before those product steps.
