# 2026-07-26: Initiative start: corpus built, split frozen, jazz baseline

**Goal.** Open the initiative scoped in ensemble-mode log 2026-07-26-01: build
the jazz-comping ruler from the Weimar Jazz Database, freeze its split, and take
the baseline that defines the target list.

**Setup.** Engine at the shipped defaults (post whatkey-local). New tools:
`tool/chord-context/weimar_extract.py` (WJazzD symbols to synthesized voicings
plus a `chord-context-labels/1` sidecar of expected identities; candidates
attached under the fixed neutral C major context; current analysis profile) and
`tool/chord-context/freeze_weimar_split.py` (split by TUNE so all solos of a
standard share a side; an NC-only eligibility gate excludes the twelve free or
fully modal recordings WJazzD annotates without changes; the gate was added
after the first freeze attempt collided with the fixture validator, before any
scoring).

```
.venv/bin/python3 tool/chord-context/freeze_weimar_split.py \
  --choco-root build/whatkey-corpora/choco

.venv/bin/python3 tool/chord-context/weimar_extract.py \
  --choco-root build/whatkey-corpora/choco

dart run tool/chord-context/rootless_corpus.dart \
  --fixtures build/chord-context/fixtures/weimar-comping-v1 \
  --labels build/chord-context/labels/weimar-comping-v1.labels.json \
  --split-file research/ensemble-tiebreak/data/splits/weimar-comping-v1.json \
  --split development --behavior stable \
  --out build/ensemble-tiebreak/weimar-dev-baseline
```

**What happened.** Corpus: 444 of 456 solos extracted (the twelve
excluded-by-gate recordings have no changes), 26,861 events, 25,390 under a
plain major or minor per-solo key. Split: 295 tunes, 54 held out, 361
development / 83 test solos, committed at `data/splits/weimar-comping-v1.json`.
License: CC BY 4.0 via ChoCo, attribution in the fixture manifest; fixtures stay
under build/ by convention.

Baseline, development split, stable behavior, 18,122 scored rootless seventh
events:

| Arm                                        | Exact |
| ------------------------------------------ | ----- |
| shipped engine, no ensemble mode           | 0.0%  |
| ensemble engine, annotated (per-solo) key  | 83.4% |
| ensemble engine, inferred key              | 83.7% |
| ensemble engine, hindsight key (one event) | 84.0% |

Annotated-key miss shapes (3,017 misses):

| Expected, then chosen                         | Count | Share |
| --------------------------------------------- | ----- | ----- |
| dominant7, then dominant7 a tritone away      | 1,251 | 41%   |
| minor7, then the relative major triad         | 504   | 17%   |
| major7, then halfDiminished7 a semitone above | 457   | 15%   |
| dominant7, then dominant7 a minor third away  | 274   | 9%    |
| halfDiminished7, then major7 a semitone below | 182   | 6%    |
| dominant7Sharp5, then plain dominant7         | 116   | 4%    |
| remainder                                     | 233   | 8%    |

Readings:

- The genre gap is real and large: about ten points below the classical
  synthesis on either key arm. The classical numbers flattered the mode; this
  ruler is the one the mode was built for.
- The scoped confusion families dominate here too, reweighted: the tritone pair
  leads at 41%, the half-diminished/major-seventh semitone family appears in
  both directions (15% and 6%), and a shape classical barely showed is second
  overall: a rootless minor seventh collapsing to its relative major triad (the
  three sounding tones are exactly that triad). The top three families cover 79%
  of the residual.
- The inferred-key arm beats the annotated arm (83.7 against 83.4). WJazzD keys
  are one global key per solo, not local keys, so the live detector's local
  belief is often the better naming context. The "annotated" arm on this ruler
  is a fixed-key reference, not an oracle.

**Plain-English reading.** On real jazz changes with a bassist covering the
root, the ensemble mode names about five chords in six correctly, well below its
classical showing, and four out of five of its mistakes are three specific
confusions: which of two tritone-related dominants, whether a shell is the minor
seventh or its relative major triad, and whether it is the half-diminished chord
or the major seventh a half step away. Each has a cue in the key and bass the
engine already holds.

**Decisions.**

- PROTOCOL amendment (recorded before any tuning): the primary paired metric on
  the Weimar ruler is the INFERRED-key arm (the realistic product number, and
  better grounded than the per-solo fixed key), with the annotated arm reported
  alongside; the adoption bar's other clauses stand. The amendment is dated in
  PROTOCOL.md.
- Target list for the tiebreak work, in order: the tritone dominant pair, the
  minor-seventh versus relative-major-triad shape, and the half-diminished
  versus major-seventh semitone family (both directions).

**Next.** Design and measure degree-aware tiebreak rules against these three
families, guarded by the comping suite and the DCML continuity ruler.
