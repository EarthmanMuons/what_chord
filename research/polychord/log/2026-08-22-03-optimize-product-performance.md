# 2026-08-22: Optimize the automatic product path

**Goal.** Reduce the product-path costs exposed by the failed v1 measurement
without changing candidate generation, selector policy, evidence thresholds,
display behavior, or diagnostic output, and use exploratory timing to identify
any measurement defects before registering a replacement benchmark.

**Setup.** Optimization began from clean commit
`f5cfd7e105c06107e97333b1e6f255b0a0f192d0`, after the negative result was
committed in log 2026-08-22-02. The frozen oracle, common, and five-case
structural workloads remained unchanged. No held data was opened. Intermediate
timings were explicitly exploratory runs on a dirty tree rather than adoption
results:

```sh
tool/polychord_benchmark.sh --check \
  --out=/tmp/polychord_optimized_exploratory.json
tool/polychord_benchmark.sh --check \
  --out=/tmp/polychord_optimized_exploratory_2.json
tool/polychord_benchmark.sh --check \
  --out=/tmp/polychord_optimized_exploratory_3.json
dart run benchmark/polychord_stage_profile.dart
```

`benchmark/polychord_stage_profile.dart` was a temporary, uncommitted
development profiler and was removed after use. It cannot reproduce the
intermediate implementations from git and its numbers are not formal results.
Its role was limited to assigning remaining cost to structural generation,
record construction, selection, tracking, and publication.

The final implementation and equivalence-test pins after formatting are:

| Artifact                        | SHA-256                                                            |
| ------------------------------- | ------------------------------------------------------------------ |
| Register candidate generator    | `ee24d8e11a30bced63c02f08aed19ca68d1ec2a7ea2e7f9438dc724a87052e6d` |
| Product onset selector          | `26555ac9f6730d6bcfaede93a38bf637b98b709762c5f9c1823b77855d8dd4ba` |
| Static register selector        | `532954af95b34e28400a62c374976435df6f3358e541327f0e8f00d94d7ccd0a` |
| Generator equivalence test      | `76daac59185b3214647d65fe80804e8254155c910b476f3ad27c6d14e4cbf698` |
| Product-policy equivalence test | `2ba2d457865c9c551742431a5263828dba134b066df80a4aa1103897e7063dd1` |

## What changed

The generator now computes prefix and suffix pitch-class masks while scanning
adjacent register boundaries. A layer can match the frozen vocabulary only when
it contains three or four distinct pitch classes, so impossible boundaries are
discarded before allocating note slices or matching roots. Matching, shared
pitch classes, and the integrated-tertian veto now use 12-bit masks instead of
temporary sets.

One package-internal generated-candidate set carries the validated MIDI notes,
their pitch-class mask, and the complete ordered candidates through evidence,
binding, and selection. The ordinary public entry points retain their existing
validation. The product path no longer regenerates the same candidates in the
evidence analyzer, binder, onset selector, and static selector. It also consumes
ordered internal records and static traces by index instead of rebuilding maps
and searching deep candidate values.

The optimized generator was compared with a direct copy of the preregistered
boundary scan on all 4,096 subsets of one chromatic octave, representative
octave-doubled cases, an all-128-note case, and the existing examples. The
optimized product decision was compared as complete JSON with the independently
validated and order-normalized record path across the 3,300-pair quality,
relative-root, and transposition matrix. Every comparison passed.

## Exploratory timing

The three development checkpoints were:

| Stage                          | Oracle core (us) | Common core (us) | Structural core (us) | Structural with `toJson()` (us) | Full-range trace |
| ------------------------------ | ---------------: | ---------------: | -------------------: | ------------------------------: | ---------------: |
| Shared generation and masks    |            2.765 |            2.252 |               25.705 |                          62.851 |          20.1 ms |
| Ordered selector intermediates |            2.723 |            2.252 |               22.891 |                          59.395 |          20.5 ms |
| Bit-mask integrated veto       |            2.679 |            2.206 |               16.601 |                          55.883 |          20.6 ms |

Against the formal v1 result, the final exploratory core means decreased about
80.9% on oracle, 76.9% on common voicings, and 64.9% on the structural controls.
The full-range serialized trace decreased from 415.1 ms to 20.6 ms, about 95.0%,
while the positive-reattack trace decreased from 664.1 to 422.4 microseconds.
Candidate counts and decisions were unchanged.

The temporary stage profiler's final run reported approximately 1.30
microseconds for generation, 2.35 for evidence and bound-record construction,
5.05 for the complete selector, 1.26 for the final tracker event, 0.17 for
observation construction, and 6.85 for one complete structural engine event.
Each stateless stage was repeated 10,000 times over all five controls; prepared
tracker and engine final events were repeated 3,000 times. These direct timings
are diagnostic approximations, not replacements for the adaptive benchmark.

## Measurement findings

The v1 structural core sampler timed only five final events per sample. On the
last exploratory run it reported a 16.601-microsecond mean but a
12.9-microsecond median, 8.4-microsecond minimum, 337.6-microsecond maximum, and
14.22% relative 95% confidence half-width after reaching the 300-sample cap. It
did not converge. The short batch makes isolated scheduler or runtime pauses
dominate its mean and prevents a defensible structural ratio.

The v1 gate also includes `PolychordProductObservation.toJson()`. The frozen v1
contract itself records that the app publishes immutable observations and does
not continuously construct JSON. The last exploratory run spent 16.601
microseconds in the measured live core and 55.883 microseconds in core plus
diagnostic map construction. Treating the latter as UI overhead therefore
answers a different question from the feature's actual event-path impact.

**Plain-English reading.** The implementation no longer repeatedly rediscovers
the same split, and an extreme all-notes trace is now about twenty times faster.
Ordinary non-polychord events add roughly two to three microseconds in the
exploratory run. A real structural event is also small in absolute terms, but
the current adaptive report cannot yet say exactly how small because it times
only five events at once and is distorted by occasional pauses. Most of the
remaining reported failure is creation of a large research JSON map that the
live app never creates.

**Decisions.** Preserve the 5% live-path budget and all semantic and diagnostic
contracts. Do not make diagnostic state lazy or remove fields merely to satisfy
a benchmark. Register benchmark v2 before another formal run with three
corrections justified by the failed v1 measurement: gate `productCoreFinal`,
report `toJson()` separately, repeat the same five frozen structural controls
within each sample until the timed batch is long enough to converge, and add a
null-control or repeated-event method for allocation churn. These changes alter
measurement validity, not the workload, product behavior, or budget.

**Verification.** `dart format .`, root and package import-order checks, root
and package analysis, the complete package test suite, the complete 263-test app
suite, and `git diff --check` passed. The app suite retained its existing six
skips.

**Next.** Commit the equivalence-guarded optimization and this exploratory
record. Then prospectively freeze benchmark v2 in a separate logical commit, run
it from that clean commit, and retain its result before any further tuning. The
separately identified Dart 3.13.1 primary-baseline maintenance remains a
distinct task.
