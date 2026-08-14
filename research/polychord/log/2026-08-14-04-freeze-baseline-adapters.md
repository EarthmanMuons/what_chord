# 2026-08-14: Freeze the prior-art adapters before comparison

**Goal.** Build reproducible environments and faithful adapters for the four
preregistered snapshot baselines, prove their transport and normalization on
source-independent controls, and implement the pure-Dart product prediction
projection without passing a product-suite target to a baseline or producing a
product score.

**Setup and no-peek boundary.** Work began from clean repository commit
`4c75f13c153eb7ffb6bf33029d16ee8d2d06b06c`, which implemented and
cross-checked the product policy. No musicpy, mingus, or ChordRecGen package was
installed in the repository environment. No prior-art detector had received a
product-suite target. The product scorer had not received an implementation
prediction.

The exact source archives were downloaded from the URLs preregistered in
`prior-art-baseline-contract-v1.md` and verified before extraction:

```text
b6e10025648632a666ce99b0647655158a87dc554ebd9edbb9547d87fbf2a3e1  musicpy-7.15.tar.gz
b0723787b69943940ca7ad1c7dffa3cb27eb83755a2a1bc25f8a8f90cd935462  python-mingus-6558cacffeaab4f084a3eedda12b0e86fd24c430.tar.gz
6f5bb36fda9156e1dff518387dcf8e95e788f342ec1963cb715573d3541994eb  ChordRecGen-3790a4df5f1c3bbef4ff0a27c43ddacc020a6639.tar.gz
```

The source-independent common-composite control was selected before suite
execution by enumerating the 42 ordered pairs of different sharp-spellable
root-position major triads. The adapters emitted a supported ordered composite
on 36 WhatChord, 6 musicpy, 42 mingus, and 7 ChordRecGen controls. Their
intersection contained two controls. The smoke suite fixed lower F-sharp major
F#2-A#2-C#3 `(42,46,49)` and upper G major G5-B5-D6 `(79,83,86)`, which every
adapter normalized as G major above F-sharp major.

The final reproducible commands were:

```sh
mise exec -- python tool/polychord/prepare_prior_art_baselines.py \
  --output-root build/polychord/prior-art-env-v1
mise exec -- python tool/polychord/prior_art_baseline_smoke.py \
  --runtime-manifest \
  build/polychord/prior-art-env-v1/runtime-manifest-v1.json \
  --out build/polychord/prior-art-adapter-smoke-v1.json
mise exec -- python tool/polychord/product_suite.py \
  --suite research/polychord/data/product-suite/suite-v0.json
PYTHONPATH=tool/polychord .venv/bin/python -m unittest \
  tool/polychord/product_suite_test.py \
  tool/polychord/product_suite_scorer_test.py \
  tool/polychord/prior_art_baseline_test.py \
  tool/polychord/product_prediction_projection_test.py
mise exec -- python -m unittest discover \
  -s tool/polychord -p '*_test.py'
mise exec -- python tool/polychord/product_policy_equivalence.py \
  --out build/polychord/product-policy-equivalence-v1.json
mise python:format
mise python:lint
dart format .
flutter analyze
dart run import_order_lint:import_order
```

The first ordinary sandbox attempts to download the archives and compile Swift
could not resolve external hosts or write the Swift module cache. They were
rerun with narrow managed-Codex sandbox approval. These were not nono denials
and did not change an input, source pin, or result.

**What was implemented.** `source-manifest-v1.json` records the three source
URLs, archive hashes, Python 3.12.13, and all nine exact ChordRecGen recognition
source hashes. The two Python environments install their verified source
archives without build isolation after installing hash-locked build and runtime
dependencies:

- musicpy: musicpy 7.15, mido-fix 1.2.12, pygame-ce 2.5.8, setuptools 80.9.0,
  wheel 0.45.1, and the Python runtime's pip 25.0.1;
- mingus: the pinned commit reporting distribution version 0.6.1, six 1.17.0,
  setuptools 80.9.0, wheel 0.45.1, and pip 25.0.1.

The original ChordRecGen Swift recognition files compile unchanged under Apple
Swift 6.3.3 for arm64 macOS. The repository-owned wrapper only converts JSON to
`[ChordNote]`, calls `ChordRecognizer().notesToChord(midiNoteValues:)`, and
serializes every returned group, score, chord, factor, assignment, and name. Its
executable SHA-256 is
`5951eeeab551d582994464d252ea25498cbf7d22a308113c6cf84e856c72ca4a`.

The adapter layer now:

- validates one neutral record containing only an observation ID, sorted
  registered MIDI notes, sharp scientific pitches, and matching sharp pitch
  classes;
- invokes musicpy with every preregistered option exactly, retains every public
  `chord_type` field recursively, and uses its fixed lower/upper split only when
  normalizing a top-level two-component result;
- passes mingus the unchanged ordered pitch-class list including duplicates and
  retains its complete native alternative order;
- infers ChordRecGen orientation only from two nonempty disjoint component note
  sets that exhaust the input and separate completely in register;
