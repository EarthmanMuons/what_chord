# Automatic polychord product performance benchmark v2

Status: preregistered replacement measurement for `polychord-output/3`. This
document supersedes the timing-gate and allocation mechanics in
`product-performance-benchmark-v1.md` after the retained v1 failure exposed two
measurement-validity problems. It does not change the frozen 5% budget, musical
workloads, product behavior, or held-data boundary. The timed run must begin
from a clean commit containing this document and the complete v2 harness.

## Why v2 is necessary

Logs 2026-08-22-02 and 2026-08-22-03 establish three defects in v1:

1. V1 gates `PolychordProductObservation.toJson()` even though the app publishes
   the immutable observation and does not construct that diagnostic map on its
   live path. This conflates optional research inspection with feature latency.
2. V1 times only five structural final events per sample. The optimized
   exploratory sampler reached its 300-sample cap with a 14.22% relative
   confidence half-width, a 12.9-microsecond median, and a 16.6-microsecond mean
   distorted by isolated outliers. It did not converge.
3. V1 divides a roughly fixed VM-service allocation-probe cost by only 35
   structural events, producing an unusable per-event churn estimate.

These problems were identified and recorded before v2 was implemented or run.
Correcting them is not permission to weaken a failed result: v1 remains the
historical result for its schema.

## Frozen workloads and claim boundary

Retain v1's exact 352-case oracle corpus, 81-case common-voicing corpus, five
policy-bearing structural controls, deterministic MIDI projection, 80 ms cohort
construction, full-range storm, and positive reattack trace. Structural fixture
source validation and hashes remain mandatory. No development or held corpus is
opened.

The measured product core includes onset tracking, structural generation,
evidence and binding, raw selection, primary authorization, continuous display
reduction, and complete immutable `PolychordProductObservation` construction. It
excludes Flutter, Riverpod scheduling, rendering, transport, and device
accessibility, which remain hands-on gates.

## Final-event timing

For each oracle, common, and structural workload, repeat its complete case list
enough times that every timing sample contains at least 1,000 final events:

| Workload   | Cases | Repetitions/sample | Timed final events/sample |
| ---------- | ----: | -----------------: | ------------------------: |
| Oracle     |   352 |                  3 |                     1,056 |
| Common     |    81 |                 13 |                     1,053 |
| Structural |     5 |                200 |                     1,000 |

Every repetition gives each case equal weight. Primary repetitions use separate
`ChordAnalyzer` instances whose caches are cleared outside the timed region.
Product repetitions use separate long-lived engines; reset and all-but-final
preparation remain outside the timed region. Report per-event time after
dividing by the complete repeated batch.

Keep v1's adaptive methodology: five warmups, 30 to 300 samples, target 95%
relative confidence half-width of 1.5%, existing wall-clock caps, and a
same-process allocation-free reference workload. Report convergence and all raw
statistics. A nonconverged gating measurement is indeterminate even if its point
estimate is below budget.

For every workload, report:

- `primaryFinal`: cold primary analysis on the complete voicing;
- `productCoreFinal`: the actual live final-event product path;
- `productSerializedFinal`: the same observation followed by `toJson()` map
  construction;
- `primaryEntry`: cold primary analysis across growing note-on prefixes; and
- `productSerializedEntry`: product observation and `toJson()` across the same
  prefixes.

The repeated minimum applies to the three final measurements. Whole-entry timing
remains descriptive and uses one complete corpus pass per sample.

## Frozen gate

For oracle, common, and structural workloads independently:

```text
productCoreFinal mean / primaryFinal mean <= 0.05
```

Propagate within-run 95% relative confidence intervals in quadrature. Classify
each workload:

- `pass` when both measurements converged and the point estimate is at most 5%;
- `indeterminate` when either measurement did not converge, or when the point
  estimate exceeds 5% but its lower confidence bound does not; and
- `fail` when both measurements converged and the lower confidence bound exceeds
  5%.

`--check` succeeds only when all three workloads pass. Diagnostic serialization
remains prominently reported but is not counted as work added to the live app.
This changes the measured path, not the 5% limit.

## Allocation and retention

Measure serialized product replay on oracle and structural workloads. Construct
all replay events before opening the allocation window. Repeat complete passes
until each churn measurement contains at least 10,000 musical events: six oracle
passes (10,776 events) and 286 structural passes (10,010 events).

For each workload:

1. reset the VM allocation accumulator and force collection;
2. traverse the same prebuilt replay structure without calling the engine and
   record the null-control churn;
3. reset again, execute the serialized product replay, and record gross churn;
4. report gross, null-control, and nonnegative gross-minus-control net bytes and
   objects, plus net values per musical event; and
5. separately retain v1's post-GC live-heap comparison after one pass and after
   20 additional passes on one long-lived engine.

The null control removes fixed VM-service and harness traversal cost; it does
not subtract product object construction or `toJson()`. Retained growth remains
a bounded-state diagnostic rather than an exact zero-byte gate.

## Stress and other diagnostics

For both frozen stress traces, report core and core-plus-`toJson()` timing
separately, with candidate distributions. Keep candidate counts per ordinary
frame and structural final case, displayed-frame counts, and diagnostic byte
counts unchanged. Stress results remain descriptive until the separate oldest
supported iOS and Android note-storm checks are complete.

## Commands and result record

Run from the clean committed v2 tree:

```sh
tool/benchmark.sh --check
tool/polychord_benchmark.sh --check
```

The dedicated command writes the ignored `benchmark/polychord_last_run.json`. A
new append-only dated result must pin the clean commit, schema
`whatchord-polychord-benchmark/2`, harness and workload hashes, corpus hashes,
exact commands, timing and convergence, gate intervals, gross/control/net
allocation, retention, candidates, and both stress paths. A failure or
indeterminate result is retained and blocks performance qualification.
