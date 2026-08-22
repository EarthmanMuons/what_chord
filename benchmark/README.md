# Chord engine benchmark

An offline performance baseline for the pure analysis engine
(`ChordAnalyzer.analyze`). It exists so the time and memory impact of future
engine changes (temporal context, key detection) can be measured reproducibly,
independent of the machine it runs on.

## Run

```bash
tool/benchmark.sh
```

This writes `benchmark/last_run.json` and prints a summary. For benchmark runs,
the wrapper enables the VM service (needed for allocation measurement) and the
counters define. Pass `-h`/`--help` for usage.

To print the committed baseline in the same summary format as a new benchmark
run:

```bash
tool/benchmark.sh --show-baseline
```

To gate a run against the committed baseline:

```bash
tool/benchmark.sh --check
```

Unless `--out` points at the baseline, the run also prints a delta against
`benchmark/baseline.json` when it exists, so you can see at a glance whether a
change moved anything. The counters are exact, so any counter delta on the same
corpus is a real algorithmic change; a normalized-time delta inside its reported
CI is just noise.

## What it measures

Two corpora are replayed through `analyze()`:

- the **oracle corpus** -- every voicing in `tool/chord/oracle_reviewed.json`,
  deliberately adversarial edge cases;
- the **common voicing pool** (`src/common_voicings.dart`) -- the common chord
  qualities with inversions, approximating real-playing structures.

**Time** is reported for both corpora; **memory and counters** are reported for
the oracle corpus only, since it is the adversarial stress case and therefore
the most sensitive regression signal. The two corpora differ a lot in time (the
oracle corpus is the worst case), so do not judge a change by the oracle numbers
alone.

- **Time, normalized to a fixed reference workload.** Absolute wall-clock time
  is hardware-dependent and noisy on shared CI runners, so it is not comparable
  across runs. The harness also times a fixed, allocation-free integer workload
  (`referenceWork`) on the same machine and reports
  `referenceDisplayScale * engineTime / referenceTime`. A slower runner slows
  both, so the ratio stays roughly constant. The `referenceDisplayScale` (x100)
  is purely cosmetic, sized so the oracle cold score lands near 100 and the
  common pool near 20; it leaves every relative delta and CI unchanged. The warm
  (cache-hit) scores stay near zero regardless of scale and serve only as a
  "cache is working" sanity line. **Compare the normalized scores across runs,
  not the raw microseconds.** Cold (every call a cache miss) and warm (every
  call a cache hit) are reported separately.

  Each timing is **sampled adaptively** (like hyperfine/Criterion): after a few
  warmups the harness keeps sampling until the 95% confidence interval on the
  mean is within `targetRelCi95` (1.5%), bounded by a run cap and a wall-clock
  budget so the expensive cold pass still terminates. It reports mean, median,
  stddev, min/max, sample count, and the achieved CI, plus whether it converged
  or hit the budget. The warm pass is batched per sample so its sub-microsecond
  cost clears the timer's resolution. The normalized CI is the two component CIs
  propagated in quadrature.

- **Memory (VM-observed).** Allocation counts are useful for spotting memory
  movement, but small byte-level differences can come from runtime, VM-service,
  alignment, or GC effects.
  - `churn`: bytes/objects allocated during the measured cold pass, after
    resetting the VM allocation accumulator. This is the driver of GC pressure
    and the relevant number while the engine is mostly stateless.
  - `retained`: the post-GC heap growth from before the cold pass to after it.
    This approximates what the pass caused the isolate to keep alive, mostly the
    analyzer cache today.
  - `live heap`: the whole isolate's post-GC heap usage after the cold pass.
    This is useful context for process footprint, but it includes runtime and
    benchmark harness state, not only analyzer-owned memory.
- **Algorithmic operation counters (deterministic).** Cache hits/misses, roots
  considered, templates evaluated, candidates produced. These are integers that
  depend only on input and code, so they catch algorithmic regressions (e.g. a
  history scan that stops being incremental) with zero hardware noise. They are
  gated behind the `whatchord.counters` compile-time define and are dead-code
  eliminated in normal builds (see `EngineCounters`).

## Checking regressions

`--check` runs the benchmark normally, compares it to `benchmark/baseline.json`,
and exits nonzero only for meaningful regressions. It separates statistical
significance from practical significance:

- Time metrics must be slower than the baseline by at least 5% and outside the
  combined uncertainty window.
- Memory metrics must increase by at least 3%, clear a small absolute threshold,
  and exceed the calibrated VM-observed noise when a noise model is available.
- Counter metrics fail on deterministic increases.

The combined time uncertainty starts with the stored normalized CI from both the
baseline and current run. If `benchmark/noise.json` exists, the check also
includes calibrated full-run noise:

```text
combined uncertainty = sqrt(baseline CI^2 + current CI^2 + calibrated noise^2)
```

This matters because the per-run CI only measures sampling precision inside one
benchmark process. Separate invocations can drift more due to runtime layout,
thermal state, CPU scheduling, VM-service effects, and other runner conditions.

## Calibrating noise

Generate a local run-to-run noise model with:

```bash
tool/benchmark.sh --calibrate-noise
```

Calibration launches separate benchmark subprocesses, compares each result to
`benchmark/baseline.json`, and writes `benchmark/noise.json`. It runs at least
10 subprocess benchmarks, then keeps going until every metric's noise estimate
changes by less than 10% from the previous estimate, stopping at a hard maximum
of 50 runs.

For each time and VM-observed memory metric, the noise model stores a robust 95%
relative run-to-run noise estimate:

```text
noiseRel95 = 1.96 * 1.4826 * medianAbsoluteDeviation(relative deltas)
```

Use calibration from the same class of machine or CI runner where `--check` will
run. A laptop-generated noise model is useful locally, but it does not fully
describe hosted CI variance.

## Tracking a baseline

`benchmark/last_run.json` is the latest run and is not committed. To track a
baseline for regression comparison, copy a known-good run to a committed file:

```bash
tool/benchmark.sh --out=benchmark/baseline.json
```

and diff future runs against it. Because of timing noise, gate regressions on
counters, meaningful memory movement, and normalized time, not raw microseconds.

## Automatic polychord product path

The separate automatic-polychord qualification compares the complete pure-Dart
product path with cold primary analysis in the same process:

```bash
tool/polychord_benchmark.sh --check
```

It writes the uncommitted `benchmark/polychord_last_run.json`. The active frozen
workload, live-core 5% gate, repeated structural timing, null-controlled memory
method, and split core/diagnostic stress traces are specified in
`research/polychord/product-performance-benchmark-v2.md`. Use `--validate-only`
to check fixture projection, timing repetitions, and control reachability
without performing a timed measurement. The v1 contract and failed result are
retained in the research log.
