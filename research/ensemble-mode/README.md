# Ensemble Mode

When a pianist comps with a bass player, the left hand stops playing roots: the
bassist has that covered. So `E B♭ D A` is how a jazz pianist spells C13, even
though there is no C anywhere in it. Can the app name the chord the player
means, rather than the one the keyboard literally holds?

**Status:** complete. Shipped 2026-07-25 as a user-facing Solo/Ensemble toggle.

## What came out

- **The mode ships.** Under an explicit ensemble context the engine names
  rootless voicings at 92.5-93.6% [top-1 exact](../GLOSSARY.md#top-1-exact) on
  [held-out data](../GLOSSARY.md#development-split-and-held-out-split). The same
  engine named none of them before, so this is not an accuracy improvement but a
  capability that did not previously exist.
- **Solo analysis is byte-for-byte unchanged**, verified rather than assumed.
  Turning the mode on is the only thing that changes any answer.
- **The toggle has to be manual, and that is a finding rather than a shortcut.**
  Every one of the six solo test cases also admits a plausible rootless reading,
  so no amount of cleverness can infer the mode from pitch content. Whether a
  bassist is in the room is information only the player has, which is why it
  became part of the product contract instead of a heuristic.

## Where this fits

This initiative implements Track D of
[Chord Context](../chord-context/README.md), which measured the problem and
proved the mechanism before handing the go/no-go decision off. That groundwork
established three things:

- **The gap was total, not marginal.** Zero of twelve rootless and shell cases
  in the comping suite, and 0.0% exact across 13,197 synthesized rootless
  seventh chords.
- **The mechanism was sufficient.** Hypothesizing the absent root reaches the
  expected identity in all twelve suite cases; with a diatonic key filter, about
  82% unique-correct under the app's own inferred key and 89% under the
  annotated key, with a ceiling near 93% once a guide-tone tiebreak resolves the
  ambiguous remainder.
- **The mode could not be automatic**, for the reason above.

What it handed on: the naming errors that survive once the key is already
correct became [Ensemble Tiebreak](../ensemble-tiebreak/README.md).

Evidence for the groundwork is in chord-context log entries
[2026-07-20-16](../chord-context/log/2026-07-20-16-comping-gate.md) and
[2026-07-20-19](../chord-context/log/2026-07-20-19-rootless-corpus.md), with the
design sketch in
[rootless voicings notes](../chord-context/rootless-voicings-notes.md).

## Contents

- [Plan](ensemble-mode-plan.md): the adopted design, five phases from engine
  contract change through docs and release.
- [Protocol](PROTOCOL.md): evaluation rules; inherits the frozen chord-context
  protocol, rulers, and splits.
- [Log](log/): dated, append-only record of every experiment and decision.

Supporting code lives in `tool/chord-context/` (`comping_gate.dart`,
`rootless_corpus.dart`), extended in place rather than duplicated since it
scores against the same frozen rulers. The acceptance suite is
`research/chord-context/data/sources/comping/comping-suite-v1.json`.