- requires the exact inspected native forms for the five product qualities and
  leaves altered, incomplete, nested, unsupported, or unorientable composites
  unsupported;
- compares the complete frozen Python and pure-Dart register-only WhatChord
  decisions before normalizing its selected candidate; and
- records adapter input, options, raw return, captured native output, status,
  runtime identity, elapsed diagnostics, and every normalized alternative.

The two JSON schemas freeze the neutral input and complete raw-plus-normalized
result shapes. Exceptions, no output, timeouts, unavailable builds, and
unparseable returns remain distinguishable from abstention.

The product prediction projection builds all Dart requests without checkpoint
values, expected candidates, construction expectations, source titles, or
labels. Case-local candidate IDs are derived in first-seen order from Dart
output. The suite-owned construction object is attached only after execution
because it is evaluation metadata rather than a detector output; it is never
sent to Dart. The projection was tested on synthetic raw product documents, but
its suite-producing command was deliberately not run in this session.

**Smoke result.** Seven source-independent observations exercised empty, one-
and two-note input, pitch-class duplication, an ordinary major triad, an
ordinary dominant seventh, and the common six-note composite. All eight
transport assertions passed for all four baselines:

```text
4 baselines x 7 controls; allPass=true
```

Every adapter preserved its declared converted input, raw alternative order,
native failure state, and byte-equivalent result after removing only elapsed
time. Every adapter produced the same supported ordered composite on the
six-note control. The musicpy empty-input call natively raised `IndexError: list
index out of range`; the adapter retained that exception with its exact empty
converted input instead of turning it into no output.

The first smoke attempt had two false harness failures for musicpy. It treated
the native empty-input exception as a transport failure and discarded the
already-converted input when serializing the exception. The worker was corrected
to bind adapter input before native invocation and retain it in an exception
result; small-input smoke acceptance now permits a retained native exception.
No suite target or musical expectation was involved, and the corrected final
report replaced only this pre-freeze smoke artifact.

**Metadata-only suite refreeze.** The baseline contract requires committed
adapter files to be pinned by the product suite, but the original machine suite
predated their implementation. A single `baselineFreeze` dependency was added
to the suite schema. Its manifest pins every adapter, lock, schema, worker,
test, product projection, source manifest, runtime manifest, smoke report, and
runtime/executable identity.

Removing the `dependencies` object leaves the new and pre-adapter machine suites
byte-equivalent as decoded JSON. Removing `suiteSha256` likewise leaves the old
and new scorer controls equal. No case, action, checkpoint, expected value,
baseline target, version ID, scorer rule, or deliberate-failure recipe changed.
The new suite and scorer-control digests are:

```text
a32b1cf11562dd591a51dd4382dcbfbd472334a5bbc19632ec83fe0583cb214d  suite-v0.json
265af7dcf00be043848d18ee286066a1f6aaf7262f019fd392636b592a7a3994  scorer-controls-v0.json
```

The suite validator and all 33 focused suite, scorer, adapter, and projection
tests passed after the refreeze. The complete polychord run passed all 342
Python tests, including its Python/Dart integration checks. Root Flutter
analysis and import-order, Python formatting and lint, Dart formatting, and
whitespace checks also passed. Repeating the implementation comparison on the
new suite digest retained exact equivalence:

```text
202 product actions and 3300 structural decisions; 0 mismatches
```

**Plain-English reading.** The comparison machinery is now locked before it can
see the comparison cases. The external libraries receive only the notes they
would receive in real use, and their oddities remain visible rather than being
helpfully repaired. We can also generate a grader-shaped WhatChord result
without giving the Dart implementation the answer sheet. Nothing here says
which system performs better; that result has not been run yet.

**Decisions.** Accept the four adapters, their strict normalization, and the
product prediction projection as the frozen version-1 comparison path. Preserve
the suite's musical content exactly and refreeze only its dependency metadata so
the adapter artifacts are genuinely pinned as preregistered. Treat suite-owned
construction metadata as evaluation applicability, not an inferred product
field. Retain native empty-input exceptions and no-output behavior as baseline
results.

The main freeze pins are:

- adapter freeze manifest:
  `d2a6f898297badcfb248e47be52ab2022985ee2b67ad93bf7de4e9d268ca3cb4`;
- runtime manifest:
  `67d3c364565e2347a72cf779465b5f52eb7f9a8b3ccd1157b95c464a63ff11d5`;
- smoke report:
  `b945f9b7110b07a3e72649831ee3d8779301982822ca8f53055faf537d246038`;
  and
- post-refreeze product-policy equivalence report:
  `cd1ba0e0b3047647f2b2efda45caff2248c8ad308f63b2fe6536b7e92402bc59`.

The adapter-freeze manifest contains the complete individual artifact and
runtime pin set. No named-snapshot result, adapted-stream result, product-suite
prediction, product score, development output, or held output was produced.

**Next.** Commit this pre-result freeze. From that clean commit, produce the
first pure-Dart product prediction and score it once, then run all four frozen
baselines on the declared named snapshots and adapted streams without changing
an expectation, adapter, or normalization rule in place.
