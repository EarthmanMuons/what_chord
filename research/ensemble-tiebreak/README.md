# Ensemble Tiebreak

Closing the ensemble mode's pure naming residual: the misses that remain when
the key is exactly right. The ensemble-mode initiative shipped the mode and
measured it at ~93% top-1 on held-out classical synthesis; the whatkey-local
initiative then closed the key-detection side and decomposed what was left. This
initiative implements the handoff scoped in ensemble-mode log 2026-07-26-01: two
structural confusion pairs are 88% of the annotated-key naming residual, and the
missing jazz-comping corpus turned out to be sitting in the corpus checkout the
project already pins.

Status: active (started 2026-07-26).

## Why

- The oracle-key ensemble arm misses 543 of 13,197 DCML dev events, and 88% of
  those misses are two coin flips: a rootless half-diminished seventh read as
  the major seventh a semitone below (the two leave identical sounding tones;
  264 + 49 mirror), and the two tritone-related dominants sharing a guide-tone
  tritone (163, the dyad-shell question ensemble-mode log 2026-07-25-06 parked).
- Both flips can be weighted by information the engine already holds: the scale
  degree of the candidate root in the supplied key (a half-diminished root on
  the leading tone of major or the second degree of minor is idiomatic where a
  major seventh is not; V7 outranks its flat-II substitute absent contrary bass
  evidence).
- Every ensemble number so far rests on classical synthesis. The Weimar Jazz
  Database (456 solos, real jazz vocabulary, per-solo keys) ships in the pinned
  ChoCo checkout under CC BY 4.0, so this initiative finally measures the mode
  on the genre it was built for.

## Contents

- [Protocol](PROTOCOL.md): rulers, guards, and adoption bar; inherits the frozen
  chord-context protocol.
- [Log](log/): dated, append-only record of every experiment and decision.
- Data: the frozen split lives at
  [data/splits/weimar-comping-v1.json](data/splits/weimar-comping-v1.json);
  fixtures are build-only (`build/chord-context/fixtures/weimar-comping-v1`)
  with attribution recorded in their manifest.

Supporting code: the corpus tools live in `tool/chord-context/`
(`weimar_extract.py`, `freeze_weimar_split.py`); measurement reuses
`rootless_corpus.dart` unchanged; engine changes land in `packages/whatchord/`
and must keep solo analysis bit-identical.
