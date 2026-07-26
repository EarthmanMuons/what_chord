# 2026-07-26: Minor-evidence relative tilt is negative in both forms

**Goal.** Design and measure the last open avenue from entry -07: an asymmetric
mechanism supplying the vote the profiles cannot cast, against the measured
claimed-minor lean of the relative confusion.

**Setup.** Engine at the shipped defaults (cadenceBoost 4) plus a new
`HmmKeyDetector` option pair, byte-identical off: `relativeEvidenceTilt`
(log-odds toward the major twin of every relative pair on events without
minor-defining evidence for that pair's minor key, pair sums conserved) and
`relativeEvidenceWindow` (how many recent events the gate looks across; window 1
is per-event). Minor-defining evidence: the minor key's raised seventh sounding,
or a minor-tonic-quality chord on its root. The structural rationale was first
confirmed at the profile level: the Albrecht-Shanahan minor profile spreads
weight across both sixths and both sevenths, so every relative-major scale tone
carries at least 0.061 minor weight while minor-specific content votes hard
against the major twin (G sharp against C major carries 0.009); sustained major
content therefore never contradicts the relative minor. Recipes pin both options
at their neutral values.

```
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --decay-half-life-seconds 1 \
  --relative-evidence-tilt 0.5 --relative-evidence-window 8 \
  --out build/whatkey-local/wir-dev-hl1-ret0.5-w8
```

**What happened.** When-in-Rome dev, exact on claimed (base is the shipped
default):

| Config             | Stable | hl1    |
| ------------------ | ------ | ------ |
| base               | 0.4548 | 0.5553 |
| tilt 0.5, window 1 | 0.4307 | 0.5417 |
| tilt 1, window 1   | 0.4113 | 0.5096 |
| tilt 2, window 1   | 0.3886 | 0.4727 |
| tilt 0.5, window 8 | 0.4479 | 0.5472 |
| tilt 1, window 8   | 0.4400 | 0.5442 |

Monotone harm in the per-event form, at both timescales, with MIREX moving the
same way and stable spurious p90 rising 1 to 2. The windowed form, built after
the per-event failure showed the gate punishing genuine minor passages between
cadences (the raised seventh sounds at cadences, not in every chord), recovers
most of the damage but never crosses its baseline on exact or MIREX at any dose.
No guard runs were needed; the primary ruler refuted the mechanism directly.

**Plain-English reading.** The idea was: if nobody has played the sharpened
leading tone of a minor key recently, lean toward reading the passage as the
relative major. The classical corpus says no: real minor music spends long
stretches between cadences without that note, and the lean mislabels those
stretches faster than it fixes the majors being mislabeled as minors. Widening
"recently" from one chord to eight softens the mistake but never turns it into a
win.

**Decisions.**

- The avenue is closed as measured-negative in both its per-event and windowed
  forms. Both options stay in code at neutral defaults, matching the
  relative-tilt precedent.
- The claimed-minor lean in the DCML residual (entry -07) stands as a
  characterization without a validated mechanism. Any future attempt should note
  what failed here: per-event and short-window absence gates on the raised
  seventh, in the conserving-tilt construction.

**Next.** No open detector avenues remain in this initiative. The holdout
question is explicitly paused for further discussion before any test-split
evaluation, and no test-split runs have occurred.
