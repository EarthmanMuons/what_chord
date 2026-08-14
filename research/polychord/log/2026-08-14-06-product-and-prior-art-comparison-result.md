# Record the product and prior-art comparison result

**Date:** 2026-08-14  
**Status:** retained frozen result

## Execution

The first prior-art suite run started from clean commit
`14bcde6b9b3cff26895c1698f2f3992bc9ebeb6d`. The comparison runner verified the
suite, adapter freeze, comparison freeze, runner, and local runtime-manifest
digests before invoking a detector. It then sent the same 185 neutral
observations to all four pinned baselines:

```text
Named targets                         29
Named detector invocations            28
Adapted streams                       20
Changed sounding stream frames       157
Total adapter observations           185
```

Petrushka rehearsal 49 remains the single named-snapshot coverage exclusion. Its
24 actual changed frames remain in the adapted-stream task. No expectation,
source identity, primary chord, onset cue, or product output crossed the adapter
boundary.

The complete case-level report, including native returns, standard output and
error, adapter inputs, normalized alternatives, runtime identities, failures,
and elapsed-time diagnostics, is retained at
`research/polychord/results/product-comparison-v1/prior-art-comparison-v1.json`.
That raw report is authoritative; the smaller summary is a mechanically derived
view.

## Product result

The expectation-isolated pure-Dart product prediction covered all 20 cases and
108 frozen checkpoints. It passed exact equality in all seven dimensions: frame
and observation time, construction, candidates, cue records, raw decision,
authorization, and display.

```text
suiteExactGatePass: true
checkpoint count:   108
```

The retained prediction and score are byte-identical to the first product run
made after adapter commit `ea97d535`, before any prior-art output was read.

## Named-snapshot comparison

The following are combined descriptive totals after retaining the preregistered
`inherited`, `authored-positive`, and `authored-guard` strata separately in the
machine report:

| Baseline                  | Ordered identity | Unordered components | Exact assignment | Guard abstention | Composite emitted | Named failures |
| ------------------------- | ---------------: | -------------------: | ---------------: | ---------------: | ----------------: | -------------: |
| WhatChord register policy |            14/14 |                28/30 |            14/14 |            13/13 |             14/28 |              0 |
| musicpy 7.15              |             5/14 |                12/30 |             5/14 |            10/13 |             18/28 |              0 |
| python-mingus             |             2/14 |                 4/30 |    not available |             7/13 |              8/28 |              0 |
| ChordRecGen               |             2/14 |                 4/30 |             2/14 |            11/13 |              7/28 |              0 |

There are 15 simultaneous positive snapshots, hence 30 possible unordered
component credits. Fourteen have resolved upper/lower order. The Augurs sonority
supplies the fifteenth: the score establishes both components, but its
overlapping registers do not establish a safe notation order. WhatChord's
register-only policy correctly remains silent there, producing its 28/30
component total without weakening the 14/14 eligible ordered result. Petrushka
does not enter either denominator because no static snapshot was invented.

WhatChord also abstained on every boundary and negative guard. The prior-art
guard violations were:

- musicpy: Elektra's overlapping construction, D over C major seventh, and the
  rooted-seventh-extension control;
- mingus: the Maiden Voyage slash territory, doubled C major seventh, integrated
  D6, same-root C-major registers, compact C major seventh, and rooted C major
  ninth; and
- ChordRecGen: D over C major seventh and the matching rooted-seventh-extension
  control.

The exact positive matches illuminate complementary detector assumptions:
musicpy recognized five fixed-split cases, mingus recognized the two copies of
the disjoint F-sharp-major over C-major collection, and ChordRecGen recognized
the two copies of G major over A-flat dominant seventh. Many additional native
composites contained altered, incomplete, nested, suspended, or otherwise
unsupported components and therefore remained raw output rather than being
coerced into product vocabulary.

## Adapted-stream exposure

