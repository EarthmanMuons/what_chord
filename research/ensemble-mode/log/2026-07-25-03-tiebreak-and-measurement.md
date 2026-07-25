# 2026-07-25: Tiebreak, gate and corpus measurement, holdout confirmation

**Goal.** Complete Phase 3: land the dominant-preference tiebreak, replace the
chord-context simulation with real-engine measurement on the gate suite and the
DCML rootless synthesis, verify the performance budget, and confirm on the
held-out split.

**Setup.** Engine as of Phase 2 (log entry 2026-07-25-02) plus the tiebreak rule
below. Harnesses `tool/chord-context/comping_gate.dart` and
`tool/chord-context/rootless_corpus.dart` extended with real-engine arms that
call `analyze()` under `PlayingContext.ensemble` (gate solo cases run solo,
guarding mode-off behavior). Fixtures: dcml-distant-listening-v1-span, split
file `research/chord-context/data/splits/dcml-distant-listening-v1.json`.

```sh
dart run tool/chord-context/comping_gate.dart \
  --suite research/chord-context/data/sources/comping/comping-suite-v1.json
for mode in stable balanced reactive; do
  dart run tool/chord-context/rootless_corpus.dart \
    --fixtures build/chord-context/fixtures/dcml-distant-listening-v1-span \
    --labels build/chord-context/labels/dcml-distant-listening-v1-span.labels.json \
    --split-file research/chord-context/data/splits/dcml-distant-listening-v1.json \
    --split development --behavior $mode \
    --out build/chord-context/rootless/dcml-dev-$mode-engine
done
# Held-out spend (once, declared result set): same loop with
#   --split test --out build/chord-context/rootless/dcml-test-$mode-engine
./tool/benchmark.sh --check
```

**What happened.**

1. **Tiebreak v1 is a single rule and it suffices.** "Prefer dominant reading
   among implied roots" fires only between two implied-root candidates in a
   near-tie and prefers the dominant-family one. It slots in directly after the
   key-functional-seventh rule, ahead of the generic diatonic and tonic
   tie-breakers that otherwise pick the tonic-stack reading of a rootless
   dominant (F-B-E in C as Cmaj7(11) over G13). The guide-tone completeness
   reward from the design sketch was not needed: template legality already
   guarantees complete guide tones, and cost ordering handles the rest.
2. **Gate suite: 18/18 exact.** All 12 rootless and shell cases name top-1
   exactly (baseline was 0/12), including both dominant-vs-tonic-stack shells,
   and all 6 solo guard cases are unchanged. Committed as package CI tests
   (`packages/whatchord/test/comping_suite_test.dart`).
3. **Corpus, development split (13,197 events).** Engine top-1 exact
   (root+quality) under the closed-loop inferred key: 92.7% (stable), 93.0%
   (balanced), 93.2% (reactive), against simulated floors of 81.9/82.4/83.1 and
   tiebreak ceilings of 93.0/93.2/93.4. Under the annotated key: 95.9%
   (simulated unique-correct 89.2%, ceiling 96.1%). The engine lands at the
   ceiling because its ranking resolves nearly the whole ambiguous bucket and
   its richer color handling (e.g. sharp-nine dominants) reaches some readings
   the simulation's strict legality filter missed.
4. **Held-out split (2,299 events, spent once for this declared result):** 92.5%
   (stable), 93.6% (balanced), 93.2% (reactive) under the inferred key; 96.7%
   under the annotated key. Development results replicate.
5. **Performance: PASS.** `tool/benchmark.sh --check` passes; all deterministic
   counters (roots considered, templates evaluated, candidates produced/ranked)
   are unchanged, confirming the solo path executes identically.
6. **Suite data correction.** The guard case `guard-minor-ii065-inversion`
   (F-Ab-C-D as Dm7b5/F) listed `extensions: ["eleven"]`, but D's eleventh (G)
   does not sound in that voicing; every tone is a chord tone. The field was
   never exercised (the harness scores solo cases by root+quality), so the error
   was inert. Corrected to `[]` in comping-suite-v1.json.
7. **Remaining misses** under the inferred key are dominated by dominant7 and
   halfDiminished7 in exactly the proportions of the key-error residual the
   chord-context work attributed to local-key detection (its entry
   2026-07-20-18); the annotated-key gap (~96% vs ~93%) confirms most of what is
   left is key error, not naming error.

**Plain-English reading.** With the mode on, the app now names about nine-in-ten
rootless comping voicings exactly right using only the key it infers from your
playing, and about 24 of 25 with a perfect key. The app without the mode gets
zero of these. The measured result slightly beats what the research predicted
was reachable, and it holds on data the tuning never saw. Most of what is still
missed traces to the key detector momentarily holding the wrong key, which is a
separate, already-scoped WhatKey initiative.

**Decisions.**

- The protocol (`../PROTOCOL.md`) is FROZEN as of this entry. Its text is
  unchanged since initiative start; the freeze is recorded with, rather than
  before, the first measurement, and nothing in it was retuned against these
  results.
- The adoption bar is met on all four points: solo invariance (bit-identical
  goldens, unchanged counters, benchmark pass), acceptance suite 12/12 and 6/6
  in CI, corpus floor exceeded by ~10 points on dev and held-out, and the
  tiebreak shipped measured rather than estimated.
- The tiebreak stays minimal (one rule). The off-idiom exception from Phase 2
  survives measurement: it costs nothing detectable against the floor.
- Engine work for ensemble mode is complete pending Phase 4 app integration; the
  held-out spend is recorded here as the one permitted use for this result set.

**Next.**

- Phase 4: app integration (settings toggle, presentation, history event field,
  deep links, lookup, demo pin, web/CLI parity).
- Phase 5: algorithm article, changelog, whatsnew, closing entry.
