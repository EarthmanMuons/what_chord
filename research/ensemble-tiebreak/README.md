# Ensemble Tiebreak

Ensemble mode could name rootless voicings, but some it still got wrong even
when it knew the right key. What is left over once key detection is no longer
the problem, and can better tie-breaking rules fix it?

**Status:** complete. Key-open admission plus two narrow guards shipped.

## What came out

- **The premise was wrong, and finding that out was the result.** The misses
  were not readings the engine ranked badly. They were readings it never
  proposed at all: the generator only hypothesized roots inside the current key,
  so a secondary or substitute dominant could never be named, and the in-key
  twin won by default. No tie-breaker can pick a candidate that does not exist.
- **The fix was to widen what gets proposed**, then guard against the readings
  that widening lets in. Out-of-key roots are now hypothesized, but they are
  only promoted when the colors are natural, which rejects the spurious tritone
  reading of a chord that is already sounding complete.
- **One pure coin flip needed deciding on principle.** A rootless
  half-diminished seventh and the major seventh a semitone below it leave
  identical sounding tones. Whichever root the key contains now wins, which
  restores protection the old in-key-only generator had been providing by
  accident.
- **A jazz benchmark exists now.** Every ensemble number before this rested on
  classical synthesis; the mode was built for jazz comping and had never been
  measured on it.

## Results

Held-out test split, one shot, [top-1 exact](../GLOSSARY.md#top-1-exact):

| Ruler                 | Before | After | Per-solo change   |
| --------------------- | ------ | ----- | ----------------- |
| Weimar jazz, stable   | 87.3%  | 94.2% | 41 wins, 0 losses |
| Weimar jazz, reactive | 85.5%  | 93.1% | 46 wins, 0 losses |

Development split: Weimar 83.7% to 92.9%, and the classical DCML corpus improved
alongside it rather than paying for the jazz gain, 92.8% to 96.5% under the
app's inferred key.

**Reading these numbers.** They count only how often the top-ranked name matches
the reference exactly, on a corpus of real recorded jazz solos with per-solo
keys. Zero losses across 41 and 46 solos matters more than the headline: the
change is not a trade that helps some pieces and hurts others. The comping suite
passes exactly and solo analysis stays bit-identical throughout, so nothing
outside ensemble mode moved.

## Where this fits

[Ensemble Mode](../ensemble-mode/README.md) shipped the capability and measured
it on classical synthesis. [WhatKey Local](../whatkey-local/README.md) then
closed the key-detection side, which is what made this initiative possible:
until the key was reliable, there was no way to tell a naming error from a key
error.

The corpus that made it measurable was already on disk. The Weimar Jazz Database
(456 solos, real jazz vocabulary, per-solo keys) ships inside the ChoCo checkout
the project already pins.

Still open: a resolution-aware relabel of ensemble history, scoped in log entry
[-03](log/2026-07-26-03-later-shapes-dispositioned.md).

## Contents

- [Protocol](PROTOCOL.md): rulers, guards, and adoption bar; inherits the frozen
  chord-context protocol.
- [Log](log/): dated, append-only record of every experiment and decision.
- Data: the frozen split is
  [weimar-comping-v1.json](data/splits/weimar-comping-v1.json); fixtures are
  build-only, with attribution recorded in their manifest.

Supporting code lives in `tool/chord-context/` (`weimar_extract.py`,
`freeze_weimar_split.py`); measurement reuses `rootless_corpus.dart` unchanged.
Engine changes land in `packages/whatchord/` and must keep solo analysis
bit-identical.
