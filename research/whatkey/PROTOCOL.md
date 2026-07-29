# WhatKey Evaluation Protocol

**Status: FROZEN 2026-07-07** (log entry 2026-07-07-06). Changes from here are
amendments: append a dated entry to the Amendments section and a log entry
explaining why, and never retune against data the amendment exposes. The
held-out test split has not been evaluated as of the freeze.

Frozen against: fixture set `when-in-rome-v1` (When in Rome corpus commit
`aa7539f1`, contrapunctus-bench commit `b9e011c8`), split
`data/splits/when-in-rome-v1.json`, behavioral suite `pop-jazz-v2` (at freeze:
`pop-jazz-v1`; see Amendments). The scoring implementation in
`tool/whatkey/src/scoring.dart` at the freeze commit is the normative
operational definition of every metric; this document states the rules in prose.

## Task definition

Streaming local-key estimation with abstention. The input is a causal stream of
`ChordEvent`s (see `lib/features/history/`): ranked chord candidates with
explanation costs, voicing, analysis-time tonality, timestamps, and hold
durations. After each event, the detector outputs either a ranked list of
`(Tonality, confidence)` hypotheses or an explicit abstention. The detector
never sees the future and is never re-run on edited history.

Two evaluation views over the same outputs:

- **Global key:** one claim per piece (the duration-weighted majority claim; see
  Metrics), for comparability with the published literature.
- **Local key:** the claim at each event, scored against time-aligned
  annotations, which is what the app actually displays.

**Label isolation.** Detectors receive only observation fields (timestamps,
durations, voicing, candidates); the harness structurally strips fixture
`labels` before events reach a detector, so ground truth cannot leak even by
accident.

**What is scored.** The top-1 claim is what every metric scores; the ranked
hypothesis list is diagnostic output. Scoring is event-weighted: each event
counts once regardless of its duration.

## Metrics

The metric set:

