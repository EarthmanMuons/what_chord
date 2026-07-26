# 2026-07-26: Hindsight and provenance arms; relative residual mined

**Goal.** Measure the three open avenues from entries -04/-06: the sticky-key
dilution in the ensemble filter, the one-event-lag hindsight ceiling (the
retro-relabel question), and the structure of the relative-confusion residual.

**Setup.** Engine commit 9436ff0e (shipped cadenceBoost 4).
`rootless_corpus.dart` restructured to two passes: the detector's sticky claim
and claim freshness are precomputed per event, then scoring adds an
`engineHindsightExact` arm (key = sticky claim after event i+1, the ceiling for
relabeling a history entry one event later) and exact-by-provenance for the
inferred arm (fresh = claimed at the previous event; carried = an older claim
held through abstention; fallback = no claim yet). `key_error_diagnostic.dart`
relation buckets now carry direction tags for relative and parallel.

```
dart run tool/chord-context/rootless_corpus.dart \
  --fixtures build/chord-context/fixtures/dcml-distant-listening-v1-span \
  --labels build/chord-context/labels/dcml-distant-listening-v1-span.labels.json \
  --split-file research/chord-context/data/splits/dcml-distant-listening-v1.json \
  --split development --behavior reactive \
  --out build/whatkey-local/rootless-dev-reactive-hindsight
```

**What happened.**

Ensemble arms on DCML dev (shipped boost), engine top-1 exact:

| Behavior | Live inferred | Hindsight (one event) | Annotated oracle |
| -------- | ------------- | --------------------- | ---------------- |
| stable   | 92.8%         | 92.9%                 | 95.9%            |
| reactive | 93.5%         | 94.7%                 | 95.9%            |

Provenance of the key the inferred arm used (exact/total):

| Behavior | Fresh             | Carried          | Fallback       |
| -------- | ----------------- | ---------------- | -------------- |
| stable   | 93.0% (11,694 ev) | 91.0% (1,365 ev) | 94.9% (138 ev) |
| reactive | 94.3% (11,156 ev) | 88.7% (1,912 ev) | 94.6% (129 ev) |

Readings:

- At stable, hindsight is worth +0.1 points: the stable detector mostly never
  adopts the local key at all, so seeing its claim one event later reveals
  nothing new. The announcing-dominant residual (180 events here) is not
  recoverable through the stable detector's own later claims.
- At reactive, hindsight is worth +1.2 points, recovering half of the 2.4-point
  oracle gap. The reactive detector does reach the local key, just one event
  late for the announcing dominant. This revives the hindsight mechanism that
  chord-context log 2026-07-20-15 measured dead (retroKey): that null was for
  solo naming of full voicings, where the key barely matters; for rootless
  ensemble naming the key is load-bearing, and the same mechanism is alive.
- Sticky-key dilution is real at reactive: carried keys run 5.6 points behind
  fresh ones over 14.5% of events (roughly 0.8 points of headroom if carried
  events scored like fresh), and only 2 points behind over 10% of events at
  stable.
- A behavior-decoupling observation falls out of the live column: ensemble
  naming under the reactive key beats naming under the stable key 93.5% to 92.8%
  with identical engines. The app currently feeds ensemble naming whatever key
  preset the user displays; naming could consult a faster-timescale key
  internally while the visible indicator stays calm.

Relative residual structure (key diagnostic, shipped boost; share of claimed
events):

| Bucket                                 | Stable | Reactive |
| -------------------------------------- | ------ | -------- |
| relative, claimed minor vs major truth | 4.7%   | 3.4%     |
| relative, claimed major vs minor truth | 3.2%   | 3.0%     |
| parallel, claimed major vs minor truth | 1.6%   | 1.4%     |
| parallel, claimed minor vs major truth | 1.2%   | 1.1%     |

The relative confusion leans claimed-minor against a major truth (4.7 vs 3.2 at
stable), the opposite of a naive major-bias story. A plausible cause is
structural: the evidence and scale masks give minor keys the natural union
harmonic scale, eight pitch classes that fully contain the relative major's
seven, so sustained major-key content never contradicts the relative minor
hypothesis. Exactness at the shipped boost, for the record: stable 63.9%,
reactive 65.9% (up from 61.1% and 65.7% pre-boost).

**Plain-English reading.** Three follow-up hopes, three verdicts. Waiting one
chord before finalizing a history entry's name is nearly worthless in stable
mode but recovers half the remaining key-related ensemble errors in reactive
mode, because the reactive detector really does catch up one chord later.
Holding onto an old key through silence costs a measurable amount in reactive
mode. And the detector's relative-key mistakes lean toward calling a major
passage by its relative minor, probably because our minor scale definition
swallows the whole relative major scale, so nothing a major passage plays ever
votes against the minor twin.

**Decisions.**

- The retro-relabel front is revived for ensemble history naming specifically,
  with measured ceilings: about +1.2 points at reactive, +0.1 at stable. Scoped
  as an ensemble-mode/history follow-up (relabel a history entry when the
  detector's claim changes on the following event), distinct from the dead solo
  retroKey.
- The decoupled naming key (fast internal key for ensemble naming, calm display
  key) is recorded as a product-shaped candidate worth +0.7 points for
  stable-display users, pending a product decision on whether naming and display
  may disagree.
- The relative-residual lead is the minor-mask asymmetry; the candidate
  mechanism is an asymmetric penalty when the minor hypothesis lacks
  minor-defining evidence (its leading tone or tonic-quality chords), which is
  emission-side but conserving in the mode-tilt style. Not designed here.

**Next.**

- Bring the three scoped candidates (ensemble hindsight relabel, decoupled
  naming key, minor-evidence asymmetry) to a product/design decision before
  further engine work; all further gains on the ensemble surface now depend on
  choices outside the detector defaults.
- Holdout remains untouched.
