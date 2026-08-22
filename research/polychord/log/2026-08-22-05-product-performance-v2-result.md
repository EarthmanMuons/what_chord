# 2026-08-22: Measure product performance benchmark v2

**Goal.** Run the prospectively frozen benchmark v2 from its clean commit,
retain the result without post-result tuning, and decide whether the optimized
automatic polychord path satisfies its unchanged 5% live-core budget.

**Setup.** Both registered commands ran successfully from clean commit
`deaa49ab131ac084ef5b231972391f444c7e7196`. The dedicated result reports Dart
3.13.1 on macOS arm64, schema `whatchord-polychord-benchmark/2`, and
`gitDirty: false`. No development or held corpus was opened.

```sh
tool/benchmark.sh --check
tool/polychord_benchmark.sh --check
```

The complete dedicated JSON was retained at
`research/polychord/results/product-performance-v2/benchmark-result.json`. It
has the same parsed content as the generated ignored output; the retained file
adds one terminal newline. The relevant implementation and result pins are:

| Artifact                   | SHA-256                                                            |
| -------------------------- | ------------------------------------------------------------------ |
| Retained dedicated result  | `75f9f3c7fe3dc958d6f2ef31afc7f7143919ddc32e6501db518be6d71d75e689` |
| Generated dedicated output | `57066b47c785aed08f2c0b0b7878e10181dd4e74735ad459440bb043f58148ab` |
| Benchmark runner           | `28214947e3589c2dbebf6a70e26f3e9e18ef635dfe274eeaf038e30ed6832238` |
| Workload definition        | `50fba6d6766d438ca94e183e37bb5fdfc1fe94815d0a0d3130e594b7e9ea4aad` |
| Shell wrapper              | `862934e1f08cc628e875bc0a8f5961a6abbb76906bbfe55a8158286873e710ce` |
| Benchmark-v2 contract      | `ce2c24bbbeb0dc10a3e3855de469a9a102dc8d8ffe62e3d72a9c0f6881595072` |
| Primary result JSON        | `81f19f1cba7abb29bd44b5c0d172c5549e0cada07e376ff2d529a71d9370537a` |
| Primary baseline           | `9f0094260fce3574c61b830f7b23640a5270ebbab2dcf6ee131a7083474b7126` |
| Primary noise model        | `b7e2cb9dd6449711c6d43493fa46ce7f5b14619cb0e2255a53a4b11ba1f18d09` |
| Primary benchmark wrapper  | `5ea8c75308e0507961fb223dfa309a8968a5efd4f9f6d4e1fbc41a5cb8c80118` |

The dedicated result embeds these corpus pins:

| Corpus artifact                   | SHA-256                                                            |
| --------------------------------- | ------------------------------------------------------------------ |
| Reviewed oracle                   | `05d48ea502347e2c8b7f75c06851871d35f8d2bcf1e7a472c16474258dbb3463` |
| Common voicings                   | `a01c8ba94effe8fb7b4853d039811a1dc826651aa32169468c13176cee6b59c0` |
| Structural basic positive         | `fa6bd1292aaa9e43fc77bf258ce1d676773eea87cc7f9dba0dd40c58c39861f4` |
| Structural upper seventh          | `bdbff6f47458270e392cfd7a718320b864f857620ebad934e69a7af3153d580b` |
| Structural assignment ambiguity   | `9f36b60548646eb8beb1d5f635852fae24717fca93deee95111460cabb880fd5` |
| Structural multiple identities    | `354ac45bbd8bf05d3b3ea3b631fe31a499e1203f770be448e8fe896d578479bb` |
| Structural seventh-extension veto | `8590adef9fc8fa3a64886014f0740a03858e57be1489ed765724db06a956d127` |

## Primary prerequisite

The unchanged primary benchmark passed its committed comparison:

| Primary metric       | Current normalized | Change from baseline | Result |
| -------------------- | -----------------: | -------------------: | ------ |
| Oracle cold          |            29.8099 |                +2.2% | pass   |
| Oracle warm          |             0.0141 |                +0.3% | pass   |
| Common voicings cold |            16.7698 |                +2.6% | pass   |
| Common voicings warm |             0.0142 |                +0.9% | pass   |

Oracle churn was 51,818 bytes per call, 2.5% above baseline and below the 3%
gate. Retained memory was 1,203,648 bytes, 0.6% above baseline. The
deterministic counters remained exactly 352 cache misses, 1,796 roots
considered, 48,492 templates evaluated, 21,483 candidates produced, and 3,265
candidates ranked, with zero cache hits. This closes the separate primary
prerequisite that failed in the earlier v1 session.

