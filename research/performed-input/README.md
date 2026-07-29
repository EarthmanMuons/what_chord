# Performed Input

Every accuracy number the engine had earned was measured on clean input:
complete chords, all notes arriving together, boundaries taken from the
annotations themselves. Nobody plays like that. Real performances arpeggiate,
blur under the sustain pedal, and arrive one note at a time, and the app has to
decide for itself where one chord ends and the next begins. How accurate is it
on that?

**Status:** complete. Both rulers frozen, all avenues resolved,
[held-out split](../GLOSSARY.md#development-split-and-held-out-split) spent.

## What came out

- **The first honest live number**, along with a decomposition of what it
  contains, because the raw figure is easy to misread in both directions. See
  Results below.
- **A flicker problem that was not an accuracy problem.** The displayed chord
  name changed more than five times a second during real playing, and nearly
  half of all displayed time went to labels that lived under half a second. The
  analyzer was not confused; the screen was simply wired to every intermediate
  guess. Routing the display through the machinery that already decides what
  counts as a chord beat every alternative on every axis at once, and shipped.
- **Three engine ideas measured and declined**, each for a different reason:
  filtering pedal-held notes removes the harmony along with the blur, because
  pianists use the pedal to hold real chords; matching the analyst's choice of
  root would mean optimizing away from the naming conventions the app promises;
  and treating the highest extra note as melody only describes a quarter of the
  cases.
- **A textbook-voicing worry closed.** Across 7,834 real octave layouts the
  engine kept the same name 99.3% of the time, so the synthesized pools every
  earlier number used were not hiding a sensitivity to how a chord is spread
  out.

## Results

Held-out performed input, twelve unseen Beethoven movements: **0.551 exact**,
against 0.602 on development. The development figure should be described as
exactly that, not as the accuracy of the app.

**How to read 0.551, because it is easy to misquote.** It measures agreement
with a _functional analysis_ [ruler](../GLOSSARY.md#ruler): the share of
displayed time where the app's top name matches what a Roman-numeral analyst
wrote. The app names the sounding sonority and the analyst names the harmonic
function, and those differ for principled reasons the engine cannot and mostly
should not fix. The disagreement splits three ways:

| Bucket   | Share of displayed time | What it is                                           |
| -------- | ----------------------- | ---------------------------------------------------- |
| absent   | 13.0%                   | the analyst's chord was never literally played       |
| partial  | 18.9%                   | the app named the sounding part of it                |
| playable | 12.4%                   | every chord tone was there, app named something else |

Only the last is engine-actionable. Credit the never-voiced labels and the
figure is 0.681; credit the defensible partial readings too and it is 0.870. So
**0.551 is the strictest honest reading and 12.4% is the real error budget**,
and both belong in any sentence that quotes the number.

## Where this fits

The measurement was overdue rather than novel. The corpus identity numbers the
engine already had (98.8% on classical, 94.2% on held-out jazz) score
synthesized voicings, so they are blind by construction to everything the input
path introduces: segmentation boundaries, non-chord tones, pedal overlap, and
partial arrivals. The older oracle-comparison harness had reached diminishing
returns, finding debatable names rather than product misses, and weighting a
dense chromatic cluster the same as a shell voicing someone actually plays.

What it handed on: the engine-actionable remainder is concentrated in one shape,
the ranker folding an extra sounding note into a bigger chord name. That became
[Tone Pricing](../tone-pricing/README.md), which measured it and declined to
change it.

One avenue is shelved rather than closed. The engine has no concept of a melodic
voice riding above a held harmony, so a sustained melody note renames the chord
underneath it. The honest fix is polyphonic voice separation through time, a
substantial project priced against the roughly 3.7% of displayed time it could
recover.

## Contents

- [Protocol](PROTOCOL.md): inherited discipline, both frozen rulers, the split
  rules, and the adoption bar.
- [Log](log/): dated, append-only record of every experiment and decision. The
  holdout pre-declaration ([-12](log/2026-07-28-12-holdout-predeclaration.md))
  and its results ([-13](log/2026-07-28-13-holdout-results.md)) close the
  initiative.

## License gate

ASAP is CC BY-NC-SA 4.0 and the When in Rome Beethoven-sonata analyses are not
in the license-verified group set, so all fixtures derived from them stay under
`build/`; the extractors refuse to write inside `research/`. Frozen splits and
manifests, which contain no corpus content, live in this directory.
