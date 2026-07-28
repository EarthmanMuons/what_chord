# 2026-07-27: Pedal-demotion prototype rejected; the residual is a pricing question

**Goal.** Prototype the pedal-blur mechanism queued in log -09 against its
pre-declared expectation: added-tone pedalCarry and transientPress time falls
materially, exact rises on the development split, coverage roughly flat.

**Setup.** Provenance-carrying snapshots landed behind an option
(`sounding_snapshots(provenance=True)` adds a `held` list per snapshot and emits
held/sustained transitions the union-deduplication previously dropped; default
path byte-identical). `replay_batch.dart` gained `pedalDemotion` with two rules
applied before segmentation, both keeping physically held notes unconditionally:
`transient` drops sustained-only notes whose press was under 200 ms; `attack`
additionally drops sustained-only notes once any fresh attack lands after their
release. `asap_wir_extract.py` gained `--pedal-demotion off|transient|attack`
(suffixing the set name). Dart and Python checks green; nothing here ships in
the app.

```sh
.venv/bin/python tool/whatkey/asap_wir_extract.py ... --pedal-demotion transient
.venv/bin/python tool/whatkey/asap_wir_extract.py ... --pedal-demotion attack
.venv/bin/python tool/performed-input/identity_score.py \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2-pd-transient ...
.venv/bin/python tool/performed-input/provenance_census.py \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2-pd-transient ...
```

**What happened.** Development split, mean per piece:

| config       | coverage | exact | root  | members |
| ------------ | -------- | ----- | ----- | ------- |
| A0 baseline  | 0.493    | 0.595 | 0.737 | 0.525   |
| pd-transient | 0.377    | 0.564 | 0.719 | 0.534   |
| pd-attack    | 0.319    | 0.568 | 0.720 | 0.550   |

The mechanism works exactly as designed: the provenance census shows the
targeted time collapsing (added-tone family 17.6% of disagreement at baseline,
10.1% under transient, 5.5% under attack; transientPress share 22% to 3.5% to
1.5%; pedalCarry 25% to 17% to 2%). And the pre-declared expectation fails
anyway, decisively: coverage falls 12 to 17 points and exact drops 3 points
under both rules. Verdict: rejected, both rules.

The insight is why. Sustained-only notes are, on net, legitimate harmony: the
pedal is how pianists hold a chord while the hands move. Demoting by provenance
and timing removes the true chord (gutting voicings below the three-note capture
gate, hence the coverage collapse) about ten times more often than it removes
blur. The blur is real but inseparable from real harmony at the input layer;
nothing about a note's press length or release order says whether it belongs to
the chord.

What does know is the analyzer: its explanation-cost machinery already prices
unexplained tones against extended-quality readings. Every shape this initiative
has surfaced (the melody dwell named into Dm(maj7), the carried pedal tone named
into the new chord) is the same decision going the same way: the ranker prefers
absorbing an extra tone into a bigger chord name over naming the base chord and
leaving the tone unexplained. That threshold is a pricing question, squarely in
the oracle-comparison lever territory (explanation-cost scoring), and it unifies
the melody-absorption and pedal-blur buckets that provenance could not separate
into mechanisms.

**Plain-English reading.** We tried teaching the app to ignore notes the pedal
was holding, and it started ignoring the chords themselves: on real playing, the
pedal's notes are usually the harmony, so the filter threw out ten true tones
for every false one. The genuine fix lives elsewhere: the namer's willingness to
swallow one extra note into a fancier chord name, which is a costing dial we
already know from the oracle work, and it addresses the melody case and the
pedal case at once.

**Decisions.**

- Input-layer pedal demotion: rejected with the numbers above. The provenance
  tooling stays (it made this a one-day answer and remains the measurement for
  any future input-layer idea).
- The surviving engine direction for the added-tone family is ranking-side: the
  extended-name versus base-name-plus-unexplained-tone pricing threshold, to be
  scoped against the oracle-comparison pricing conventions (lever 4) with this
  ruler as the live-input check and pool continuity as the guard.

**Next.** Scope the pricing-threshold avenue: measure how much added-tone time
flips to exact if the top candidate's extended reading loses to the base-triad
reading when exactly one sounding tone goes unexplained, using the existing
near-tie and cost data in the fixtures before touching any engine code.
