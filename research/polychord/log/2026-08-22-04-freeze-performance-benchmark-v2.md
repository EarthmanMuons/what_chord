# 2026-08-22: Freeze product performance benchmark v2

**Goal.** Prospectively correct the path definition, structural sampling, and
allocation method invalidated by the retained v1 result, without changing the 5%
budget, frozen musical workloads, optimized product implementation, or held
boundary.

**Setup.** Work began from clean optimization commit
`b553a9789fd1c16e4b57db636951b38dbdc5697a`. The evidence permitting a
measurement revision was fixed before implementation in logs 2026-08-22-02 and
2026-08-22-03: v1 gated a diagnostic map absent from the live app, its
five-event structural samples did not converge, and its 35-event allocation
window was dominated by fixed probe cost. No timed v2 command was run in this
step.

The non-timing implementation and validation commands were:

```sh
dart format benchmark/polychord_benchmark.dart \
  benchmark/src/polychord_workload.dart \
  test/benchmark/polychord_workload_test.dart
dart analyze benchmark/polychord_benchmark.dart \
  benchmark/src/polychord_workload.dart \
  test/benchmark/polychord_workload_test.dart
flutter test test/benchmark/polychord_workload_test.dart --reporter compact
tool/polychord_benchmark.sh --validate-only
npx prettier --write --prose-wrap always \
  benchmark/README.md \
  research/polychord/PROTOCOL.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/product-completion-plan.md \
  research/polychord/product-performance-benchmark-v2.md \
  research/polychord/log/2026-08-22-04-freeze-performance-benchmark-v2.md
dart format .
dart run import_order_lint:import_order
flutter analyze
flutter test --reporter compact
git diff --check
```

The final implementation pins after formatting are:

| Artifact              | SHA-256                                                            |
| --------------------- | ------------------------------------------------------------------ |
| Benchmark runner      | `28214947e3589c2dbebf6a70e26f3e9e18ef635dfe274eeaf038e30ed6832238` |
| Workload definition   | `50fba6d6766d438ca94e183e37bb5fdfc1fe94815d0a0d3130e594b7e9ea4aad` |
| Workload test         | `6da4a008af57c17cedc418c1ed83243b6fb270fd1480ab83355be907ec076e35` |
| Shell wrapper         | `862934e1f08cc628e875bc0a8f5961a6abbb76906bbfe55a8158286873e710ce` |
| Benchmark-v2 contract | `ce2c24bbbeb0dc10a3e3855de469a9a102dc8d8ffe62e3d72a9c0f6881595072` |

**What changed.** Schema `whatchord-polychord-benchmark/2` gates
`productCoreFinal`, which includes complete immutable product-observation
construction and matches the work the app executes on a MIDI event.
`productSerializedFinal` remains measured and printed beside it, but optional
research `toJson()` map construction is no longer characterized as live UI
overhead. Both stress traces likewise report core and serialized time.

Every final timing sample now contains at least 1,000 final events. The
unchanged oracle cases repeat three times for 1,056 events, common voicings
repeat 13 times for 1,053 events, and the unchanged five structural controls
repeat 200 times for 1,000 events. Each case retains equal weight. Primary
repetitions use separate analyzers cleared before the timed region; product
repetitions use separate long-lived engines prepared through all-but-final input
before timing. A gating measurement that does not attain the frozen confidence
target is now explicitly indeterminate.

Allocation replay events are constructed before the measurement window. Churn
uses at least 10,000 musical events: six oracle passes or 286 structural passes.
A same-structure null traversal is measured after its own accumulator reset, and
v2 reports gross, null-control, and nonnegative net bytes and objects. One-pass
and 20-additional-pass post-GC retention remain separately reported.

Final non-timing validation reported:

```text
oracle: 352 cases, 1796 events, max 0 candidates/frame, 3 final-timing repetitions (1056 events/sample)
common: 81 cases, 345 events, max 0 candidates/frame, 13 final-timing repetitions (1053 events/sample)
structural: 5 cases, 35 events, max 2 candidates/frame, 200 final-timing repetitions (1000 events/sample)
full-midi-range: 258 events; positive-reattack: 16 events
```

The focused benchmark suite passed seven tests. Flutter analysis reported no
issues, and the complete app suite passed 265 tests with the repository's
existing six skips. Formatting, import ordering, Markdown formatting, and the
diff check also passed.

**Plain-English reading.** V2 still asks whether the feature adds at most 5% to
primary chord analysis, using the same musical examples. It now times enough
events to produce a stable answer and gates the work the app actually performs.
The much larger diagnostic conversion is still visible in the report rather than
being mislabeled as live feature cost. Memory reporting similarly removes the
profiler's fixed setup cost before dividing by musical events.

**Decisions.** Adopt `product-performance-benchmark-v2.md` and
`whatchord-polychord-benchmark/2` as the active prospective performance
measurement. Preserve v1 and its failure unchanged. Keep the point estimate,
combined confidence interval, and three-workload pass requirement, but classify
any nonconverged gating pair as indeterminate. Keep whole-entry, serialization,
allocation, retention, candidates, and stress as reported guards rather than
silently removing unfavorable measurements.

**Next.** Commit v2 and these pins without running timed mode. From that clean
commit, run the unchanged primary check followed by
`tool/polychord_benchmark.sh --check`; retain all results in a new dated entry.
The Dart 3.13.1 primary baseline failure remains a separately disclosed
prerequisite and must not be repaired by changing the polychord benchmark.
