# Research

Applied research that shapes WhatChord's analysis engine. App code answers "how
does the feature work"; the documents here answer "how do we know it is right"
by testing the engine's musical judgments against external corpora, other tools,
and published methods.

Everything is open: the protocols, the dated logs, the frozen data splits, the
reproduction commands, the corrections, and the ideas that did not work.

## Start here

- **Curious, but not looking for a technical read?**
  [We Can Measure Exactly How Wrong We Are](https://whatchord.earthmanmuons.com/articles/measuring-how-wrong-we-are.html)
  is a plain-English tour of the thirty-two ideas we measured and decided not to
  ship, and why keeping that record is part of the method.
- **Want the science?** [WhatKey](whatkey/) is the deepest study here and the
  only one written up as a paper. Its
  [plain-English companion](whatkey/CONTRIBUTION.md) explains what it claims and
  why it is worth reading.
- **Hit an unfamiliar term?** The [glossary](whatkey/GLOSSARY.md) defines the
  measurement vocabulary in plain English: coverage, held-out split, paired
  statistics, exact versus MIREX, and the rest.

## How the work fits together

The initiatives are not a flat list. Each one handed a measured problem to the
next, in three threads:

```
Finding the key       WhatKey ─────────────► WhatKey Local
                         │
                         ▼
Naming the chord      Chord Context ───────► Ensemble Mode ──► Ensemble Tiebreak

Surviving real        Performed Input ─────► Tone Pricing
playing
```

Chord Context also fed WhatKey Local: its measurements showed that key
detection, not chord naming, was the thing holding accuracy back.

## Initiatives

### Finding the key

**[WhatKey](whatkey/)** asks what key you are in right now, while you are still
playing, from the chord recognizer's output rather than a finished score, and
with the option to stay quiet when the evidence is too thin to call. That last
part is unusual: most key-detection research requires an answer every time.

The detector reaches at least parity with standard offline key finders that read
the whole song first, under much stricter conditions. It is written up as a
preprint, and its evaluation protocol is the one every later initiative
inherits.

**[WhatKey Local](whatkey-local/)** asks how closely that detector should chase
the brief key changes inside a piece, and what chasing them costs in the
steadiness a glanceable indicator needs.

Two changes shipped: key changes now weigh cadences, and an arbitrary rule that
kept the detector silent for its first three chords turned out to be
unnecessary. Seven other mechanisms were measured and closed.

### Naming the chord

**[Chord Context](chord-context/)** asks whether knowing the chords you just
played helps name the one you are playing now.

Mostly it does not, once the current key is already accounted for. The temporal
cues were inert or harmful against a strong baseline. Two simpler wins shipped
instead, and the investigation handed off two problems that became the next two
initiatives.

**[Ensemble Mode](ensemble-mode/)** asks whether the app can name a rootless
voicing: the kind a pianist plays when a bassist is covering the root.

It could not name any of them at all before. An explicit mode names them
reliably on held-out data, and solo analysis is verified byte-for-byte
unchanged.

**[Ensemble Tiebreak](ensemble-tiebreak/)** asks what is still misnamed once the
key is already correct.

The answer reframed the problem: the misses were readings the engine never
proposed, not readings it ranked badly. Widening what gets proposed cut the
remaining naming errors by more than half on a new jazz benchmark, with no solo
regressions.

### Surviving real playing

**[Performed Input](performed-input/)** asks how accurate the app is on real
recorded performances, with pedal blur, rolled chords, and passing tones, rather
than on the clean textbook voicings every earlier number had used.

It produced the first honest live figure, along with a decomposition of what
that figure actually contains, since much of the disagreement is a difference
between naming conventions rather than engine error. Its README explains how to
read the number without overstating it in either direction. The stability work
also moved a flicker problem out of the analyzer and into display policy,
cutting on-screen churn sevenfold.

**[Tone Pricing](tone-pricing/)** asks what a chord name should pay for a note
it cannot explain, and what discount an honest incomplete reading deserves.

Both are the same dial seen from opposite sides. One side was measured and
declined; the other shipped a single, narrowly contained new label.

## Standalone studies

Shorter, self-contained investigations rather than multi-week initiatives:

- [Chord Naming Oracle Comparison](chord-oracle-comparison.md): comparing
  WhatChord's chord names against music21, tonal, and pychord to surface edge
  cases worth musical review.
- [Chord Coverage From ChoCo](choco-chord-coverage.md): checking WhatChord's
  supported chord families against a large public corpus of real chord
  annotations.
- [Contrapunctus Benchmark Comparison](contrapunctus-benchmark-comparison.md):
  evaluating root identification and surfaced alternatives against a
  Roman-numeral analysis corpus.

## How the archive works

Each initiative directory holds the same three things:

- **README.md**: what the initiative asked, what came out, and where to look.
- **PROTOCOL.md**: the rules, fixed in writing before results were seen. What
  counts as a win, which data it is measured on, and what would falsify it.
- **log/**: dated, append-only entries recording what was tried, what happened,
  and what was decided, with the exact commands so a result can be re-run. Null
  results, reversals, and corrections stay in the record; an entry that turns
  out wrong gets a later entry correcting it rather than being edited.

Two habits run through all of it. Music is split into a development set, where
ideas may be refined, and a held-out set that stays sealed until the final
configuration is fixed, so no piece appears on both sides. And changes are
compared piece by piece against the current system rather than by overall
average, so one unusually long work cannot outvote many shorter ones.

Supporting code lives with the rest of the project: batch drivers and corpus
tooling in `tool/`, performance benchmarks in `benchmark/`, and the engine
itself under `packages/whatchord/`.
