# Automatic polychord product performance benchmark v1

Status: preregistered benchmark design for `polychord-output/3`. This document
operationalizes the performance budget already frozen in
`output-evaluation-contract.md`; it does not change the 5% limit. The timed run
must begin from a clean commit containing this document and the complete
benchmark harness.

## Question and boundary

Measure the incremental pure-Dart cost of the automatic polychord engine beside
the unchanged primary `ChordAnalyzer`. The benchmark includes onset tracking,
candidate generation, candidate-bound evidence, raw selection, authorization,
display reduction, immutable diagnostic observations, and `toJson()` map
construction. It does not measure Flutter, Riverpod scheduling, rendering, BLE
transport, or platform accessibility. Those remain covered by the hands-on
device and note-storm gate.

The timed diagnostic path calls `PolychordProductObservation.toJson()` but does
not UTF-8 encode the returned object. The app does not continuously encode JSON;
reporting core engine time separately from engine-plus-`toJson()` time prevents
the diagnostic requirement from being mistaken for visible UI overhead.

## Frozen workloads

### Ordinary snapshot corpora

Use the same inputs as the established primary benchmark:

- all 352 entries in `tool/chord/oracle_reviewed.json`; and
- all 81 entries produced by `benchmark/src/common_voicings.dart`.

Project each `ChordInput` into one deterministic compact MIDI voicing. Place its
bass at `36 + bassPc`; traverse pitch classes upward from the bass and place
each present pitch class once at its first occurrence. Fail closed unless
`noteCount` equals the number of present pitch classes and the declared bass is
present. This prevents the benchmark from inventing register or octave doublings
absent from the source fixture.

For temporal setup, attack the lower half of the projected notes synchronously
at time zero and the upper half synchronously at 80 milliseconds. Odd-cardinal
collections assign the smaller half to the lower cohort. These are authored
benchmark times, not claims about the source voicings.

Workload validation found zero structural polychord candidates in both ordinary
corpora. That is retained as an expected fast-path fact, not hidden or repaired
after inspection. The policy-bearing structural controls below ensure the
benchmark also exercises the nonempty candidate path.

### Policy-bearing structural controls

Use these five already-frozen product-suite realizations:

| Benchmark ID             | Product fixture                                     | Branch exercised                         |
| ------------------------ | --------------------------------------------------- | ---------------------------------------- |
| `basic-positive`         | `product-basic-positive-80.json`                    | positive onset-bound selection           |
| `upper-seventh`          | `product-upper-seventh-80.json`                     | complete seventh chord in the upper unit |
| `assignment-ambiguity`   | `product-assignment-ambiguity-80.json`              | multiple exact assignments               |
| `multiple-identities`    | `product-lower-seventh-multiple-identities-80.json` | multiple structural identities           |
| `seventh-extension-veto` | `product-rooted-seventh-extension-80.json`          | integrated-tertian veto                  |

The harness copies their exact MIDI notes and cohort boundary into a small typed
fixture whose unit test asserts the selected and abstaining branches. It does
not read expected labels during timing. The five controls contain 35 note-on
frames and at most two candidates per frame.

### Stress traces

Two named traces sit outside the percentage gate and are reported directly:

1. `full-midi-range`: attack MIDI notes 0 through 127 one millisecond apart,
   press sustain, release all 128 notes one millisecond apart while they remain
   sustained, then release sustain. This is 258 events and repeatedly exercises
   the maximum supported sounding range.
2. `positive-reattack`: build the registered `C|Gm` positive, promote it through
   a pedal event at the inclusive display deadline, release and reattack one
   sustained note, release every key, then release pedal. This is 16 events and
   covers selection, appearance, binding invalidation, and clear.

Both stress timings include `toJson()` map construction after every event.

## Timing measurements

Use the existing allocation-free reference workload and adaptive sampler:

- five warmups;
- at least 30 and at most 300 samples;
- target 95% relative confidence half-width of 1.5%; and
- the existing wall-clock caps.

Report raw microseconds and normalized time. All cross-path ratios are computed
inside one process; the normalized values remain for comparability with the
primary benchmark.

For every ordinary and structural case, measure:

1. `primaryFinal`: one cold `ChordAnalyzer.analyze()` call on the complete
   voicing, with cache clearing outside the timed region;
2. `productCoreFinal`: prepare all but the last note outside the timed region,
   then time the final `PolychordProductEngine.observeEvent()` call;
3. `productSerializedFinal`: the same final event plus observation `toJson()`;
4. `primaryEntry`: cold primary analysis after every growing note-on prefix; and
5. `productSerializedEntry`: product observation plus `toJson()` after every
   note-on event.

Preparation, engine reset, event-list construction, and analyzer cache clearing
remain outside timed regions. Engine object construction is excluded because the
app owns one long-lived engine, not one engine per note or chord.

## Frozen gate

For oracle, common, and structural workloads independently:

```text
productSerializedFinal mean / primaryFinal mean <= 0.05
```

Propagate the two within-run 95% relative confidence intervals in quadrature.
Classify a corpus:

- `pass` when the point estimate is at most 5%;
- `indeterminate` when the point estimate exceeds 5% but its lower confidence
  bound does not; and
- `fail` when the lower confidence bound exceeds 5%.

`--check` succeeds only when all three workloads pass. Requiring the structural
controls as well as the originally named ordinary corpora is a conservative
addition; it does not weaken or reinterpret the frozen budget.

The whole-entry ratio is descriptive. It estimates cumulative incremental work
while a chord is constructed, using matching growing-note frames, but it does
not replace the final-event gate.

## Allocation and bounded-state measurements

Use the existing VM-service allocation probe on both the oracle and structural
workloads. With one long-lived product engine, report:

- churn bytes and objects per musical event;
- retained and live heap after one complete serialized pass; and
- retained heap growth after 20 additional complete passes.

The engine has no temporal-history cache. Repeated-pass retained growth is a
bounded-state diagnostic, not an exact zero-byte gate because VM-service and GC
measurements carry process noise. Any growth suggesting history-proportional
retention requires investigation before adoption.

Report candidate counts per frame and per final case with count, minimum,
median, nearest-rank p90, maximum, and total. Report serialized diagnostic bytes
outside the timed region.

## Commands and artifacts

Run from a clean committed tree:

```sh
tool/benchmark.sh --check
tool/polychord_benchmark.sh --check
```

The dedicated command writes `benchmark/polychord_last_run.json`, which remains
an uncommitted latest-run artifact. The dated result log must pin the clean
commit, harness and workload hashes, corpus hashes recorded in the JSON, exact
commands, raw headline numbers, gate status, candidate distributions, memory,
and stress results. A failed or indeterminate gate is retained as a result and
blocks the current release candidate; it is not tuned away silently.

No development or held corpus is opened by this benchmark. In particular, the
808-song POP909 reserve remains untouched.
