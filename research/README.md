# Research

Applied research that shapes WhatChord's analysis engine. App code answers "how
does the feature work"; the documents here answer "how do we know it is right"
by testing the engine's musical judgments against external corpora, other tools,
and published methods.

## Standalone studies

- [Chord Naming Oracle Comparison](chord-oracle-comparison.md): comparing
  WhatChord's chord names against music21, tonal, and pychord to surface edge
  cases worth musical review.
- [Chord Coverage From ChoCo](choco-chord-coverage.md): checking WhatChord's
  supported chord families against a large public corpus of real chord
  annotations.
- [Contrapunctus Benchmark Comparison](contrapunctus-benchmark-comparison.md):
  evaluating root identification and surfaced alternatives against a
  Roman-numeral analysis corpus.

## Initiatives

- [WhatKey](whatkey/): automatic key (tonal center) detection from live playing,
  studied as streaming key estimation with abstention and written up as a
  preprint. It holds the design plan, evaluation protocol, dated logs, data
  conventions, and paper in one place.
- [Chord Context](chord-context/): using recently played chords to improve live
  chord naming (contextual re-ranking, contextual spelling, display stability,
  and a gate for rootless/ensemble voicings). Complete: findings validated on
  held-out data; every front shipped, closed by measurement, or costed.
- [Ensemble Mode](ensemble-mode/): an explicit comping mode that names rootless
  voicings over a bassist, implementing the costed Track D handoff from Chord
  Context. Complete: ~93% top-1-exact on held-out data against 0% without the
  mode, with solo analysis verified unchanged.
- [WhatKey Local](whatkey-local/): local-key accuracy for the streaming key
  detector, the bottleneck handed off by Chord Context and Ensemble Mode.
  Complete: cadence-aware transitions and a one-event warmup gate shipped (with
  an internal ensemble naming key and a one-event history relabel in the app),
  seven further mechanisms closed by measurement, and the holdout confirms
  significant coverage gains at maintained accuracy over the paper baseline.

Supporting code lives with the rest of the project: batch drivers and corpus
tooling in `tool/`, performance benchmarks in `benchmark/`, and the engine
itself under `packages/whatchord/`.
