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

Status: open; scoping avenue 1.

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

1. **Performed-input identity benchmark** (active): ASAP performed Beethoven
   sonatas crossed with When in Rome harmony annotations, scored per annotated
   chord span with a time-weighted, coverage-style metric rather than one-to-one
   event pairing, because the segmenter's events will not align with annotation
   spans and that mismatch is part of what is being measured. Run with
   attribution arms from day one: live inferred key versus annotated key, and
   the app's segmentation versus annotation-boundary segmentation, so residual
   error decomposes into key context, segmentation, and analysis ranking. Only
   the last bucket is engine work; the first two would be the first ruler the
   input layer has ever had.
2. **Causal prefix stability**: live, the label is recomputed as notes arrive,
   so there is a stability dimension no current eval touches. Replay corpus
   voicings note by note in performed onset order and measure label churn and
   time-to-final-label. Gives blast-radius measurement a second axis: a price
   change can leave whole-voicing accuracy flat while making partial voicings
   flap on the way to the same answer.
3. **Frequency-weighted pool and observed voicings**: weight the oracle pool by
   ChoCo/iReal chord-symbol frequency so disagreements rank by expected musical
   exposure, and sample real observed voicings per label from the performed
   corpora instead of only canonical stacks, testing robustness to the doubling,
   omission, and register choices musicians actually make.
4. **POP909 diligence**: piano MIDI for 909 pop songs with chord and key
   annotations, which would complement classical DCML and jazz Weimar with the
   domain where fixture coverage is thinnest. License and annotation quality
   need diligence before any commitment.
5. **Voicing-structure awareness** (added from the log -09 provenance split):
   the engine has no concept of a melodic voice riding above a held harmony, so
   sustained melody dwells rename the chord underneath (a held C# over D minor
   displays as Dm(maj7)). About 3.7% of displayed time on the avenue 1 ruler,
   larger in user-visible weirdness; a structural research question (top-voice
   versus harmonic block), not an input-layer filter.

## Contents

- [Protocol](PROTOCOL.md): inherited discipline and the freeze plan; the ruler
  definition lands with the avenue 1 scoping entries.
- [Log](log/): dated, append-only record of every experiment and decision.

## License gate

ASAP is CC BY-NC-SA 4.0 and the When in Rome Beethoven-sonata analyses are not
in the license-verified group set, so all fixtures derived from them stay under
`build/` (the extractors refuse to write inside `research/`, see
`research/whatkey/data/NOTICE.md`). Frozen splits and manifests, which contain
no corpus content, live in this directory once defined.