- **[MIREX-weighted](https://music-ir.org/mirex/wiki/2019:Audio_Key_Detection)
  key score** for near misses: exact 1.0, perfect fifth 0.5, relative
  major/minor 0.3, parallel major/minor 0.2. The weighting is only a scoring
  function, applied to our own corpora; scores are not comparable to MIREX
  leaderboard results, which were computed from audio on MIREX's own evaluation
  sets.
- **Time-aligned local-key accuracy**: fraction of evaluated events where the
  claim matches the annotated local key (also MIREX-weighted as a secondary
  view).
- **Modulation lag**: events between an annotated key change and the detector
  switching to the new key.
- **Stability**: spurious key switches per piece (switches not aligned to any
  annotated change).
- **Time-to-first-claim**: events before the detector first commits to any key.
- **Abstain calibration**: accuracy conditioned on claiming vs. abstaining; an
  abstention on genuinely ambiguous passages counts for the detector, not
  against it.

**Abstention scoring.** Accuracy metrics use the selective-prediction frame:
report **coverage** (fraction of events with a claim) and **accuracy on claimed
events** as an inseparable pair, never accuracy alone. Abstentions are not
errors; they reduce coverage. On events labeled ambiguous (`localKey` null with
`acceptableKeys`, hand-authored fixtures only), abstaining or claiming any
acceptable key is correct; such events are excluded from corpus-set accuracy
pools.

**Abstain calibration presentation** (pinned 2026-07-07, from the first sweep;
see log entry 2026-07-07-01): report the coverage-accuracy curve swept over the
detector's confidence threshold (`--sweep-margin-floors` in the harness), with
the selected operating point marked on it, not a single operating point alone.
Detectors whose confidence has no threshold report their one point.

**Posterior reliability diagnostic** (added 2026-07-08; log entry
2026-07-08-01): for detectors whose ranked output is a probability distribution
over keys (HMM, BOCPD), report top-label reliability on exact-labeled events:
mean top posterior, exact accuracy, expected calibration error (ECE), negative
log likelihood, and Brier score, both over all exact-labeled events and over
claimed exact-labeled events. Acceptable-key-only events are skipped because
they define a set of correct answers rather than a single probability target. In
plain terms, this asks whether a posterior of 0.8 is right about 80% of the
time. This diagnostic does not replace the coverage-accuracy abstention sweep
and must not be used to retune a spent test split.

**Switches.** Stability counts a switch only between consecutive claims with
different keys; an abstention followed by a claim of the same key as before is
not a switch. Abstaining under uncertainty must not be charged twice. A switch
is **spurious** only when the annotated local key did not change between the two
claims' events AND the new claim does not land on the annotated key; a lagged
catch-up switch onto the annotated key is never spurious.

**Modulation alignment** (pinned at freeze): every annotated local-key change
counts, with no minimum segment length. A change is **matched** when the
detector claims the new key at or after the change and before the next annotated
change (or the piece end); its lag is the event count from change to that claim.
Unmatched changes are **censored**, reported as a separate count and never
averaged into lag. Context for reading absolute rates: on the development split,
27% of annotated key segments last 2 events or fewer (local-key regions a causal
detector has essentially no window to claim), so censored counts include a
structural floor; comparisons between detectors are unaffected since all face
the same segments. A minimum-segment filter was rejected because it adds a
tunable threshold to a frozen metric.

**Global key** (pinned at freeze): the duration-weighted majority claim (the key
holding the largest duration-weighted share of a piece's claims), scored with
the MIREX weighting against the piece's first annotated local key. It is robust
to end-of-piece wobble and was empirically equal to or better than the
final-event claim everywhere observed; the final-event claim stays in the
per-piece report output as a diagnostic only.

Lag, stability, and time-to-first-claim trade off against each other; report all
three, never a single blended score.

## Corpora and splits

- **When in Rome** (RomanText annotations): time-aligned local keys and
  modulation boundaries. Corpus commit pinned in the freeze header above.
- **Hand-authored pop/jazz set**: I-V-vi-IV loops, ii-V-I chains, 12-bar blues,
  modal vamps, deliberately ambiguous progressions. Authored with labels before
  any detector sees them. This set is a directed behavioral suite, not a
  statistical sample: each fixture is a pass/fail probe of a known failure mode
  (abstention on vamps, stability through tonicizations, the harmonic-minor
  dominant). Report it per fixture and exclude it from pooled statistics and
  paired comparisons; statistical claims come from corpus-derived sets only.
- **ASAP** (performed piano MIDI, aligned scores, key-signature annotations):
  the bridge from quantized score events to realistic live input, replayed
  through the actual Phase 1 capture path.

**Split rules:** held-out test split by piece, and by composer where the corpus
allows, frozen and recorded in `data/splits/` before the first experiment (done:
`data/splits/when-in-rome-v1.json`). All tuning, ablation, and model selection
happens on the development split only. The test split is evaluated once per
reported result set, not per iteration.

**Harness discipline:**

- The harness runs the development split by default; evaluating the test split
  requires an explicit flag, and every test-split run gets a dated log entry.
- The harness validates that the split file's corpus and bench pins match the
  fixture manifest's, and fails if the fixture set's pieces do not exactly match
  the split; silently skipping missing pieces changes the sample.
- Results from different fixture versions are never pooled or compared in one
  report.

## Fixtures

Fixtures embed the engine's candidate rankings, and the engine gets retuned, so
fixtures are versioned like a dataset. Every fixture set records: engine commit,
generation script and parameters, corpus source and commit pins, and per-fixture
license/provenance. See `data/README.md`. Results are only comparable within a
fixture version.

Fixture candidates are ranked under a fixed neutral analysis context (default
`C:maj`), recorded in the manifest, never under the annotated key: several
ranking tie-breakers are tonality-gated, so ranking under ground truth would
leak the answer into the observations the detectors consume.

## Baselines

Our algorithms are only meaningful against external reference points on the same
fixtures:

- music21's Krumhansl-Schmuckler variants (Krumhansl-Kessler, Temperley,
  Albrecht-Shanahan profiles).
- justkeydding (Napoles Lopez et al. 2019), HMM with profile emissions.
- Internally, profile correlation (plan section 2a) is the floor every later
  model must beat to earn its complexity.

External baselines are offline and non-abstaining; they anchor the accuracy
metrics, while the streaming metrics are compared between our own variants.

## Ablations

Each ingredient toggles independently: profile pair, duration weighting, decay
weighting, recognizer-confidence weighting (cost gaps), and each functional
pattern detector. Recognizer-confidence weighting is the most novel claim and
gets the cleanest ablation: identical pipelines with it on and off.

## Reporting

- Per-piece results with paired comparisons across pieces; pooled event accuracy
  alone is not acceptable (a few long pieces dominate pools).
- Accuracy-like metrics (MIREX-weighted score, local-key accuracy): per-piece
  mean with a bootstrap CI95, and paired A/B comparisons via the Wilcoxon
  signed-rank test across pieces. One confidence level (95%) throughout; when a
  result is marginal, show the per-piece distribution rather than reaching for a
  different interval.
- Latency- and count-like metrics (modulation lag, time-to-first-claim, spurious
  switches): skewed, long-tailed distributions, so report the median and p90
  across pieces rather than means, with bootstrap CIs when an interval is
  needed.
- Always report n (pieces and events) alongside any aggregate. Fix and record
  the RNG seed for bootstrap resampling so intervals reproduce.
- Every experiment gets a dated entry in `log/` with the fixture version and
  engine commit it ran against.

## References

The MIREX weighting comes from the
[MIREX Audio Key Detection task](https://music-ir.org/mirex/wiki/2019:Audio_Key_Detection),
whose evaluation table is stable across task years. The paired test is the
[Wilcoxon signed-rank test](https://en.wikipedia.org/wiki/Wilcoxon_signed-rank_test)
(implemented in `tool/whatkey/compare.py`; plain-English explanation in
[GLOSSARY.md](../GLOSSARY.md)). Every other system, profile set, and corpus
named here (Krumhansl-Schmuckler variants and their profile pairs, justkeydding,
When in Rome, RomanText, ASAP) is cited with links in the
[design doc's references](temporal-context-key-detection.md#references).

## Amendments

- **2026-07-07** (log entry 2026-07-07-10): behavioral suite updated from
  `pop-jazz-v1` to `pop-jazz-v2`, adding one fixture, a two-chorus 12-bar blues.
  The single-chorus fixture ends on the V7 turnaround before the loop-seam
  cadence that identifies the blues tonic, so it under-tests the realistic
  looping case; both fixtures are retained. No corpus set, split, metric, or
  scoring change; the suite is per-fixture pass/fail and outside all pooled
  statistics, so no tuning contamination is possible.
- **2026-07-07** (log entries 2026-07-07-13/14/16/21): three corpus sets added
  under the existing split rules, no metric or scoring change. `asap-nc-v2`
  (ASAP performed piano MIDI, key-signature labels mode-unknown via
  `acceptableKeys`; split `data/splits/asap-nc-v2.json` frozen before any tuning
  on the set) and `isophonics-nc-v1` (Isophonics pop songs via ChoCo,
  section-key tonic-and-mode song keys; split
  `data/splits/isophonics-nc-v1.json`, likewise frozen first). Both are
  license-gated to `build/` (see `data/NOTICE.md`). `asap-wir-nc-v1` (ASAP
  performances labeled with When in Rome analyst keys) is evaluation-only: no
  tuning is permitted on it and every configuration run against it must be
  committed beforehand, so it carries no split.
- **2026-07-07** (log entries 2026-07-07-09/19): the justkeydding baseline is
  recorded as unmeasurable in this environment (unreproducible build); the
  external anchor obligation is met by the music21 analyzers alone, and no
  comparison claim against justkeydding is made in either direction.
- **2026-07-08** (log entry 2026-07-08-01): posterior reliability diagnostics
  added to the harness reports for probability-distribution detectors. This is a
  reporting diagnostic only: no detector parameters, splits, adoption rules, or
  existing accuracy/stability metrics change.
