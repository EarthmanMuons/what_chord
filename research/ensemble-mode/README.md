# Ensemble Mode

An explicit ensemble (comping) mode for WhatChord: naming rootless voicings the
way a jazz pianist means them when a bassist is covering the root. This
initiative implements Track D of the chord-context investigation
(`research/chord-context/`), which measured the problem, proved the mechanism,
and handed the go/no-go off as a product decision. That decision was made on
2026-07-25: we are building it.

Status: planning. The plan is adopted (log entry 2026-07-25-01); no engine work
has landed yet.

## Why

The shipped engine cannot name a rootless voicing: candidate roots must be
sounding pitch classes, so `E Bb D A` over a bassist's C reads as a strained
slash chord instead of C13. The chord-context measurements established:

- **Severity is total.** 0 of 12 rootless and shell cases in the comping suite;
  0.0% exact on 13,197 synthesized rootless seventh chords at corpus scale.
- **The mechanism is sufficient.** Ghost-root hypotheses reach the expected
  identity in 12/12 suite cases; with a diatonic key filter, ~82% unique-correct
  under the app's own inferred key (89% under the annotated key), with a ~93%
  ceiling once a guide-tone/dominant-color tiebreak resolves the ambiguous
  bucket.
- **The mode must be explicit.** 6/6 solo suite cases admit a ghost-root
  competitor, so auto-detection from pitch content is impossible in principle.
  Solo versus ensemble is a user-facing toggle, part of the product contract.

Evidence: chord-context log entries 2026-07-20-16 (gate) and 2026-07-20-19
(corpus scale), plus the design sketch in
`research/chord-context/rootless-voicings-notes.md`.

## Contents

- [Plan](ensemble-mode-plan.md): the adopted design and integration plan; five
  phases from engine contract change through docs and release, with progress
  tracking.
- [Protocol](PROTOCOL.md): evaluation rules for this initiative; inherits the
  frozen chord-context protocol, rulers, and splits.
- [Log](log/): dated, append-only record of every experiment and decision.

Supporting code: the measurement harnesses live in `tool/chord-context/`
(`comping_gate.dart`, `rootless_corpus.dart`), extended in place rather than
duplicated, since they score against the same frozen rulers. The acceptance
suite is `research/chord-context/data/sources/comping/comping-suite-v1.json`.
