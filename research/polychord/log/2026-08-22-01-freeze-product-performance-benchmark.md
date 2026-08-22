# 2026-08-22: Freeze the product performance benchmark

**Goal.** Turn the already-frozen 5% automatic-polychord performance budget into
an executable, reproducible measurement without opening the held corpus or
confusing diagnostic serialization cost with the visible app's live cost.

**Setup.** Work began from clean commit
`15020e7f3710ffddc44014c410e8ed159c9c89ac`, after automatic polychord app
integration was committed. The applicable existing requirements were read from
`output-evaluation-contract.md`, `PROTOCOL.md`, and
`product-completion-plan.md`. No timed product benchmark was run in this step.

The non-timing implementation checks were:

```sh
dart format benchmark/polychord_benchmark.dart \
  benchmark/src/polychord_workload.dart \
  test/benchmark/polychord_workload_test.dart
dart analyze benchmark/polychord_benchmark.dart \
  benchmark/src/polychord_workload.dart
flutter test test/benchmark/polychord_workload_test.dart --reporter compact
tool/polychord_benchmark.sh --validate-only
dart format .
dart run import_order_lint:import_order
flutter analyze
flutter test --reporter compact
npx prettier --write --prose-wrap always \
  benchmark/README.md \
  research/polychord/PROTOCOL.md \
  research/polychord/product-completion-plan.md \
  research/polychord/product-performance-benchmark-v1.md \
  research/polychord/log/2026-08-22-01-freeze-product-performance-benchmark.md
git diff --check
```

The final implementation pins are recorded after formatting:

| Artifact            | SHA-256                                                            |
| ------------------- | ------------------------------------------------------------------ |
| Benchmark runner    | `290ec59b03712963ef7b1e638eb1cc784ccaf0d228d02e4ecaf41184f14e2e32` |
| Workload definition | `28702ecec6682e6d6c87a9a7b919234c29a143690e2ba677ae4c12312b564942` |
| Workload test       | `e44cec19ed15d7ba4252a2f89047e63ae9674d5023e6926608515c31c80df24a` |
| Shell wrapper       | `862934e1f08cc628e875bc0a8f5961a6abbb76906bbfe55a8158286873e710ce` |
| Benchmark contract  | `d3a5f9054682b1d966e568c7da12f94662754d46681b38d811fd6f7963c82ba6` |

**What happened.** The benchmark now separates three questions. The frozen gate
compares the final-event product path, including complete diagnostic `toJson()`
map construction, with one cold primary analysis of the same complete voicing. A
second timing reports the core engine without `toJson()`, so the research
diagnostic requirement cannot be misreported as UI overhead. A third timing
compares cumulative product and primary cost while every corpus voicing is built
note by note.

The ordinary oracle and common snapshot corpora are projected into compact MIDI
voicings with a fail-closed rule against invented octave doublings. Workload
validation produced 352 oracle cases and 1,796 events, plus 81 common cases and
345 events. Both contained zero structural polychord candidates. This is an
expected ordinary fast path and is retained honestly rather than treated as a
sufficient complete-path benchmark.

Five exact product-suite realizations were therefore added as a stricter third
gating workload. Their 35 events cover a positive, an upper seventh, assignment
ambiguity, multiple identities, and the integrated seventh-extension veto, with
at most two candidates per frame. The unit test confirms their policy branches.
The percentage command will pass only if oracle, common, and these structural
controls each satisfy the original 5% limit.

The harness also measures allocation churn and repeated-pass retention for the
oracle and structural paths. Its two ungated stress traces are the complete
128-note MIDI range with pedal capture and release (258 events) and a positive
selection followed by sustain, reattack, and clear (16 events).

The complete app suite passed 263 tests with the repository's existing 6 skips,
and Flutter analysis reported no issues. Formatting, import order, focused
workload tests, workload validation, Markdown formatting, and the diff check
also passed.

**Plain-English reading.** The eventual headline will not be based only on easy
ordinary chords that never form a polychord candidate. It must also pass on
known examples that force the detector to build evidence and make a decision.
The report will say separately how much the live detector costs and how much
extra work is caused by constructing its detailed research diagnostics.

**Decisions.** Adopt `product-performance-benchmark-v1.md` and
`whatchord-polychord-benchmark/1` as the prospective measurement. Keep the
original 5% threshold unchanged and require it on the added structural controls
as a conservative extension. Keep UTF-8 JSON encoding outside timed regions,
because the product publishes immutable objects rather than continuously writing
JSON. Treat whole-entry overhead, allocation, and stress traces as descriptive
guards alongside the exact final-event percentage gate.

**Next.** Commit this benchmark and its pins without running the timed command.
From that clean commit, run the unchanged primary check and then
`tool/polychord_benchmark.sh --check`. Record every result, including a failure
or indeterminate interval, in a new dated measurement entry before changing the
harness or implementation.
