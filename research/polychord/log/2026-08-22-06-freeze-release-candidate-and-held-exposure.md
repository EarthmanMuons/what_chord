# 2026-08-22: Freeze release candidate and held exposure

**Goal.** Record the completed cross-platform product and accessibility
acceptance, make a transparent product-level amendment to the device telemetry
gate, and prospectively freeze the one final held POP909 exposure without
opening held MIDI.

**Setup.** This step began from clean performance-result commit `609d06e7f`. The
maintainer reported satisfactory functional behavior on both an iPhone and an
Android device, followed by acceptable accessibility behavior on both platforms.
Device models, OS versions, exact traces, and frame telemetry were not retained.
The package presentation controls independently passed:

```sh
cd packages/whatchord
dart test test/polychord_presentation_builder_test.dart
dart analyze \
  lib/src/polychord/services/polychord_presentation_builder.dart \
  lib/src/polychord/models/polychord_presentation.dart
```

Those controls cover the exact upper/lower semantic sentence, enharmonic
spelling, and all registered layer qualities. Static app review confirmed one
live semantic node after the primary result, no duplicated visual semantics, a
scrollable secondary region without ellipsis, ordinary platform text scaling,
and no polychord animation that could bypass reduced motion.

No held MIDI file was opened while implementing or validating the held harness.
Only the already-public roster shape, source-checkout identity, and directory
availability were checked. The roster still contains 101 sample and 808 held IDs
with no overlap, and the POP909 checkout is clean at its frozen commit.

The non-outcome harness controls are:

```sh
dart format tool/polychord/held_exposure_batch.dart
dart analyze tool/polychord/held_exposure_batch.dart
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover \
  -s tool/polychord -p 'held_exposure_test.py'
```

The synthetic Dart-backed control requires one stable `C|Gm` episode at 280 ms
for coherent lower-then-upper cohorts and zero episodes for the same six notes
attacked simultaneously. Roster controls require the exact 101/808 disjoint
shape. Neither control reads a corpus file.

The two focused controls passed while Dart SDK cache access was available.
During the final clean-tree rerun, the roster control passed, but the managed
Codex workspace sandbox denied the Python process's Dart child permission to
write Flutter's SDK cache outside the repository. `flutter analyze`, Python
formatting and lint, Dart formatting, and the root import-order check passed in
that final tree. This environmental denial did not open held data or alter the
earlier synthetic result.

The broad historical Python suite then exposed that benchmark-v2 commit
`deaa49ab1` had edited the already-frozen `output-evaluation-contract.md`. Its
internal and product suites correctly rejected the changed dependency digest
before executing their controls. The v2 measurement mechanics were already
independently versioned and preserved in `product-performance-benchmark-v2.md`
and logs 2026-08-22-03 through -05, so this step restores the frozen output
contract's original bytes rather than rewriting either frozen suite pin. This is
a research-record correction only; it does not change the 5% budget, v2 result,
product code, or held design.

**Prospective artifact pins.** These SHA-256 values were computed after final
formatting and before the held reserve was opened:

| Artifact                  | SHA-256                                                            |
| ------------------------- | ------------------------------------------------------------------ |
| Held exposure contract    | `c51b8b66d799bab8c379219493d36b00845c3068bd96b904b45cd2dd90c0de56` |
| Held Python harness       | `d0fbcb4589351f083454f1bd02ab6511822981ccf37eaae5523e1596bbe952eb` |
| Held Dart product batch   | `354786dc225b42c551cb6c40e6977eaacc766f6e52cad5e903cbe54ea14b98e9` |
| Held harness controls     | `ed675f0fa51d2af553369b279655c6f725d1fe11aac445f9fdef8bf08a583da8` |
| Held result verifier      | `570f649886c0a0c5e0699b05e5f3ac011f53b8ff601bd66a9f06ea2ae9c3dc8c` |
| POP909 roster             | `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781` |
| Product engine            | `3e042ec8b7a8a29fd94787eb9faf70e89476773379b6b0bfc926bd9d4fa66aaa` |
| Onset/register selector   | `26555ac9f6730d6bcfaede93a38bf637b98b709762c5f9c1823b77855d8dd4ba` |
| Authorization gate        | `b4fcca861ed98fb8378fd9273a2fe0466585ccf1115a8e142d4fdb7060805c3e` |
| Shared development parser | `21d3de85923d488f35a93bfd5c8aa1317ca087eea7c7ba889aca7b5ec338e6ab` |

**Device-gate amendment.** The earlier contract requested oldest-tier iOS and
Android dropped-frame profiling with reduced motion on and off. For this product
release, replace that exact telemetry requirement with the maintainer's
qualitative functional and accessibility acceptance on one iPhone and one
Android device, together with the passing pure-Dart performance benchmark. This
is a pragmatic release decision, not measured proof about every supported
device. The remaining risk is platform-specific rendering or scheduling jank on
slower hardware; it is judged low because the live engine's worst converged
ratio interval ends at 4.84%, the secondary view is a small text-only region,
and appearances are infrequent and stability-gated. Exact device telemetry
remains an optional post-release diagnostic rather than a release blocker.

**Held design.** `held-exposure-v1.md` freezes the exact 808-song roster,
BRIDGE+PIANO projection, shared normalization, actual `PolychordProductEngine`,
primary-availability replay, timer behavior, complete per-piece output,
integrity verifier, review boundary, and zero-out-of-scope-display gate. The
harness has no development/sample flag and fails unless both repositories are
clean. Any stable display must be reviewed; an out-of-scope disposition fails
the candidate permanently on this reserve. Immutable measurement output is
manifest-hashed; the separately hashed initial review template permits only the
required disposition and rationale fields to change, while the verifier
reconstructs all review evidence from the immutable piece reports.

**Plain-English reading.** The feature has passed its automated musical,
integration, baseline, and performance work and has now behaved acceptably on
both mobile platforms, including accessibility. Detailed device profiling would
increase confidence about the slowest hardware, but it is unlikely to change the
release decision and is not being represented as evidence we collected. The only
remaining product-safety measurement is whether the frozen feature emits an
inappropriate stable annotation anywhere in the untouched held songs.

**Decisions.** Accept the maintainer's iPhone and Android sessions as the
hands-on functional and accessibility gate for this release. Freeze the app
implementation at `609d06e7f` and the forthcoming clean commit containing only
this held harness and research boundary as the release candidate. Do not modify
the feature after reading held output. Adopt `held-exposure-v1.md` as the single
authorized held measurement.

**Next.** Commit this prospective freeze and all final artifact pins without
running the held command. From that clean commit, execute the two registered
commands exactly once, retain the result even if it fails, then complete the
release decision and documentation.