The stream task is exposure-only. Static detectors were rerun after changed
sounding-note frames; the values below are not frame-level ground-truth scores
and are not product display results.

| Baseline                  | Composite frames | Known composite dwell | Identity changes | No output | Failures |
| ------------------------- | ---------------: | --------------------: | ---------------: | --------: | -------: |
| WhatChord register policy |           15/157 |              3,640 ms |               16 |       142 |        0 |
| musicpy 7.15              |           36/157 |              3,970 ms |                3 |         0 |        9 |
| python-mingus             |            5/157 |                600 ms |                5 |        84 |        0 |
| ChordRecGen               |            6/157 |                800 ms |                1 |        42 |        0 |

All nine musicpy failures were native `IndexError: list index out of range`
returns on empty sounding-note frames. They were serialized as exceptions as
required, rather than retried or reclassified as abstentions. No note-bearing
musicpy frame failed. No other baseline produced an exception, timeout,
unparseable invocation, or unavailable build.

The optional common 200-ms wrapper was not run. Native systems can return
multiple alternatives, and version 1 did not freeze an identity-selection rule
for adapting those alternatives. Applying one after seeing results would alter
the comparison. WhatChord's product display behavior is instead covered by its
separate 108-checkpoint exact result.

## Interpretation limits

This is a descriptive product-policy comparison, not an independent benchmark.
The suite is author-adjudicated, WhatChord's policy was developed against its
construction and guard requirements, and the other libraries were not designed
for this exact vocabulary or real-time evidence contract. The result supports
the implementation premise that existing libraries do not supply the needed
ordered, assignment-aware, conservative behavior. It does not establish a
general accuracy ranking outside the frozen suite.

The comparison also leaves two intentional feature boundaries visible:

- overlapping-register constructions such as Augurs cannot be recovered by the
  adjacent-register policy; and
- unfolding constructions such as Petrushka require evidence beyond a single
  simultaneous snapshot.

Neither boundary blocks the current automatic product scope. They remain
documented future avenues rather than being silently converted into failures or
synthetic inputs.

## Verification and retained artifacts

`tool/polychord/prior_art_comparison_result_verify.py` performed no detector
invocation. It independently rescored the product prediction, validated every
retained baseline result and neutral-input digest, reconstructed every named
metric and stream summary from case-level output, confirmed 185 unique results
per baseline, and checked all artifact pins. Its control passed. The complete
`tool/polychord` Python suite passed 353/353, and the required Python format and
lint checks passed.

The result manifest is
`research/polychord/results/product-comparison-v1/result-manifest-v1.json`, with
SHA-256 `fca8eec8e4994f9a9ff3c573a01cf95c0d18424cf354fd7e5820d3f91ca996cd`. The
principal artifact digests are:

- complete prior-art report:
  `5b638a682375d3869c484226dd136969cc41b5be2d3d576cf99cfb990a8118ab`;
- product predictions:
  `d637c5416aa12edb886a86669206b610a4a8947841c7aeb2b8619fee838a59cc`;
- product score:
  `308d2cb83bbc7f67056bb6616ffbcd4bce518d8a1eb84b7a1fb8bf460ef957c5`;
- derived comparison summary:
  `661c8d147eb69340cf909efbcd4b27c8f6ad4cde45581c82205f5d40d8c7140f`;
- result verifier:
  `c558d29c828b1945886b767e92056982ad25325878aecaeefdd90270d6d47e0f`; and
- verifier control:
  `4057c32b6ec81bf78afb3e6f69bd6b7c3394dc133eb047b9bb3a67055eb3936b`.

## Decision

Accept the frozen product result and descriptive baseline comparison. Do not
tune product policy or rewrite suite expectations from these outputs. The next
product-completion step is integration of the already-equivalent pure-Dart
policy into the app's real MIDI analysis flow, followed by package and app-level
non-widget tests for presentation, history, diagnostics, and primary-chord
coexistence.
