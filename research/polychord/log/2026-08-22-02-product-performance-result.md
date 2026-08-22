# 2026-08-22: Measure the automatic product path

**Goal.** Run the prospectively frozen product benchmark from a clean commit,
retain a negative result without tuning the harness, and determine whether the
automatic polychord path satisfies its 5% performance budget.

**Setup.** The run used clean commit `e7f23b97719948a252ecc889f8884722733e3841`,
which contains the harness and contract frozen in log 2026-08-22-01. The
benchmark reported Dart 3.13.1 on macOS arm64, schema
`whatchord-polychord-benchmark/1`, and `gitDirty: false`. Its recorded corpus
and structural-fixture hashes match the prospective contract. The exact commands
were:

```sh
tool/benchmark.sh --check
tool/polychord_benchmark.sh --check
```

The first dedicated-command attempt stopped before starting Dart because the
managed execution sandbox could not update Flutter SDK cache metadata. The same
command was rerun with the required SDK-cache access. Only that completed run
produced `benchmark/polychord_last_run.json` and the results below.

## Results

The unchanged primary benchmark failed its committed comparison before the
dedicated result was interpreted:

| Primary metric       | Current normalized | Change from baseline | Result |
| -------------------- | -----------------: | -------------------: | ------ |
| Oracle cold          |              30.42 |                +4.3% | pass   |
| Oracle warm          |             0.0143 |                +1.3% | pass   |
| Common voicings cold |              18.76 |               +14.7% | fail   |
| Common voicings warm |             0.0158 |               +12.9% | fail   |

All deterministic primary counters were unchanged: 352 cache misses, 1,796 roots
considered, 48,492 templates evaluated, 21,483 candidates produced, and 3,265
candidates ranked. Oracle churn rose 2.7% and retained memory rose 0.7%, both
below their gates. The baseline was recorded under Dart 3.12.2, while this run
followed the separately committed Flutter upgrade and used Dart 3.13.1. Primary
analyzer sources, the oracle, the common-voicing fixture, and the benchmark
logic have not changed since that upgrade apart from mechanical Dart formatting.
The evidence therefore strongly suggests a stale cross-runtime timing baseline
rather than a deterministic analyzer or polychord-integration regression, but
the frozen prerequisite still formally failed.

The same-process dedicated gate failed on every workload:

| Workload   | Primary final (us) | Product core (us) | With `toJson()` (us) | Gate ratio |  95% interval | Result |
| ---------- | -----------------: | ----------------: | -------------------: | ---------: | ------------: | ------ |
| Oracle     |            262.722 |            14.041 |               21.736 |      8.27% |   8.11%-8.44% | fail   |
| Common     |            138.045 |             9.563 |               16.208 |     11.74% | 11.49%-11.99% | fail   |
| Structural |            164.622 |            47.245 |               88.211 |     53.58% | 51.98%-55.19% | fail   |

The core-only ratios, which exclude diagnostic map construction, were about
5.34% for oracle, 6.93% for common, and 28.70% for the structural controls.
Serialization is therefore material, especially for structural observations, but
removing it alone would not make all three workloads pass.

The descriptive whole-entry ratios were 5.93% for oracle, 8.05% for common, and
23.31% for structural controls. The structural final-event core and serialized
samplers reached the 300-sample cap without attaining the requested 1.5%
relative confidence half-width. Their observed relative half-widths were 4.38%
and 2.60%, respectively. This does not change the decision: even the serialized
ratio's lower interval bound was 51.98%, far beyond the 5% budget.

Candidate diagnostics confirmed the intended workload split. Oracle contributed
1,796 zero-candidate frames and common voicings contributed 345 zero-candidate
frames. The 35 structural frames produced nine candidates in total, with a
maximum of two per frame; their five final frames produced seven candidates.

The memory probe reported:

| Workload   | Churn bytes/event | Churn objects/event | Retained after one pass | Growth after 20 more passes |
| ---------- | ----------------: | ------------------: | ----------------------: | --------------------------: |
| Oracle     |            10,977 |                90.0 |               167,984 B |                    51,408 B |
| Structural |           570,043 |             4,681.5 |                   224 B |                     4,128 B |

The structural churn rate is not a credible per-event product cost: both probes
reported roughly 20 MB of total churn, and dividing that fixed VM-service and
measurement overhead by only 35 structural events inflated the rate. The v1
number is retained as measured, but a revised allocation method needs a null
control or enough repeated events to amortize fixed probe work. Retained growth
did not scale with the number of repeated musical events and did not show an
unbounded temporal-history cache in this run.

The serialized stress traces were:

| Trace             | Events | Time/trace | Mean/event | Maximum candidates/frame |
| ----------------- | -----: | ---------: | ---------: | -----------------------: |
| Full MIDI range   |    258 |   415.1 ms |   1.609 ms |                        0 |
| Positive reattack |     16 |     664 us |    41.5 us |                        1 |

The full-range trace is deliberately artificial, but its 415 ms total is a
meaningful scaling warning. Candidate generation scans every adjacent register
boundary even though none can form a supported layer pair in this trace.

**Plain-English reading.** Ordinary notes that do not resemble a polychord add
roughly 10 to 22 microseconds on this machine, depending on whether detailed
diagnostic maps are built. A real structural example is much more expensive:
about 47 microseconds for the live engine and 88 microseconds with the research
diagnostic conversion. Those are small absolute times for an isolated MIDI
event, but they exceed the deliberately strict budget relative to the existing
analyzer. The extreme 128-note storm also shows that the present generator does
unnecessary work as the sounding set grows. The feature is not performance
qualified yet.

**Decisions.** Retain the v1 result as a failure and do not amend the 5% budget.
Do not treat removal of `toJson()` from the app as the complete fix: the app
already publishes immutable observations rather than JSON, and the core
structural path itself is over budget. Optimize the pure-Dart orchestration so
candidate generation and validation are not repeated for the same frame, then
improve the generator's zero-candidate scaling without changing its output.
Correct the allocation probe in a prospectively documented benchmark revision.
Refresh or recalibrate the primary benchmark only as an explicit Dart 3.13.1
baseline-maintenance step, not as part of making the polychord result pass.

**Next.** Add equivalence tests around a shared single-generation product path,
implement the internal reuse without weakening public validation, and benchmark
the optimized implementation against this recorded result. Add a benchmark-v2
allocation amendment before reading its replacement memory figures. Device
note-storm and accessibility checks remain blocked on passing pure-Dart
performance qualification.
