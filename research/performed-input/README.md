# Performed Input

Surfacing the chord-identity accuracy issues that remain in the live streaming
use case. Every identity number the engine has earned so far rests on clean
synthesized voicings: complete, simultaneous, pre-segmented events built from
the annotations themselves. The product never sees that input. It sees
arpeggiation, passing tones, sustain-pedal blur, and asynchronous onsets, and
its events are whatever the segmenter decides they are. This initiative measures
that surface directly, and it captures the other unexplored angles on live
accuracy as ranked avenues so they are tackled deliberately instead of
opportunistically.

Status: complete. All avenues resolved (avenues 1 and 2 standing with two frozen
rulers, full attribution decomposition, and the display-policy frontier
replicated on POP909; avenue 3 closed; avenue 4 diligence done; avenue 5
shelved), and the held ASAP test split is spent, pre-declared and reported in
logs -12 and -13.

Headline, held-out performed input: **0.551 exact** on twelve unseen Beethoven
movements, against 0.602 on development, which should now be described as the
development figure rather than the accuracy of the app. The display gate's
structural claim reproduced cleanly on held-out music, which was the spend's
main purpose. Nothing was tuned in response, per the pre-declared rule.

**How to read 0.551, because it is easy to misquote.** It is agreement with a
_functional-analysis_ ruler: the share of displayed time where the app's top
name matches a Roman-numeral analyst's chord. The app names the surface
sonority, the analyst names the harmonic function, and those differ for
principled reasons the engine cannot and mostly should not fix. Of the 44.2% of
displayed time that disagrees on the holdout, the error census splits it:

| bucket   | share of displayed time | what it is                                                  |
| -------- | ----------------------- | ----------------------------------------------------------- |
| absent   | 13.0%                   | the analyst's chord was never literally played              |
| partial  | 18.9%                   | the app named the sounding sub-chord of the analyst's label |
| playable | 12.4%                   | the engine had every chord tone and named something else    |

Only the last is engine-actionable. Credit the never-voiced labels and the
figure is 0.681; credit the defensible sub-chords too and it is 0.870. So
**0.551 is the strictest honest reading and 12.4% is the real error budget**,
and both belong in any sentence that quotes the number. Roughly half the
development-to-holdout shortfall is harder-to-name content and roughly half is
engine-actionable, the latter concentrated in the superset-absorption bucket
that [Tone Pricing](../tone-pricing/README.md) measured and declined to change.

## Why now

- The oracle-comparison harness
  ([chord-oracle-comparison.md](../chord-oracle-comparison.md)) has reached
  diminishing returns. It enumerates an unweighted synthetic pool and flags
  disagreements with advisory libraries; after several review rounds the large
  structural clusters are triaged, and new passes mostly re-litigate rows
  already judged genuine ambiguity. It finds debatable names, not product
  misses, and it weights a dense chromatic cluster the same as a shell voicing
  someone actually plays.
- The corpus identity numbers (DCML solo 98.8%, held-out jazz ensemble 94.2%)
  score synthesized voicings, so they are blind by construction to errors the
  input path introduces: segmentation boundaries, non-chord tones, pedal
  overlap, and partial arrivals.
- The recent research rounds built almost every asset the missing measurement
  needs: ASAP performed MIDI replayed through the app's real capture path
  (`tool/whatkey/asap_extract.py`, pedal-aware, using the actual
  `ChordEventSegmenter`), performance-to-score downbeat alignment onto When in
  Rome analyses (`tool/whatkey/asap_wir_extract.py`), and Roman-numeral figure
  parsing (the contrapunctus tooling). The alignment script already parses chord
  figures and currently discards them, keeping only the keys.

## Avenues

Ranked by guessed priority and impact. Each avenue gets a scoping log entry
before any engine work, and negative scoping verdicts are recorded rather than
silently dropped.

1. **Performed-input identity benchmark** (complete and standing, logs -02
   through -12, holdout in 2026-07-28-12 and -13): ASAP performed Beethoven
   sonatas crossed with When in Rome harmony annotations, scored per annotated
   chord span with a time-weighted, coverage-style metric rather than one-to-one
   event pairing, because the segmenter's events will not align with annotation
   spans and that mismatch is part of what is being measured. Run with
   attribution arms from day one: live inferred key versus annotated key, and
   the app's segmentation versus annotation-boundary segmentation, so residual
   error decomposes into key context, segmentation, and analysis ranking. Only
   the last bucket is engine work; the first two would be the first ruler the
   input layer has ever had.
2. **Causal prefix stability** (complete and standing, logs -13 through -16 and
   2026-07-28-02): live, the label is recomputed as notes arrive, so there is a
   stability dimension no current eval touches. Replay corpus voicings note by
   note in performed onset order and measure label churn and
   time-to-final-label. Outcome: a frozen stability ruler, the finding that this
   was a display-policy problem rather than an analyzer one, and the
   segmenter-gated display now shipped, whose dominance held on the holdout and
   replicated on POP909.
3. **Frequency-weighted pool and observed voicings** (closed, logs 2026-07-28-03
   through -05): exposure weighting shipped as measurement support (committed
   POP909 weight table, weighted reporting in pool_diff and rule_ablation
   alongside unweighted counts); observed-voicing pool expansion dismissed by
   measurement (99.3% naming consistency across 7,834 real octave layouts).
4. **POP909 diligence** (done, log 2026-07-28-01): piano MIDI for 909 pop songs
   with chord and key annotations. Verdict: genuinely performance-flavored input
   (pedal, expressive velocity and timing) admitted under ASAP-style gating for
   the stability ruler and observed-voicing sampling; chord labels are
   machine-extracted (0.88 independent content agreement), so identity use is
   advisory-only, never headline ground truth.
5. **Voicing-structure awareness** (added from the log -09 provenance split;
   scoped and shelved in log -16): the engine has no concept of a melodic voice
   riding above a held harmony, so sustained melody dwells rename the chord
   underneath (a held C# over D minor displays as Dm(maj7)). Topology census:
   only a quarter of the added-tone family has a separable top voice
   (register-rule ceiling about 1.2% of displayed time); the majority of extra
   tones are interior, so the honest version is polyphonic voice separation
   through time, a substantial project priced against the roughly 3.7% of
   displayed time it could recover.

## Contents

- [Protocol](PROTOCOL.md): inherited discipline, both frozen rulers, the split
  rules, and the adoption bar.
- [Log](log/): dated, append-only record of every experiment and decision. The
  holdout pre-declaration (-12) and its results (-13) close the initiative.

## License gate

ASAP is CC BY-NC-SA 4.0 and the When in Rome Beethoven-sonata analyses are not
in the license-verified group set, so all fixtures derived from them stay under
`build/` (the extractors refuse to write inside `research/`, see
`research/whatkey/data/NOTICE.md`). Frozen splits and manifests, which contain
no corpus content, live in this directory once defined.