## Dedicated timing result

All six primary and core gating measurements converged. The formal result is:

| Workload   | Timed events/sample | Primary final (us) | Product core (us) | Core ratio | 95% ratio interval | Result |
| ---------- | ------------------: | -----------------: | ----------------: | ---------: | -----------------: | ------ |
| Oracle     |               1,056 |            243.520 |             2.793 |      1.15% |        1.13%-1.16% | pass   |
| Common     |               1,053 |            132.484 |             2.350 |      1.77% |        1.75%-1.80% | pass   |
| Structural |               1,000 |            160.017 |             7.636 |      4.77% |        4.70%-4.84% | pass   |

The structural core was the slowest and closest to the budget. It required 226
samples and reached a 1.4998% relative confidence half-width; its complete ratio
interval remained below 5%. Oracle core required 89 samples and common core 93.
Every primary measurement converged in 30 samples.

Diagnostic serialization remained visible but outside the live-core gate:

| Workload   | Core plus `toJson()` (us/event) | Serialized whole-entry ratio |
| ---------- | ------------------------------: | ---------------------------: |
| Oracle     |                           9.746 |                        3.79% |
| Common     |                           8.770 |                        5.07% |
| Structural |                          56.586 |                       14.18% |

The whole-entry ratios compare serialized diagnostic replay with cold primary
analysis across growing prefixes. They are descriptive and do not represent the
app's event path, which publishes the already-constructed immutable observation
without calling `toJson()`.

## Allocation and retention

The registered repeated-event and null-control measurements reported:

| Workload   | Events | Gross bytes | Control bytes | Net bytes | Net bytes/event | Net objects/event |
| ---------- | -----: | ----------: | ------------: | --------: | --------------: | ----------------: |
| Oracle     | 10,776 |  22,568,288 |    22,529,008 |    39,280 |            3.65 |              0.03 |
| Structural | 10,010 |  20,418,144 |    20,422,672 |         0 |            0.00 |              0.00 |

Structural gross churn was 4,528 bytes and 179 objects lower than its separately
reset null control, so the contract's nonnegative subtraction reports zero. This
does not establish zero product allocation. It establishes that product churn
was not distinguishable from the approximately 20 MB VM-service and harness cost
in this probe. The v2 method prevents that fixed cost from being divided by 35
events as if it were product allocation, but its near-zero net figures are a
resolution limit rather than a precise allocation estimate.

After garbage collection, oracle retained 14,528 bytes after one pass and grew
18,224 bytes after 20 additional passes. Structural retained 3,040 bytes after
one pass and grew 32 bytes after 20 additional passes. The bounded growth does
not indicate an unbounded temporal-history cache.

## Candidate and stress diagnostics

Oracle and common workloads produced zero candidates and zero displays across
1,796 and 345 frames respectively. The 35 structural frames produced nine
candidates total, with a maximum of two; their five final frames produced seven
candidates. No structural display appeared because the timing projection does
not wait through the stable-display dwell.

Both stress paths converged:

| Trace             | Events | Core time/trace | Core us/event | With `toJson()`/trace | Maximum candidates/frame |
| ----------------- | -----: | --------------: | ------------: | --------------------: | -----------------------: |
| Full MIDI range   |    258 |        6.309 ms |         24.45 |             21.127 ms |                        0 |
| Positive reattack |     16 |         67.4 us |          4.21 |              415.1 us |                        1 |

The like-for-like full-range serialized trace is about 95% faster than the 415.1
ms v1 trace. These artificial traces remain descriptive until the registered
on-device checks.

**Plain-English reading.** The feature passes its pure-Dart performance budget.
Ordinary non-polychord events add roughly two to three microseconds on this
machine. The deliberately difficult structural examples add about 7.6
microseconds, with a measured upper ratio bound of 4.84% against primary chord
analysis. Producing large research JSON maps remains substantially more
expensive, but the app does not do that while handling notes. Memory stayed
bounded; the allocation profiler could not resolve structural product churn
above its own fixed overhead, so its zero must not be read literally.

**Decisions.** Accept benchmark v2 as a pass for the pure-Dart performance gate.
Preserve benchmark v1 and its failure, and make no further timing-driven change
to the optimized implementation. Treat the allocation net as below probe
resolution, not proof of allocation-free execution. Keep the oldest-supported
iOS and Android note-storm and accessibility checks as separate hands-on release
gates.

**Next.** Commit this result record and status updates. Then perform the frozen
hands-on MIDI behavior, accessibility, and device note-storm checks before the
release-candidate freeze. The untouched 808-song POP909 reserve remains closed
until every preceding product gate is complete.
