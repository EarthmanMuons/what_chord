# WhatKey Local

Music does not stay in one key. A piece in C wanders into G for eight bars, or
tonicizes a chord for two. WhatKey reports the stable key of a section, on
purpose, because a glanceable indicator that flickers is useless. So how much
closer can it follow those brief local keys before it starts flickering?

**Status:** complete. Four changes shipped, seven mechanisms closed by
measurement,
[held-out split](../GLOSSARY.md#development-split-and-held-out-split) spent.

## What came out

- **Key changes now weigh cadences.** Conditioning the detector's key
  transitions on cadential evidence was the one mechanism aimed squarely at the
  error structure, and the only one that had never been tried.
- **An arbitrary silence was removed.** The detector had refused to answer until
  it had heard three chords, a rule that predated the current model and had
  never been re-tested. Removing it lets the key indicator light on the very
  first chord, and the claims it makes that early are overwhelmingly right,
  because the confidence threshold was doing the real work all along.
- **Two smaller adoptions**: ensemble naming now runs under an internal
  faster-reacting key, and history entries are relabeled one event later, once
  the detector has heard the chord that resolves the ambiguity.
- **Seven mechanisms were measured and closed**, including a cold-start guess
  that the first chord is the tonic (jazz starts on ii often enough to make that
  actively harmful) and three separate attempts to lean between a key and its
  relative.

## Results

Held-out test splits, one shot per the pre-declaration in log entry
[-17](log/2026-07-26-17-holdout-predeclaration.md). Isophonics test, 41 tracks,
stable behavior:

| System                         | Coverage | Exact | MIREX |
| ------------------------------ | -------- | ----- | ----- |
| WhatKey today                  | 0.895    | 0.741 | 0.788 |
| WhatKey at the paper freeze    | 0.884    | 0.732 | 0.782 |
| music21 Krumhansl-Schmuckler   | 1.000    | 0.624 | 0.726 |
| music21 Temperley-Kostka-Payne | 1.000    | 0.637 | 0.740 |

**Reading the table.** [Coverage](../GLOSSARY.md#coverage) is how often the
system names a key at all, while
[exact and MIREX](../GLOSSARY.md#exact-vs-mirex-weighted) are two ways of
scoring the name it gives: exact counts only the annotated key, MIREX gives
partial credit for musically close misses. The offline baselines read the whole
song before answering and never abstain, which is a strictly easier setting;
their coverage is 1.000 for that reason, not because they are more willing.

Against the paper freeze, coverage rose significantly on both rulers while exact
held. The honest summary is that the detector now speaks more often without
being wrong more often. Against Krumhansl-Schmuckler at matched coverage, the
paper's careful "at least parity under a harder setting" strengthens to parity
or better, with an interval that no longer touches zero.

The three key-behavior presets against the same rulers:

| Preset   | Isophonics test       | When-in-Rome test     |
| -------- | --------------------- | --------------------- |
| stable   | 0.895 / 0.741 / 0.788 | 0.938 / 0.576 / 0.695 |
| balanced | 0.873 / 0.722 / 0.782 | 0.886 / 0.571 / 0.693 |
| reactive | 0.805 / 0.683 / 0.754 | 0.860 / 0.580 / 0.704 |

## Where this fits

Three finished initiatives left a contradiction on the record. The original
[WhatKey](../whatkey/README.md) work tested progression analysis twice and found
no benefit, while [Chord Context](../chord-context/README.md) and
[Ensemble Mode](../ensemble-mode/README.md) both concluded that key detection
was the thing limiting their accuracy.

[The local-key bottleneck](local-key-bottleneck.md) reconciles the two with the
recorded numbers. The short version: progression evidence is genuinely dead as
an ingredient in the detector's per-chord evidence, tested at every timescale,
twice. But local-key accuracy really was the downstream bottleneck. And the
errors are organized rather than random, with about a quarter of wrong claims
landing on the dominant, subdominant, or relative key, which is the signature of
a detector with no cadence model. That last observation is what this initiative
acted on.

## Contents

- [The local-key bottleneck](local-key-bottleneck.md): the founding document;
  settles the temporal-context debate with the recorded numbers.
- [Protocol](PROTOCOL.md): rulers, guards, and adoption bar; inherits the frozen
  WhatKey protocol.
- [Log](log/): dated, append-only record of every experiment and decision.

Supporting code: the WhatKey harness (`tool/whatkey/`) and the chord-context
diagnostic harnesses (`tool/chord-context/`) are extended in place. Detector
changes land in `packages/whatkey/` behind options that default to shipped
behavior.
